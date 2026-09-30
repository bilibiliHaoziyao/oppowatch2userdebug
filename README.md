# OW20W1 一键永久 Root（PC 端）

OPPO Watch 2 46mm（OW20W1，固件 A.89 / A.92）——通过设备上载体 App 的 fastrpc 漏洞，从 PC 磨出 `uid=0`，命中后**自动把 boot 分区刷成 v7 镜像**：永久 root + 无线 adb + 开机 Permissive + SELinux 随时自由开关；并把维护 **TWRP（adb 可用）** 刷入 recovery。

> ⚠️ 仅用于**你自己设备**的安全研究。所有写入都带回读校验；boot 分区为本包唯一关键写入，且任何时候都能从 Android 侧一条命令回滚，误操作仍有风险，后果自负。

连接设备后脚本会【自动检测固件版本】（A.89 / A.92），刷入对应版本的镜像套件；版本识别不出会直接停止。

---

## v7 boot 刷进去能得到什么

| 能力 | 机制 |
|---|---|
| **USB adb 直接是 root**（重启不丢） | `ro.debuggable=1` + `service.adb.root=1` → adbd 不降权，uid=0 |
| **无线 adb**：同一 Wi-Fi 下不插线连接 | `service.adb.tcp.port=5555` → adbd 在 USB 之外同时监听 TCP 5555 |
| **开机即 Permissive** | 内核命令行追加 `androidboot.selinux=permissive` |
| **SELinux 随时自由开关** | boot_completed 时以 init 上下文执行 `/data/local/tmp/magiskpolicy --live "allow shell kernel security setenforce"` → `setenforce 1`/`0` 两个方向都通 |
| adb 默认开启 | `persist.sys.usb.config=mtp,adb` |
| 安全模型不变 | `ro.adb.secure=1` 保留——连接仍需你的 PC 的 adb 密钥授权 |

> 注：root shell 的 SELinux 域仍是 `shell`。直读写块设备需要 `setenforce 0`（Permissive 下 uid0 adb 可读写分区——这也是紧急时不动 recovery 就能刷分区的后路）。

## 配套 TWRP（维护 recovery）

`twrp-3.7.0_9-ow20w3-recovery_{A89,A92}_adb4.img`——内核与本固件严格匹配的 TWRP 3.7.0_9：

- 触屏 UI（备份/恢复/安装镜像/终端）＋ **adb 也是 uid0(root)**、可直接读写块设备
- 已修复本机 USB 链路（configfs gadget + adbd 启动 + root 化全链路）
- **与 boot 完全解耦**：recovery 出任何问题都不影响正常开机（boot 分区不被动过；进不去 rec 时从 Android 直接 dd 换回即可）

## 固件版本支持（重要）

本包**同时携带 A.89 与 A.92 两套镜像**，脚本连接设备后自动检测固件版本、选用对应套件：

| 检测结果 | 识别依据 | 使用的镜像套件 |
|---|---|---|
| **A.89**（2024-08-22 构建） | `ro.build.display.id` 含 `A.89`（或 boot 时间戳 1724329644） | `*_a89.img` / `*_A89_adb4.img` / `recovery_原厂_A89.img` |
| **A.92**（2025-02-12 构建） | `ro.build.display.id` 含 `A.92`（或 boot 时间戳 1739333172） | `boot_wifiadb_v7_policy_a92.img` / `*_A92_adb4.img` / `recovery_原厂_A92.img` |
| 其他版本 | —— | **脚本直接停止**（利用链偏移按这两版内核硬编码） |

- ✅ **利用链完全通用**：A.89 与 A.92 两版内核的链依赖符号地址**差值全为 0**、fastrpc 驱动代码逐字节一致——`.so` 载荷零改动
- ✅ 镜像按版本分套：boot / recovery 内嵌各自版本内核与 ramdisk，**不可跨版本混刷**
- 识别方法：`adb shell getprop ro.build.display.id`

## 包内文件

| 文件 | 用途 |
|---|---|
| `rc17_hunt_v2.sh` | 磨机：重启循环 + 注参拉起载体 App + 命中后自动刷 v7 + 命中即停保证据 |
| `auto_root.sh` | **一键编排**：安全门 → adb/设备检查 → 固件版本检测 → 幂等预置（含 magiskpolicy）→ 磨机 → 实时回报 |
| `一键Root.bat` | Windows 双击入口（自动找 Git Bash，ASCII-only） |
| `ea0.apk` | 载体 App（com.gc.p2）——漏洞载荷 `libp2probe.so` 打包在内，md5 `4af0b2c5283ab616da0a8c049f567105` |
| `zzq1` / `mod.sh` | 设备侧辅助 payload |
| `magiskpolicy_arm32` | v7 开机钩子依赖（一键脚本自动放入 `/data/local/tmp/magiskpolicy`），md5 `bfeaa0843da89d4038e1432ed3412195` |
| `boot_wifiadb_v7_policy_a92.img` | **A.92 v7 boot**（一键刷写目标），md5 `ab62f167eab2983a43bd419af600c9a3` |
| `boot_wifiadb_v7_policy_a89.img` | **A.89 v7 boot**（一键刷写目标），md5 `2e06f10a58d1be0ddeef7f4ccab15ec2` |
| `twrp-3.7.0_9-ow20w3-recovery_A89_adb4.img` | A.89 维护 TWRP（adb 可用），md5 `57c9aa012f045161e3475f9626333850` |
| `twrp-3.7.0_9-ow20w3-recovery_A92_adb4.img` | A.92 维护 TWRP（adb 可用），md5 `fe56bcf23a305c7ef30fba8dcd9e88c3` |
| `recovery_原厂_A92.img` / `recovery_原厂_A89.img` | 原厂 recovery 镜像（回滚用），md5 `d05b0d37…` / `521436b3…` |
| `flash_partition_from_recovery.sh` | 分区刷写工具：白名单（boot/recovery/misc）+ 推送校验 + 按镜像长度回读比对 |
| `flash_v7_after_root.sh` | 手动重刷/切换 v7 的辅助脚本（staging magiskpolicy + recovery 通道 + setenforce 往返检查） |

> **镜像说明**：v7 镜像在 EOF-0x44 处带 4 个"转向字节"，把整文件 FNV-1a32 精确调到载荷 `preload` 校验要求的值（否则命中后刷机源会被载荷拒绝）。这 4 字节位于工厂 AVB 结构之外的惰性零填充区——不影响开机、AVB0/AVBf 或回读校验。TWRP 镜像为内核匹配重打包版（id 重算，内核/ramdisk 逐字节对应）。

## 前置条件

- 设备：OW20W1，固件 A.89 或 A.92，**boot 为原厂**，BL 已解锁（`orange`），USB 调试开启且本机 adb 密钥已授权
- PC：任意装有 adb 的环境；Windows 用户直接双击 BAT

## 一键 Root（推荐）

**Windows**：双击 **`一键Root.bat`**。脚本依次自动完成：

1. 展示安全事项，要求 y/N 确认
2. 检查 adb 驱动与设备连接
3. **检测设备固件版本**（A.89 / A.92）→ 打印将使用的镜像套件与刷写守卫值；识别不出直接停止
4. 幂等预置：装载体 App、推**对应版本**的 v7 刷写目标、写守卫三件套、放入 magiskpolicy、校验**对应版本**的 TWRP 镜像
5. 后台磨机 + 每 30 秒实时状态（命中 / 刷写开始 / 刷写完成高亮）
6. 命中后自动刷 **v7（boot）+ TWRP（recovery）** 并重启——最终态：永久 root + 无线 adb + Permissive/可开关 + TWRP

**Linux/macOS**：`bash auto_root.sh`（同上，去掉 `MSYS_NO_PATHCONV=1` 前缀即可）。

<details>
<summary><b>手动模式（可选，与一键等价——想逐步控制再用）</b></summary>

### 1️⃣ 安装载体 App

```bash
adb install -r ea0.apk
# 若报 INSTALL_FAILED_UPDATE_INCOMPATIBLE：adb uninstall com.gc.p2 后重试
```

### 2️⃣ 预置刷写目标、守卫与策略工具

先确认固件版本（`adb shell getprop ro.build.display.id`），按版本取对应值：

| 参数 | A.89 | A.92 |
|---|---|---|
| 镜像文件 | `boot_wifiadb_v7_policy_a89.img` | `boot_wifiadb_v7_policy_a92.img` |
| 镜像 md5 | `2e06f10a58d1be0ddeef7f4ccab15ec2` | `ab62f167eab2983a43bd419af600c9a3` |
| 守卫 FNV（原厂 boot 前 1MB） | `184546148` | `4259604844` |

```bash
# 示例为 A.89；A.92 请替换上表对应值
MSYS_NO_PATHCONV=1 adb push boot_wifiadb_v7_policy_a89.img /data/local/tmp/boot_debuggable_v2.img
adb shell 'md5sum /data/local/tmp/boot_debuggable_v2.img'
#   必须等于 2e06f10a58d1be0ddeef7f4ccab15ec2

adb shell "printf 'flash_guarded\n' > /data/local/tmp/flash_action; \
printf '184546148\n' > /data/local/tmp/expected_boot_sum; \
: > /data/local/tmp/flash_stage.txt; \
chmod 666 /data/local/tmp/flash_action /data/local/tmp/expected_boot_sum /data/local/tmp/flash_stage.txt"

# v7 开机钩子依赖（必须）
MSYS_NO_PATHCONV=1 adb push magiskpolicy_arm32 /data/local/tmp/magiskpolicy
adb shell 'chmod 755 /data/local/tmp/magiskpolicy'
```

### 3️⃣ 跑磨机

```bash
bash rc17_hunt_v2.sh
```

- **设备每 1–2 分钟自动复位一次 = 正常现象**，不要拔线
- 平均 **35–45 分钟**命中（单发约 2.2%）；每 25 轮脚本会提示做一次电池冷启动（拔线 → 长按侧键 12 秒关机 → 开机 → 插回），强烈建议照做
- 命中后脚本**自动完成刷写并停止**，证据落到当前目录

</details>

### 命中后自动发生

1. exploit 取得 `uid=0` → 校验当前 boot 为**对应版本原厂**（FNV 守卫）→ 把 v7 整块写入 boot 分区（带回读比对）→ 复位启动 v7
2. 磨机检测到命中 → **自动刷入 TWRP**（recovery 通道，回读校验）→ 自动重启
3. 最终态：**v7 永久 root + TWRP**，无需人工（`RECOVERY_AUTOFLASH=0` 可关掉第 2 步）

> 若第 2 步"未能进入 recovery"（首次全新安装时可能发生，无损）：v7 已经生效，从 Android 直接补刷即可：
> `adb shell "setenforce 0; dd if=/data/local/tmp/xxx_twrp.img of=/dev/block/bootdevice/by-name/recovery bs=1048576; sync"`

### 验证

```bash
adb shell 'id; getprop ro.debuggable; getprop service.adb.tcp.port; getenforce'
# 期望：uid=0(root) / 1 / 5555 / Permissive

adb shell 'setenforce 1; getenforce; setenforce 0; getenforce'
# 期望：Enforcing → Permissive（v7 策略钩子生效，两个方向都通）
```

## 无线 adb（v7 的招牌功能）

```bash
adb shell ip -4 addr show wlan0      # 拿手表 IP
adb connect <IP>:5555
adb -s <IP>:5555 shell id            # uid=0(root)，全程不插线
```

## SELinux 自由开关（v7 特性）

```bash
adb shell setenforce 1   # 收紧（更安全，部分银行/DRM 应用友好）
adb shell setenforce 0   # 放开（可读写块设备/调试）
# 重启后自动回到 Permissive（cmdline 决定）
```

依赖 `/data/local/tmp/magiskpolicy` 存在；缺失时只会导致"Enforcing 下切不回来"（重启即恢复），不影响开机与 root。

## 维护通道：TWRP（adb 可用）

```bash
adb reboot recovery                 # 约 25 秒进入 TWRP
adb shell id                        # uid=0(root)，可读写块设备
```

- 触屏 UI 可直接备份/恢复/刷写；adb 侧也可用 `flash_partition_from_recovery.sh`
- **回滚 recovery 到原厂**：`bash flash_partition_from_recovery.sh recovery_原厂_A92.img recovery`（A.89 用 `recovery_原厂_A89.img`）
- **回滚 boot**：把上版/原厂 boot 镜像刷回 boot（原厂镜像在《OPPO手表2_全分区备份_20260921》或官方固件包中；也可以直接用 `flash_v7_after_root.sh` 的流程换回 v7）

## 中断与续磨

磨机是**无状态循环**：所有进度都在表上——载体 App、刷写目标、三件套、命中证据文件都在 `/data` 与 `/cache`，PC 重启/断电/脚本被杀都不会丢。恢复只需：

```bash
adb devices                        # 确认设备在线
bash rc17_hunt_v2.sh               # 直接重跑，即为续磨
```

- 中断前**没有命中**：直接继续（轮数计数从 1 重新开始，不影响命中率）
- 中断前**其实已命中**：重跑后第一轮的证据守卫会立刻发现它、拉取证据并停机——**命中不会因为中断而丢**
- 中断前**已命中并刷了 v7**：`adb shell getprop ro.debuggable` = `1` 即已到手，不用再磨
- 单例锁文件在 PC 断电后是死锁，脚本会自动识别死锁并放行

## 重置与再来一次

命中证据按设计**从不清空**（那是验收凭证），紧接着再跑磨机会立刻停机。再磨前：

```bash
bash rc17_hunt_v2.sh reset
```

注意：命中后 boot 已是 v7，想完整再走一遍需先刷回原厂 boot（见《维护通道》）。

## 故障速查

| 现象 | 处置 |
|---|---|
| 设备 offline / 消失几分钟又回来 | USB 枚举抖动，30–60s 自愈；脚本已内置最长 180s 等待 |
| 磨机中反复复位 | **正常**（每轮失败多以 DSP 异常→看门狗复位收场） |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 表上有签名不同的同名 App：`adb uninstall com.gc.p2` 后重装 |
| `adb connect <IP>:5555` 超时但 USB 正常 | 手表 Wi-Fi 省电会灭屏断网；亮屏/充电时用 |
| 进不去 recovery | 不影响开机（boot 未动）；从 Android Permissive 下直接 dd 补刷 |
| 想进 fastboot | 该机 ABL 不可达（BCB/按键/reason 全被无视），别浪费时间 |

## 命中率说明

单发成功率约 **2.2%**，均值 35–45 分钟——链路是五段低概率竞态的串联。命中率的关键变量是 ADSP 会话池健康度（差时会回落复用旧会话、发数变少）；**真·电池冷启动**（拔线→长按侧键 12 秒关机→开机→插回；温重启无效）能显著改善，磨机第 25 轮会提示。
