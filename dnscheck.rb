#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true, quiet: true) do
  source "https://rubygems.org"
  gem "tty-option"
  gem "tty-table"
  gem "tty-spinner"
  gem "pastel"
  gem "tty-cursor"
  gem "tty-screen"
  gem "strings"
  gem "reline" # tty-table loads readline to size the table; silences a Ruby 3.5 deprecation warning
end

require "io/console"
require "ipaddr"
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
    example "dnscheck.rb                  # no hostnames: interactive TUI"
  end

  argument :hostnames do
    arity zero_or_more
    desc "Hostnames to resolve (omit, with no --file, for the interactive TUI)"
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
    servers = collect_servers
    record_type = lookup_record_type

    if interactive?
      TUI.new(self, servers, params[:type].to_s.upcase).run
      return
    end

    hosts = collect_hosts
    abort_with("No hostnames given. Pass them as arguments or use --file.") if hosts.empty?

    results = resolve_all(hosts, servers, record_type)
    print_table(results)
    report_outcome(results)
  end

  # Resolves one host against every server in parallel.
  # Returns { server_label => [result, elapsed_ms] } in server order.
  def lookup(host, servers, record_type)
    threads = servers.map do |label, server_ip|
      Thread.new { [label, resolve(host, server_ip, record_type)] }
    end
    threads.to_h(&:value)
  end

  def failed?(result)
    result.start_with?("FAIL")
  end

  def disagree?(by_server)
    by_server.values.map(&:first).reject { |result| failed?(result) }.uniq.size > 1
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

  # No hostnames and no --file on a real terminal drops into the TUI.
  def interactive?
    Array(params[:hostnames]).empty? && params[:file].nil? && $stdin.tty? && $stdout.tty?
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
    total = hosts.size
    done = 0
    spinner = TTY::Spinner.new(":spinner Resolving :query", format: :dots, clear: true, hide_cursor: true)
    spinner.update(query: "")
    spinner.auto_spin

    hosts.to_h do |host|
      done += 1
      spinner.update(query: "#{host} (#{done}/#{total})")
      [host, lookup(host, servers, record_type)]
    end
  ensure
    spinner&.stop
  end

  def print_table(results)
    value_width = result_column_width(results)
    rows = []
    results.each_with_index do |(host, by_server), i|
      rows << :separator if i.positive?
      by_server.each do |label, (result, elapsed_ms)|
        rows << [host, label, colorize(result, value_width), failed?(result) ? "-" : "#{elapsed_ms} ms"]
      end
    end

    table = TTY::Table.new(header: ["Host", "Server", "Result", "Time"], rows: rows)
    puts table.render(:unicode, padding: [0, 1], alignment: [:left], multiline: true)
  end

  # Room left for the Result column once the other columns and borders are
  # drawn. Values are truncated to fit rather than using tty-table's resize,
  # which mangles narrow columns (and can crash) when one value is very long.
  def result_column_width(results)
    host_width = results.keys.map(&:size).max
    label_width = results.values.first.keys.map(&:size).max
    used = [host_width, 4].max + [label_width, 6].max + 8 + 13 # time column, borders + padding
    [TTY::Screen.width - used, 20].max
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

  def pastel
    @pastel ||= Pastel.new
  end

  # One value per line, so multi-record answers stay narrow in the table.
  def colorize(result, width)
    return pastel.red(Strings.truncate(result, width)) if failed?(result)

    result.split(", ").map { |value| pastel.green(Strings.truncate(value, width)) }.join("\n")
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

  # Sorted so servers returning the same records in a different order don't
  # count as disagreeing: IPs numerically, MX by preference, the rest by text.
  def format_answer(answer)
    answer.map { |r| [sort_key(r), record_value(r)] }.uniq.sort.map(&:last).join(", ")
  end

  def record_value(record)
    case record
    when Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA
      record.address.to_s
    when Resolv::DNS::Resource::IN::CNAME, Resolv::DNS::Resource::IN::NS
      record.name.to_s
    when Resolv::DNS::Resource::IN::MX
      "#{record.preference} #{record.exchange}"
    when Resolv::DNS::Resource::IN::TXT
      record.strings.join(" ")
    else
      record.to_s
    end
  end

  def sort_key(record)
    case record
    when Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA
      [IPAddr.new(record.address.to_s).to_i, ""]
    when Resolv::DNS::Resource::IN::MX
      [record.preference, record.exchange.to_s]
    else
      [0, record_value(record)]
    end
  end
end

class DNSCheck
  # Full-screen interactive mode: a large scrolling results box on top and a
  # one-line input box at the bottom. Each line entered is one or more
  # hostnames (space/comma separated), optionally with a record type such as
  # MX. A blank line, Esc or Ctrl-C exits.
  class TUI
    SPINNER_FRAMES = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
    INPUT_HEIGHT = 3
    MIN_WIDTH = 40
    MIN_HEIGHT = 10
    TIME_WIDTH = 8
    KEY_PATTERN = /\e\[[0-9;]*[~A-Za-z]|\eO[A-Za-z]|\e|./m
    KEY_ACTIONS = {
      "\r" => :submit, "\n" => :submit,
      "\u007F" => :backspace, "\b" => :backspace,
      "\x15" => :clear_input, # Ctrl-U
      "\x03" => :quit, "\x04" => :quit, "\e" => :quit, # Ctrl-C, Ctrl-D, Esc
      "\e[A" => :history_back, "\eOA" => :history_back,
      "\e[B" => :history_forward, "\eOB" => :history_forward,
      "\e[5~" => :page_up, "\e[6~" => :page_down
    }.freeze

    def initialize(checker, servers, default_type)
      @checker = checker
      @servers = servers
      @default_type = default_type
      @pastel = Pastel.new
      @cursor = TTY::Cursor
      @lines = []
      @input = +""
      @history = []
      @history_index = nil
      @scroll = 0
      @notice = nil
    end

    def run
      trap("WINCH") { @resized = true }
      $stdout.print "\e[?1049h" # switch to the alternate screen, restored on exit
      $stdin.raw { event_loop }
    ensure
      trap("WINCH", "DEFAULT")
      $stdout.print @cursor.show, "\e[?1049l"
      $stdout.flush
    end

    private

    def event_loop
      redraw
      loop do
        redraw if @resized
        chunk = read_input
        next if chunk.nil?

        return if chunk.scan(KEY_PATTERN).any? { |key| handle_key(key) == :quit }
        redraw
      end
    end

    def read_input
      return unless $stdin.wait_readable(0.1)

      chunk = $stdin.read_nonblock(1024, exception: false)
      chunk.nil? ? "\x04" : chunk # EOF on stdin behaves like Ctrl-D
    end

    # Returns :quit when the TUI should exit.
    def handle_key(key)
      action = KEY_ACTIONS[key]
      return send(action) if action

      @input << key if key.match?(/\A[[:print:]]\z/)
      nil
    end

    def quit = :quit
    def backspace = @input.chop! && nil
    def clear_input = @input.clear && nil
    def history_back = recall_history(-1)
    def history_forward = recall_history(1)
    def page_up = (@scroll += results_height / 2) && nil
    def page_down = (@scroll = [@scroll - (results_height / 2), 0].max) && nil

    def submit
      line = @input.strip
      return :quit if line.empty?

      @history << line unless @history.last == line
      @history_index = nil
      @input = +""
      @notice = nil
      hosts, type = parse_line(line)
      if hosts.empty?
        @notice = "No hostname in \"#{line}\""
      else
        hosts.each { |host| look_up(host, type) }
      end
      nil
    end

    # Splits "bbc.com, github.com mx" into hosts and an optional record type.
    def parse_line(line)
      tokens = line.split(/[\s,]+/).reject(&:empty?)
      types, hosts = tokens.partition { |token| RECORD_TYPES.key?(token.upcase) }
      [hosts.uniq, types.last&.upcase || @default_type]
    end

    def recall_history(step)
      return if @history.empty?

      index = (@history_index || @history.size) + step
      if index >= @history.size
        @history_index = nil
        @input = +""
      else
        @history_index = index.clamp(0, @history.size - 1)
        @input = @history[@history_index].dup
      end
    end

    # Runs the lookup on a background thread so the spinner keeps animating.
    def look_up(host, type)
      worker = Thread.new { @checker.lookup(host, @servers, RECORD_TYPES.fetch(type)) }
      frame = 0
      while worker.alive?
        draw_busy("#{SPINNER_FRAMES[frame % SPINNER_FRAMES.size]} Resolving #{host} (#{type})…")
        frame += 1
        worker.join(0.08)
      end
      add_result(host, type, worker.value)
      @scroll = 0
    end

    def add_result(host, type, by_server)
      @lines << "" unless @lines.empty?
      @lines << result_header(host, type, by_server)
      @lines.concat(result_rows(by_server))
    end

    def result_header(host, type, by_server)
      header = "#{@pastel.bold.cyan(host)} #{@pastel.dim(type)}"
      header += "  #{@pastel.yellow('⚠ servers disagree')}" if @checker.disagree?(by_server)
      header
    end

    # One row per server; multi-value answers continue on following lines so
    # nothing gets truncated. Widths are recomputed on each redraw.
    def result_rows(by_server)
      by_server.flat_map do |label, (result, elapsed_ms)|
        failed = @checker.failed?(result)
        values = failed ? [result] : result.split(", ")
        time = failed ? "-" : "#{elapsed_ms} ms"
        values.each_with_index.map do |value, i|
          { label: i.zero? ? label : "", value: value, failed: failed, time: i.zero? ? time : "" }
        end
      end
    end

    # --- drawing ---------------------------------------------------------

    def width = TTY::Screen.width
    def height = TTY::Screen.height
    def inner_width = width - 4
    def results_height = height - INPUT_HEIGHT - 2

    def redraw
      @resized = false
      out = +@cursor.hide
      out << @cursor.clear_screen
      if width < MIN_WIDTH || height < MIN_HEIGHT
        out << @cursor.move_to(0, 0) << "Too small (min #{MIN_WIDTH}x#{MIN_HEIGHT})"
      else
        out << draw_results << draw_input
      end
      $stdout.print out
      $stdout.flush
    end

    def draw_results
      rendered = (@lines.empty? ? placeholder : @lines).map { |line| render_line(line) }
      @scroll = @scroll.clamp(0, [rendered.size - results_height, 0].max)
      last = rendered.size - @scroll
      visible = rendered[[last - results_height, 0].max...last]

      title = "DNS Check · #{@servers.map(&:first).join(', ')} · type #{@default_type}"
      above = last - visible.size
      title += " · ↑#{above} ↓#{@scroll} (PgUp/PgDn)" if above.positive? || @scroll.positive?
      frame(0, results_height + 2, title, visible)
    end

    def draw_input
      title = @notice ? @pastel.yellow(@notice) : "Domain(s) + optional type · Enter to look up · blank line exits"
      visible = @input[-(inner_width - 2)..] || @input
      out = frame(height - INPUT_HEIGHT, INPUT_HEIGHT, title, ["#{@pastel.cyan('›')} #{visible}"])
      out << @cursor.move_to(4 + visible.size, height - 2) << @cursor.show
    end

    def draw_busy(message)
      $stdout.print @cursor.hide, frame(height - INPUT_HEIGHT, INPUT_HEIGHT, "Working…", [@pastel.yellow(message)])
      $stdout.flush
    end

    def placeholder
      [
        @pastel.dim("Type one or more domains below and press Enter, e.g."),
        @pastel.dim("  bbc.com github.com"),
        @pastel.dim("  gmail.com mx"),
        "",
        @pastel.dim("Up/Down: previous input · PgUp/PgDn: scroll"),
        @pastel.dim("Blank line, Esc or Ctrl-C: exit")
      ]
    end

    # Rows are either plain strings (headers/blank) or hashes (server rows).
    def render_line(line)
      return truncate(line) if line.is_a?(String)

      label_width = @servers.map { |label, _| label.size }.max
      value_width = [inner_width - label_width - TIME_WIDTH - 4, 10].max
      value = truncate(line[:value], value_width).ljust(value_width)
      value = line[:failed] ? @pastel.red(value) : @pastel.green(value)
      "  #{line[:label].ljust(label_width)}  #{value}#{@pastel.dim(line[:time].rjust(TIME_WIDTH))}"
    end

    def truncate(text, max = inner_width)
      Strings::Truncate.truncate(text, max, trailing: "…")
    end

    # Draws a rounded box at row `top` spanning the full width.
    def frame(top, rows, title, content)
      out = +@cursor.move_to(0, top) << top_border(title)
      (1..(rows - 2)).each do |i|
        out << @cursor.move_to(0, top + i) << "│ " << (content[i - 1] || "")
        out << @cursor.move_to(width - 1, top + i) << "│"
      end
      out << @cursor.move_to(0, top + rows - 1) << "╰#{'─' * (width - 2)}╯"
    end

    def top_border(title)
      title_text = " #{truncate(title, width - 8)} "
      fill = "─" * [width - 3 - Strings::ANSI.sanitize(title_text).size, 0].max
      "╭─#{title_text}#{fill}╮"
    end
  end
end

DNSCheck.new.run if $PROGRAM_NAME == __FILE__
