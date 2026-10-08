#!/system/bin/sh
MODDIR=${0%/*}
SENSOR=/odm/lib64/camera/com.qti.sensormodule.pudding_sunny_ovx9500_wide_i.bin
CONFIG=/odm/etc/camera/camxoverridesettings.txt
PAYLOAD="$MODDIR/payload/sensormodule.bin"

[ "$(getprop ro.product.device)" = pudding ] || exit 0
[ -f "$SENSOR" ] && [ -f "$CONFIG" ] || exit 0
HASH=$(sha256sum "$SENSOR") || exit 0
case "${HASH%% *}" in
  a77d196343b2265abb3879267c9b221a21e693db83dab5d0066d34e58b6c6b54|35546ef937aea1d263471c8fd97f051c95d9bb36a916383b79693c09d2f9d804) ;;
  *) exit 0 ;;
esac
HASH=$(sha256sum "$PAYLOAD") || exit 0
[ "${HASH%% *}" = 35546ef937aea1d263471c8fd97f051c95d9bb36a916383b79693c09d2f9d804 ] || exit 0

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
' "$CONFIG" > "$MODDIR/native-settings.tmp" || { rm -f "$MODDIR/native-settings.tmp"; exit 0; }
mv -f "$MODDIR/native-settings.tmp" "$MODDIR/native-settings.txt" || exit 0
chmod 0644 "$MODDIR/native-settings.txt" "$PAYLOAD" || exit 0
chcon u:object_r:vendor_file:s0 "$PAYLOAD" || exit 0
chcon u:object_r:vendor_configs_file:s0 "$MODDIR/native-settings.txt" || exit 0
nsenter -t 1 -m -- mount --bind "$PAYLOAD" "$SENSOR" || exit 0
if ! nsenter -t 1 -m -- mount --bind "$MODDIR/native-settings.txt" "$CONFIG"; then
  nsenter -t 1 -m -- umount "$SENSOR"
  exit 0
fi
