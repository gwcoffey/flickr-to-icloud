require 'json'
require "erb"
require "date"
require 'optparse'

require './src/ruby/lib/photos_scripts'

ARGV << '-h' if ARGV.empty?
CONFIG = File.open("CONFIG.json", "r") {|f| JSON.parse(f.read) }

options = {}
OptionParser.new do |opts|
    opts.banner = "Usage: bin/run import [-a] [-n COUNT] [-x]\nimport the prepared data into Photos.app; will pick up where it left off on successive runs"

    opts.on("-n COUNT", "--max-photos", "Stop import after COUNT photos (so you can inspect)") do |count|
        options[:max_count] = count.to_i
    end

    opts.on("-a", "--all", "Import all photos without stopping") do
        options[:all] = true
    end

    opts.on("-r", "--restart", "Reset progress data (next run will start over again with the first photo)") do
        options[:restart] = true
    end
end.parse!

unless options.key?(:max_count) || options.key?(:all)
    STDERR.puts "Error: you must specify either -n or -a; use -h for help"
    exit -1
end

imported_shas_path = File.join("out", "imported_shas")
if options[:restart] && File.exists?(imported_shas_path)
    File.delete(imported_shas_path)
end

imported_shas = {}
if File.exists?(imported_shas_path)
    File.open(imported_shas_path, "r") do |shafile|
        shafile.read.split("\n")
            .filter {|sha| sha != "" }
            .each {|sha| imported_shas[sha] = true }
    end
end

puts "creating folder '#{CONFIG['photos_folder_name']}' in Photos.app (if needed)..."
PhotosScripts::create_folder_if_needed(CONFIG['photos_folder_name'])

shalog = File.open(imported_shas_path, "a")

import_data = File.open(File.join("out", "import_data.json"), "r") {|f| JSON.parse(f.read) }

skip_count = 0
stop_idx = options[:max_count]
import_data.each_with_index do |datum, idx|
    break if idx >= stop_idx

    if imported_shas.key?(datum["sha"])
        skip_count += 1
        stop_idx += 1
        next
    end

    if skip_count > 0
        puts "... skipped #{skip_count} already imported photos ..."
        skip_count = 0
    end

    print "#{idx+1}: importing photo: #{datum['selected_photo']}"
    STDOUT.flush
    PhotosScripts::import_photo(datum)
    shalog.puts datum["sha"]
    puts " [DONE]"
end

if skip_count > 0
    puts "... skipped #{skip_count} already imported photos ..."
end
