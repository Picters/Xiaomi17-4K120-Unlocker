#!/system/bin/sh
SKIPMOUNT=true

ui_print ""
ui_print "  $(sed -n 's/^name=//p' "$MODPATH/module.prop")"
ui_print "  ────────────────────"

[ "$(getprop ro.product.device)" = pudding ] || abort "  Unsupported device"

SENSOR=/odm/lib64/camera/com.qti.sensormodule.pudding_sunny_ovx9500_wide_i.bin
CONFIG=/odm/etc/camera/camxoverridesettings.txt
[ -f "$SENSOR" ] && [ -f "$CONFIG" ] || abort "  Camera files not found"

HASH=$(sha256sum "$SENSOR") || abort "  Cannot read sensor table"
case "${HASH%% *}" in
  a77d196343b2265abb3879267c9b221a21e693db83dab5d0066d34e58b6c6b54|35546ef937aea1d263471c8fd97f051c95d9bb36a916383b79693c09d2f9d804) ;;
  *) abort "  Unsupported sensor table" ;;
esac
HASH=$(sha256sum "$MODPATH/payload/sensormodule.bin") || abort "  Payload not found"
[ "${HASH%% *}" = 35546ef937aea1d263471c8fd97f051c95d9bb36a916383b79693c09d2f9d804 ] || abort "  Invalid payload"
grep -q '^[[:space:]]*VideoSizeCustom[[:space:]]*=' "$CONFIG" || abort "  Video settings not found"

set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/payload/sensormodule.bin" 0 0 0644

ui_print "  Ready. Reboot to apply."
ui_print ""
ui_print "  Made by Picters"
