# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2019-present Shanti Gilbert (https://github.com/shantigilbert)

PKG_NAME="emuelec"
PKG_VERSION=""
PKG_REV="1"
PKG_ARCH="any"
PKG_LICENSE="GPLv3"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain emulationstation retroarch"
PKG_SECTION="emuelec"
PKG_SHORTDESC="EmuELEC Meta Package"
PKG_LONGDESC="EmuELEC Meta Package"
PKG_IS_ADDON="no"
PKG_AUTORECONF="no"
PKG_TOOLCHAIN="make"

# Thanks to magicseb  Reicast SA now WORKS :D
PKG_EMUS="$LIBRETRO_CORES advancemame PPSSPPSDL reicastsa amiberry hatarisa openbor dosbox-sdl2 mupen64plus-nx fba4arm mame2010 mame2015 mba.mini.plus"
PKG_RETROPIE_DEP="bash pyudev dialog six fbterm git dbus-python pygobject coreutils"
PKG_TOOLS="common-shaders scraper Skyscraper MC libretro-bash-launcher fbida mpv SDL_GameControllerDB linux-utils xmlstarlet CoreELEC-Debug-Scripts $PKG_RETROPIE_DEP sixaxis evdev_tools"
PKG_DEPENDS_TARGET="$PKG_DEPENDS_TARGET $PKG_EMUS $PKG_TOOLS"
 
make_target() {
if [ "$PROJECT" == "Amlogic-ng" ]; then
	cd $PKG_DIR/fbfix
	$CC -O2 fbfix.c -o fbfix
fi
}

makeinstall_target() {
   
	if [ "$PROJECT" == "Amlogic-ng" ]; then
	mkdir -p $INSTALL/usr/config/emuelec/bin
	cp $PKG_DIR/fbfix/fbfix $INSTALL/usr/config/emuelec/bin
	rm $PKG_DIR/fbfix/fbfix
	fi

  mkdir -p $INSTALL/etc/samba
   cp $PKG_DIR/config/samba.conf $INSTALL/etc/samba/smb.conf

  mkdir -p $INSTALL/usr/config/
    cp -rf $PKG_DIR/config/* $INSTALL/usr/config/
    cp $PKG_DIR/autostart.sh $INSTALL/usr/config/autostart.sh
    cp $PKG_DIR/custom_start.sh $INSTALL/usr/config/custom_start.sh
 
  mkdir -p $INSTALL/usr/config/emuelec/scripts
    cp $PKG_DIR/scripts/* $INSTALL/usr/config/emuelec/scripts
    chmod +x $INSTALL/usr/config/emuelec/scripts/*
    
  mkdir -p $INSTALL/usr/bin/
    
  if [ "$PROJECT" != "Amlogic-ng" ]; then
    rm $INSTALL/usr/config/emuelec/scripts/resetfb.sh
  fi

  FILES=$INSTALL/usr/config/emuelec/scripts/*
	for f in $FILES 
	do
	FI=$(basename $f)
	ln -sf "/storage/.config/emuelec/scripts/$FI" $INSTALL/usr/bin/
  done

  mkdir -p $INSTALL/usr/share/retroarch-overlays
    cp -r $PKG_DIR/overlay/* $INSTALL/usr/share/retroarch-overlays
  
  mkdir -p $INSTALL/usr/share/common-shaders
    cp -r $PKG_DIR/shaders/* $INSTALL/usr/share/common-shaders
    
  mkdir -p $INSTALL/usr/share/libretro-database
     touch $INSTALL/usr/share/libretro-database/dummy
     
  mkdir -p $INSTALL/usr/config/emuelec/
    cp -rf $PKG_DIR/retropie/* $INSTALL/usr/config/emuelec/
    ln -sf /storage/.config/emuelec $INSTALL/emuelec
    find $INSTALL/usr/config/emuelec/ -type f -exec chmod o+x {} \;
}

post_install() {
# Remove unnecesary Retroarch Assets and overlays
  for i in branding glui nuklear nxrgui ozone pkg switch wallpapers zarch; do
    rm -rf "$INSTALL/usr/share/retroarch-assets/$i"
  done
  
  for i in borders effects gamepads ipad keyboards misc; do
    rm -rf "$INSTALL/usr/share/retroarch-overlays/$i"
  done

mkdir -p $INSTALL/etc/retroarch-joypad-autoconfig
cp -r $PKG_DIR/gamepads/* $INSTALL/etc/retroarch-joypad-autoconfig

# link default.target to emuelec.target
   ln -sf emuelec.target $INSTALL/usr/lib/systemd/system/default.target
   enable_service emuelec-autostart.service
  
# Thanks to vpeter we can now have bash :) 
  rm -f $INSTALL/usr/bin/{sh,bash,busybox,sort}
  cp $(get_build_dir busybox)/.install_pkg/usr/bin/busybox $INSTALL/usr/bin
  cp $(get_build_dir bash)/.install_pkg/usr/bin/bash $INSTALL/usr/bin
  cp $(get_build_dir coreutils)/.install_pkg/usr/bin/sort $INSTALL/usr/bin
  ln -sf bash $INSTALL/usr/bin/sh
 
  echo "chmod 4755 $INSTALL/usr/bin/bash" >> $FAKEROOT_SCRIPT
  echo "chmod 4755 $INSTALL/usr/bin/busybox" >> $FAKEROOT_SCRIPT
  find $INSTALL/usr/ -type f -iname "*.sh" -exec chmod +x {} \;
  
# Generate force_update.sh script based on the files that need to be updated
OIFS="$IFS"
IFS=$'\n'
  FILES=$(find $INSTALL/usr/config/emuelec -type f)
for f in $FILES 
	do
		FI=$(echo "$f" | sed "s|$INSTALL/usr/config/emuelec/||")
	if  [[ "$FI" != *"ports"* ]]; then
		echo "cp -rf \"/usr/config/emuelec/$FI\" \"/emuelec/$FI\"" >> $INSTALL/usr/config/emuelec/scripts/force_update.sh
	fi
done
echo " " >> $INSTALL/usr/config/emuelec/scripts/force_update.sh
echo "# emulationstation " >> $INSTALL/usr/config/emuelec/scripts/force_update.sh
echo " " >> $INSTALL/usr/config/emuelec/scripts/force_update.sh   
  
  FILES=$(find $INSTALL/usr/config/emulationstation/scripts -type f)
		for f in $FILES 
		do
		FI=$(echo "$f" | sed "s|$INSTALL/usr/config/emulationstation/scripts/||")
	echo "cp -rf \"/usr/config/emulationstation/scripts/$FI\" \"/storage/.emulationstation/scripts/$FI\"" >> $INSTALL/usr/config/emuelec/scripts/force_update.sh
  done

echo "cp -rf /usr/config/EE_VERSION /storage/.config/EE_VERSION" >> $INSTALL/usr/config/emuelec/scripts/force_update.sh
echo "cp -rf /usr/config/autostart.sh /storage/.config/autostart.sh" >> $INSTALL/usr/config/emuelec/scripts/force_update.sh
  
# This should always be the last line
  echo " " >> $INSTALL/usr/config/emuelec/scripts/force_update.sh
  echo "fi" >> $INSTALL/usr/config/emuelec/scripts/force_update.sh
  echo 'check_reboot $1' >> $INSTALL/usr/config/emuelec/scripts/force_update.sh
  IFS="$OIFS"  
} 
