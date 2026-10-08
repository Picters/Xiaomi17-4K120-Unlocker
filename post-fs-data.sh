#!/system/bin/sh
MODDIR=${0%/*}
umask 077
[ ! -f "$MODDIR/boot.log" ] || mv -f "$MODDIR/boot.log" "$MODDIR/boot.previous.log"
exec > "$MODDIR/boot.log" 2>&1 || exit 0
date
set -x
fail() {
  printf 'Error: %s\n' "$1"
  exit 0
}
SENSOR=/odm/lib64/camera/com.qti.sensormodule.pudding_sunny_ovx9500_wide_i.bin
CONFIG=/odm/etc/camera/camxoverridesettings.txt
PAYLOAD="$MODDIR/payload/sensormodule.bin"

[ "$(getprop ro.product.device)" = pudding ] || fail "Unsupported device"
[ -f "$SENSOR" ] && [ -f "$CONFIG" ] || fail "Camera files not found"
HASH=$(sha256sum "$SENSOR") || fail "Cannot read sensor table"
case "${HASH%% *}" in
  a77d196343b2265abb3879267c9b221a21e693db83dab5d0066d34e58b6c6b54|35546ef937aea1d263471c8fd97f051c95d9bb36a916383b79693c09d2f9d804) ;;
  *) fail "Unsupported sensor table" ;;
esac
HASH=$(sha256sum "$PAYLOAD") || fail "Cannot read payload"
[ "${HASH%% *}" = 35546ef937aea1d263471c8fd97f051c95d9bb36a916383b79693c09d2f9d804 ] || fail "Invalid payload"

awk '
  /^[[:space:]]*VideoSizeCustom[[:space:]]*=/ {
    found = 1
    sub(/\r$/, "")
    if ($0 !~ /[=|]0@8@120([|[:space:]]|$)/) {
      sub(/[[:space:]]*$/, "")
      $0 = $0 "|0@8@120"
    }
  }
  { print }
  END { if (!found) exit 1 }
' "$CONFIG" > "$MODDIR/native-settings.tmp" || { rm -f "$MODDIR/native-settings.tmp"; fail "Cannot generate video settings"; }
mv -f "$MODDIR/native-settings.tmp" "$MODDIR/native-settings.txt" || fail "Cannot save video settings"
chmod 0644 "$MODDIR/native-settings.txt" "$PAYLOAD" || fail "Cannot set file permissions"
chcon u:object_r:vendor_file:s0 "$PAYLOAD" || fail "Cannot label sensor payload"
chcon u:object_r:vendor_configs_file:s0 "$MODDIR/native-settings.txt" || fail "Cannot label video settings"
nsenter -t 1 -m -- mount --bind "$PAYLOAD" "$SENSOR" || fail "Cannot mount sensor table"
if ! nsenter -t 1 -m -- mount --bind "$MODDIR/native-settings.txt" "$CONFIG"; then
  nsenter -t 1 -m -- umount "$SENSOR" || fail "Cannot mount video settings; cannot roll back sensor mount"
  fail "Cannot mount video settings; sensor mount rolled back"
fi
printf 'Applied: 4K120 sensor table and video settings\n'
