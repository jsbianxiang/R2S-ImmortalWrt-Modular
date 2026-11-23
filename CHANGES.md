# 改造说明：融合 YAOF 插件生态

本项目 fork 自 `jsbianxiang/NanoPi-R2S-ImmortalWrt-Builder`，在其严谨的构建与验证体系之上，
移植了 `QiuSimons/YAOF` 的部分插件生态。**仍只支持 NanoPi R2S**，默认代理栈为 clashoo（原项目为 nikki）。

## 改了什么

| 文件 | 变更 |
| --- | --- |
| `shell/custom-packages.sh` | 新增「2.3 模块化开关」：`ENABLE_MODULES` 环境变量驱动 `_add_module()` 分派，8 个模块 |
| `.github/workflows/build-rockchip-immortalWrt-25.12.x.yml` | 新增 `enable_modules` 输入（经 `IN_ENABLE_MODULES` env 中转）、白名单校验步骤、docker 传参、Release 正文显示模块 |
| `shell/audit.py` | 新增检查 4b（模块清单三处同步）、检查 14c（模块包存在性）；修正过期源侧数字 |
| `README.md` | 新增「可用模块」章节（8 个模块的包清单、用法、刻意未移植项）；更新源侧数字 |
| `PACKAGES.md` | 新增「四、可选模块」章节及 2026-11-24 源侧核实记录 |

## 8 个模块与移植来源

| 模块 | 对应 YAOF 功能 | 包数 |
| --- | --- | --- |
| `network` | WireGuard / ZeroTier / NATMap-T / UPnP | 5 |
| `qos` | SQM (CAKE) | 2 |
| `ddns` | DDNS + Cloudflare | 3 |
| `monitor` | Bandix / ARP 绑定 / 3cat | 3 |
| `storage` | 文件管理 / 分区扩容 / f2fs / zram-swap | 5 |
| `tuning` | BBR + ethtool | 2 |
| `usbnet` | 手机 USB 共享网络 (RNDIS/CDC-Ether/usbmuxd) | 4 |
| `theme-vantage` | Vantage 主题 + 应用 | 2 |

默认全关，保持原项目极简基线。用法：`Run workflow` 时 `enable_modules` 填空格分隔的模块名，
如 `network qos ddns tuning`。填错直接报错（工作流白名单校验），不会静默漏装。

## 刻意未移植

- **代理类插件**（HomeProxy / dae / Honk / FlowCone）：透明代理接管型，与默认 clashoo 互斥，
  必须走原项目的代理换栈流程。FlowCone 依赖的 eBPF FullCone 模块在 ImmortalWrt 25.12 源中缺失。
- **BBR3**（`kmod-tcp-bbr3`）：ImmortalWrt 25.12 rockchip kmods 中不存在，`tuning` 只提供 BBR。
- **Docker / store / istore**：原项目明确不集成，维持不变。

## 源侧核实（2026-11-24）

逐项核对 26 条模块包引用，全部可在以下源解析：

- ImmortalWrt 25.12.2 官方源：11542 包（base 762 + luci 3724 + packages 4879 + routing 56 +
  telephony 873 + target 98 + kmods 1150）
- dllkids 25.12 aarch64_generic：640 包（其中 luci-app-* 416 个）

注意：上游源在 fork 后 drift 过（dllkids 622→640、官方 11428→11542），已由
`audit.py --online` 捕获并修正文档声明。这印证了原项目「定时审计防漂移」设计的价值。

## 验证结果

```
python3 shell/audit.py            → PASS 16 / WARN 0 / FAIL 0
python3 shell/audit.py --online   → PASS 30 / WARN 1 / FAIL 0
```

唯一 WARN 是原项目遗留的 apk 择优安装提示（clashoo 提供 `mihomo` 虚拟名，
可能导致另一套代理栈内核被装入），非本次改造引入，且不影响单栈互斥校验。

模块化拼接已实测 4 种场景：默认空、指定 4 模块、全 8 模块、未知模块容错，均符合预期。

## 追加变更：默认代理 nikki → clashoo

用户要求把默认代理换成 clashoo。这不是简单换两行——clashoo 与 nikki 的内核机制不同：

| 项 | nikki | clashoo |
| --- | --- | --- |
| 内核路径 | `/usr/libexec/mihomo-core`（由 `mihomo` apk 提供） | `/usr/libexec/clashoo/mihomo-stable`（clashoo 包自带，21 MB） |
| 内核版本 | `build.sh` 跟随 GitHub 上游最新正式版并覆盖 | 随 dllkids 源重建更新，实测 `1.19.34` |
| 中文包 | 无独立 i18n | `luci-app-clashoo` **硬依赖** `luci-i18n-clashoo-zh-cn` |
| kmod | 需显式列出 | `clashoo` 的 `D:` 已含 kmod-tun / nft-tproxy 等，apk 自动解析 |

因此改了 5 个文件：

- `shell/custom-packages.sh`：默认行改为 clashoo 三件套；nikki 行注释掉并补充换栈说明
- `rockchip/build.sh`：新增 `CLASHOO_SELF_KERNEL` 识别，内核覆盖逻辑显式跳过 clashoo
  （原逻辑只认 nikki/ssr-plus，若不改会白下载 GitHub 资产并写入没人用的文件）
- `README.md` / `PACKAGES.md`：同步全部「默认」声明、代理互斥表标注、内核来源章节
- `CHANGES.md`：本记录

**验证**：`audit.py --online` PASS 31 / WARN 0 / FAIL 0（换栈前的跨栈 WARN 也消失了，
因为 clashoo 自带内核，不再有 nikki 的 `D: mihomo` 被冲突栈满足的问题）。
依赖闭包 160 包，含且仅含 clashoo 一套代理前端。

## 追加：全链路联动审查（2026-11-24）

对 workflow ↔ build.sh ↔ custom-packages.sh ↔ 99-custom.sh ↔ audit.py ↔ 文档
做了全链路联动检查，并修复 3 类问题：

### 修复的真实缺陷

1. **storage 模块重复包**：模块含 `luci-i18n-filemanager-zh-cn`，而 build.sh 默认
   PACKAGES 已装，全模块同开时重复声明。已去掉模块里的重复项（8 个模块单独/组合
   实测均无重复）。
2. **rootfs_partsize 无兜底**：case 映射 1G/2G/3G/4G 无 default 分支；GitHub API
   触发可绕过 UI 的 choice 限制传任意值，使 ROOTFS_SIZE 为空 → make image 异常。
   已加 `*` 分支 exit 1。
3. **残留 nikki 默认假设 5 处**：build.sh 头部对照说明、互斥错误提示、内核跳过
   日志、custom-packages.sh 模块注释、99-custom.sh 防火墙提示，换 clashoo 时遗漏。
   已全部同步。

### 验证通过项

- 环境变量传递链：8 个 workflow 输入 → `IN_*` env → docker `-e` → build.sh 消费，
  完整闭合；`custom_router_ip.txt` 挂载路径与 99-custom.sh 读取路径一致。
- 产物路径链：容器 `/home/build/immortalwrt/bin` ← 宿主 `${{ github.workspace }}/bin`
  ← workflow 上传路径，三者一致。
- WAN 配置链：workflow → build.sh 写 wan-settings → 99-custom.sh 读取，含 DNS glob
  防护、CIDR 记法等细节。
- 三 workflow 联动：clean 默认 keep_days=90 与 Artifact retention-days=90 对齐；
  audit 的 paths 触发器覆盖所有改动文件；action 版本一致。
- 审计有效性：6 组变异测试（篡改 ALLOWED 白名单、README 模块表、_PROXY_STACKS、
  注入 inputs 到 shell、未定义 IN_ 变量等）均被 audit 精确判 FAIL，无假阳性通过。
- YAML 语法：3 个 workflow 全部合法；shell 语法：3 个脚本 bash -n 全过。
- 离线审计 PASS 16 / FAIL 0。

### 已知的非缺陷（设计取舍）

- `on:` 键被 PyYAML 解析为 `True` 是 YAML 1.1 行为，GitHub Actions 用兼容解析，
  三个 workflow 原本就正常运行。
- `clean-workflow.yml` 会删除所有 workflow（含 audit）的运行记录；默认 90 天与
  Artifact 保留期对齐，属可接受取舍。
- 模块 d) 未知模块名只 WARN 不 FAIL（工作流层已用白名单 exit 1 兜底，双重防护）。

## 追加：2.3 模块化对 ImmortalWrt 25.12.x 的适用性核实

用户要求确认 2.3 段是否适合整个 25.12.x 系列（workflow 可选 25.12.0/.1/.2），
而非仅默认的 .2。逐版本拉取 5 个 feed + target + kmods 的 index.json 核对：

- **三版本用户态包集合**：25.12.0=11531、25.12.1=11542、25.12.2=11542；
  .1 比 .0 多 11 个 kmod（nf-nathelper 系等），与模块包无关。.1 与 .2 完全一致。
- **26→31 条模块包引用**：跨越三版本全部存在，零缺失（kmod 由各版本 kmods 提供，
  内核分别为 6.12.87 / 6.12.94 / 6.12.103）。

### 发现并修复：中文包缺失

原模块只写 app 不写 i18n，但 7 个 app 在官方源有独立中文包，导致启用 network /
ddns / monitor / storage 后界面为英文。已补 6 个 i18n 包
（zerotier / natmap / upnp / ddns / arpbind / 3cat）；filemanager 的中文包由
build.sh 默认已装故不重复，natmapt / partexp / vantage 两源均无独立 i18n 保持原样。
包引用从 26 增至 31。

### 审计增强

新增检查 14d「模块包 workflow 全版本覆盖」：解析 luci_version 的 choice options，
对**每个声明版本**抓 5 个 feed 的 index.json，验证 25 个非 kmod 模块包全部可解析。
变异测试确认：注入不存在的包时 14c 与 14d 均精确判 FAIL。

**验证**：`audit.py --online` PASS 32 / WARN 0 / FAIL 0；全模块同开 46 包无重复。
