# OPPO Watch 2 一键 Root 工具（oppowatch2userdebug）

适用于 **OPPO Watch 2 46mm（型号 OW20W1）**、固件版本 **A.89 / A.92** 的 PC 端一键获取 root 工具。

本仓库 fork 自 [`lokkl-LZY/oppowatch2-root`](https://github.com/lokkl-LZY/oppowatch2-root)，在其基础上对一键编排与磨机脚本做了重构，并整理了文档。**仅供个人在自有设备上进行安全研究与学习，请遵守当地法律法规，误用风险自负。**

---

## 它能做什么

通过设备上一个载体 App 触发高通 **FastRPC 驱动**的内核缺陷，从普通应用权限竞争出 `uid=0`；命中后自动把定制的 boot 镜像写入 boot 分区，并将维护用 TWRP 写入 recovery 分区，从而获得：

- **USB adb 直接为 root**，重启后依然有效；
- **无线 adb**（同一 Wi-Fi 下免数据线连接，端口 5555）；
- **开机即 Permissive**，且 SELinux 可在 Enforcing / Permissive 之间随时切换；
- 一套与 boot 解耦的 **TWRP 维护 recovery**（adb 同样为 root，可读写块设备，便于备份与救砖）。

> root shell 的 SELinux 域仍为 `shell`；需要直接读写块设备时请先 `setenforce 0`。`ro.adb.secure=1` 予以保留，连接仍需本机 adb 密钥授权。

## 工作原理（简述）

1. 普通 App 即可打开 FastRPC 设备节点 `/dev/adsprpc-smd`；
2. 借助驱动中一处「释放后使用」（UAF）的竞争缺陷，配合 KGSL（`/dev/kgsl-3d0`）堆占位，构造出内核内存的任意写；
3. 将预置子进程的凭证（cred）替换为内核的 `init_cred`，得到 `uid=0`；另有改写 `modprobe_path` 的兜底路线；
4. 提权后先校验 boot 分区为对应版本原厂镜像（FNV-1a 守卫），再写入定制 boot 与 TWRP，全部带回读校验。

由于整条链路由多段低概率竞争串联，**单次成功率约 2.2%**，需要脚本自动反复重启尝试（平均 35–45 分钟）。内核符号地址按 A.89 / A.92 硬编码，**其他固件版本不予支持、脚本会直接停止**。

## 环境要求

- 设备：OW20W1，固件 A.89 或 A.92，**boot 为原厂**，Bootloader 已解锁（`orange`），已开启 USB 调试且本机 adb 密钥已授权；
- 电脑：**Windows**，安装 [Git for Windows](https://git-scm.com/download/win)（提供 Git Bash）与 adb（platform-tools）。

## 快速开始

1. 下载并解压本仓库；
2. 在 Windows 上双击 **`一键Root.bat`**（等价于在 Git Bash 中执行 `bash auto_root.sh`）；
3. 脚本会依次完成：
   - 安全提示与确认；
   - 检查 adb 与设备连接；
   - **自动检测固件版本**并选用对应的 boot / recovery 镜像套件（无法识别则停止）；
   - 幂等预置：安装载体 App、推送镜像与守卫文件、放置 `magiskpolicy`；
   - 后台循环尝试并每 30 秒回报状态；
   - 命中后自动刷入定制 boot 与 TWRP 并重启。

> 磨机过程中手表每 1–2 分钟自动复位一次属正常现象，请勿拔线。每 25 轮脚本会提示做一次电池冷启动（拔线 → 长按侧键 12 秒关机 → 开机 → 插回），有助于提升命中率。

## 结果验证

```bash
adb shell 'id; getprop ro.debuggable; getprop service.adb.tcp.port; getenforce'
# 期望：uid=0(root) / 1 / 5555 / Permissive

adb shell 'setenforce 1; getenforce; setenforce 0; getenforce'
# 期望：Enforcing → Permissive（双向均可切换）
```

无线 adb：

```bash
adb shell ip -4 addr show wlan0      # 查看手表 IP
adb connect <IP>:5555
adb -s <IP>:5555 shell id           # uid=0(root)
```

进入维护 recovery：

```bash
adb reboot recovery                 # 约 25 秒进入 TWRP
adb shell id                        # uid=0(root)
```

## 仓库文件说明

| 文件 | 作用 |
|---|---|
| `一键Root.bat` / `auto_root.sh` | Windows 入口与一键编排（检测、预置、磨机、回报） |
| `rc17_hunt_v2.sh` | 循环磨机：重启、拉起载体、命中检测、自动刷写与证据保存 |
| `ea0.apk` | 载体 App（com.gc.p2），内含利用载荷 |
| `zzq1` / `mod.sh` | 设备侧 root 后动作与 modprobe 兜底载荷 |
| `magiskpolicy_arm32` | 开机 SELinux 策略钩子依赖（自动放入 `/data/local/tmp/magiskpolicy`） |
| `boot_wifiadb_v7_policy_{a89,a92}.img` | 对应版本的定制 boot（刷写目标） |
| `twrp-3.7.0_9-*_{A89,A92}_adb4.img` | 对应版本的维护 TWRP recovery |
| `recovery_原厂_{A89,A92}.img` | 原厂 recovery，用于回滚 |
| `flash_partition_from_recovery.sh` | recovery 下分区刷写工具（白名单 + 推送 / 回读校验） |
| `flash_v7_after_root.sh` | 手动重刷 / 切换定制 boot 的辅助脚本 |
| `MANIFEST.txt` | 文件清单与校验值 |

## 中断与恢复

磨机为无状态循环，进度保存在设备的 `/data`、`/cache` 分区中，电脑端重启或脚本中断均不丢失。重新连接设备后再次执行 `bash rc17_hunt_v2.sh` 即可续磨；如需清空命中证据重新开始，先执行 `bash rc17_hunt_v2.sh reset`。

## 回滚

- **recovery**：`bash flash_partition_from_recovery.sh recovery_原厂_A92.img recovery`（A.89 使用对应原厂镜像）；
- **boot**：将原厂或上一版本 boot 镜像刷回 boot 分区即可。

## 免责声明

本工具仅用于**个人自有设备**的安全研究、教学与个性化定制。对设备的任何修改都存在变砖、数据丢失或丧失保修的风险，作者与贡献者不对任何直接或间接损失负责。请在充分理解后果的前提下使用，勿用于任何未经授权的设备或用途。

## 致谢

- 上游项目：[`lokkl-LZY/oppowatch2-root`](https://github.com/lokkl-LZY/oppowatch2-root)；
- 第三方开源组件：TWRP、Magisk（magiskpolicy）等，其权利归各自所有者。
