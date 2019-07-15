#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2019-present Shanti Gilbert (https://github.com/shantigilbert)

# This whole file has become very hacky, I am sure there is a better way to do all of this, but for now, this works.

arguments="$@"

# TEMP: I need to figure out how to mix sounds, but for now make sure BGM is killed completely to free up the soundcard
if [[ $arguments != *"KEEPMUSIC"* ]]; then
	if  pgrep mpg123 >/dev/null ; then
    killall -9 mpg123 
   #/storage/.emulationstation/scripts/bgm.sh 
	fi
fi

# Extract the platform from the arguments in order to show the correct bezel/splash
if [[ "$arguments" == *"-P"* ]]; then
	PLATFORM="${arguments##*-P}"  # read from -P onwards
	PLATFORM="${PLATFORM%% *}"  # until a space is found
else
# if no -P was set, read the first argument as platform
	PLATFORM="$1"
fi

# Set the variables
CFG="/storage/.emulationstation/es_settings.cfg"
LOGEMU="No"
VERBOSE=""
EMUELECLOG="/storage/emuelec.log"
PAT="s|\s*<string name=\"EmuELEC_$1_CORE\" value=\"\(.*\)\" />|\1|p"
EMU=$(sed -n "$PAT" "$CFG")

# Evkill setup

# Set keys home+start in Xbox controller as quit combo, you can find the button numbers for your gamepad using "evtest /dev/input/eventX"
KILLKEYS="316+315"

# By default use joystick0 (player 1?) 
KILLDEV="js0"

# We set this to none, and set the corresponding bin name at the launch line
KILLTHIS="none"


# remove Libretro_ from the core name
EMU=$(echo "$EMU" | sed "s|Libretro_||")

# if there wasn't a --NOLOG included in the arguments, enable the emulator log output. TODO: this should be handled in ES menu
if [[ $arguments != *"--NOLOG"* ]]; then
LOGEMU="Yes"
VERBOSE="-v"
fi

# if the emulator is in es_settings this is the line that will run 
RUNTHIS='/usr/bin/retroarch $VERBOSE -L /tmp/cores/${EMU}_libretro.so "$2"'

# very WIP {

PAT="s|\s*<bool name=\"EmuELEC_BEZELS\" value=\"\(.*\)\" />|\1|p"
BEZ=$(sed -n "$PAT" "$CFG")
[ "$BEZ" == "true" ] && SHOW_BEZELS="Yes" || SHOW_BEZELS="No"
PAT="s|\s*<bool name=\"EmuELEC_SPLASH\" value=\"\(.*\)\" />|\1|p"
SPL=$(sed -n "$PAT" "$CFG")
[ "$SPL" == "true" ] && SHOW_SPLASH="Yes" || SHOW_SPLASH="No"

[ "$SHOW_BEZELS" = "Yes" ] && /emuelec/scripts/bezels.sh "$PLATFORM" "$2" || /emuelec/scripts/bezels.sh "default"
[ "$SHOW_SPLASH" = "Yes" ] && /emuelec/scripts/show_splash.sh "$PLATFORM" "$2" || /emuelec/scripts/show_splash.sh "default" 

# } very WIP 

# Clear the log file
echo "EmuELEC Run Log" > $EMUELECLOG

# Read the first argument in order to set the right emulator
case $1 in
"OPENBOR")
	KILLTHIS="OpenBOR"
	RUNTHIS='/usr/bin/openbor.sh "$2"'
		;;
"RETROPIE")
	RUNTHIS='bash /emuelec/scripts/fbterm.sh "$2"'
		;;
"LIBRETRO")
	RUNTHIS='/usr/bin/retroarch $VERBOSE -L /tmp/cores/$2_libretro.so "$3"'
		;;
"REICAST")
    if [ "$EMU" = "REICASTSA" ]; then
    KILLTHIS="reicast"
	RUNTHIS='/usr/bin/reicast.sh "$2"'
	LOGEMU="No" # ReicastSA outputs a LOT of text, only enable for debugging.
	fi	;;
"MAME"|"ARCADE")
	if [ "$EMU" = "AdvanceMame" ]; then
	KILLTHIS="advmame"
	RUNTHIS='/usr/bin/advmame.sh "$2"'
	fi
		;;
"DRASTIC")
	KILLTHIS="drastic"
	RUNTHIS='/storage/.emulationstation/scripts/drastic.sh "$2"'
		;;
"N64")
    if [ "$EMU" = "M64P" ]; then
    KILLTHIS="mupen64plus"
	RUNTHIS='bash /usr/bin/m64p.sh "$2"'
	fi
		;;
"AMIGA")
    if [ "$EMU" = "AMIBERRY" ]; then
    KILLTHIS="amiberry"
	RUNTHIS='bash /usr/bin/amiberry.start "$2"'
	fi
		;;
"DOSBOX")
    if [ "$EMU" = "DOSBOXSDL2" ]; then
    KILLTHIS="dosbox"
	RUNTHIS='bash /usr/bin/dosbox.start "$2"'
	fi
		;;		
"PSP")
      if [ "$EMU" = "PPSSPPSA" ]; then
   #PPSSPP can run at 32BPP but only with buffered rendering, some games need non-buffered and the only way they work is if I set it to 16BPP
   # /emuelec/scripts/setres.sh 16 # This was only needed for S912, but PPSSPP does not work on S912 
    RUNTHIS='/usr/bin/ppsspp.sh "$2"'
      fi
        ;;
"NEOCD")
      if [ "$EMU" = "fbneo" ]; then
      RUNTHIS='/usr/bin/retroarch $VERBOSE -L /tmp/cores/fbneo_libretro.so --subsystem neocd "$2"'
      fi
        ;;
esac

# Write the command to the log file.
echo "PLATFORM: $PLATFORM" >> $EMUELECLOG 
echo "1st Argument: $1" >> $EMUELECLOG 
echo "2nd Argument: $2" >> $EMUELECLOG
echo "3rd Argument: $3" >> $EMUELECLOG 
echo "4th Argument: $4" >> $EMUELECLOG 
echo "Run Command is:" >> $EMUELECLOG 
eval echo  ${RUNTHIS} >> $EMUELECLOG 

# TEMP: I need to figure out how to mix sounds, but for now make sure BGM is killed completely to free up the soundcard
if [[ $arguments != *"KEEPMUSIC"* ]]; then
	killall -9 mpg123 
fi

if [[ "$KILLTHIS" != "none" ]]; then
	/emuelec/bin/evkill -k${KILLKEYS} -d${KILLDEV} ${KILLTHIS} &
fi

# Exceute the command and try to output the results to the log file if it was not dissabled.
if [[ $LOGEMU == "Yes" ]]; then
   echo "Emulator Output is:" >> $EMUELECLOG
   eval ${RUNTHIS} >> $EMUELECLOG 2>&1
else
   echo "Emulator log was dissabled" >> $EMUELECLOG
   eval ${RUNTHIS}
fi 

# Only run resetfb if it exists, mainly for N2
if [ -f "/emuelec/scripts/resetfb.sh" ]; then
/emuelec/scripts/resetfb.sh
fi

if [ ! -e /proc/device-tree/t82x@d00c0000/compatible ]; then
# Yet even more hacks to get S912 to play nice, don't display a splash on S912 after quiting a game
/emuelec/scripts/show_splash.sh intro
fi

if [[ $arguments != *"KEEPMUSIC"* ]]; then
	DEFE=$(sed -n 's|\s*<bool name="BGM" value="\(.*\)" />|\1|p' $CFG)
 if [ "$DEFE" == "true" ]; then
	killall -9 mpg123
	/storage/.emulationstation/scripts/bgm.sh
 fi 
fi

# Kill evkill 
killall evkill

# Return to default mode
/emuelec/scripts/setres.sh
