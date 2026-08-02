#!/usr/bin/env ruby
# frozen_string_literal: true

# Inline gem loading
require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "tty-prompt"
  gem "tty-table"
end

require "tty-prompt"
require "tty-table"
require "ipaddr"

prompt = TTY::Prompt.new

# Allow CIDR via CLI argument or prompt
cidr = ARGV[0] || prompt.ask("Enter a CIDR block (e.g., 10.0.0.0/16):") do |q|
  q.required true
  q.validate(/\A\d{1,3}(\.\d{1,3}){3}\/\d{1,2}\z/, "Must be a valid CIDR")
end

begin
  net = IPAddr.new(cidr)
rescue IPAddr::InvalidAddressError => e
  abort "Invalid CIDR: #{e.message}"
end

range = net.to_range
first_ip = range.first
last_ip  = range.last
total    = range.count

table = TTY::Table.new(
  ["Field", "Value"],
  [
    ["CIDR", cidr],
    ["Network", net.to_s],
    ["Range start", first_ip.to_s],
    ["Range end", last_ip.to_s],
    ["Total hosts", total.to_s]
  ]
)

puts table.render(:ascii)
