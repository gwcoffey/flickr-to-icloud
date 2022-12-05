# Flicker to iCloud

With the Shared Library feature in macOs Ventura, my wife decided it was time to abandon Flickr after many years. 

This project documents the process I used and the scripts I wrote to import her photos into the macOS Photos app. The goal was to preserve the metadata that was important to her.

> **Warning:** Use at your own risk.
>
> I make no guarantee that this will work cleanly with any other Flickr export. I did all the work to import her 30,000 photos so I figured I'd share this in case it helps someone in the same situation. I'm not particularly experienced with Flickr, Photos, or AppleScript so YMMV.

This project was tested on macOS Ventura with developer tools installed. In theory it should work with a base install.

## Quick Start

1. Fork and check out this repo on macOS Ventura./
2. On Flickr, request to [Download all your content](https://www.flickrhelp.com/hc/en-us/articles/4404079675156-Downloading-content-from-Flickr) and then download all the files, unzip each into a folder, and put them in the `in` folder in this project.
3. Run these steps:

```sh
$ cd flicker-to-icloud
$ bin/run verify
$ bin/run prepare
$ bin/run import -n 100
```

For help on commands:

```sh
$ bin/run -h
```

> Note: The commands never modify the contents of `./in` so your original import remains untouched. It is safe to `bin/run clean` and start the process over, with the caveat that any photos you've imported into Photos.app will need to manually be deleted. They're all added to a special album called `ALL` and tagged so they're easy to find.

## Commands

The `bin/run` script in the repo supports four commands:

* `verify`: Verify the consistency of the Flickr export data.
* `prepare`: Processes the export data and prepares data for review and import
* `import`: Import the prepared data into Photos.app
* `clean`: Remove all derived data from the project directory (NOT the Photos.app itself) and return to pristine state.

Each is explained in more detail below.

### Command `verify` ([Source](https://github.com/gwcoffey/flickr-to-icloud/blob/main/src/ruby/verify.rb))

The `verify` command analyzes the contents of `./in` to ensure it is a complete and consistent Flickr full data export. Among other things it:

* Warns you if you seem to have missed one of the downloads.
* Makes sure every photo has metadata, and every metadata file has a corresponding photo.
* Figures out the Flickr `photo_id` of each photo file and produces a warning if it has to guess.
* Detects *exact* duplicate photos and warns about them.

See [Troubleshooting]() below for tips on how to deal with any errors this step produces.

### Command `perpare` ([Source](https://github.com/gwcoffey/flickr-to-icloud/blob/main/src/ruby/prepare.rb))

> Note: This command uses the `./out/analysis.json` file produced by `verify`. You must run `verify` first. And if you make any changes to the contents of `./in` you need to run `verify` again.

The `prepare` command prepares data for import into Photos.app. It writes a file to `./out/import_data.jaon` with one entry for each photo. An entry looks like this:

```json
{
  "originals": [
    "https://www.flickr.com/photos/someuser/123456789/",
    "https://www.flickr.com/photos/someuser/987654321/"      
  ],
  "selected_photo": "in/data-download-16/my_photo_123456789.jpg",
  "name": "My Photo Name",
  "date": "2008-10-04 13:27:35",
  "description": "My photo description",
  "favorite": false,
  "keywords": [
    "keyword_one",
    "keyword_two"
  ],
  "location": [
    37.504833,
    -92.082333
  ],
  "albums": [
    "My Album #1",
    "My Album #2"
  ],
  "sha": "b897d2c225f26649c49fc738d49ca09e85ae466f"
}
```

You can then review this file to see how your metadata is being mapped to Photos.app fields. 

Here's how I mapped the Flickr metadata to Photos.app:

* Flickr `name` -> Photos `Name`
* Flickr `tags` -> Photos `Keywords`
* Flickr `description` -> Photos `Description`
* FLickr `date_taken` -> Photos `Date`
* Flickr `fave` -> Photos `Favorite` (Hear icon)
* Flickr `geo` -> Photos `Location`
* Flickr `albums` -> Photos `Albums`

In addition, for convenience when troubleshooting and verifying 
results, I also:

* Add the `flickr` keyword to every imported photo. (You can change this keyword in the config, see below.)
* If a photo has no description, and it does have comments, I put the text of the first comment into the description. (This may not be appropriate in your case. You can turn this off in the config, see below.)

I **do not** preserve this data from Flickr:
* `comments` (with the caveat above)
* `account_profile` information
* `contacts` (your friends)
* `followers`
* `galleries` (shared albums you've contributed to)
* `groups` and `group_discussions`

### Command `import` ([Source](https://github.com/gwcoffey/flickr-to-icloud/blob/main/src/ruby/import.rb))

> Note: This command uses the `./out/import_data.json` file produced by `prepare`. You must run `prepare` first. And if you make any changes to the contents of `./in` you need to start over.

The `import` command actually imports data into Photos.app. It does this by processing `./out/import_data.json` item by item and triggering an "Import" operation in Photos.app for each one. It:

1. Imports the photo to the library with duplicate checking disabled (I could not find a way to stop Photos.app from interrupting the process when it detects duplicates).
2. Updates the metadata on the photo to match the import data file.
3. Adds the photo to each appropriate album.
4. Adds the photo to a special album called "All" so you can easily find them all in one place.

This command runs in two modes:

* `bin/run import -n COUNT`: This will import COUNT photos, and then stop so you can inspect the results. If you run this command again it will pick up where it left off.
* `bin/run import -a`: This will import all files (skipping any you already imported). Do this once you're confident.

It is highly likely some problem will cause the import to abort. If this happens you can fix the problem and start again. The script will pick up where you left off. (If you want to start from the beginning, pass the `-r` switch to the `import` command.)

> Note: It may very well be faster/more efficient to import a batch of photos instead of doing one at a time. But it was cumbersome to reliably *find* the correct photos after import. And I need to find them again to add them to multiple albums and set the metadata. So for simplicity I do them one at a time. In my case the script could import about 1,000 photos per hour.

### Command `clean` ([Source](https://github.com/gwcoffey/flickr-to-icloud/blob/main/bin/run#L5))

This command deletes all the artifacts the scripts put in `./out`. The contents of `./in` are never modified so once you `clean` you can start over again.

## Troubleshooting Verify

### Warning: photo ... has multiple ids in its name...

Flickr makes matching photos to their metadata difficult. The photo filenames contain the `photo_id` but not in a consistent location. The script extracts every number from the file name and checks which one matches a `photo_id` from the metadata files. In most casese this works fine. But it is possible a photo filename has two different numbers that match different existing `photo_id`s.

In my (limited) experience, this seems to happen when a Flickr photo was downloaded, modified, and re-uploaded as a new photo. Again, in my experience, it is the *last* id in the filename that counts. So the script makes this choice. But it always warns when it does this so you can inspect the files and see for sure. This rule worked for all my data but if it doesn't for you you may need to rename the offending photo file and re-verify, or modify the code.

### Error: ... photos have a photo file but no meta file

This means there is an image file in the data download folders that is not referenced by any metadata file. This probably means you missed one or nmore of the "Account Data" downloads.

### Error: ... photos have a meta file but no photo file

This means there is a photo metadata file. But the photo file it references does not exist. This probably means you missed one or more of the "Photos and Videos" downloads.

### Error: ... missing photos referenced in albums

This means the `albums.json` file references photo ids that are not in your export. I don't expect this to happen but if it does it probably means your data dump is corrupted in some way. Try re-downloading all the files from scratch.

### Warning: ... sets of duplicate photos found ...

This means some of your photos are *exact* duplicates. (This is based on sha1 hashing. It is not smart in any way. The files have to be byte-for-byte identical to be detected.) When this happens the script will output each set of duplicates with links to the Flickr pages for each. You can quickly check the links to verify the photos really are identical.

You don't need to *do* anything about this. The script will only import one of the duplicated photos, but it will merge the keywords and search for other metadata across all photos. So you won't lose anything.

### Warning: ... duplicate album names, they will be merged

The AppleScripts will create photo albums with the same name as each Flickr album. While Flicker and Photos.app both support duplicate album names in the same container, this script is not smart enough to deal with it. It will just merge the two albums into one. If you don't want this to happen you'll have to do a some work to either improve the code or (yuck) manually modify the individual Flicker JSON files.

### FYI: ... faves are for photos not in the export

This just means some of the "Faves" in your Flick export are for other people's photos. Those won't be imported for obvious reasons.

### FYI: ... photos are in no albums

This just means some of your photos are not in any Flickr albums. This is in no way a problem but you might spot check the count to make sure somehting isn't broken.

## Troubleshooting Import

## osascript errors

If one of the AppleScripts fails, the script will log the complete AppleScript source it's trying to run and then abort. You should be able to copy/paste this coede into Script Editor and run it directly. 

In my experience the import failed in a few cases because Photos.app refused to import the photo. I fixed this by deleting the EXIF data from the offending photos (it was apparently corrupted) and then re-importing.

## Configuration

You can configure these options in the CONFIG.json file in the root of the project directory:

* `photos_folder_name`: Albums in Photos will be added to a top level folder with this name.
* `default_keywords`: A list of keywords added to every imported photo.
* `use_first_comment_as_description`: If a photo has no description, put the text of the first comment in the description instead.
