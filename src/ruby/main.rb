# main entry point

require 'optparse'

options = {}

subtext = <<HELP
Commands:
    clean
     remove all derived data and return pristine state

    verify
     verifies consistency of the Flickr export data

    prepare
     processes the export data and prepares data for review and import

    import [-a] [-n COUNT] [-x]
     import the prepared data into Photos.app; will pick up where it left off on successive runs
     options:
        -a import all photos without stopping
        -n stop import after COUNT photos (so you can inspect)
        -x reset progress data (next run will start over again with the first photo)
HELP

global = OptionParser.new do |opts|
    opts.banner = "Usage: bin/run COMMAND [options]"
    opts.separator ""
    opts.separator subtext
end.parse!

subcommands = {
    'verify' => OptionParser.new do |opts|
        opts.banner = "Usage: verify"
    end,
    'prepare' => OptionParser.new do |opts|
        opts.banner = "Usage: prepare"
    end,
    'import' => OptionParser.new do |opts|
        opts.banner = "Usage: import [-n COUNT] [-a]"
        opts.on("-n", "--max-photos COUNT", "Stop importing after COUNT photos (so you can inspect)") do |lib|
            puts "You required #{lib}!"
        end
    end
}

command = ARGV.shift

puts options

case command
when 'verify'
when 'prepare'
    require './src/ruby/prepare'
when 'import'
    require './src/ruby/import'
else
    STDERR.puts("unknown command: #{command}, use -h for help")
end