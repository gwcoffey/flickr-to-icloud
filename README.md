With the Shared Library feature in macOs Ventura, my wife 
decided it was time to abandon Flickr after many years. 
This project documents the process I used and the scripts 
I wrote to import her photos into the Apple Photos app. The
goal was to preserve the metadata that was important to her.

> **Warning:** Use at your own risk.
> I make no guarantee that this will work cleanly with any other
> Flickr export. But I'm sharing the scripts in case it helps
> someone. I'm not particularly experienced with Flickr, Photos,
> or AppleScript so YMMV.

This project uses a mix of Ruby and AppleScript. I used the 
version of Ruby pre-installed on macOS Ventura and installed
no additional Gems.

## Metadata Mapping

Here's how I mapped the Flickr metadata to Photos.app:

* Flickr `name` -> Photos `Name`
* Flickr `tags` -> Photos `Keywords`
* Flickr `description` -> Photos `Description`
* FLickr `date_taken` -> Photos `Date`
* Flickr `geo` -> Photos `Location`
* Flickr `albums` -> Photos `Albums`

In addition, for convenience when troubleshooting and verifying 
results, I also:

* Set the filename of each photo to `{flicker id}.{ext}`. This
  makes it easy to look the photo up in Flickr later by
  replacing the ID in a Flickr URL with the id from the filename.
* Add the `flickr` keyword to every imported photo. (You can
  change this keyword in the config, see below.)
* If a photo has no description, and it does have comments, I put
  the text of the first comment into the description. (This may not
  be appropriate in your case. You can turn this off in the
  config, see below.)

I **do not** preserve this data:
* Flickr `faves`
* Flickr `comments` (with the caveat above)

## High Level Process

This process operates on the full Flick export, which includes both
the original photo files and metadata in JSON format. (See below for
instructions on how to export from Flickr.)

1. Copy all the Flick export folders to the `in` folder in the project.
> You should keep the folder with their original names. I use the folder
> names to figure out what's what. For example you should have a small 
> number of folders with names like `72157721305918252_32dfb3965e35_part1`
> and probably many other folders with names like `data-download-1`.

2. Run `bin/run verify` to verify the export.
> This script sanity checks the export, identifying things like 
> missing folder, photos with no metadata, metadata for non-existent
> photos, exact duplicate photos, etc…
> 
> It also stores data in `out/analysis.json` to make the next step 
> faster.
> 
> The script will output warnings if there's anything you should look
> at more closely, and errors if there's a critical problem with the
> data.

3. Run `bin/run prepare` to prepare the import.
> This script maps data from Flickr's format to the Photos.app format.
> You should carefully review `duplicates.json` and `metadata.json`
> and verify things look correct. The metadata file includes links 
> to the original Flickr pages for easy comparison.

3. Run `bin/run import` to import the prepared data into Photos.app.
> This script does some setup, then runs an AppleScript for each 
> individual photo (one at a time). The AppleScript:
> 1. Runs the Photos.app *Import* process for the individual photo, 
>    with duplicate-checking disabled. (Dup checking interrupts the
>    script execution so I de-dup during the prepare phase instead.)
> 2. Updates the metadata on the imported photo.
> 3. Adds the photo to each Album is belongs to.
>
> If any AppleScript fails, the script aborts. See Troubleshooting
> below for advice. Once you fix the problem you can re-run `import`
> and it will pick up where you left off.
> 
> **I strongly encourage you** to use the `-n` option to import just
> a few photos first so you can spot check results. The `import` 
> command will not re-import photos it has already imported so it
> is safe to run in batches. And if you get errors, you can fix 
> them and run again to pick up where you left off.
> 
> Once you are confident in the process you can leave off the `-n`
> option to (try to) import everything remaining.

## Exporting From Flickr

These scripts assume you have a full export of your Flickr data.
At the time of writing, this is how you do that:

1. Log in to your Flickr account
2. In the top-right corner of the page, click your profile
   photo.
3. From the popup that appears, click "Settings".
4. On the settings page, at the bottom of the right-side column,
   click "Request my Flicker Data".

> Note: If you've done this before, you will instead see a set of
> download links, and a link to "Request this data again."

5. Wait for Flickr to prepare your exports. This may take
   several days.
6. Download all the zip files, unzip them and put them in
   a single folder. (There should be one sub-folder for each
   original Zip file.)

Once you have a folder full of export files, you can try using
these scripts.

## Configuration

You can configure these options in the CONFIG.json file in the 
root of the project directory:

* `photos_folder_name`: Albums in Photos will be added to a top 
  level folder with this name.
* `default_keywords`: A list of keywords added to every imported
  photo.
* `use_first_comment_as_description`: If a photo has no description,
  put the text of the first comment in the description instead.

## Troubleshooting

If the import process fails for a photo the AppleScript code is 
dumped to stdout and the process aborts. You can copy/paste the 
script code into Script Editor to debug and fix as needed. Then 
you can re-run the `import` command to pick up where you left off.

You may need to fix bugs in `src/applescript/import_photo.scpt.erb`.

I had one photo that Photos refused to import. FWIW I fixed it by
using a command line tool to remove the EXIF data from the original
photo.