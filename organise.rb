#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "tty-prompt"
  gem "tty-spinner"
  gem "fileutils"
  gem "tty-progressbar"
end

require "fileutils"
require "tty-prompt"
require "tty-progressbar"

DOWNLOADS = File.join(Dir.home, "Downloads")

RULES = {
  images:    %w[.jpg .jpeg .png .gif .webp .svg],
  videos:    %w[.mp4 .mov .mkv .avi .webm],
  audio:     %w[.mp3 .flac .wav .aac .ogg],
  documents: %w[.pdf .doc .docx .xls .xlsx .ppt .pptx .txt .md],
  archives:  %w[.zip .tar .gz .bz2 .7z .rar],
  data:      %w[.csv .json .xml .yaml .yml .sql],
  code:      %w[.rb .py .js .html .css .java .c .cpp .php .go .rs .swift]
}

def classify(file)
  ext = File.extname(file).downcase
  RULES.each do |category, exts|
    return category.to_s.capitalize if exts.include?(ext)
  end
  "Other"
end

def organise!
  prompt = TTY::Prompt.new
  puts "Scanning #{DOWNLOADS}…"

  files = Dir.children(DOWNLOADS).reject { |f| File.directory?(File.join(DOWNLOADS, f)) }

  if files.empty?
    prompt.ok "No files to organise."
    return
  end

  prompt.ok "#{files.size} files found."

  bar = TTY::ProgressBar.new("Organising [:bar] :current/:total", total: files.size)

  files.each do |file|
    category = classify(file)
    target_dir = File.join(DOWNLOADS, category)
    FileUtils.mkdir_p(target_dir)

    source = File.join(DOWNLOADS, file)
    dest   = File.join(target_dir, file)

    FileUtils.mv(source, dest)

    bar.advance
  end

  prompt.ok "Done! Downloads folder organised."
end

organise!

