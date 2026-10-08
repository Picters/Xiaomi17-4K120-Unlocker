#!/system/bin/sh
MODDIR=${0%/*}
umask 077

[ -d /sdcard ] && [ -w /sdcard ] || { printf 'Unlock the phone to access /sdcard.\n'; exit 1; }
WORK=$(mktemp -d /data/local/tmp/xiaomi17-4k120-debug.XXXXXX) || exit 1
SNAPSHOT="$WORK/snapshot"
OUTPUT="/sdcard/Xiaomi17-4K120-debug-$(date +%Y%m%d-%H%M%S)-$$.zip"
mkdir -p "$SNAPSHOT" || exit 1

capture() {
  local name="$1" seconds="$2" status
  shift 2
  mkdir -p "${SNAPSHOT}/${name%/*}"
  timeout "$seconds" "$@" > "$SNAPSHOT/$name" 2>&1
  status=$?
  printf '%s\t%s\n' "$name" "$status" >> "$SNAPSHOT/collection-status.tsv"
  return 0
}

save() {
  local path="$1"
  [ -f "$path" ] || return 0
  mkdir -p "$SNAPSHOT/files${path%/*}"
  cp "$path" "$SNAPSHOT/files$path" 2>> "$SNAPSHOT/copy-errors.txt" || printf '%s\n' "$path" >> "$SNAPSHOT/copy-errors.txt"
}

little_endian() {
  local value="$1" width="$2"
  while [ "$width" -gt 0 ]; do
    printf '%b' "\\0$(printf '%03o' "$((value & 255))")"
    value=$((value >> 8))
    width=$((width - 1))
  done
}

zip_metadata() {
  little_endian 20 2
  little_endian 2048 2
  little_endian 8 2
  little_endian 0 2
  little_endian 33 2
  tail -c 8 "$WORK/entry.gz" | head -c 4
  little_endian "$ZIP_COMPRESSED" 4
  tail -c 4 "$WORK/entry.gz"
  little_endian "$ZIP_NAME_LENGTH" 2
  little_endian 0 2
}

make_zip() {
  local file name size offset=0 entries=0 central_size
  : > "$WORK/central.bin" || return 1
  : > "$OUTPUT.partial" || return 1
  LC_ALL=C
  export LC_ALL
  find "$SNAPSHOT" -type f > "$WORK/files.list" || return 1
  while IFS= read -r file; do
    name=${file#"$SNAPSHOT/"}
    ZIP_NAME_LENGTH=${#name}
    size=$(wc -c < "$file") || return 1
    [ "$size" -lt 4294967296 ] && [ "$ZIP_NAME_LENGTH" -lt 65536 ] && [ "$entries" -lt 65535 ] || return 1
    gzip -n -1 -c "$file" > "$WORK/entry.gz" || return 1
    ZIP_COMPRESSED=$(wc -c < "$WORK/entry.gz") || return 1
    ZIP_COMPRESSED=$((ZIP_COMPRESSED - 18))
    {
      printf 'PK\003\004'
      zip_metadata
      printf '%s' "$name"
      tail -c +11 "$WORK/entry.gz" | head -c "$ZIP_COMPRESSED"
    } >> "$OUTPUT.partial" || return 1
    {
      printf 'PK\001\002'
      little_endian 20 2
      zip_metadata
      little_endian 0 2
      little_endian 0 2
      little_endian 0 2
      little_endian 0 4
      little_endian "$offset" 4
      printf '%s' "$name"
    } >> "$WORK/central.bin" || return 1
    offset=$((offset + 30 + ZIP_NAME_LENGTH + ZIP_COMPRESSED))
    entries=$((entries + 1))
    [ "$offset" -lt 4294967296 ] || return 1
  done < "$WORK/files.list"
  central_size=$(wc -c < "$WORK/central.bin") || return 1
  {
    cat "$WORK/central.bin"
    printf 'PK\005\006'
    little_endian 0 2
    little_endian 0 2
    little_endian "$entries" 2
    little_endian "$entries" 2
    little_endian "$central_size" 4
    little_endian "$offset" 4
    little_endian 0 2
  } >> "$OUTPUT.partial" || return 1
  unzip -p "$OUTPUT.partial" > /dev/null 2> "$WORK/zip-test.txt" || return 1
  mv "$OUTPUT.partial" "$OUTPUT" || return 1
}

printf 'Xiaomi 17 4K120\nCollecting diagnostics...\n'
printf 'file\texit_status\n' > "$SNAPSHOT/collection-status.tsv"
{
  date
  uname -a
  id
  printf 'Module: %s\nKSU: %s\nMAGISK_VER: %s\nMAGISK_VER_CODE: %s\n' "$MODDIR" "${KSU:-}" "${MAGISK_VER:-}" "${MAGISK_VER_CODE:-}"
  getenforce
  uptime
} > "$SNAPSHOT/device-summary.txt" 2>&1
capture os/getprop.txt 20 getprop
capture os/storage.txt 20 df -h
capture os/memory.txt 20 cat /proc/meminfo
capture os/processes.txt 20 ps -A
capture root/magisk-version.txt 10 magisk -v
capture root/magisk-version-code.txt 10 magisk -V
capture root/ksud-version.txt 10 /data/adb/ksud --version
capture mounts/init.txt 20 cat /proc/1/mountinfo
capture mounts/action.txt 20 cat /proc/self/mountinfo
capture mounts/all.txt 20 cat /proc/mounts
capture logs/logcat-all.txt 60 logcat -b all -d -v threadtime
capture logs/dmesg.txt 30 dmesg
capture camera/media-camera.txt 45 dumpsys media.camera
capture camera/media-codec.txt 30 dumpsys media.codec
capture camera/media-metrics.txt 30 dumpsys media.metrics
capture camera/package.txt 30 dumpsys package com.android.camera
capture system/thermal.txt 30 dumpsys thermalservice
capture system/power.txt 30 dumpsys power
capture system/battery.txt 30 dumpsys battery
capture system/dropbox.txt 60 dumpsys dropbox --print
capture root/modules.txt 20 sh -c 'for dir in /data/adb/modules/*; do [ -d "$dir" ] || continue; printf "\n%s\n" "$dir"; cat "$dir/module.prop"; for flag in disable remove update; do [ ! -e "$dir/$flag" ] || printf "%s\n" "$flag"; done; done'
capture system/thermal-sensors.txt 20 sh -c 'for dir in /sys/class/thermal/thermal_zone*; do [ -d "$dir" ] || continue; printf "\n%s\n" "$dir"; cat "$dir/type" "$dir/temp"; done'

for FILE in "$MODDIR/module.prop" "$MODDIR/customize.sh" "$MODDIR/post-fs-data.sh" "$MODDIR/action.sh" "$MODDIR/boot.log" "$MODDIR/boot.previous.log" "$MODDIR/native-settings.txt" "$MODDIR/payload/sensormodule.bin" /system/build.prop /system/system/build.prop /system_ext/build.prop /product/build.prop /vendor/build.prop /odm/build.prop /odm/etc/build.prop /proc/last_kmsg /data/adb/magisk.log /cache/magisk.log /data/adb/ksu/log/ksud.log /data/adb/ksu/logs/ksud.log /sys/fs/pstore/*; do
  save "$FILE"
done

SENSOR=/odm/lib64/camera/com.qti.sensormodule.pudding_sunny_ovx9500_wide_i.bin
CONFIG=/odm/etc/camera/camxoverridesettings.txt
capture camera/action-file-hashes.txt 20 sha256sum "$SENSOR" "$CONFIG" "$MODDIR/payload/sensormodule.bin" "$MODDIR/native-settings.txt"
capture camera/init-file-hashes.txt 20 nsenter -t 1 -m -- sha256sum "$SENSOR" "$CONFIG"
capture camera/init-video-settings.txt 20 nsenter -t 1 -m -- cat "$CONFIG"
capture camera/init-sensormodule.bin 20 nsenter -t 1 -m -- cat "$SENSOR"
capture camera/odm-file-list.txt 30 ls -laR /odm/etc/camera /odm/lib64/camera
capture camera/vendor-file-list.txt 30 ls -laR /vendor/etc/camera /data/vendor/camera /data/vendor/camx
for DIR in /odm/etc/camera /vendor/etc/camera /data/vendor/camera /data/vendor/camx; do
  [ -d "$DIR" ] || continue
  timeout 30 find "$DIR" -type f \( -name '*.txt' -o -name '*.log' -o -name '*.xml' -o -name '*.json' \) > "$WORK/camera-files.list" 2>> "$SNAPSHOT/copy-errors.txt"
  while IFS= read -r FILE; do
    save "$FILE"
  done < "$WORK/camera-files.list"
done

printf 'Collecting full Android bugreport. This may take a few minutes...\n'
capture logs/bugreportz-status.txt 300 bugreportz -p
BUGREPORT=$(sed -n 's/^OK://p' "$SNAPSHOT/logs/bugreportz-status.txt" | tail -n 1 | tr -d '\r')
if [ -n "$BUGREPORT" ] && [ -f "$BUGREPORT" ]; then
  cp "$BUGREPORT" "$SNAPSHOT/android-bugreport.zip" 2>> "$SNAPSHOT/copy-errors.txt" || printf 'Could not copy Android bugreport.\n' >> "$SNAPSHOT/copy-errors.txt"
else
  printf 'Android bugreport unavailable; collected remaining diagnostics.\n'
fi

printf 'Packing ZIP...\n'
if ! make_zip; then
  rm -f "$OUTPUT.partial"
  printf 'Could not create ZIP. Diagnostics kept at: %s\n' "$SNAPSHOT"
  exit 1
fi
rm -rf "$WORK"
printf '\nSaved: %s\nMade by Picters\n' "$OUTPUT"
