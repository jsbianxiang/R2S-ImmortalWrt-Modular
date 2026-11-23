#!/bin/bash
# =============================================================================
# custom-packages.sh —— 可选软件包开关
# -----------------------------------------------------------------------------
# 由 rockchip/build.sh 以 `source` 方式加载；本文件只做 $CUSTOM_PACKAGES 字符串
# 拼接，最终由 build.sh 传给 `make image PACKAGES="..."`。
#
# 用法：
#   1. 第三方插件（默认 clashoo）已默认启用，见「一」，一般无需改动。
#   2. 官方源软件：把短名填进「二」2.1 的 ENABLE_APPS（空格分隔）即可，脚本会
#      自动展开为 luci-app-<短名> + luci-i18n-<短名>-zh-cn（后者依赖前者，
#      两者会一起装上）。可用短名见「三」。
#      例：ENABLE_APPS="filemanager rclone ttyd"
#   3. 少数包不是 luci-app-<短名> 形式（luci-proto-* / luci-mod-* / openclash /
#      passwall 等），在「二」2.2 里取消对应行注释即可。
#
# 注意事项：
#   1. 【第三方插件】必须先注入其对应的第三方源，否则 make image 会因找不到包
#      而失败。本分支已注入 kenzok8 / dllkids 的 APK 源（默认只启用 clashoo）；
#      自行加源方法见 README「如何自行增加第三方源」。
#   2. 【代理类插件互斥 —— 已由构建期硬校验兜底】
#      下面这些包**全部是「透明代理接管型」**，只能启用其中一个（共 27 套）：
#        nikki / clashoo / openclash / passwall / passwall2 / ssr-plus /
#        homeproxy / dae / daed / daed-next / daede /
#        shadowsocks / shadowsocks-libev / shadowsocks-rust /
#        redsocks / redsocks2 / domain-proxy / xray / v2raya /
#        ss-redir / nekobox / honk / jederproxy / xjay /
#        mproxy / miniproxy / fchomo
#      ⚠ **判定真源是 rockchip/build.sh 的 `_PROXY_STACKS` 表（27 条）**。
#        该表与 README「代理插件互斥」表、本清单**三处必须同步**，改一处就要改三处。
#      构建期检测到 ≥2 套会直接 exit 1（实验用途可用 ALLOW_PROXY_CONFLICT=1 放行）。
#      ⚠ 判定是**整词**匹配，故 luci-app-passwall2 ≠ luci-app-passwall、
#        luci-app-xray-status 是 luci-app-xray 的配套状态页（不算独立栈，可共存）。
#      ✅ 不算冲突（可共存）：luci-app-xray-status / microsocks / gost /
#        softethervpn / luci-app-ssrserver-python / luci-app-ssr-mudb-server /
#        luci-app-v2ray-server / tun2socks / smartdns / mosdns / chinadns-ng /
#        adguardhome / luci-app-dnsproxy / luci-app-dnscrypt-proxy2 /
#        luci-app-ikoolproxy / luci-app-haproxy-tcp / luci-app-https-dns-proxy /
#        luci-app-tinyproxy / geoview。
#        （LuCI 应用一律写**全名** luci-app-*，与 rockchip/build.sh 的 _PROXY_OK
#          白名单、README「不算冲突」表口径一致；microsocks / gost / smartdns /
#          mosdns / chinadns-ng / adguardhome / geoview 等本身就是独立包名，
#          不存在 luci-app- 形式。后两个 LuCI 项是 DNS 层与显式正向代理，
#          不接管透明流量。）
#   3. 本分支不集成 store / istore，故不提供依赖 istore 的插件选项。
#   4. 硬路由 / 小闪存设备请酌情启用；包过多会导致固件过大或构建失败。
#   5. 「三」的短名已对 ImmortalWrt 25.12 官方源（aarch64_generic，共 11542 个包）
#      逐一校验。25.12 官方源**没有 luci-app- 前端**的 cshark / dynapoint /
#      haproxy-tcp / mjpg-streamer / nft-qos / splash，以及官方源本就没有的
#      nikki / radicale，均已剔除，避免「取消注释即构建失败」。
#      ⚠ 注意：其中 haproxy-tcp / nft-qos / nikki 在 **dllkids 第三方源**里是有
#        `luci-app-` 前端的，只是**官方源没有** —— 本清单按官方源校验，故不列入；
#        要启用它们请走「一、第三方插件」（受代理互斥约束）。
#   6. 【已内置中文的 app 包】argon-config / cpufreq / diskman 这三个短名的 app 包
#      在 **dllkids 第三方源**里有 27.150.x 版本，包内**自带简体中文**
#      （usr/lib/lua/luci/i18n/<名>.zh-cn.lmo）；官方源同名包是 26.236.x，不含中文。
#      apk 取版本高者 ⇒ 实际装的是 dllkids 那份，故启用它们时**不能**再配独立的
#      luci-i18n-<短名>-zh-cn（26.236.x），否则 apk 会因文件冲突报
#      "trying to overwrite ... owned by ..." 导致 make image 失败。
#      2.1 的短名展开已用 I18N_BUILTIN 列表自动规避，无需手工处理。
# =============================================================================

# =============================================================================
# 一、第三方插件
# -----------------------------------------------------------------------------
# rockchip/build.sh 注入的第三方源（25.12 / aarch64_generic）除本分支默认启用的
# clashoo 外，还提供 luci-app-ssr-plus / passwall2 / nikki / openclash / mihomo 等，
# 需要时取消 1.2 的注释即可，无需另外加源。
#
# ⚠ 该源的第三方 LuCI 应用**没有**独立中文语言包（源内 640 个包里只有
#   clashoo 与 eqos 两个 i18n 包），所以不要给它们加 luci-i18n-xxx-zh-cn，
#   否则 make image 会因找不到包而失败。
#   （2026-11-24 复核：源侧 622 → 640，luci-app-* 411 → 416；audit.py --online 捕获。）
# =============================================================================
# 【当前已启用】clashoo —— ⚠ 与 nikki / openclash 等互斥，
# 换栈时必须先把下面这行注释掉，再取消目标栈那一行的注释（见文件头「注意事项 2」）。
#
# clashoo 三件套（2026-11-24 核实）：
#   · luci-app-clashoo 硬依赖 luci-i18n-clashoo-zh-cn ⇒ 中文包必须一起写；
#   · clashoo 包自带内核 /usr/libexec/clashoo/mihomo-stable（21 MB），并提供
#     mihomo 虚拟名 ⇒ 不需要额外装 mihomo 包；
#   · clashoo 的 D: 已含 kmod-tun / kmod-inet-diag / kmod-nft-tproxy /
#     kmod-nft-socket / kmod-dummy 等，apk 会自动解析 ⇒ 不必显式列出。
CUSTOM_PACKAGES="$CUSTOM_PACKAGES clashoo luci-app-clashoo luci-i18n-clashoo-zh-cn"

# -----------------------------------------------------------------------------
# 1.2 其他第三方插件（可选；⚠ 代理类互斥，只能选一个）
# -----------------------------------------------------------------------------
# 下面每行的包都已逐一校验存在（官方源或已注入的第三方源），取消注释即启用。
# 第三方应用是中文原生，没有独立语言包，故都不带 luci-i18n-*-zh-cn。
#
# SSR-Plus —— mihomo 内核由 rockchip/build.sh 自动补进 PACKAGES，这里不用写
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-ssr-plus xray-core naiveproxy kmod-nft-tproxy kmod-nft-socket"
# PassWall2
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-passwall2 geoview xray-core sing-box hysteria kmod-nft-tproxy kmod-nft-socket"
# nikki（核心包名就叫 nikki）—— ⚠ 透明代理接管型，与其他代理栈互斥，不可同时启用
# 注意：nikki 的内核由 rockchip/build.sh 的「跟随上游最新正式版」逻辑覆盖到
# /usr/libexec/mihomo-core；clashoo 的内核在 /usr/libexec/clashoo/mihomo-stable，
# 两者路径不同，故换栈时 build.sh 的判断条件也会随之切换（见该文件 mihomo 段）。
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-nikki nikki kmod-tun kmod-inet-diag kmod-nft-tproxy kmod-nft-socket"
#
# OpenClash 不列在这里，它在「二」2.2（内核由 rockchip/build.sh 处理）。

# =============================================================================
# 二、ImmortalWrt 官方源软件
# =============================================================================
# 2.1 短名开关：填进 ENABLE_APPS 即启用（空格分隔；留空 = 一个都不装）
# -----------------------------------------------------------------------------
ENABLE_APPS=""
# 示例：ENABLE_APPS="filemanager rclone ttyd"

# ⚠ 例外：下列短名的 app 包由 **dllkids 第三方源**提供 27.150.x 版本，**已内置简体中文**
#   （官方源同名包为 26.236.x，不含中文；apk 取版本高者 ⇒ 实际装的是 dllkids 那份）。
#   若再搭配独立的 luci-i18n-<短名>-zh-cn（26.236.x），apk 会因文件冲突报
#     ERROR: luci-i18n-xxx-zh-cn: trying to overwrite ... owned by luci-app-xxx
#   从而中断 make image。故这些短名只展开 luci-app-<短名>，不再加 i18n 包。
#   ⚠ 这三项必须同时出现在下方「三、可用短名清单」里（audit.py 会校验该包含关系）。
I18N_BUILTIN="argon-config cpufreq diskman"

for _app in $ENABLE_APPS; do
    CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-$_app"
    case " $I18N_BUILTIN " in
        *" $_app "*) : ;;                                              # 已内置中文
        *)           CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-i18n-$_app-zh-cn" ;;
    esac
done
unset _app

# -----------------------------------------------------------------------------
# 2.2 需写全名的包（不是 luci-app-<短名> 形式，或需额外依赖）
# -----------------------------------------------------------------------------
# 网络协议
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-proto-wireguard"
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-proto-minieap luci-i18n-minieap-zh-cn"
# 面板（luci-mod-*）
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-mod-battstatus luci-i18n-battstatus-zh-cn"
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-mod-dashboard luci-i18n-dashboard-zh-cn"
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-mod-dsl luci-i18n-dsl-zh-cn"
# 代理（⚠ 与其他代理栈互斥，只能选一个）
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES geoview xray-core sing-box hysteria luci-i18n-passwall-zh-cn"
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-openclash luci-compat kmod-tun kmod-inet-diag kmod-nft-tproxy bash curl ip-full unzip"

# -----------------------------------------------------------------------------
# 2.3 模块化开关（本项目新增；从 YAOF 插件集移植）
# -----------------------------------------------------------------------------
# 由工作流输入 `enable_modules` 经 env 中转传入本脚本的 ENABLE_MODULES 环境变量
# （空格分隔的模块名）。默认空 = 一个都不装，保持原项目的极简基线。
#
# 设计约束（务必遵守，否则会破坏原项目的验证体系）：
#   a) 只收录**已核实存在**于 ImmortalWrt 25.12.0/.1/.2 官方源（5 feed + target
#      + kmods）/ dllkids 源的包，逐版本核对日期 2026-11-24。三版本用户态包集合
#      一致（11531/11542/11542），差异仅在 kmods（内核 6.12.87/.94/.103）。
#      缺失的包（kmod-tcp-bbr3 / luci-app-flowcone / kmod-sched-fq-codel）不收录。
#   b) 不收录任何**透明代理接管型**插件（homeproxy / dae / honk / nikki 等）——
#      它们必须走「一、第三方插件」的代理互斥机制，避免与默认 clashoo 双开。
#   c) **不写独立 i18n 包**（2026-11-24 实测）：upnp / ddns 这 2 个 app 在
#      **dllkids 源的版本自带简体中文**（包内含 zh-cn.lmo 与 uci-defaults）。
#      apk 取版本高者（dllkids 27.x > 官方 26.x）⇒ 实际装的是自带中文那份；
#      若再配官方的 luci-i18n-<名>-zh-cn（26.x），apk 会报
#        "trying to overwrite ... owned by luci-app-<名>" 使 make image 失败。
#      这与文件头「注意事项 6」的 I18N_BUILTIN 是同一类问题，只是发生在模块里。
#      （原 natmap / arpbind / 3cat 也属此类，但已在本次精简中移除。）
#      ⚠ 例外 zerotier：dllkids 版本（1.0-r21）**低于**官方（26.x），apk 装的是
#      官方那份（不含中文），配 luci-i18n-zerotier-zh-cn 不会冲突；2026-11-24
#      的构建日志实证——其余 app 都报了 trying to overwrite，唯独 zerotier 没有。
#      audit.py 检查 4c 对 zerotier 放行。
#      filemanager 不在 dllkids 源（用官方版），其中文包由 build.sh 默认已装；
#      partexp / vantage 两源均无独立 i18n，保持原样。
#   d) 未知模块名只 WARN 不 FAIL —— 容错，避免拼错一个名字就整包构建失败。
#
# 可用模块（8 个；2026-11-24 精简掉 3 个模块内部的包，qos 模块保留）：
#   network    网络：WireGuard 协议 + ZeroTier + UPnP（已去掉 natmap）
#   qos         QoS：SQM + CAKE 队列纪律（用户要求保留）
#   ddns        动态域名：DDNS + Cloudflare 脚本
#   monitor     监控：Bandix 实时流量（已去掉 ARP 绑定与 3cat/3proxy）
#   storage     存储：文件管理 + 分区扩容 + f2fs + zram-swap
#   tuning      调优：BBR 拥塞控制 + ethtool
#   usbnet      USB 网络：RNDIS + CDC-Ether + ipheth + usbmuxd（手机共享网络）
#   theme-vantage 主题：Vantage（dllkids 源，无独立 i18n 包，故不追加 zh-cn）
ENABLE_MODULES="${ENABLE_MODULES:-}"

_add_module() {
    case "$1" in
        network)
            # ⚠ 不收录 natmap / natmapt：2026-11-24 用户确认不需要内网穿透打洞；
            #   且 natmapt 前端依赖的核心包全源缺失（曾致构建失败）。
            # zerotier 用官方 26.x（dllkids 的 1.0 更低），故可安全配官方中文包
            CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-proto-wireguard luci-app-zerotier luci-i18n-zerotier-zh-cn luci-app-upnp"
            ;;
        qos)
            # 2026-11-24 用户确认保留：SQM 智能队列 + CAKE（缓冲膨胀控制）
            CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-sqm kmod-sched-cake"
            ;;
        ddns)
            CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-ddns ddns-scripts ddns-scripts-cloudflare"
            ;;
        monitor)
            # 2026-11-24 精简：移除 arpbind（IP/MAC 绑定）与 3cat
            #   —— 3cat 依赖 3proxy-mod-tcppm/udppm（即 LuCI 里的 3proxy 来源）
            CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-bandix"
            ;;
        storage)
            # luci-i18n-filemanager-zh-cn 由 build.sh 默认 PACKAGES 已装，此处不重复
            CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-filemanager luci-app-partexp kmod-fs-f2fs zram-swap"
            ;;
        tuning)
            CUSTOM_PACKAGES="$CUSTOM_PACKAGES kmod-tcp-bbr ethtool"
            ;;
        usbnet)
            CUSTOM_PACKAGES="$CUSTOM_PACKAGES kmod-usb-net-rndis kmod-usb-net-cdc-ether kmod-usb-net-ipheth usbmuxd"
            ;;
        theme-vantage)
            CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-theme-vantage luci-app-vantage"
            ;;
        *)
            printf '[WARN] 未知模块名：%s（已忽略；可用：network qos ddns monitor storage tuning usbnet theme-vantage）\n' "$1" >&2
            ;;
    esac
}

for _mod in $ENABLE_MODULES; do
    _add_module "$_mod"
done
unset _mod

# =============================================================================
# 三、可用短名清单（已对 ImmortalWrt 25.12 官方源校验；填进 2.1 的 ENABLE_APPS）
# =============================================================================
# --- 代理 / VPN / DNS 分流 ---
#   homeproxy                 passwall                  dae                       openvpn                   v2raya
#   microsocks                tinyproxy                 privoxy                   tor                       softethervpn
#   ipsec-vpnd                ocserv                    gost                      smartdns                  nextdns
#   unbound                   https-dns-proxy           adblock                   adblock-fast              pbr
#
# --- 内网穿透 / DDNS / 远程访问 ---
#   zerotier                  frpc                      frps                      ddns                      ddns-go
#   ngrokc                    nps                       xfrpc                     n2n                       natmap
#   tailscale-community       cloudflared               sshtunnel                 rustdesk-server           wechatpush
#   eoip
#
# --- 文件 / 存储 / 下载 ---
#   filemanager               filebrowser               filebrowser-go            openlist                  samba4
#   ksmbd                     nfs                       cifs-mount                minidlna                  aria2
#   qbittorrent               transmission              amule                     syncthing                 rclone
#   vsftpd                    usb-printer               ps3netsrv                 ser2net                   hd-idle
#   diskman ★已内置中文（见 2.1 的 I18N_BUILTIN，不会另装 i18n 包）
#
# --- 媒体 / IPTV ---
#   udpxy                     msd_lite                  spotifyd                  airplay2                  music-remote-center
#   oscam                     dump1090
#
# --- 网络管理 / 监控 / 无线 ---
#   mwan3                     sqm                       qos                       nlbwmon                   vnstat2
#   netdata                   statistics                usteer                    dawn                      watchcat
#   lldpd                     bmx7                      olsr                      olsr-services             olsr-viz
#   wifischedule              arpbind                   banip                     bcp38                     eqos
#   irqbalance                cpulimit                  ramfree                   dcwapd                    advanced-reboot
#   autoreboot                attendedsysupgrade
#
# --- 网络唤醒 / 服务发现 ---
#   wol                       timewol                   upnp
#
# --- 认证 / 校园网 / 拨号 ---
#   cd8021x                   sysuh3c                   ua2f                      bitsrunlogin-go           pppoe-relay
#   pppoe-server              rp-pppoe-server           coovachilli               openwisp                  omcproxy
#
# --- 系统工具 / 服务 ---
#   ttyd                      commands                  uhttpd                    lxc                       email
#   sms-tool-js               nut                       oled                      modemband                 p910nd
#   vlmcsd                    clamav                    crowdsec-firewall-bouncer  fwknopd                   keepalived
#   snmpd                     mosquitto                 pagekitec                 3cat                      3ginfo-lite
#   acl                       acme                      appfilter                 example                   xinetd
#   xlnetacc                  travelmate                squid
#
# --- 主题 / CPU 调优 ---
#   这两个短名的 app 包由 dllkids 第三方源提供 27.150.x 版本、包内自带简体中文，
#   脚本**不会**再展开 luci-i18n-<名>-zh-cn（加了会文件冲突，见文件头「注意事项 6」）。
#   argon-config ★已内置中文（同 diskman，不再另装 i18n 包）
#   cpufreq ★已内置中文（同 diskman，不再另装 i18n 包）
#
