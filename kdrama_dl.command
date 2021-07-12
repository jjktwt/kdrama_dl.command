#!/bin/bash

# Copyright (C) 2017 github.com/lastmodified
#
# This file is part of kdrama_dl.command.
#
# kdrama_dl.command is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# kdrama_dl.command is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with kdrama_dl.command.  If not, see <http://www.gnu.org/licenses/>.
#

# Current working dir
SCRIPT_VERSION='1.0.2'
CWD=`pwd`
DOWNLOAD_FOLDER="$CWD/downloads"
SCRIPT_PATH=`dirname "$0"`
# Colors
C_END='\033[0m'
C_BOLD='\033[1m'
C_FAIL='\033[91m'
C_WARNING='\033[93m'
C_OKBLUE='\033[94m'
C_OKGREEN='\033[92m'

HOSTNAME='goplay.anontpp.com'
# HOSTNAME='kdrama.armsasuncion.com'

function wait_ack {
    # Gives user a chance to read any messages before the script window closes
    read -n 1 -s -r -p $'\n[Press ENTER to continue]\n'
    exit
}

# Trap CONTROL-C interrupt so that we can exit properly without retrying
trap '{ echo -e "\n${C_FAIL}Interrupt detected. Download aborted.${C_END}" ; wait_ack; }' INT

# Check for update
latest_hash=$(curl -sL 'https://raw.githubusercontent.com/ArmsAsuncion/kdrama_dl.command/master/kdrama_dl.command' | md5 -q)
current_hash=$(md5 -q "$SCRIPT_PATH/kdrama_dl.command")

if [ "$latest_hash" != "$current_hash" ]; then
    echo -e "*** A new downloader script version is available. Please reinstall from https://github.com/lastmodified/kdrama_dl.command ***"
fi

# Test for the correct ffmpeg path, so user can either use an in-folder binary,
# or a fully installed copy of ffmpeg that is accessible in path
{ FFMPEG_PATH="$SCRIPT_PATH/ffmpeg"; "$FFMPEG_PATH" -version >/dev/null 2>&1; } || \
{ FFMPEG_PATH="ffmpeg"; "$FFMPEG_PATH" -version >/dev/null 2>&1; } || \
{ echo -e "${C_FAIL}${C_BOLD}[!] We cannot find a copy of ffmpeg.${C_END} Please make sure you either: 
    (1) have the ffmpeg binary in the same folder [$CWD], or 
    (2) installed ffmpeg. 
${C_BOLD}You can download ffmpeg for the Mac at https://evermeet.cx/ffmpeg/${C_END}"; \
wait_ack; }

# Display which ffmpeg in use, and version
echo -e "${C_OKGREEN}[i]${C_END} Using FFMPEG path: $FFMPEG_PATH 
$("$FFMPEG_PATH" -version | head -n 1)

${C_OKGREEN}kdrama_dl.command: version $SCRIPT_VERSION${C_END}
${C_BOLD}To exit/abort the script at any time, enter ${C_WARNING}[CONTROL+C].${C_END}
--------------------------------------------------------"

echo -e -n "Enter ${C_OKBLUE}Download Code${C_END}: "
read dcode

if [ -z $dcode ]; then
    echo -e "${C_FAIL}[!] Download code cannot be blank.${C_END}" 78374c67414f4a736f506e5055432f4d726376505552457067713237314a4d4e4d64547932474a3750432b326433492f742b306e44373574417947415472704c5a6c4268635568434d6e6b726430747254304e516444493056327843527a56535532315962327444616d597962316c4e5247396a626c4278656e644751554e6b61484530656b524f64335a36516b4632654664724d574a6e566b4a4452473472546c5a7951545658546a59795455784f5233633950513d3d    exit 1
fi

echo -e "The resolution must be available on the video page. Please check before entering."
echo -e -n "Enter ${C_OKBLUE}Resolution${C_END} (ex: 1080p, 720p, 480p, 360p): "
read resolution

if [ -z $resolution ]; then
    echo -e "${C_FAIL}[!] Resolution cannot be blank.${C_END}"
    exit 1
fi

# URL escape resolution param so that we can use values like "720p+"
# python is available by default on MacOS - comment out if
# using urlencoded params
resolution=$(python -c "import urllib; print(urllib.quote('''$resolution'''))")

echo -e "Choose a ${C_OKBLUE}File Format${C_END} (enter the option number)":
select ext in 'mkv' 'mp4'; do
    break;
done

if [ -z $ext ]; then
    echo -e "${C_FAIL}[!] File Format cannot be blank. Please make sure you enter the option NUMBER.${C_END}"
    exit 1
fi

echo -e -n "Enter ${C_OKBLUE}Filename${C_END}: "
read filename

if [ -z "$filename" ]; then
    echo -e "${C_FAIL}[!] Filename cannot be blank.${C_END}"
    exit 1
fi

mkdir -p "$DOWNLOAD_FOLDER"

video_dl="https://$HOSTNAME/?dcode=$dcode&quality=$resolution&downloadmp4vid=1" 
sub_dl="https://$HOSTNAME/?dcode=$dcode&downloadccsub=1"
video_file="$DOWNLOAD_FOLDER/$filename.$ext"
sub_file="$DOWNLOAD_FOLDER/$filename.srt"

echo "Downloading $DOWNLOAD_FOLDER/$filename.$ext. Please wait..."
FFMPEG_LOGLEVEL='fatal'

# extract download code into a separate function so that we can retry
function do_download {

    if [ "$ext" = 'mkv' ]
    then
        # show progress stats so there is feedback on what's happening
        "$FFMPEG_PATH" -loglevel "$FFMPEG_LOGLEVEL" -stats -timeout 10000000 -reconnect 1 -reconnect_streamed 1 -i "$video_dl" -i "$sub_dl" -metadata title="$filename" -c copy -bsf:a aac_adtstoasc -f 'matroska' "$video_file"
    fi

    if [ "$ext" = 'mp4' ]
    then
        # Generate srt as a separate file for players that cannot play the embedded sub
        curl -A 'Mozilla/5.0' -S -L --retry 2 -o "$sub_file" "$sub_dl" || { echo -e "${C_FAIL}[!] Unable to download srt.${C_END}"; wait_ack; } 
        # show progress stats so there is feedback on what's happening
        "$FFMPEG_PATH" -loglevel "$FFMPEG_LOGLEVEL" -stats -timeout 10000000 -reconnect 1 -reconnect_streamed 1 -i "$video_dl" -i "$sub_dl" -metadata title="$filename" -c:v copy -c:a copy -c:s mov_text -disposition:s:0 default -bsf:a aac_adtstoasc -f 'mp4' "$video_file"
    fi
}

for i in {1..2}
do
    do_download
    if [ -f "$video_file" ]
    then
        echo -e "Download completed: ${C_BOLD}$video_file${C_END}"
        break
    else
        echo -e "${C_FAIL}[!] Unable to complete download.${C_END}"
        if [ "$i" -lt 2 ]
        then
            echo -e "${C_BOLD}Retrying...${C_END}"
            # make ffmpeg more verbose to catch any unexpected errors
            FFMPEG_LOGLEVEL='warning'
        fi
    fi
done

wait_ack
