require 'json'
require 'digest'

## discover the metadata folders
photo_dirs = []
meta_dirs = []

Dir.each_child("in") do |dir|
    path = File.join("in", dir)
    next unless File.directory?(path)
    case dir
    when /^data-download-\d+$/
        photo_dirs << path
    else
        meta_dirs << path
    end
end

## check for non-sequential photo directories
photo_dir_numbers = photo_dirs.map {|d| d.match(/\d+$/)[0].to_i }.sort
photo_dir_number_gaps = (photo_dir_numbers[0]...photo_dir_numbers[-1]).to_a - photo_dir_numbers
if photo_dir_number_gaps.length > 1
    puts("Warning: photo directory numbers are non-sequential; did you miss some downloads? Missing: #{photo_dir_number_gaps}")
end

puts "found #{meta_dirs.length} metadata folder(s) and #{photo_dirs.length} photo folder(s)"

## discover the albums metadata file
albums_path = nil
meta_dirs.each do |meta_dir|
    path = File.join(meta_dir, "albums.json")
    if File.exists?(path)
        albums_path = path
        break
    end
end

if albums_path.nil?
    puts "Failed: unexpectedly unable to find albums.json in the metadata"
    exit(-1)
else
    puts "found album metadata in #{albums_path}"
end


## discover the faves metadata files
faves_paths = []
meta_dirs.each do |meta_dir|
    Dir.each_child(meta_dir) do |path|
        if path =~ /^faves_part\d+.json$/
            faves_paths << File.join(meta_dir, path)
        end
    end
end

if faves_paths.length == 0
    puts "Warning: no faves metadata files found; this may be ok but if you have faves something may be wrong"
else
    puts "found faves metadata in #{faves_paths.length} file(s):"
    faves_paths.each {|p| puts "   #{p}" }
end

## discover photo metadata files
photo_meta_paths = []
meta_dirs.each do |meta_dir|
    Dir.each_child(meta_dir) do |path|
        if path =~ /^photo_\d+.json$/
            photo_meta_paths << File.join(meta_dir, path)
        end
    end
end

if photo_meta_paths.length == 0
    puts "Error: unexpectedly found no photo metadata files (photo_{id}.json)"
    exit(-1)
else
    puts "found #{photo_meta_paths.length} photo metadata file(s)"
end


## discover photo files
photo_paths = []
photo_dirs.each do |photo_dir|
    Dir.each_child(photo_dir) do |path|
        photo_path = File.join(photo_dir, path)
        unless File.directory?(photo_path)
            photo_paths << photo_path
        end
    end
end

if photo_paths.length == 0
    puts "Error: unexpectedly found no photo files (in `data-download-nnn` directories)"
    exit(-1)
else
    puts "found #{photo_paths.length} photo file(s)"
end


## index photo metadata by id
puts "determining photo ids of photo files, this may take a few seconds..."
photo_meta_by_id = {}
photo_meta_paths.each do |photo_meta_path|
    name_id = photo_meta_path.match(/photo_(\d+).json$/)[1]
    meta = File.open(photo_meta_path, "r") {|f| JSON.parse(f.read) }
    meta_id = meta["id"]

    if meta_id != name_id
        puts "Error: file #{photo_meta_path} has id #{name_id} in filename, but id #{meta_id} in content; cowardly refusing to go on"
        exit(-1)
    end

    photo_meta_by_id[meta_id] = meta
end

## discover photo file ids and index by id
photos_by_id = {}
photo_ids_by_path = {}
photo_paths.each do |photo_path|
    # extract integer numbers from the filename -- one of these will be the id but the position
    # is inconsistent
    hits = []
    photo_path.scan(/\d{4,}/) do |candidate|
        # keep only the numbers that match some photo id
        hits << candidate if photo_meta_by_id.key?(candidate)
    end

    # if there are multiple possible we take the last one because that is what worked
    # for *all* my cases; these seem to happen when a photo was downloaded from Flickr,
    # modified in some way, and re-uploaded as a new photo; in that case the name is
    # roughly {old name}_{new_id}.{ext} and the old name has the old id in it.
    if hits.length != 1
        puts "Warning: photo #{photo_path} has multiple ids in its name (#{hits.join(',')}); guessing it is #{hits.last}"
    end

    photos_by_id[hits.last] = photo_path
    photo_ids_by_path[photo_path] = hits.last
end

# calculate shas for every photo
puts "calculating shas, this may take a few minutes..."
shas_by_photo_id = {}
photo_ids_by_sha = {}
photo_paths.each do |photo_path|
    sha = File.open(photo_path, "r") {|f| Digest::SHA1.hexdigest(f.read) }
    shas_by_photo_id[photo_ids_by_path[photo_path]] = sha
    photo_ids_by_sha[sha] ||= []
    photo_ids_by_sha[sha] << photo_ids_by_path[photo_path]
end

## load all albums
albums_by_id = {}
File.open(albums_path, "r") do |f|
    JSON.parse(f.read)["albums"].each do |album|
        albums_by_id[album["id"]] = album
    end
end

puts "found #{albums_by_id.length} albums"

# index album ids by photo id
album_ids_by_photo_id = {}
albums_by_id.each_value do |album|
    album["photos"].select {|id| id != "0" }.each do |id|
        album_ids_by_photo_id[id] ||= []
        album_ids_by_photo_id[id] << album["id"]
    end
end

# load faves
fave_photo_ids = []
faves_paths.each do |fave_path|
    faves = File.open(fave_path, "r") {|f| JSON.parse(f.read)}
    faves["faves"].each do |fave|
        fave_photo_ids << fave["photo_id"]
    end
end
puts "found #{fave_photo_ids.length} faves"

# write analysis data for use by the prepare script
puts "saving analysis data for future use..."
File.open(File.join("out", "analysis.json"), "w") do |outfile|
    out = {
        photo_meta_by_id: photo_meta_by_id,
        photos_by_id: photos_by_id,
        albums_by_id: albums_by_id,
        album_ids_by_photo_id: album_ids_by_photo_id,
        photo_ids_by_sha: photo_ids_by_sha,
        fave_photo_ids: fave_photo_ids
    }
    outfile.write(JSON.pretty_generate(out))
end


# detect problems
puts "looking for problems..."
photo_no_meta = photos_by_id.keys - photo_meta_by_id.keys
meta_no_photo = photo_meta_by_id.keys - photos_by_id.keys
album_no_photo = album_ids_by_photo_id.keys - photos_by_id.keys
photo_no_album = photos_by_id.keys - album_ids_by_photo_id.keys
fave_no_photo = fave_photo_ids - photos_by_id.keys

duplicate_photos = photo_ids_by_sha.select {|sha, ids| ids.size > 1}

album_names = albums_by_id.values.map {|a| a["title"]}
duplicate_album_names = album_names.select{ |a| album_names.count(a) > 1 }.uniq

# report problems
print "Error: " if photo_no_meta.length > 0
puts "#{photo_no_meta.length} photos have a photo file but no meta file"
photo_no_meta.each {|id| puts "  ID #{id} #{photos_by_id[id]}" }

print "Error: " if meta_no_photo.length > 0
puts "#{meta_no_photo.length} photos have a meta file but no photo file"
meta_no_photo.each {|id| puts "  ID #{id} #{photo_meta_by_id[id]["original"]}" }

print "Error: " if album_no_photo.length > 0
puts "#{album_no_photo.length} missing photos referenced in albums "
album_no_photo.each {|id| puts "  ID #{id} ALBUMS #{album_ids_by_photo_id[id]}" }

print "Warning: " if duplicate_photos.length > 0
puts "#{duplicate_photos.length} sets of duplicate photos found, only one will be imported and metadata will be merged"
duplicate_photos.each do|sha, ids|
    puts "   #{ids.size} duplicates:"
    ids.each do |id|
        print "      ID #{id}: "
        if photo_meta_by_id.key? id
            puts "#{photo_meta_by_id[id]["original"]}"
        else
            puts "** no meta found for this photo **"
        end
    end
end

print "Warning: " if duplicate_album_names.length > 0
puts "#{duplicate_album_names.length} duplicate album names, they will be merged"
duplicate_album_names.each {|name| puts "  Album name: #{name}" }

puts "FYI: #{fave_no_photo.length} of #{fave_photo_ids.length} faves are for photos not in the export (probably OK)"
puts "FYI: #{photo_no_album.length} of #{photos_by_id.length} photos are in no albums (probably OK)"

if (photo_no_meta|meta_no_photo|album_no_photo).empty?
    puts "=> No critical problems found, but please review above"
else
    puts "=> Critical problems found, please review above"
end
