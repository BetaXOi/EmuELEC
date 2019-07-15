#!/bin/sh

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2009-2014 Stephan Raue (stephan@openelec.tv)

# create logfile

DATE=`date -u +%Y-%m-%d-%H.%M.%S`
BASEDIR="/tmp"
LOGDIR="log-$DATE"
RELEASE="`cat /etc/release`"
GIT="`cat /etc/issue | grep git`"

getlog_cmd() {
  if command -v $1 >/dev/null; then
    echo "################################################################################" >> $BASEDIR/$LOGDIR/$LOGFILE
    echo "# ... output of $@" >> $BASEDIR/$LOGDIR/$LOGFILE
    echo "# emuELEC release: $RELEASE" >> $BASEDIR/$LOGDIR/$LOGFILE
    echo "# $GIT" >> $BASEDIR/$LOGDIR/$LOGFILE
    echo "################################################################################" >> $BASEDIR/$LOGDIR/$LOGFILE
    $@ >> $BASEDIR/$LOGDIR/$LOGFILE 2>/dev/null
    echo "" >> $BASEDIR/$LOGDIR/$LOGFILE
  fi
}

get_governor_details() {
  (
    cat_all_files /sys/devices/system/cpu
    cat_all_files /sys/devices/system/cpu/cpufreq
    for cpun in /sys/devices/system/cpu/cpu[0-9]*; do
      cat_all_files ${cpun}/cpufreq
    done
  )
}

cat_all_files() {
  local adir=$1
  local afile var

  [ -d ${adir} ] || return 0

  echo "${adir}"

  cd ${adir}
  for afile in $(find . -maxdepth 1 -print | sort); do
    afile=${afile:2}
    if [ -n "${afile}" ]; then
      if [ -d ${afile} ]; then
        var="<dir>"
      else
        var="$(cat ${afile} 2>/dev/null)"
      fi
      [ -n "${var}" ] && printf "    %-30s : %s\n" "${afile}" "${var}"
    fi
  done
}

rm -rf $BASEDIR/$LOGDIR
mkdir -p $BASEDIR/$LOGDIR

# es_log.txt
  EE_LOG_DIR=/storage

  LOGFILE="01_EE_VERSION.log"
  for i in EE_VERSION; do
    [ -f ${EE_LOG_DIR}/${i} ] && getlog_cmd cat ${EE_LOG_DIR}/$i
    getlog_cmd echo "usr:"
    getlog_cmd cat /usr/config/EE_VERSION
  done
  
  LOGFILE="01_ES.LOG"
  for i in es_log.txt es_input.cfg es_settings.cfg es_log.txt.bak es_systems.cfg; do
    [ -f ${EE_LOG_DIR}/.emulationstation/${i} ] && getlog_cmd cat ${EE_LOG_DIR}/.emulationstation/$i
  done

  LOGFILE="01_EMUELEC.log"
  for i in emuelec.log sx05re.log retroarch.log emulationstation.log; do
     [ -f ${EE_LOG_DIR}/${i} ] && getlog_cmd cat ${EE_LOG_DIR}/$i
  done

EE_LOG_DIR=/storage/.config/retroarch
  
LOGFILE="01_RETROARCH.log"
  for i in retroarch.cfg; do
     [ -f "$EE_LOG_DIR/$i" ] && getlog_cmd cat "$EE_LOG_DIR/$i"
  done

EE_LOG_DIR=/tmp/joypads
  
LOGFILE="01_JOYPADS.log"
  for i in $EE_LOG_DIR/*.cfg; do
     [ -f "$i" ] && getlog_cmd cat "$i"
  done

# System.log
  LOGFILE="02_System.log"
  getlog_cmd dmesg
  getlog_cmd lsmod
  getlog_cmd ps xa
  for i in /storage/.config/hwdb.d/*.hwdb \
      /storage/.config/modprobe.d/*.conf \
      /storage/.config/modules-load.d/*.conf \
      /storage/.config/sleep.d/*.power \
      /storage/.config/sysctl.d/*.conf \
      /storage/.config/udev.rules.d/.rules \
  ; do
    if [ -f "$i" ] ; then
      getlog_cmd cat $i
    fi
  done
  if [ -f "/storage/.config/autostart.sh" ] ; then
    getlog_cmd cat /storage/.config/autostart.sh
  fi
  if [ -f "/storage/.config/shutdown.sh" ] ; then
    getlog_cmd cat /storage/.config/shutdown.sh
  fi
  getlog_cmd ls -laR /storage/.config/system.d
  # note: we dont add .mount units here as they may contan
  # login credentials
  for i in /storage/.config/system.d/*.service ; do
    if [ -f "$i" -a ! -L "$i" ] ; then
      getlog_cmd cat $i
    fi
  done

# Hardware.log
  LOGFILE="03_Hardware.log"
  getlog_cmd lspci -vvvvnn
  getlog_cmd lsusb -vvv
  getlog_cmd lsusb -t
  getlog_cmd cat /proc/cpuinfo
  getlog_cmd get_governor_details
  getlog_cmd cat /proc/meminfo

# Audio.log
  LOGFILE="04_Audio.log"
  getlog_cmd aplay -l
  getlog_cmd aplay -L
  getlog_cmd amixer

# Network.log
  LOGFILE="05_Network.log"
  getlog_cmd ifconfig -a
  getlog_cmd netstat -rn
  getlog_cmd netstat -nalp
  getlog_cmd connmanctl services
  getlog_cmd cat /etc/resolv.conf

# varlog.log
  LOGFILE="06_varlog.log"
  for i in `find /var/log -type f`; do
    getlog_cmd cat $i
  done

# Input.log
  LOGFILE="07_input.log"
  getlog_cmd cat /proc/bus/input/devices
  # make RPi users happy
  if [ -e /proc/acpi/wakeup ] ; then
    getlog_cmd cat /proc/acpi/wakeup
  fi

# Filesystem.log
  LOGFILE="08_Filesystem.log"
  getlog_cmd cat /proc/mounts
  getlog_cmd df -h
  getlog_cmd blkid

# Journal (current)
  LOGFILE="09_Journal-cur.log"
  getlog_cmd journalctl --no-pager -b -0

# Journal (prev)
  LOGFILE="10_Journal-prev.log"
  getlog_cmd journalctl --no-pager -b -1

# pack logfiles
  mkdir -p /storage/logfiles
  zip -jq /storage/logfiles/log-$DATE.zip $BASEDIR/$LOGDIR/*
  cat $BASEDIR/$LOGDIR/* > /storage/logfiles/EMUELEC.LOG
  pastebinit /storage/logfiles/EMUELEC.LOG

# remove logdir
  rm -rf $BASEDIR/$LOGDIR
