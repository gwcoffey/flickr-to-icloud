require 'json'

CONFIG = File.open("CONFIG.json", "r") {|f| JSON.parse(f.read)}

puts "loading analysis data..."
analysis_path = File.join("out", "analysis.json")
unless File.exists? analysis_path
    STDERR.puts "unexpectedly unable to find #{analysis_path}; did you bin/run verify first?"
    exit(-1)
end
analysis_data = File.open(analysis_path, "r") {|f| JSON.parse(f.read) }
photo_meta_by_id = analysis_data["photo_meta_by_id"]
photos_by_id = analysis_data["photos_by_id"]
albums_by_id = analysis_data["albums_by_id"]
photo_ids_by_sha = analysis_data["photo_ids_by_sha"]
fave_photo_ids = analysis_data["fave_photo_ids"]
album_ids_by_photo_id = analysis_data["album_ids_by_photo_id"]


puts "mapping metadata..."
import_data = []
photo_ids_by_sha.each do |sha, photo_ids|
    photo_path = photos_by_id[photo_ids.first]

    keywords = {}
    photo_ids.each do |id|
        photo_meta_by_id[id]["tags"].map {|t| t["tag"].strip}.each {|t| keywords[t] = 1}
    end
    keywords = keywords.keys

    default_keyword = CONFIG["default_keyword"]
    keywords << default_keyword if default_keyword != nil && default_keyword != ""

    name = ""
    photo_ids.each do |id|
        name = photo_meta_by_id[id]["name"].strip
        break if name != ""
    end

    date = ""
    photo_ids.each do |id|
        date = photo_meta_by_id[id]["date_taken"]
        break if date != ""
    end

    description = ""
    photo_ids.each do |id|
        description = photo_meta_by_id[id]["description"].strip
        if CONFIG["use_first_comment_as_description"]
            if description == "" && photo_meta_by_id[id]["comments"].length > 0
                description = photo_meta_by_id[id]["comments"].first["comment"].strip
            end
        end
        break if description != ""
    end

    favorite = (fave_photo_ids & photo_ids).length > 0

    geo = nil
    photo_ids.each do |id|
        if photo_meta_by_id[id]["geo"].length > 0
            geo = [photo_meta_by_id[id]["geo"].first["latitude"].to_f / 1000000.0, photo_meta_by_id[id]["geo"].first["longitude"].to_f / 1000000.0]
            break
        end
    end

    albums = {}
    photo_ids.each do |id|
        album_ids_by_photo_id[id].each {|a| albums[a] = 1} if album_ids_by_photo_id.key?(id)
    end
    albums = albums.keys.map {|k| albums_by_id[k]["title"]}

    pages = photo_ids.map {|id| photo_meta_by_id[id]["photopage"] }
    import_data << {
        originals: pages,
        selected_photo: photo_path,
        name: name,
        date: date,
        description: description,
        favorite: favorite,
        keywords: keywords,
        location: geo,
        albums: albums,
        sha: sha
    }
end

puts "saving metadata..."
File.open(File.join("out", "import_data.json"), "w") {|f| f.write(JSON.pretty_generate(import_data)) }
puts "=> Import data is prepared. Review out/import_data.json and then bin/run import if it looks good."
