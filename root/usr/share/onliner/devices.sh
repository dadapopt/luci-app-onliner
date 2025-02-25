#!/bin/sh

# 默认备注文件路径
MAC_REMARKS_FILE="/usr/share/onliner/mac_remarks"

# 保存备注到文件
save_remark() {
    mac=$1
    remark=$2

    # 如果文件不存在则创建
    if [ ! -f "$MAC_REMARKS_FILE" ]; then
        touch "$MAC_REMARKS_FILE"
    fi

    # 删除旧的备注（如果存在）
    sed -i "/^$mac /d" "$MAC_REMARKS_FILE"

    # 添加新的备注
    echo "$mac $remark" >>"$MAC_REMARKS_FILE"
}
# 获取所有设备信息
get_devices() {
    # 获取 LAN 接口名称
    LAN_IFACE=$(uci get network.lan.device 2>/dev/null)
    if [ -z "$LAN_IFACE" ]; then
        echo '{"error": "LAN interface not found"}'
    fi

    # 初始化 JSON 数组
    echo '{"onlines":['

    first=true

    # 获取 IPv4 设备信息
    ip -4 neigh show dev $LAN_IFACE | while read -r entry; do
        ip=$(echo $entry | awk '{print $1}')
        mac=$(echo $entry | awk '{print $3}')
        state=$(echo $entry | awk '{print $4}')

        # 过滤掉非活跃设备
        if [ "$state" != "REACHABLE" ] && [ "$state" != "STALE" ]; then
            continue
        fi

        # 获取主机名
        hostname=$(grep "$mac" /tmp/dhcp.leases | awk '{print $4}')

        # 获取 IPv6 地址
        ipv6=$(ip -6 neigh show dev $LAN_IFACE | grep -v fe80 | grep "$mac" | awk '{print $1}' | tr '\n' '/')

        # 获取备注信息
        remark=""
        if [ -f "$MAC_REMARKS_FILE" ]; then
            remark=$(grep "^$mac " "$MAC_REMARKS_FILE" | awk '{print $2}')
        fi

        # 输出设备信息
        if [ "$first" = true ]; then
            first=false
        else
            echo ','
        fi

        echo '{"hostname": "'$hostname'", "ipaddr": "'$ip'","ipv6": "'$ipv6'", "macaddr": "'$mac'", "remark": "'$remark'", "device": "'$LAN_IFACE'"}'
    done

    echo ']}'
}
case "$1" in
remark)
    save_remark $2 $3
    ;;

list)
    get_devices
    ;;

*)
    ${0} list
    ;;
esac
