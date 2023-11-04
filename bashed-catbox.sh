
#!/bin/bash
#
# CatBox v2.0
# An implementation of catbox.moe API in Bash
# Author: MineBartekSA
# Gist: https://gist.github.com/MineBartekSA/1d42d6973ddafb82793fd49b4fb06591
# Change log: https://gist.github.com/MineBartekSA/1d42d6973ddafb82793fd49b4fb06591?permalink_comment_id=4596132#gistcomment-4596132
#
# MIT License
#
# Copyright (c) 2023 Bartłomiej Skoczeń
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

_version="2.0"

_catbox_host="https://catbox.moe/user/api.php"
_litter_host="https://litterbox.catbox.moe/resources/internals/api.php"
_hash_file="$HOME/.catbox"

_curl_add=""

_reset="\e[0m"
_bold="\e[1m"
_red="\e[91m"
_yellow="\e[93m"

## Utils

no_color() {
    unset _reset _bold _red _yellow   #########???????????
}

version() {
    echo -e $_bold"CatBox"$_reset" v"$_version >&5
    echo "A catbox.moe API implementation in Bash"
}

usage() {
    [ -z $1 ] && version || echo $1
    echo
    echo "Usage: catbox <command> [arguments] [options]"
    echo
    echo "Commands:"
    echo "   user [user hash]             - Gets current or sets global user hash. Pass 'off' to remove global user hash"
    echo "   file <filename(s)>           - Upload files to catbox.moe"
    echo "   temp <filename(s)> [expiary] - Upload files to litterbox.catbox.moe"
    echo "   url <url(s)>                 - Upload files from URLs to catbox.moe"
    echo "   delete <filenames(s)>        - Delete files from catbox.moe"
    echo "   album                        - Album Managment"
    echo
    echo "Global options:"
    echo "   -s, --silent       - Only output upload links (stderr will still show)"
    echo "   -S, --silent-all   - Silent option but also silences stderr"
    echo "   -n, --no-color     - Disable output coloring"
    echo "   -u, --user-hash[=] - Pass user hash"
    echo "   -V, --verbose      - Show verbose output (in album)"
}

has_hash() {
    [ -z "$HASH" ] && [ -z "$USER_HASH" ] && echo false || echo true
}

## Command functions

upload_files() {
    declare -i fail=0
    for file in "${@:2}"
    do
        name=$(basename -- "$file")
        echo -e $_bold"$name"$_reset":"
        if ! ( [ -f "$file" ] || [ -L "$file" ] || [ "$file" == "-" ] )
        then
            echo -e $_bold$_red"File '$file' doesn't exist!"$_reset >&2
            fail+=1
            continue
        fi
        link=$(curl --fail-with-body -F reqtype=fileupload $_curl_add -F "fileToUpload=@$file" $1)
        if [ $? -ne 0 ]
        then
            echo -e $_bold$_red"Failed to upload: "$_reset$_red$link$_reset >&2
            fail+=1
            continue
        fi
        echo -n $link | xclip -selection clipboard
        echo -en "Uploaded to: "$_bold
        echo $link >&5
        echo -en $_reset
    done
    [ $fail -eq $[$#-1] ] && exit 2
    return 0
}

catbox_command() {
    curl -s --fail-with-body -F reqtype=$1 $_curl_add "${@:2}" $_catbox_host &
    pid=$!
    if [ ! $SILENT ]
    then
        echo -en "\e[sPlase wait... |" >&5
        declare -i stage=1
        while ps -p $pid > /dev/null
        do
            case $stage in
            0 | 4)
                echo -en "\e[1D|" >&5
                ;;
            1 | 5)
                echo -en "\e[1D/" >&5
                ;;
            3 | 7)
                echo -en "\e[1D\\" >&5
                ;;
            2 | 6)
                echo -en "\e[1D-" >&5
                ;;
            esac
            stage+=1
            [ $stage -eq 8 ] && stage=0
            sleep 0.1
        done
        echo -ne "\e[u\e[KDone!" >&5
    fi
    wait $pid
}

generic_command() {
    declare -i fail=0
    for item in "${@:5}"
    do
        echo -en $_bold"$($3 "$item")"$_reset": "
        res=$(catbox_command $1 -F "$2=$item")
        if [ $? -eq 0 ]
        then
            $4 "$res"
        else
            [ $SILENT ] && echo -en $_red"$item: " >&2 || echo -en "\e[u"
            echo -e $_red$res$_reset >&2
            fail+=1
        fi
    done
    [ $fail -eq $[$#-4] ] && exit 2
    return 0
}

url_success() {
    echo -en "\e[u"
    echo $* >&5
    echo -n $* | xclip -selection clipboard
}

upload_urls() {
    generic_command urlupload url "basename -- " url_success $@
}

delete_success() {
    echo -e "\e[uSuccesfully deleted"
}

delete_files() {
    echo "Deleting..."
    generic_command deletefiles files echo delete_success $@
}

album_usage() {
    echo "Usage: catbox album <command> [arguments]"
    echo
    echo -e $_bold$_yellow"Note: Every album command requires user hash"
    echo -e "      For title or description, double quote every text longer than one word"$_reset
    echo
    echo "Commands:"
    echo "   create <title> <description> <file(s)>       - Create album"
    echo "   edit <short> <title> <description> [file(s)] - Modify album"
    echo "   add <short> <file(s)>                        - Add files to an album"
    echo "   remove <short> <file(s)>                     - Remove files from an album"
    echo "   delete <short>                               - Delete album"
}

album_create() { 
    files="${@:3}"
    echo "Creating album..."
    if [ $VERBOSE ]
    then
        echo "Title      : $1" >&5
        echo "Description: $2" >&5
        echo "Files      : $files" >&5
    fi

    album=$(catbox_command createalbum -F "title=$1" -F "desc=$2" -F "files=$files")
    if [ $? -ne 0 ]
    then
        exec >&2
        echo -e $_red$_bold"Failed to create a new album!"$_reset
        echo -e $_red$album$_reset
        exit 2
    fi

    echo -n $album | xclip -selection clipboard
    echo -e "\nAlbum created successfully"
    if [ $VERBOSE ]
    then
        echo "Album short: ${album:21}" >&5
        echo "Album url  : $album" >&5
    else
        echo "${album:21} | $album" >&5
    fi
}

album_edit() {
    files="${@:4}"
    echo "Modifing album..."
    if [ $VERBOSE ]
    then
        echo "Album Short: $1" >&5
        echo "Title      : $2" >&5
        echo "Description: $3" >&5
        echo "Files      : $files" >&5
    fi

    res=$(catbox_command editalbum -F "short=$1" -F "title=$2" -F "desc=$3" -F "files=$files")
    if [ $? -ne 0 ]
    then
        exec >&2
        echo -e $_red$_bold"Failed to modify album!"$_reset
        echo -e $_red$res$_reset
        exit 2
    fi

    echo -e "\nAlbum modified successfully"
}

album_add() {
    files="${@:2}"
    echo "Adding files to the album..."
    if [ $VERBOSE ]
    then
        echo "Album short: $1"
        echo "Files      : $files"
    fi

    res=$(catbox_command addtoalbum -F "short=$1" -F "files=$files")
    if [ $? -ne 0 ]
    then
        exec >&2
        echo -e $_red$_bold"Failed to add files to the album!"$_reset
        echo -e $_red$res$_reset
        exit 2
    fi

    echo -e "\nSuccessfully added files to the album"
}

album_remove() {
    files="${@:2}"
    echo "Removing files from the album..."
    if [ $VERBOSE ]
    then
        echo "Album short: $1"
        echo "Files      : $files"
    fi

    res=$(catbox_command removefromalbum -F "short=$1" -F "files=$files")
    if [ $? -ne 0 ]
    then
        exec >&2
        echo -e $_red$_bold"Failed to remove files from the album!"$_reset
        echo -e $_red$res$_reset
        exit 2
    fi

    echo -e "\nSuccessfully removed files from the album"
}

album_delete() {
    echo "Deleting albums..."
    generic_command deletealbum short echo delete_success $@
}

## Start

# Check if curl exists
curl --version >> /dev/null
if [ $? -ne 0 ]
then
    echo -e $_red"cURL not found!"$_reset >&2
    echo "Please check if you have cURL installed on your system" >&2
    exit 3
fi

# Setup a file descriptor for bypassing silent option
exec 5<&1

# Handle global options
declare -i count=1
while [ $count -le $# ]
do
    case ${!count} in
    -S | --silent-all)
        exec 2>/dev/null
        set -- "${@:1:$count-1}" -s -s "${@:$count+1}"
        ;;
    -s | --silent)
        exec >/dev/null
        SILENT=1
        ;;
    -h | --help | --usage)
        exec 5>/dev/null
        usage
        exit 0
        ;;
    -v | --version)
        version
        exit 0
        ;;
    -n | --no-color)
        no_color
        ;;
    -u | --user-hash | --user-hash=*)
        if [[ ${!count} == --user-hash=* ]]
        then
            HASH=${!count:12}
        else
            get=$[$count+1]
            HASH=${!get}
            set -- "${@:1:$count-1}" "${@:$count+1}"
        fi
        [ ! -z "$HASH" ] && _curl_add="-F userhash=$HASH "
        ;;
    -V | --verbose)
        VERBOSE=1
        ;;
    *)
        count+=1
        continue
    esac
    set -- "${@:1:$count-1}" "${@:$count+1}"
done
unset count no_color

# Read user hash if it was not given through global options
if [ -z ${HASH+x} ] && [ -f $_hash_file ]
then
    while read line
    do
        if [[ $line != \#* ]] && [ "$line" != "" ]
        then
            USER_HASH=$line
            _curl_add="-F userhash=$USER_HASH "
            break
        fi
    done < $_hash_file
    unset line
fi

# Handle commands
case $1 in
version)
    version
    ;;
help | usage)
    exec 5>&1
    usage
    ;;
user)
    if [ -z $2 ]
    then
        if [ "$(has_hash)" == "true" ]
        then
            if ! [ -z "$HASH" ]
            then
                echo "User hash given!"
                echo -n "User hash: "
                echo $HASH >&5
            else
                echo "User hash present!"
                echo -n "User hash: "
                echo $USER_HASH >&5
            fi
            echo "CatBox will act as you"
        else
            echo "No user hash"
            echo "CatBox will act annonymously"
        fi
    elif [ "$2" == "off" ]
    then
        rm $_hash_file
        echo "CatBox will now upload annonymously"
    else
        echo -e "# CatBox v2 User Hash\n$2" > $_hash_file
        echo "User hash set!"
        echo "CatBox will now upload files to your account"
    fi
    ;;
file)
    if [ $# -eq 1 ]
    then
        exec >&2
        echo "Usage: catbox file <filename> [<filename>...] - Upload files to catbox.moe"
        echo "Anonymously uploaded files cannot be deleted"
        exit 1
    fi
    [ "$(has_hash)" == "false" ] && echo "Uploading annonymously..." || echo "Uploading..."
    upload_files $_catbox_host "${@:2}"
    ;;
temp)
    if [ $# -lt 2 ]
    then
        exec >&2
        echo "Usage: catbox temp <filename> [<filename>...] [1h/12h/24h/72h] - Upload files to litterbox.catbox.moe"
        echo "Only the given expiry times are supported"
        echo "By default, temporary files will expire after an hour"
        exit 1;
    fi
    [[ ${@: -1:1} == @(1|12|24|72)h ]] && time=${@: -1:1} && end=-1 || time=1h || end=0
    _curl_add="-F time=$time"
    echo "Uploading temporarily..."
    upload_files $_litter_host "${@:2:$#-1$end}"
    ;;
url)
    if [ $# -eq 1 ]
    then
        exec >&2
        echo "Usage: catbox url <url> [<url>...] - Upload files from urls to catbox.moe"
        echo "Anonymously uploaded files cannot be deleted"
        exit 1
    fi
    [ "$(has_hash)" == "false" ] && echo "Uploading annonymously..."  || echo "Uploading..."
    upload_urls "${@:2}"
    ;;
delete)
    if [ $# -eq 1 ]
    then
        exec >&2
        echo "Usage: catbox delete <filename> [<filename>...] - Delete files from your catbox.moe account"
        echo "This command required a catbox.moe account"
        echo "Please add your user hash by using the catbox user command"
        echo "Filenames must be the names of files already hosted on catbox.moe"
        echo "Anonymously uploaded files cannot be deleted"
        exit 1
    elif [ "$(has_hash)" == "false" ]
    then
        exec >&2
        echo -e $_bold$_red"No user hash!"$_reset
        echo -e $_red"Please add your user hash"
        echo -e "Use the catbox user command to do so"$_reset
        exit 1
    fi
    delete_files ${@:2}
    ;;
album)
    if [ $# -gt 1 ] && [ "$(has_hash)" == "false" ]
    then
        exec >&2
        echo -e $_bold$_red"No user hash!"$_reset
        echo -e $_red"Please add your user hash"
        echo -e "Use the catbox user command to do so"$_reset
        exit 1
    fi
    case $2 in
    create)
        if [ $# -lt 5 ]
        then
            exec >&2
            echo "Usage: catbox album create <title> <description> <filename> [<filename> ...] - Create an album with given title, description, and files"
            echo -e $_yellow"For title or description, double quote every text longer than one word"$_reset
            echo "Filenames must be the names of files already hosted on catbox.moe"
            exit 1
        fi
        album_create "$3" "$4" ${@:5}
        ;;
    edit)
        if [ $# -lt 5 ]
        then
            exec >&2
            echo "Usage: catbox album edit <short> <title> <description> [<filename> ...] - Modify the entirety of the album"
            echo -e $_yellow"For title or description, double quote every text longer than one word"
            echo -e "Filenames are not necessary, but given none, the album will become empty"$_reset
            echo "Filenames must be the names of files already hosted on catbox.moe"
            exit 1
        fi
        album_edit $3 "$4" "$5" ${@:6}
        ;;
    add)
        if [ $# -lt 4 ]
        then
            exec >&2
            echo "Usage: catbox album add <short> <filename> [<filename> ...] - Add files to the album"
            echo "Filenames must be the names of files already hosted on catbox.moe"
            exit 1
        fi
        album_add $3 ${@:4}
        ;;
    remove)
        if [ $# -lt 4 ]
        then
            exec >&2
            echo "Usage: catbox album remove <short> <filename> [<filename> ...] - Remove files from the album"
            echo "Filenames must be the names of files already hosted on catbox.moe"
            exit 1
        fi
        album_remove $3 ${@:4}
        ;;
    delete)
        if [ $# -lt 3 ]
        then
            echo "Usage: catbox album delete <short> [<short> ...] - Delete album(s)" >&2
            exit 1
        fi
        album_delete ${@:3}
        ;;
    *)
        exec >&2
        album_usage
        exit 1
    esac
    ;;
*)
    exec >&2
    exec 5>&2
    usage
    exit 1
esac
