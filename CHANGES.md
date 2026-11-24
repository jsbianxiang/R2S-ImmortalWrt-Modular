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

## 追加：全项目复审（2026-11-24）

对全部 14 个文件做了独立复审（三个专项审查并行 + 文档/契约人工核对），
共确认 4 个真实缺陷并修复，1 个建议经实测后回退，2 个疑点留待实机验证。

### 已修复

1. **【严重】99-custom.sh 缺升级保护**
   OpenWrt 官方文档明确：uci-defaults 在「首次刷机」和「sysupgrade 保留配置
   升级」后都会执行，无条件写入会重置用户在 LuCI 改过的 LAN/WAN 地址，LAN
   被改回 192.168.2.1 时升级后进不了管理页。按官方推荐的标记法修复：写
   `system.@system[0].r2s_custom_init=1`，脚本开头检测到标记即 exit 0。
2. **【中】build.sh dllkids 公钥下载无失败检查**：`curl -fsSL` 失败不会中断
   （脚本无 set -e），且残留旧公钥可能被误用。已加 `rm -f` + `|| exit 1`
   + `-s` 非空检查 + 重试。
3. **【中】build.sh source 依赖当前工作目录**：改为基于 `BASH_SOURCE` 定位，
   并加失败检查。原写法在容器内恰好可用，但手动从别处执行会静默产出
   无 clashoo 的固件。
4. **【中】WAN heredoc 注入面**：无引号 heredoc 做命令替换，dhcp 模式下
   workflow 不校验 IP 字段，API 触发可绕过 UI。已在 build.sh 写文件前独立
   校验 WAN_PROTO 白名单 + IPv4 正则（实测拦截 `$(...)` / `;` 等注入）。

### 经实测回退的建议

- 审查建议把 audit.py 检查 15c 的 `m2["p"]` 换成 `m2["names"]`（理由是
  apkmeta 文档称多 provides 包的 p 会少项）。**实测发现 names 含 libc /
  ca-bundle 等普通依赖名**，替换后把 27 套代理栈全报成"跨栈提供者"
  （WARN 洪水）。当前源里各栈的 mihomo/clash-meta 都在 p 中，故保留 p
  并在代码里写明回退理由。这是"agent 建议必须实测"的例证。

### 待实机验证的疑点（未改代码）

- **static 模式 wan6**：文档称"static 分支不生成 wan6"，但 config_generate
  在 preinit 基于出厂 dhcp 生成 wan6 后，99-custom.sh 改 proto 为 static
  却未删除 wan6 —— 理论上会残留 dhcpv6 客户端。因不确定 config_generate
  读取 proto 的确切时机，未贸然改代码或文档，建议实机 `uci show network.wan6`
  确认后再定。
- **audit.py 虚拟名依赖不反查**：resolve_closure 只按同名包展开，错误信息
  却称"也没找到 provides 者"。理论上 apk 经虚拟名择优拉入的包会漏出闭包。
  属原项目 inherited 的深层设计问题，修它会扩大检查范围、引入新 WARN，
  本次不动，记录备查。

### 验证

- shell 语法 ×3、YAML ×3 全过
- 审计离线 PASS 16 / FAIL 0；在线 PASS 32 / WARN 0 / FAIL 0
- 升级保护、注入拦截、公钥失败检测均做了模拟测试

## 追加：首次 Actions 构建失败修复（2026-11-24）

### 失败 1：source 路径（已在上一个 commit 修复）

复审时把 `source shell/custom-packages.sh` 改为 `../shell/...`，但容器内
build.sh 与 shell/ 是父子关系（build.sh 挂到 /home/build/immortalwrt/，
shell/ 挂到其下），`../shell` 指向不存在的 /home/build/shell。
改为自动探测三种布局，兼容容器与本地。

### 失败 2：natmapt 坏包（本次修复）

日志：`ERROR: unable to select packages: natmapt (no such package):
required by: luci-app-natmapt-...`

根因：`luci-app-natmapt` 只在 dllkids 源存在，但它依赖的核心包 `natmapt`
在**所有源都不存在**（官方 5 feed + target + kmods + dllkids 全查过）。
这是 dllkids 源的坏包——前端留着、后端没编译。

修复：从 `network` 模块移除 `luci-app-natmapt`，保留官方的
`luci-app-natmap + natmap`（后者在官方源完整存在，apk 自动解析装入）。
README/PACKAGES 同步标注。

### 审计增强：检查 14e 模块包一层依赖可解析

14c/14d 只验"包本身存在"，抓不到"前端存在、依赖缺失"的坏包。
新增 14e：对模块显式包逐个取 apkmeta，检查 `D:` 依赖中哪些名字
①不在源目录、②无"<名字>-*"实体包提供（虚拟名近似）、③非基础虚拟名。
变异测试确认：加回 natmapt 时精确判 FAIL（"network: luci-app-natmapt
依赖 natmapt"），移除后 30 个模块包全部 PASS。

**验证**：`audit.py --online` PASS 33 / WARN 0 / FAIL 0。

## 追加：全模块构建预检（2026-11-24）

本地无 Docker，无法跑真实 ImageBuilder，但用 audit 的依赖闭包机制模拟了
`make image` 的完整包解析（默认 12 包 + 全模块 33 包 = 45 个显式包）：

- 闭包 272 个包，未被 500 包上限截断
- 代理栈只命中 clashoo 一套，无第二栈混入
- 4 个"疑似缺失"逐个甄别：`uci-firewall` 由 firewall4 提供、
  `libncursesw6` 由 libncurses6 提供（均实测确认 provides）；
  `2022.03.22` / `2023.01.21` 是版本号被误当包名的解析噪声
- 结论：**全模块组合无下一个坏包，构建预检通过**

注意：这是离线预检，不等价于真实构建；最终以 GitHub Actions 运行结果为准。

## 追加：第三次构建失败修复 —— i18n 文件冲突（2026-11-24）

日志：`luci-i18n-3cat-zh-cn (26.298 官方): trying to overwrite
usr/lib/lua/luci/i18n/3cat.zh-cn.lmo owned by luci-app-3cat (27.150 dllkids)`

根因：上一轮"补全中文包"时只看了"官方源有独立 i18n 包"，却忽略了这些 app
在 **dllkids 源的版本自带简体中文**（实测 6 个 app 的包内均含 zh-cn.lmo 与
uci-defaults）。apk 取版本高者装了 dllkids 的 27.x app，再装官方 26.x 的独立
i18n 就撞文件——正是文件头「注意事项 6」I18N_BUILTIN 要防的同类问题，
只是发生在 2.3 模块里而没被覆盖到。

修复：
- 移除模块内全部 6 个独立 i18n（zerotier / natmap / upnp / ddns / arpbind / 3cat），
  app 用 dllkids 版即可，中文已内置。filemanager 不在 dllkids 源，其中文包
  仍由 build.sh 默认提供，不受影响。
- 更新 2.3 注释 c) 与 README/PACKAGES 的模块表。
- audit.py 新增检查 4c（离线）：模块内 `luci-app-X` 与 `luci-i18n-X-zh-cn`
  同现即 FAIL。变异测试确认加回 i18n 会被精确捕获。

**验证**：`audit.py --online` PASS 34 / WARN 0 / FAIL 0；离线 PASS 17 / FAIL 0。

## 追加：zerotier 中文包回补（2026-11-24）

上一轮移除 6 个 i18n 是保守处理，其中 zerotier 属误伤：
- dllkids 的 `luci-app-zerotier` 版本 1.0-r21，**低于**官方 26.x
- apk 取版本高者 ⇒ 实际装官方版（不含中文），配独立 i18n 不冲突
- 实证：第三次构建日志里其余 5 个 app 都报了 trying to overwrite，
  唯独 zerotier 没有

改动：network 模块加回 `luci-i18n-zerotier-zh-cn`；audit.py 检查 4c 增加
`I18N_APPROVED = {"zerotier"}` 白名单例外；注释记录例外理由与前提。

⚠ 残余风险：白名单依赖人工维护，且若将来 dllkids 把 zerotier 版本升过官方，
“官方版 app 不含中文” 的前提就不成立，需重新评估。白名单仅 1 项、理由写在
代码注释里，便于审查。

**验证**：离线 PASS 17 / 在线 PASS 34 / FAIL 0。

## 追加：按用户需求精简模块（2026-11-24）

用户确认 4 项插件对其无用（已刷入固件后反馈），从模块定义中移除：

| 用户所说 | 对应包 | 处理 |
| --- | --- | --- |
| natmap | `luci-app-natmap` | 从 network 移除 |
| 3proxy | `3proxy-mod-tcppm/udppm`（由 3cat 依赖带入） | 连 3cat 一并从 monitor 移除 |
| IP/MAC绑定 | `luci-app-arpbind` | 从 monitor 移除 |
| Smart Queue Management | `luci-app-sqm`+`kmod-sched-cake` | 删除整个 qos 模块 |

模块数 8 → 7，包引用 31 → 23。同步更新：workflow 的 `ALLOWED` 白名单与输入框
说明、custom-packages.sh 的警告信息与注释、README/PACKAGES 的模块表、
README 里残留的"默认 nikki"表述（改 clashoo）。

**验证**：
- 离线 PASS 17 / 在线 PASS 34，均 FAIL 0；模块三处同步（代码/workflow/README）零差集
- 全模块包解析模拟：23 包 → 闭包 206，上述 4 项全部不在闭包内，代理栈仅 clashoo

## 追加：qos 模块保留（2026-11-24）

用户确认 `luci-app-sqm` + `kmod-sched-cake` 要保留（用于 WAN 下多设备的
缓冲膨胀控制），故恢复 `qos` 模块。上次的精简实际只删了这一个独立模块；
`natmap` / `arpbind` / `3cat`（连同 3proxy）都是各自模块**内部**的包，
它们的移除保持不变。模块数回到 8。

同步：workflow 白名单与输入框描述、custom-packages.sh 的 case 分支与警告信息、
README/PACKAGES 模块表与计数、模块数表述（明确 3 项移除是模块内部的包）。

**验证**：离线 PASS 17 / 在线 PASS 34，FAIL 0；模块三处同步零差集。
构建包清单含 sqm+cake，不含 natmap/3cat/arpbind。

## 追加：移除 ddns 模块（2026-11-24）

用户确认光猫为路由模式、R2S 的 WAN 拿私网 IP，DDNS 无意义（域名解析不到），
故删除 `ddns` 模块（`luci-app-ddns` + `ddns-scripts` + `ddns-scripts-cloudflare`）。
模块数 7 → 7（删 1 个模块，但此前已恢复 qos，净数仍为 7）。

同步：custom-packages.sh、workflow 白名单与输入框、README、PACKAGES。
离线审计 PASS 17 / FAIL 0，三处模块清单零差集。

## 追加：默认代理改回 nikki（2026-11-24）

用户要求把默认代理从 clashoo 改回 nikki。按 1afa40a（nikki→clashoo）的
diff 精确反向操作：

- **shell/custom-packages.sh**：1.1 段启用 nikki 六件套（luci-app-nikki + nikki
  + 4 个 kmod），clashoo 三件套改回注释；文件头与模块注释里的"默认 clashoo"
  改为 nikki。
- **rockchip/build.sh**：删除 CLASHOO_SELF_KERNEL 判断，mihomo 覆盖条件恢复
  为 `nikki|luci-app-nikki|luci-app-ssr-plus`（nikki 需要跟随上游最新内核）；
  保留换栈到 clashoo 时的处理说明。
- **README/PACKAGES**：默认声明、代理内核来源段（改为 nikki 跟随上游正式版，
  clashoo 自带内核改为换栈附注）、互斥清单标记、目录说明同步。

**验证**：
- 离线 PASS 17 / 在线 PASS 33，FAIL 0
- 依赖闭包 156 包，无第二代理前端（闭包含 nikki，显式启用 nikki）
- 1 个 WARN（预期）：clashoo provides mihomo 且版本更高，apk 择优可能装它。
  但源内有 mihomo 实体包兜底，且 build.sh 会把 /usr/libexec/mihomo-core
  覆盖为上游最新版，nikki 实际执行的就是覆盖后的内核，不影响使用。
