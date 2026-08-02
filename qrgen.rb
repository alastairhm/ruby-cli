#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "tty-prompt"
  gem "tty-spinner"
  gem "rqrcode"
  gem "rqrcode_png"
end

require "tty-prompt"
require "tty-spinner"
require "rqrcode"
require "rqrcode_png"

prompt = TTY::Prompt.new

# -------------------------------
# Helpers
# -------------------------------

# Smart filename numbering:
# qr.png → qr_2.png → qr_3.png → ...
def next_filename(base = "qr", ext = "png")
  n = 1
  loop do
    name = n == 1 ? "#{base}.#{ext}" : "#{base}_#{n}.#{ext}"
    return name unless File.exist?(name)
    n += 1
  end
end

# Raises RQRCodeCore::QRCodeRunTimeError if text is too large to encode.
def render_qr_png(text)
  qr = RQRCode::QRCode.new(text)
  qr.as_png(size: 300, border_modules: 4).to_s
end

def generate_qr(text)
  spinner = TTY::Spinner.new("[:spinner] Generating QR code...", format: :pulse_2)
  spinner.auto_spin

  begin
    png = render_qr_png(text)
  rescue RQRCodeCore::QRCodeRunTimeError => e
    spinner.error("(failed)")
    abort "Could not generate QR code: #{e.message}"
  end

  filename = next_filename
  File.binwrite(filename, png)

  spinner.success("(done)")
  puts "Saved as #{filename}"
end

def prompt_for_text(prompt)
  prompt.ask("What text or URL should the QR code contain?") do |q|
    q.required true
  end
end

# -------------------------------
# Tiny Dispatcher
# -------------------------------
command = ARGV.shift

case command
when "generate", nil
  # Default command: generate a QR code
  text = ARGV.shift
  text = prompt_for_text(prompt) if text.nil? || text.strip.empty?
  generate_qr(text)

when "wifi"
  ssid = prompt.ask("WiFi SSID?") { |q| q.required true }
  pass = prompt.ask("WiFi Password?") { |q| q.required true }
  wifi_string = "WIFI:T:WPA;S:#{ssid};P:#{pass};;"
  generate_qr(wifi_string)

when "batch"
  file = ARGV.shift
  unless file && File.exist?(file)
    puts "Batch mode requires a valid filename"
    exit 1
  end

  File.readlines(file, chomp: true).each_with_index do |line, i|
    next if line.strip.empty?
    puts "Generating QR for line #{i + 1}: #{line}"

    begin
      png = render_qr_png(line)
    rescue RQRCodeCore::QRCodeRunTimeError => e
      puts "Skipping line #{i + 1}: #{e.message}"
      next
    end

    filename = next_filename("qr_#{i + 1}")
    File.binwrite(filename, png)
    puts "Saved as #{filename}"
  end

else
  puts "Unknown command: #{command}"
  puts
  puts "Usage:"
  puts "  qrgen generate [text]   # Generate a QR code"
  puts "  qrgen wifi              # Create a WiFi QR code"
  puts "  qrgen batch file.txt    # Generate many QR codes"
end
