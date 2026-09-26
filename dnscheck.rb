#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true, quiet: true) do
  source "https://rubygems.org"
  gem "tty-option"
  gem "tty-table"
  gem "tty-spinner"
  gem "pastel"
  gem "reline" # tty-table loads readline to size the table; silences a Ruby 3.5 deprecation warning
end

require "resolv"
require "timeout"

# Resolves a list of hostnames against one or more DNS servers and reports
# whether each server returns an answer, what it returns, and how long it
# took. Useful for spot-checking that a resolver (e.g. Pi-hole) is actually
# being used, or that internal/external DNS agree.
class DNSCheck
  include TTY::Option

  usage do
    program "dnscheck.rb"
    no_command
    desc "Resolve hostnames against one or more DNS servers and compare results"

    example "dnscheck.rb example.com"
    example "dnscheck.rb example.com github.com --servers 1.1.1.1,8.8.8.8"
    example "dnscheck.rb --file hosts.txt --servers 192.168.1.2,1.1.1.1"
    example "dnscheck.rb example.com --type AAAA --timeout 3"
  end

  argument :hostnames do
    arity zero_or_more
    desc "Hostnames to resolve"
  end

  option :servers do
    short "-s"
    long "--servers list"
    desc "Comma-separated DNS server IPs (default: system resolver, 1.1.1.1, 8.8.8.8)"
  end

  option :file do
    short "-f"
    long "--file path"
    desc "Path to a file with one hostname per line (blank lines and # comments ignored)"
  end

  option :type do
    long "--type string"
    default "A"
    desc "Record type to query: A, AAAA, CNAME, MX, TXT, NS"
  end

  option :timeout do
    short "-t"
    long "--timeout float"
    convert :float
    default 2.0
    desc "Per-query timeout in seconds"
  end

  flag :strict do
    long "--strict"
    desc "Exit with a non-zero status if any query fails or servers disagree"
  end

  flag :help do
    short "-h"
    long "--help"
    desc "Print usage"
  end

  DEFAULT_SERVERS = ["system", "1.1.1.1", "8.8.8.8"].freeze

  RECORD_TYPES = {
    "A" => Resolv::DNS::Resource::IN::A,
    "AAAA" => Resolv::DNS::Resource::IN::AAAA,
    "CNAME" => Resolv::DNS::Resource::IN::CNAME,
    "MX" => Resolv::DNS::Resource::IN::MX,
    "TXT" => Resolv::DNS::Resource::IN::TXT,
    "NS" => Resolv::DNS::Resource::IN::NS
  }.freeze

  def run
    parse_params!

    hosts = collect_hosts
    abort_with("No hostnames given. Pass them as arguments or use --file.") if hosts.empty?

    servers = collect_servers
    record_type = lookup_record_type
    results = resolve_all(hosts, servers, record_type)

    print_table(results)
    report_outcome(results)
  end

  private

  def parse_params!
    parse
    if params[:help]
      print help
      exit 0
    end
    return unless params.errors.any?

    puts pastel.red(params.errors.summary)
    print help
    exit 1
  end

  def abort_with(message)
    puts pastel.red(message)
    exit 1
  end

  def lookup_record_type
    RECORD_TYPES.fetch(params[:type].to_s.upcase) do
      abort_with("Unknown record type '#{params[:type]}'. Supported: #{RECORD_TYPES.keys.join(', ')}")
    end
  end

  # Returns { host => { server_label => [result, elapsed_ms] } }, showing a
  # spinner with progress while the (blocking) lookups run.
  def resolve_all(hosts, servers, record_type)
    total = hosts.size * servers.size
    done = 0
    spinner = TTY::Spinner.new(":spinner Resolving :query", format: :dots, clear: true, hide_cursor: true)
    spinner.update(query: "")
    spinner.auto_spin

    hosts.to_h do |host|
      by_server = servers.to_h do |label, server_ip|
        done += 1
        spinner.update(query: "#{host} via #{label} (#{done}/#{total})")
        [label, resolve(host, server_ip, record_type)]
      end
      [host, by_server]
    end
  ensure
    spinner&.stop
  end

  def print_table(results)
    rows = []
    results.each_with_index do |(host, by_server), i|
      rows << :separator if i.positive?
      by_server.each do |label, (result, elapsed_ms)|
        rows << [host, label, colorize(result), failed?(result) ? "-" : "#{elapsed_ms} ms"]
      end
    end

    table = TTY::Table.new(header: ["Host", "Server", "Result", "Time"], rows: rows)
    puts table.render(:unicode, padding: [0, 1], alignment: [:left], resize: true)
  end

  def report_outcome(results)
    any_failure = any_failure?(results)
    disagreement = results.values.any? { |by_server| disagree?(by_server) }

    if disagreement
      puts
      puts pastel.yellow("⚠ Servers returned different results for at least one host.")
    end

    exit 1 if params[:strict] && (any_failure || disagreement)
  end

  def any_failure?(results)
    results.values.flat_map(&:values).any? { |result, _| failed?(result) }
  end

  def failed?(result)
    result.start_with?("FAIL")
  end

  def disagree?(by_server)
    by_server.values.map(&:first).reject { |result| failed?(result) }.uniq.size > 1
  end

  def pastel
    @pastel ||= Pastel.new
  end

  def colorize(result)
    if failed?(result)
      pastel.red(result)
    else
      pastel.green(result)
    end
  end

  def collect_hosts
    # tty-option returns nil for no args, a String for one, an Array for many
    hosts = Array(params[:hostnames])

    if params[:file]
      unless File.exist?(params[:file])
        puts pastel.red("File not found: #{params[:file]}")
        exit 1
      end
      File.readlines(params[:file]).each do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")

        hosts << line
      end
    end

    hosts.uniq
  end

  def collect_servers
    labels = params[:servers] ? params[:servers].split(",").map(&:strip) : DEFAULT_SERVERS
    labels.map do |label|
      if label == "system"
        ["system", nil]
      else
        [label, label]
      end
    end
  end

  def resolve(host, server_ip, record_type)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    answer = Timeout.timeout(params[:timeout]) do
      resolver = server_ip ? Resolv::DNS.new(nameserver: [server_ip]) : Resolv::DNS.new
      resolver.getresources(host, record_type)
    end

    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

    if answer.empty?
      ["FAIL (no answer)", elapsed_ms]
    else
      [format_answer(answer), elapsed_ms]
    end
  rescue Timeout::Error
    ["FAIL (timeout)", nil]
  rescue Resolv::ResolvError => e
    ["FAIL (#{e.message})", nil]
  rescue StandardError => e
    ["FAIL (#{e.class}: #{e.message})", nil]
  end

  def format_answer(answer)
    values = answer.map do |r|
      case r
      when Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA
        r.address.to_s
      when Resolv::DNS::Resource::IN::CNAME, Resolv::DNS::Resource::IN::NS
        r.name.to_s
      when Resolv::DNS::Resource::IN::MX
        "#{r.preference} #{r.exchange}"
      when Resolv::DNS::Resource::IN::TXT
        r.strings.join(" ")
      else
        r.to_s
      end
    end
    # Sort so servers returning the same records in a different order don't count as disagreeing
    values.uniq.sort.join(", ")
  end
end

DNSCheck.new.run if $PROGRAM_NAME == __FILE__
