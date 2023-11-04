# Bashed 🐾 catbox

.

![MOSHED-2023-11-4-17-28-44](https://github.com/berwiecom/bashed-catbox/assets/34105153/4a8afda9-5060-44c1-984a-5c9b9786fbe4)

Bash your files with [bashed-catbox.sh](bashed-catbox.sh) to upload & delete them to and from [Catbox.moe](https://Catbox.moe) - even manage whole albums!  
Or wait till they automatically disappear from [Litterbox.Catbox.moe](https://litterbox.catbox.moe) after max. 3 days.

.

## Usage

```
Usage: catbox <command> [arguments] [options]

Commands:
   user [user hash]               - Gets current or sets global user hash. Pass 'off' to remove global user hash
   file   <filename(s)>           - Upload files to           catbox.moe
   temp   <filename(s)> [expiary] - Upload files to litterbox.catbox.moe
   url    <url(s)>                - Upload files from URLs to catbox.moe
   delete <filenames(s)>          - Delete files from         catbox.moe
   album                          - Album Managment

Global options:
   -s, --silent                   - Only output upload links (stderr will still show)
   -S, --silent-all               - Silent option but also silences stderr
   -n, --no-color                 - Disable output coloring
   -u, --user-hash[=]             - Pass user hash
   -V, --verbose                  - Show verbose output (in album)

```
