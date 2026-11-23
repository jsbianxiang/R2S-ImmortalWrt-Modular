# 改造说明：融合 YAOF 插件生态

本项目 fork 自 `jsbianxiang/NanoPi-R2S-ImmortalWrt-Builder`，在其严谨的构建与验证体系之上，
移植了 `QiuSimons/YAOF` 的部分插件生态。**仍只支持 NanoPi R2S**，保持单代理栈（nikki）默认。

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

- **代理类插件**（HomeProxy / dae / Honk / FlowCone）：透明代理接管型，与默认 nikki 互斥，
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
