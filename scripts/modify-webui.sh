#!/bin/sh
# Made by Jack'lul <jacklul.github.io>
#
# Apply tweaks to the WebUI dynamically
#

#shellcheck disable=SC2155

readonly SCRIPT_PATH="$(readlink -f "$0")"
readonly SCRIPT_NAME="$(basename "$SCRIPT_PATH" .sh)"
readonly SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
readonly SCRIPT_CONFIG="$SCRIPT_DIR/$SCRIPT_NAME.conf"
readonly SCRIPT_TAG="$(basename "$SCRIPT_PATH")"

if [ -f "$SCRIPT_CONFIG" ]; then
    #shellcheck disable=SC1090
    . "$SCRIPT_CONFIG"
fi

TMP_WWW_PATH="/tmp/$SCRIPT_NAME/www"

replace_and_check() {
    _SED="$1"
    _FILE="$2"

    _MD5SUM="$(md5sum "$_FILE" | awk '{print $1}')"

    sed -i "$_SED" "$_FILE"

    _MD5SUM2="$(md5sum "$_FILE" | awk '{print $1}')"

    if [ "$_MD5SUM" != "$_MD5SUM2" ]; then
        return 0
    fi

    logger -st "$SCRIPT_TAG" "There was a problem running modification on file $_FILE: $_SED"
    
    return 1
}

cpu_temperature_on_status() {
    case "$1" in
        "set")
            if ! mount | grep -q "/www/cpu_ram_status.asp"; then
                cp -f /www/cpu_ram_status.asp "$TMP_WWW_PATH/cpu_ram_status.asp"

                echo "cpuTemp = '<%get_cpu_temperature();%>';" >> "$TMP_WWW_PATH/cpu_ram_status.asp"

                mount --bind "$TMP_WWW_PATH/cpu_ram_status.asp" /www/cpu_ram_status.asp
            fi

            if ! mount | grep -q "/www/device-map/router_status.asp"; then
                mkdir -p "$TMP_WWW_PATH/device-map"
                cp -f /www/device-map/router_status.asp "$TMP_WWW_PATH/device-map/router_status.asp"

                replace_and_check 's@render_CPU(cpuInfo);@render_CPU(cpuInfo, cpuTemp);@g' "$TMP_WWW_PATH/device-map/router_status.asp"
                replace_and_check 's@function(cpu_info_new)@function(cpu_info_new, cpu_temp_new)@g' "$TMP_WWW_PATH/device-map/router_status.asp"
                replace_and_check "s@Object.keys(cpu_info_new).length;@Object.keys(cpu_info_new).length;\$(\"#cpu_temp\").html(parseFloat(cpu_temp_new).toFixed(1));@g" "$TMP_WWW_PATH/device-map/router_status.asp"
                replace_and_check "s@\$('#cpu_field').html(code);@code += '<div class=\"info-block\">Temperature: <span id=\"cpu_temp\"></span> °C</div>';\$('#cpu_field').html(code);@g" "$TMP_WWW_PATH/device-map/router_status.asp"

                mount --bind "$TMP_WWW_PATH/device-map/router_status.asp" /www/device-map/router_status.asp
            fi
        ;;
        "unset")
            if mount | grep -q "/www/cpu_ram_status.asp"; then
                umount "/www/cpu_ram_status.asp"
                rm -f "$TMP_WWW_PATH/cpu_ram_status.asp"
            fi

            if mount | grep -q "/www/device-map/router_status.asp"; then
                umount "/www/device-map/router_status.asp"
                rm -f "$TMP_WWW_PATH/device-map/router_status.asp"
            fi
        ;;
    esac
}

guest_wifi_qr_code() {
    case "$1" in
        "set")
            if ! mount | grep -q "/www/Guest_network.asp"; then
                cp -f /www/Guest_network.asp "$TMP_WWW_PATH/Guest_network.asp"

                replace_and_check 's@<script type="text/javascript" src="js/httpApi.js"></script>@<script type="text/javascript" src="js/httpApi.js"></script><script src="https://cdn.rawgit.com/davidshimjs/qrcodejs/gh-pages/qrcode.min.js"></script>@g' "$TMP_WWW_PATH/Guest_network.asp"
                replace_and_check 's@onclick="applyRule();">@onclick="applyRule();"><br><span id="qr_code" style="display:inline-block;margin:25px 0 25px 0;"></span>@g' "$TMP_WWW_PATH/Guest_network.asp"
                replace_and_check "s@gn_array\[i\]\[4\];@'Hidden';@g" "$TMP_WWW_PATH/Guest_network.asp"
                replace_and_check "s@gn_array\[i\]\[key_index\];@'Hidden';@g" "$TMP_WWW_PATH/Guest_network.asp"
                replace_and_check 's@updateMacModeOption();@updateMacModeOption();var qrstring="WIFI:S:"+document.form.wl_ssid.value+";";document.form.wl_wpa_psk.value\&\&0<document.form.wl_wpa_psk.value.length?qrstring+="T:WPA;P:"+document.form.wl_wpa_psk.value+";":qrstring+="T:nopass;",1==document.form.wl_closed[0].checked\&\&(qrstring+="H:true;"),document.getElementById("qr_code").innerHTML="",new QRCode(document.getElementById("qr_code"),{text:qrstring+";",width:500,height:500});@g' "$TMP_WWW_PATH/Guest_network.asp"

                mount --bind "$TMP_WWW_PATH/Guest_network.asp" /www/Guest_network.asp
            fi
        ;;
        "unset")
            if mount | grep -q "/www/Guest_network.asp"; then
                umount "/www/Guest_network.asp"
                rm -f "$TMP_WWW_PATH/Guest_network.asp"
            fi

            rm -fr "$TMP_WWW_PATH"
        ;;
    esac
}

www_override() {
    case "$1" in
        "set")
            mkdir -p "$TMP_WWW_PATH"

            cpu_temperature_on_status set
            guest_wifi_qr_code set
        ;;
        "unset")
            cpu_temperature_on_status unset
            guest_wifi_qr_code unset

            rm -fr "$TMP_WWW_PATH"
        ;;
    esac
}

case "$1" in
    "start")
        www_override set
    ;;
    "stop")
        www_override unset
    ;;
    "restart")
        sh "$SCRIPT_PATH" stop
        sh "$SCRIPT_PATH" start
    ;;
    *)
        echo "Usage: $0 start|stop|restart"
        exit 1
    ;;
esac
