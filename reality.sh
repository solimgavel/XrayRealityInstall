#!/usr/bin/env bash
LOGGER="XRAY-REALITY-SCRIPT"

BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
BGREEN="\033[1;32m"
BRED="\033[1;31m"
RESET="\033[0m"

SCRIPT="$0"
CURDIR="$(dirname $0)"
XRAY_ORIG_CONFIG="/usr/local/etc/xray/config.json"
CONFIG="$CURDIR/config.json"

TEMPL_CONFIG="$CURDIR/configs/config_1.json"
CMFG_SITE="teamdocs.su"
INBOUND_PORT="443"

URL_FILE="$CURDIR/url.txt"

trap "DIE" SIGHUP SIGINT SIGQUIT SIGABRT

function DIE() {
    CURDATE="${BLUE}$(date +'%Y-%m-%d %T')${RESET}"
    LOGLEVEL="${BRED}CRITICAL${RESET}"
    LOGMSG="the script is exiting"
    echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
    sleep 1
    exit 1
}

function LOG() {
    CURDATE="${BLUE}$(date +'%Y-%m-%d %T')${RESET}"

    case $1 in
        "DEBUG")
            shift
            LOGLEVEL="${GREEN}  DEBUG${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            ;;
        "INFO")
            shift
            LOGLEVEL="${CYAN}   INFO${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            ;;
        "WARNING")
            shift
            LOGLEVEL="${YELLOW}WARNING${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            ;;
        "ERROR")
            shift
            LOGLEVEL="${RED}  ERROR${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            DIE
            ;;
        "CRITICAL")
            shift
            LOGLEVEL="${BRED}CRITICAL${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            DIE
            ;;
        *)
            LOGLEVEL="${WHITE}NOLEVEL${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            ;;
    esac
}

function usage_msg() {
    echo "Usage: $SCRIPT {init (Default) | config [--url (Default) | --qrencode] | update | --help | -h}"
    echo ""
    echo "init:   Default, install, update required packages, generate a config, and start xray"
    echo "config [--url | --qrencode]: generate a new config based on a template config"
    echo "        --url: print to terminal the VLESS url"
    echo "        --qrencode: print the url and also the QR encoded version to terminal"
    echo "update: update the required packages, including xray-core"
    echo "--help | -h: print this help message"
    echo ""
}

function sanity_checks() {
    LOG INFO "checking system requirements"
    [ "$EUID" -eq 0 ] || LOG ERROR "must have root access to run the script!"
    if ! command -v systemctl &>/dev/null; then
        LOG CRITICAL "systemd must be enabled as the init system!"
    fi
}

function install_pkgs() {
    LOG INFO "updating & upgrading system"
    apt update -y && apt upgrade -y

    pkgs=("openssl" "qrencode" "jq" "curl" "xclip")

    for pkg in ${pkgs[@]}; do
        LOG INFO "installing package: $pkg"
        apt install -y $pkg
    done

    LOG DEBUG "installing latest beta version of xray"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta
    LOG DEBUG "testing xray-core version"
    xray --version
    [ $? -ne 0 ] && LOG CRITICAL "something went wrong with xray core!"
}

function xray_new_config() {
    LOG DEBUG "generating uuid"
    uuid=$(xray uuid)
    LOG INFO "setting uuid: ${uuid}"

    LOG DEBUG "generating X25519 private and public key pairs"
    keys=$(xray x25519)
    private_key=$(echo $keys | cut -d " " -f 2)
    LOG INFO "setting private key: ${private_key}"
    public_key=$(echo $keys | cut -d " " -f 4)
    LOG INFO "setting public key: ${public_key}"

    LOG DEBUG "generating short id"
    short_id=$(openssl rand -hex 4)
    LOG INFO "setting short id: ${short_id}"
    
    LOG DEBUG "resolving public ip"
    public_ip=$(curl -s 2ip.io)
    LOG INFO "setting public ip: ${public_ip}"

    cmfgsite="$CMFG_SITE"
    LOG INFO "using camouflag website: ${cmfgsite}"

    flow="xtls-rprx-vision"
    LOG INFO "using flow: ${flow}"

    inbound_port="$INBOUND_PORT"
    LOG INFO "setting inbound listen port: ${inbound_port}"

    protocol_type="tcp"
    LOG INFO "using ${protocol_type}"

    security="reality"
    LOG INFO "setting security: ${security}"

    fingerprint="chrome"
    LOG INFO "using fingerprint: ${fingerprint}"

    random_string=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 4; echo '')
    name="$security-$random_string"
    LOG INFO "setting name of the profile: ${name}"

    LOG DEBUG "using template config file: ${TEMPL_CONFIG}"
    cp "$TEMPL_CONFIG" "$CONFIG"

    LOG DEBUG "populating config.json file"
    #cat <<< $(jq --arg uuid  $uuid '.inbounds[1].settings.clients[0].id = $uuid' "$CONFIG") > "$CONFIG"
    #cat <<< $(jq --arg public_key  $public_key '.inbounds[1].streamSettings.realitySettings.publicKey = $public_key' "$CONFIG") > "$CONFIG"
    #cat <<< $(jq --arg private_key $private_key '.inbounds[1].streamSettings.realitySettings.privateKey = $private_key' "$CONFIG") > "$CONFIG"
    #cat <<< $(jq --arg short_id  $short_id '.inbounds[1].streamSettings.realitySettings.shortIds = [$short_id]' "$CONFIG") > "$CONFIG"

    cat <<< $(jq --arg uuid  $uuid '.inbounds[0].settings.clients[0].id = $uuid' "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg public_key  $public_key '.inbounds[0].streamSettings.realitySettings.publicKey = $public_key' "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg private_key $private_key '.inbounds[0].streamSettings.realitySettings.privateKey = $private_key' "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg short_id  $short_id '.inbounds[0].streamSettings.realitySettings.shortIds = [$short_id]' "$CONFIG") > "$CONFIG"

    case "$1" in
        "--url" | "")
            LOG INFO "generating url"
            url="vless://$uuid@$public_ip:$inbound_port?type=$protocol_type&security=$security&sni=$cmfgsite&pbk=$public_key&flow=$flow&sid=$short_id&fp=$fingerprint#$name"
            echo $url
            LOG INFO "saving url to: ${URL_FILE}"
            echo $url > ${URL_FILE}
            copy_config
            ;;
        "--qrencode")
            LOG INFO "generating url"
            url="vless://$uuid@$public_ip:$inbound_port?type=$protocol_type&security=$security&sni=$cmfgsite&pbk=$public_key&flow=$flow&sid=$short_id&fp=$fingerprint#$name"
            echo $url
            LOG INFO "saving url to: ${URL_FILE}"
            echo $url > ${URL_FILE}

            LOG DEBUG "generating qr encoding of the url"
            qrencode -t ANSIUTF8 $url
            copy_config
            ;;
        *)
            usage_msg
            ;;
    esac
}

function copy_config() {
    LOG INFO "backing up $XRAY_ORIG_CONFIG and replacing it with new config"
    xray_orig_config_dir=$(dirname $XRAY_ORIG_CONFIG)
    [ -f "$xray_orig_config_dir/config.json.old"  ] && LOG WARNING "$xray_orig_config_dir/config.json.old exists, replacing"
    mv "$XRAY_ORIG_CONFIG" "$xray_orig_config_dir/config.json.old"
    cp $CONFIG "$xray_orig_config_dir"
}

function xray_run() {
    copy_config

    if ! systemctl is-enabled --quiet xray.service; then
        LOG DEBUG "xray.service is not enabled, enabling now"
        systemctl enable xray.service
        [ $? -ne 0 ] && LOG CRITICAL "something went wrong when enabling xray.service"
    fi

    if ! systemctl is-active --quiet xray.service; then
        LOG DEBUG "xray.service is not running, starting now"
        systemctl start xray.service
        [ $? -ne 0 ] && LOG CRITICAL "something went wrong when starting xray.service"
    else
        LOG DEBUG "xray.service is already running, restarting"
        systemctl restart xray.service
        [ $? -ne 0 ] && LOG CRITICAL "something went wrong when restarting xray.service"
    fi

    LOG DEBUG "checking status on xray.service"
    systemctl status xray.service
    [ $? -ne 0 ] && LOG CRITICAL "something has went wrong with xray.service, status check not passed"

}

add_short_id() {
    echo "Adding new short ID..."
    
    new_short_id=$(openssl rand -hex 4)
    echo "Generated short ID: $new_short_id"
    
    cat <<< $(jq --arg new_id "$new_short_id" '.inbounds[0].streamSettings.realitySettings.shortIds += [$new_id]' "$CONFIG") > "$CONFIG"
    copy_config
    
    echo "Short ID $new_short_id added successfully!"
    
    list_short_ids
    systemctl restart xray
}

delete_short_id() {
    echo "Deleting short ID..."
    
    local short_ids=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[]?' "$CONFIG" 2>/dev/null)
    
    if [[ -z "$short_ids" ]]; then
        echo "No short IDs found in config!"
        return 1
    fi
    
    local i=1
    local short_id_array=()
    while IFS= read -r id; do
        if [[ -n "$id" ]]; then
            echo "$i. $id"
            short_id_array+=("$id")
            ((i++))
        fi
    done <<< "$short_ids"
    
    if [[ ${#short_id_array[@]} -eq 0 ]]; then
        echo "No valid short IDs found!"
        return 1
    fi
    
    echo ""
    read -p "Select short ID by number [1-${#short_id_array[@]}]: " selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#short_id_array[@]} ]]; then
        echo "Invalid selection!"
        return 1
    fi
    
    local short_id_to_delete="${short_id_array[$((selection-1))]}"
    
    cat <<< $(jq --arg del_id "$short_id_to_delete" '.inbounds[0].streamSettings.realitySettings.shortIds |= map(select(. != $del_id))' "$CONFIG") > "$CONFIG"
    copy_config

    echo "Short ID $short_id_to_delete deleted successfully!"
    
    list_short_ids
    systemctl restart xray
}

list_short_ids() {
    local short_ids=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[]?' "$CONFIG")
    
    if [[ -n "$short_ids" ]]; then
        echo "Current short IDs:"
        echo "$short_ids" | while read -r id; do
            echo "  - $id"
        done
    else
        echo "No short IDs found in config"
    fi
}

get_vless_profile() {
    local short_ids=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[]?' "$CONFIG")
    
    if [[ -z "$short_ids" ]]; then
        echo "No short IDs found in config!"
        return 1
    fi
    
    echo "Available short IDs:"
    local i=1
    local short_id_array=()
    while IFS= read -r id; do
        if [[ -n "$id" ]]; then
            echo "$i. $id"
            short_id_array+=("$id")
            ((i++))
        fi
    done <<< "$short_ids"
    
    if [[ ${#short_id_array[@]} -eq 0 ]]; then
        echo "No valid short IDs found!"
        return 1
    fi
    
    echo ""
    read -p "Select short ID by number [1-${#short_id_array[@]}]: " selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#short_id_array[@]} ]]; then
        echo "Invalid selection!"
        return 1
    fi
    
    local uuid=$(jq -r '.inbounds[0].settings.clients[0].id?' "$CONFIG")

    local selected_short_id="${short_id_array[$((selection-1))]}"
    echo "Selected short ID: $selected_short_id"
    
    local server_name=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]?' "$CONFIG")
    local private_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey?' "$CONFIG")
    local server_port=$(jq -r '.inbounds[0].port?' "$CONFIG")
    
    # local public_key=$(echo "$private_key" | base64 -d | openssl ec -pubout -outform der 2>/dev/null | tail -c 65 | base64 -w 0 | tr '/+' '_-' | tr -d '=' 2>/dev/null)
    local public_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.publicKey?' "$CONFIG")
    
    server_ip=$(curl -s https://2ip.io | awk '{print $1}')
    
    local vless_url="vless://${uuid}@${server_ip}:${server_port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${server_name}&fp=chrome&pbk=${public_key}&sid=${selected_short_id}&type=tcp&headerType=none#Xray-Reality"
    
    echo ""
    echo "=== VLESS URL ==="
    echo "$vless_url"
    echo ""
    
    echo "=== QR Code ==="
    qrencode -t ANSIUTF8 "$vless_url"
    echo ""
    
    # local output_file="vless_url_${selected_short_id}.txt"
    # echo "$vless_url" > "$output_file"
    # echo "URL saved to: $output_file"
}

menu() {
    while true; do
        echo "What do you want to do?"
        echo "1. Add new short ID"
        echo "2. Delete short ID"
        echo "3. List all short IDs"
        echo "4. Get vless profile"
        echo "5. Replace all config"
        echo "6. Update packages"
        echo "7. Help"
        echo "8. Exit"
        
        read -p "Please choose an option [1-8]: " choice

        if [[ -z "${choice// }" ]]; then
          exit 0
        fi

        case $choice in
            1)
                add_short_id
                ;;
            2)
                delete_short_id
                ;;
            3)
                list_short_ids
                ;;
            4)
                get_vless_profile
                break
                ;;
            5)
                xray_new_config "$@"
                xray_run
                break
                ;;
            6)
                install_pkgs "$@"
                ;;
            7)
                usage_msg
                ;;
            8)
                break
                ;;
            *)
                echo "Invalid option!"
                ;;
        esac
        
        echo
    done
}

function main() {
    case "$1" in
        "init" | "")
            shift
            if [[ ! -f "/usr/local/etc/xray/config.json" ]]; then
                sanity_checks
                install_pkgs
                xray_new_config --qrencode
                xray_run
            else
                menu
            fi

            ;;
        "config")
            shift
            xray_new_config "$@"
            xray_run
            exit 0
            ;;
        "update")
            shift
            install_pkgs "$@"
            ;;
        "--help" | "-h")
            usage_msg
            ;;
        *)
            usage_msg
            ;;
    esac
}

main "$@"
