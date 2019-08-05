
pre_openvpn(){
    mount -o rw,remount /system
    export PATH=${PATH}:$(pwd)/bin
    for C in killall awk grep pgrep;do
        if ! command -v $C >/dev/null 2>&1;then
            if ! busybox cp bin/busybox /system/bin/$C;then
                echo "请赋予文件夹及其子文件777权限"
                exit 1
            fi
        fi
    done
    . ./config.ini
    rm -f *.bak */*.bak
    IP=$(grep "^[ \t]*http-proxy " config/$config | awk '{print $2}' || grep "^[ \t]*remote" config/$config | awk '{print $2}')
    if [ -d "/system/lib64" ];then
        openvpn=openvpn_aarch64
    else
        openvpn=openvpn_arm
    fi
    interface=$(ip addr | grep "inet " | sed -n "2p" | awk '{print $NF}')
}

check_openvpn(){
    if pgrep $openvpn >/dev/null 2>&1;then
        openvpn_status="    ⊂●"
    else
        openvpn_status="    ○⊃"
    fi
    echo
    echo "$openvpn_status  $openvpn"
}

start_openvpn(){
    if [ ! -z "$user" -a ! -z "$passwd" ];then
        echo "$user $passwd" | awk '{print $1 "\n" $2}' > ./config/$config.passwd
        $openvpn --config ./config/$config --auth-user-pass ./config/$config.passwd --dev-node /dev/tun --dev tun_openvpn --route-noexec >./bin/openvpn.log 2>&1 &
    else
        $openvpn --config ./config/$config --dev-node /dev/tun --dev tun_openvpn --route-noexec >./bin/openvpn.log 2>&1 &
    fi
    mount -o ro,remount /system
}

stop_openvpn(){
    killall $openvpn
    ip route del default dev tun_openvpn table 122
    eval ip rule | grep -E "to | 122" | sed 's|.*from|ip rule del from |g' | sh
    iptables -t nat -D OUTPUT -p udp --dport 53 -j DNAT --to 114.114.114.114:53
    while true;do
        pgrep $openvpn || break
    done
} >/dev/null 2>&1

add_rule(){
    while true;do
        ip route show dev tun_openvpn && break
        sleep 0.5
    done >/dev/null 2>&1
    sleep 0.5
    ip route add default dev tun_openvpn table 122
    ip rule add table 122
    ip rule add to $IP table $interface
    iptables -t nat -I OUTPUT -p udp --dport 53 -j DNAT --to 114.114.114.114:53
}

edit_config(){
    sed -i "s|\"||g ; s|'||g ; /setenv /d ; /push/d" ./config/$config
    sed -i 's|EXT1 |EXT1 "|g ; s|EXT1.*|&"|g' ./config/$config
} >/dev/null 2>&1

chmod -R 777 ${0%/*}
cd ${0%/*}
pre_openvpn
if [ "$1" = "stop" ];then
    stop_openvpn
elif [ -z "$1" ];then
    stop_openvpn
    edit_config
    start_openvpn
    add_rule
fi
check_openvpn
