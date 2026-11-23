# 软件包说明（NanoPi R2S 专用分支）

本分支**不克隆**任何第三方插件源码仓库（`run/` 方式），只以 APK 源的形式注入第三方源。
可安装的软件来自以下两类来源。

## 一、ImmortalWrt 官方源

所有 ImmortalWrt 官方软件包与**全部 kmod** 均可直接安装。
由于使用官方 Image Builder + 官方内核，官方 kmods 源的内核模块与固件内核版本天然匹配，
不会出现「kmod 装不上」的问题。

- 查询官方软件包：<https://downloads.immortalwrt.org/releases/>
- kmods 源由 Image Builder 自动纳入 `repositories`，无需手工配置

> ℹ️ **首启后官方源地址会被改写**：固件自带的 `/etc/uci-defaults/99-default-settings-chinese`
> 会把 `/etc/apk/repositories.d/distfeeds.list` 里的 `https://downloads.immortalwrt.org`
> 换成 ImmortalWrt 官方镜像 `https://mirrors.vsean.net/openwrt`（重定向到中科大镜像）。
> 这是 **ImmortalWrt 官方行为**，非本分支定制；留下的 `distfeeds.list.bak` 不会被 apk 加载。
> 详见 `README.md`「官方源」一节。

## 二、第三方源：dllkids（kenzok8）

本分支只注入了一个第三方源 —— **dllkids**（kenzok8 的 APK 源），由 `rockchip/build.sh` 注入。

**当前默认启用**（代理栈只能启用一个，见 README「代理插件互斥」）：

| 软件包 | 简介 | 来源 |
| --- | --- | --- |
| `clashoo` | clashoo 服务本体，**自带 mihomo 内核**（21 MB，路径 `/usr/libexec/clashoo/mihomo-stable`） | [kenzok8](https://github.com/kenzok8) |
| `luci-app-clashoo` | clashoo 的 LuCI 前端（TUN / fake-ip 透明代理） | [kenzok8](https://github.com/kenzok8) |
| `luci-i18n-clashoo-zh-cn` | 简体中文包（`luci-app-clashoo` 的**硬依赖**，必须一起装） | [kenzok8](https://github.com/kenzok8) |
| `kmod-tun` / `kmod-inet-diag` / `kmod-nft-tproxy` / `kmod-nft-socket` / `kmod-dummy` | clashoo 依赖的内核模块（由 `clashoo` 的 `D:` 自动解析，无需显式列出） | ImmortalWrt 官方 kmods 源 |

> ℹ️ **clashoo 的内核随包自带，不做上游覆盖**（2026-11-24 核实）：clashoo 包内含
> `/usr/libexec/clashoo/mihomo-stable`，并提供 `mihomo` / `clash-meta` 虚拟名满足
> 依赖。`rockchip/build.sh` 已显式识别 clashoo 并跳过「跟随上游最新正式版」的
> 下载/覆盖逻辑（该逻辑写的是 nikki 的 `/usr/libexec/mihomo-core`，路径不同，
> 对 clashoo 无效）。源内实测版本 `clashoo-2026.11.12.1.19.34-r4`，随 dllkids
> 源重建更新，不跟 GitHub 上游最新 tag。

> ℹ️ **换回 nikki 时**其内核来自 `mihomo` 包，默认跟随上游最新正式版、不是 Alpha
> （2026-10-23 上游核实）：nikki 自身没有内核频道开关（`nikki.init` 直接执行
> `/usr/bin/mihomo`，配置与 LuCI 均无版本设置），内核完全由 `mihomo` 包提供
> （实体 `/usr/libexec/mihomo-core`，`/usr/bin/mihomo` 为 alternatives 链接）。
> Alpha 频道在上游是独立的 `Prerelease-Alpha` tag，只有 nikki 官方 feed 的
> `mihomo-alpha` 包跟它，本构建不引入该包。
> **默认行为**：构建期经 GitHub API 解析 mihomo 最新正式版
> （`releases/latest`，非 draft / 非 prerelease），下载
> `mihomo-linux-arm64-<tag>.gz`，校验（URL 与 tag 精确同名 / 体积 / ELF
> aarch64 / 二进制内嵌版本串）后覆盖 `/usr/libexec/mihomo-core`，上游发新
> 正式版后下次构建自动跟上。详见 README「nikki 的内核版本」。
> 另两态：`MIHOMO_CORE_VER`+`MIHOMO_CORE_SHA256` 钉版指定版本；
> `MIHOMO_CORE_TRACK=0` 用源内 apk 的二进制（正式版但滞后数周——
> 源内当前 `mihomo-1.19.31-r1`，2026-10-23 实测）。
> 覆盖不影响 apk 依赖解析；设备端 `apk upgrade mihomo` 会恢复成源内版本。

- APK 源：`https://down.dllkids.xyz/openwrt-feed/25.12/aarch64_generic/packages.adb`
- 签名公钥：`https://down.dllkids.xyz/openwrt-feed/keys/dllkids-feed.pub.pem`

> 该源是完整的第三方源，除默认启用的 clashoo 外还提供 `nikki`、`mihomo`、
> `luci-app-ssr-plus`、`luci-app-passwall` / `passwall2`、`luci-app-openclash`、
> `sing-box`、`geoview` 等。**这些代理插件互斥，只能启用一个**（见 README
> 「代理插件互斥」）。`rockchip/build.sh` 在检测到 `luci-app-ssr-plus` 时会
> 顺带加入该源的 `mihomo` 包作为内核（不再手动下载固定版本二进制）。
>
> ⚠️ 该源的第三方 LuCI 应用**没有**独立中文语言包（源内 640 个包中只有 `clashoo`
> 与 `eqos` 两个 i18n 包），启用它们时**不要**加 `luci-i18n-xxx-zh-cn`，
> 否则 `make image` 会因找不到包而失败。
> （2026-10-14 复核：源侧从 616 增至 **617** —— 新增 `ifb-shaper-0.1.1-r1`，
> 另 9 个包版本号上浮。`audit.py --online` 会逐项实测比对，文档不用手工同步。）
> （2026-11-24 复核：源侧增至 **640** 个包，其中 `luci-app-*` **416** 个 ——
> 上游停更期间又漂移过，由 `audit.py --online` 捕获。）

> ⚠️ 代理插件互斥：nikki / clashoo / openclash / passwall(2) / ssr-plus / daed …
> 只能启用一个，**先停旧的再开新的**。`rockchip/build.sh` 有构建期硬校验
> （≥2 套直接 `exit 1`），详见 README「代理插件互斥」。
> ⚠️ 代理插件依赖的 kmod（`kmod-tun`、`kmod-nft-tproxy`、`kmod-nft-socket`、
> `kmod-inet-diag` 等）由 ImmortalWrt 官方 kmods 源解析，不由第三方源提供。

> ℹ️ **设备端也可以直接安装/升级该源的包。**
> `rockchip/build.sh` 把该源与公钥写在两处：
> - **构建期**：源追加到 Image Builder 的 `repositories`、公钥放进 `keys/`
>   （`make image` 用 `--repositories-file` / `--keys-dir` 读取）。这两处**不会**进固件。
> - **随固件发布**：同时写进 `files/`，落到固件内的
>   `/etc/apk/repositories.d/customfeeds.list` 与 `/etc/apk/keys/dllkids-feed.pub.pem`。
>   （`customfeeds.list` 是 `apk` 包为「用户自加第三方源」预留的 conffile，
>   上游默认就是三行注释占位；本分支保留其原样并在末尾追加 dllkids 源。）
>
> 因此设备上可以直接 `apk update` / `apk add <包名>` / `apk upgrade`。
> 注意固件启用了 `CONFIG_SIGNATURE_CHECK`，公钥缺失会被判为 `UNTRUSTED signature`。

## 三、如何启用/新增软件

1. **官方源中的软件**：直接在 `rockchip/build.sh` 的 `PACKAGES` 变量里追加包名。
2. **可选软件包**：在 `shell/custom-packages.sh` 里把短名填进 `ENABLE_APPS`
   （如 `ENABLE_APPS="filemanager rclone ttyd"`），脚本会自动展开为
   `luci-app-<短名>` + `luci-i18n-<短名>-zh-cn`；文件末尾列出全部可用短名。
   少数非 `luci-app-*` 形式的包（`luci-proto-*` / `luci-mod-*` / openclash /
   passwall 等）取消对应行注释即可。第三方插件默认仅 clashoo（换栈见 README「代理插件互斥」）。
   > ⚠️ **例外：已内置中文的 app 包。** `argon-config` / `cpufreq` / `diskman`
   > 这三个短名的 app 包由 **dllkids 第三方源**提供 `27.150.x` 版本，**自带简体中文**
   > （内含 `usr/lib/lua/luci/i18n/*.zh-cn.lmo` 与 `etc/uci-defaults/luci-i18n-*`）；
   > 官方源同名包是 `26.236.x`（`diskman` 为 `0.2.13-r1`），**不含**中文。
   > 由于 apk **取版本高者**，实际装上的是 dllkids 的 `27.150.x` 构建。
   > 若再装官方源同名的独立语言包 `luci-i18n-<短名>-zh-cn`（`26.236.x`），apk 会因
   > 文件冲突报 `ERROR: ... trying to overwrite ... owned by luci-app-...`，
   > 使 `make image` 以 `package_install Error 3` 失败。
   > 脚本已用 `I18N_BUILTIN` 列表自动规避（这些短名只装 app 包、不加 i18n）。
   > 其余 app 包（`26.236.x`，如 filemanager / ttyd / firewall / package-manager）
   > 未内置中文，仍照常搭配独立 i18n 包，不会冲突。
3. **新增第三方源**：
   把源的 `packages.adb` 全路径追加到 `repositories`，公钥放入 `keys/`（构建期可用）；
   若还要让**设备端**能安装，再按 `rockchip/build.sh` 里 dllkids 源的写法，把源写进
   `files/etc/apk/repositories.d/customfeeds.list`（apk 包预留的第三方源 conffile），
   公钥写进 `files/etc/apk/keys/`。

## 四、可选模块（从 YAOF 移植）

除上述短名开关外，本项目新增 **7 个模块化开关**，由工作流输入 `enable_modules`
（空格分隔的模块名）经环境变量 `ENABLE_MODULES` 传入 `shell/custom-packages.sh` 的
`_add_module()` 分派。默认全关，保持原项目的极简基线。

| 模块 | 包 | 来源 |
| --- | --- | --- |
| `network` | `luci-proto-wireguard` / `luci-app-zerotier`+zh（官方版） / `luci-app-upnp`（dllkids 版自带中文） | 官方 / dllkids |
| `qos` | `luci-app-sqm` / `kmod-sched-cake`（用户要求保留） | 官方（含 kmods） |
| `monitor` | `luci-app-bandix`（实时流量） | dllkids |
| `storage` | `luci-app-filemanager` + 中文 / `luci-app-partexp` / `kmod-fs-f2fs` / `zram-swap` | 官方 / dllkids / kmods |
| `tuning` | `kmod-tcp-bbr` / `ethtool` | 官方 kmods / 官方 |
| `usbnet` | `kmod-usb-net-rndis` / `kmod-usb-net-cdc-ether` / `kmod-usb-net-ipheth` / `usbmuxd` | 官方 kmods / 官方 |
| `theme-vantage` | `luci-theme-vantage` / `luci-app-vantage` | dllkids（无独立 i18n 包） |

> **2026-11-24 精简**：移除 `natmap`、`3proxy`（3cat 的依赖，连 3cat 一并移除）、
> `arpbind` 共 3 项用户不需要的功能；`qos`（SQM+CAKE）按用户要求保留。
> 三项都是模块内部的包，`qos` 保留；另移除 `ddns` 模块（私网 IP 无意义）。模块数 7。

**源侧核实（2026-11-24）**：包引用逐个核对存在于 ImmortalWrt 25.12.2
官方源（10294 包，含 target kmods 1150 包）或 dllkids 源（640 包）；
`audit.py --online` 的检查 14c/14d/14e 会持续复验，源侧漂移即判 FAIL。

**刻意未收录**：`kmod-tcp-bbr3` / `luci-app-flowcone` / `kmod-sched-fq-codel`
在 ImmortalWrt 25.12 源中均不存在；透明代理接管型插件（HomeProxy / dae / Honk 等）
不走模块开关，必须遵循 README「代理插件互斥」的换栈流程。
