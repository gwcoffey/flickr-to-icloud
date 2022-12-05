# this module makes the AppleScripts easily callable from ruby

module PhotosScripts
    # pre-compile the ERB templates
    CREATE_FOLDER_SCPT = File.open("src/applescript/create_folder.scpt.erb", "r") {|f| ERB.new(f.read) }
    IMPORT_PHOTO_SCPT = File.open("src/applescript/import_photo.scpt.erb", "r") {|f| ERB.new(f.read) }

    # creates a folder in the photo library with the given name
    def self.create_folder_if_needed(folder_name)
        osascript(CREATE_FOLDER_SCPT.result(binding))
    end

    # imports a single photo and sets its metadata
    def self.import_photo(data)
        keywords = data["keywords"].join('", "')
        keywords = '"' + keywords + '"' unless keywords == ""

        location = data["location"].nil? ? "" : data["location"].join(", ")

        albums = data["albums"].join('", "')
        albums = '"' + albums + '"' unless albums == ""

        osascript(IMPORT_PHOTO_SCPT.result(binding))
    end

    private

    # given an AppleScript as a string, run it and raise if it fails
    def self.osascript(script)
        success = system('osascript', '-s', 's', *script.split(/\n/).map { |line| ['-e', line] }.flatten)
        unless success
            puts "=== Unexpected import error ==="
            puts "Full script text: \n#{script}"
            raise "aborting because an import unexpectedly failed, see above"
        end
    end
end