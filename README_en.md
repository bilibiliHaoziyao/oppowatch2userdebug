# OW20W1 One-Click Permanent Root (PC-side)

OPPO Watch 2 46mm (OW20W1, firmware A.89 / A.92) — drives the carrier app's fastrpc vulnerability from a PC to grind out `uid=0`; on a hit it **automatically flashes the boot partition with the v7 image matching the device firmware**: permanent root + wireless adb + Permissive at boot + free SELinux toggling; it also flashes a maintenance **TWRP (with working adb)** into the recovery partition.

> ⚠️ For security research on **your own device** only. Every write is verified by readback; the boot partition is the only critical write and it can be rolled back from Android with a single command at any time — a mistake can still be risky. You are responsible for your own actions.

After connecting, the script **auto-detects the firmware version** (A.89 / A.92) and uses the matching image set; if the version cannot be identified it stops immediately.

---

## What the v7 boot gives you

| Capability | Mechanism |
|---|---|
| **USB adb is root** (survives reboots) | `ro.debuggable=1` + `service.adb.root=1` → adbd keeps uid=0 |
| **Wireless adb**: connect over the same Wi-Fi, no cable | `service.adb.tcp.port=5555` → adbd also listens on TCP 5555 |
| **Permissive at boot** | kernel cmdline `androidboot.selinux=permissive` |
| **Toggle SELinux at will** | at boot_completed init execs `/data/local/tmp/magiskpolicy --live "allow shell kernel security setenforce"` → `setenforce 1`/`0` both directions work |
| adb enabled by default | `persist.sys.usb.config=mtp,adb` |
| Security model unchanged | `ro.adb.secure=1` kept — connections still require your PC's adb key |

> Note: the root shell's SELinux domain is still `shell`. Raw block-device access needs `setenforce 0` (in Permissive, root adb can read/write partitions — a backup channel that needs no recovery at all).

## The bundled TWRP (maintenance recovery)

`twrp-3.7.0_9-ow20w3-recovery_{A89,A92}_adb4.img` — TWRP 3.7.0_9 with the kernel strictly matched to each firmware:

- Touch UI (backup/restore/install/terminal) + **adb also runs as uid=0(root)** with direct block-device access
- The device's USB chain is fully fixed (configfs gadget + adbd start + root path)
- **Fully decoupled from boot**: any recovery problem cannot affect normal boot (the boot partition is untouched; if you cannot enter recovery, dd it back from Android)

## Firmware version support (important)

The package **carries both the A.89 and the A.92 image sets**; the script auto-detects the firmware and picks the matching set:

| Detection | Basis | Image set |
|---|---|---|
| **A.89** (built 2024-08-22) | `ro.build.display.id` contains `A.89` (or boot build stamp 1724329644) | `*_a89.img` / `*_A89_adb4.img` / `recovery_原厂_A89.img` |
| **A.92** (built 2025-02-12) | `ro.build.display.id` contains `A.92` (or boot build stamp 1739333172) | `boot_wifiadb_v7_policy_a92.img` / `*_A92_adb4.img` / `recovery_原厂_A92.img` |
| Anything else | — | **the script stops** (exploit offsets are hard-coded for these two kernels) |

- ✅ **The exploit chain itself is fully portable**: every chain-relevant symbol address is identical (all deltas 0) and the fastrpc driver code is byte-identical — the `.so` payload needs zero modification
- ✅ Images are version-matched pairs: boot/recovery embed their own firmware's kernel+ramdisk and **must not be cross-flashed**
- Identify with: `adb shell getprop ro.build.display.id`

## Package contents

| File | Purpose |
|---|---|
| `rc17_hunt_v2.sh` | The grind loop: reboot cycle + param injection + auto-flashes v7 on a hit + stops to preserve evidence |
| `auto_root.sh` | **One-click orchestrator**: safety gate → adb/device check → firmware detection → idempotent prep (incl. magiskpolicy) → grind → live status |
| `一键Root.bat` | Windows double-click entry (auto-finds Git Bash, ASCII-only) |
| `ea0.apk` | Carrier app (com.gc.p2) — embeds the exploit `libp2probe.so`, md5 `4af0b2c5283ab616da0a8c049f567105` |
| `zzq1` / `mod.sh` | Device-side auxiliary payloads |
| `magiskpolicy_arm32` | v7 boot-hook dependency (the one-click script stages it at `/data/local/tmp/magiskpolicy`), md5 `bfeaa0843da89d4038e1432ed3412195` |
| `boot_wifiadb_v7_policy_a92.img` | **A.92 v7 boot** (the one-click flash target), md5 `ab62f167eab2983a43bd419af600c9a3` |
| `boot_wifiadb_v7_policy_a89.img` | **A.89 v7 boot** (the one-click flash target), md5 `2e06f10a58d1be0ddeef7f4ccab15ec2` |
| `twrp-3.7.0_9-ow20w3-recovery_A89_adb4.img` | A.89 maintenance TWRP (adb working), md5 `57c9aa012f045161e3475f9626333850` |
| `twrp-3.7.0_9-ow20w3-recovery_A92_adb4.img` | A.92 maintenance TWRP (adb working), md5 `fe56bcf23a305c7ef30fba8dcd9e88c3` |
| `recovery_原厂_A92.img` / `recovery_原厂_A89.img` | Stock recovery images (for rollback), md5 `d05b0d37…` / `521436b3…` |
| `flash_partition_from_recovery.sh` | Partition flasher: whitelist (boot/recovery/misc) + push verification + readback compare by image length |
| `flash_v7_after_root.sh` | Helper to re-flash/switch v7 manually (stages magiskpolicy + recovery channel + setenforce round-trip check) |

> **Image note**: the v7 images carry 4 "steering bytes" at EOF-0x44 that pin the whole-file FNV-1a32 to the value the payload's `preload` check requires (otherwise the flash source is rejected and a hit cannot flash). The 4 bytes live in inert zero padding outside the factory AVB structures — boot, AVB0/AVBf and the readback check are unaffected. The TWRP images are kernel-matched repacks (id recomputed; kernel/ramdisk byte-wise from the matching build).

## Prerequisites

- Device: OW20W1, firmware A.89 or A.92, **stock boot**, bootloader unlocked (`orange`), USB debugging on and this PC's adb key authorized
- PC: any environment with adb; Windows users can just double-click the BAT

## One-click root (recommended)

**Windows**: double-click **`一键Root.bat`**. The script performs, in order:

1. The safety notes, gated by a y/N prompt
2. adb driver and device connection checks
3. **Detects the device firmware** (A.89 / A.92) → prints the image set and flash guard value; stops if unrecognised
4. Idempotent prep: installs the carrier app, stages the **matching** v7 flash target, writes the **matching** guard files, stages magiskpolicy, verifies the **matching** TWRP image
5. Runs the grind in the background with live status every 30 s (UID0 / flash-start / flash-done highlighted)
6. On a hit it auto-flashes **v7 (boot) + TWRP (recovery)** and reboots — final state: permanent root + wireless adb + Permissive/toggle + TWRP

**Linux/macOS**: `bash auto_root.sh` (same flow; drop the `MSYS_NO_PATHCONV=1` prefixes).

<details>
<summary><b>Manual mode (optional, equivalent to the one-click)</b></summary>

### 1️⃣ Install the carrier app

```bash
adb install -r ea0.apk
# If you get INSTALL_FAILED_UPDATE_INCOMPATIBLE: adb uninstall com.gc.p2, then retry
```

### 2️⃣ Stage the flash target, guard and policy tool

First confirm the firmware (`adb shell getprop ro.build.display.id`) and pick the matching values:

| Parameter | A.89 | A.92 |
|---|---|---|
| Image file | `boot_wifiadb_v7_policy_a89.img` | `boot_wifiadb_v7_policy_a92.img` |
| Image md5 | `2e06f10a58d1be0ddeef7f4ccab15ec2` | `ab62f167eab2983a43bd419af600c9a3` |
| Guard FNV (stock boot, first 1 MB) | `184546148` | `4259604844` |

```bash
# Example is A.89; for A.92 substitute the values above
MSYS_NO_PATHCONV=1 adb push boot_wifiadb_v7_policy_a89.img /data/local/tmp/boot_debuggable_v2.img
adb shell 'md5sum /data/local/tmp/boot_debuggable_v2.img'
#   must equal 2e06f10a58d1be0ddeef7f4ccab15ec2

adb shell "printf 'flash_guarded\n' > /data/local/tmp/flash_action; \
printf '184546148\n' > /data/local/tmp/expected_boot_sum; \
: > /data/local/tmp/flash_stage.txt; \
chmod 666 /data/local/tmp/flash_action /data/local/tmp/expected_boot_sum /data/local/tmp/flash_stage.txt"

# v7 boot-hook dependency (required)
MSYS_NO_PATHCONV=1 adb push magiskpolicy_arm32 /data/local/tmp/magiskpolicy
adb shell 'chmod 755 /data/local/tmp/magiskpolicy'
```

### 3️⃣ Run the grind

```bash
bash rc17_hunt_v2.sh
```

- **The watch reboots itself every 1–2 minutes = normal**, do not unplug
- Average **35–45 minutes** to a hit (~2.2% per shot); every 25 rounds the script asks for a battery cold-boot (unplug → hold side button 12 s → boot → plug back) — strongly recommended
- On a hit the script **finishes the flash automatically and stops**; evidence lands in the current folder

</details>

### What happens automatically after a hit

1. The exploit gains `uid=0` → verifies the current boot is the **matching firmware's** stock (FNV guard) → writes v7 to the boot partition (with readback) → reboots into v7
2. The grind detects the hit → **auto-flashes the TWRP** (recovery channel, readback) → reboots again
3. Final state: **v7 permanent root + TWRP**, zero manual steps (`RECOVERY_AUTOFLASH=0` disables step 2)

> If step 2 cannot enter recovery (possible on a first-time/fresh install; harmless): v7 is already live — just dd it from Android:
> `adb shell "setenforce 0; dd if=/data/local/tmp/xxx_twrp.img of=/dev/block/bootdevice/by-name/recovery bs=1048576; sync"`

### Verify

```bash
adb shell 'id; getprop ro.debuggable; getprop service.adb.tcp.port; getenforce'
# expected: uid=0(root) / 1 / 5555 / Permissive

adb shell 'setenforce 1; getenforce; setenforce 0; getenforce'
# expected: Enforcing → Permissive (the v7 policy hook works both ways)
```

## Wireless adb (a v7 headline feature)

```bash
adb shell ip -4 addr show wlan0      # get the watch's IP
adb connect <IP>:5555
adb -s <IP>:5555 shell id            # uid=0(root), no cable
```

## Free SELinux toggling (v7)

```bash
adb shell setenforce 1   # tighten (safer; friendlier to banking/DRM apps)
adb shell setenforce 0   # loosen (block-device access / debugging)
# after a reboot it returns to Permissive automatically (cmdline)
```

Depends on `/data/local/tmp/magiskpolicy`; if missing, only "cannot switch back from Enforcing" (reboot restores) — boot and root are unaffected.

## Maintenance channel: TWRP (adb working)

```bash
adb reboot recovery                 # TWRP comes up in ~25 s
adb shell id                        # uid=0(root), block-device access
```

- Use the touch UI for backup/restore/flash, or adb + `flash_partition_from_recovery.sh`
- **Roll recovery back to stock**: `bash flash_partition_from_recovery.sh recovery_原厂_A92.img recovery` (use `recovery_原厂_A89.img` on A.89)
- **Roll boot back**: flash the previous/stock boot image to boot (stock images live in the `OPPO手表2_全分区备份_20260921` backup folder or the official firmware package; or simply switch back to v7 with `flash_v7_after_root.sh`)

## Interrupted? Resume

The grind is a **stateless loop**: all progress lives on the watch — the carrier app, the flash target, the guard files and the evidence files are in `/data` and `/cache`; a PC reboot / power loss / killed script loses nothing. To resume:

```bash
adb devices                        # confirm the device is online
bash rc17_hunt_v2.sh               # just run it again — that IS the resume
```

- **No hit before the interruption**: it simply continues (the round counter restarts; the hit rate is per-round, unchanged)
- **A hit actually landed** (evidence not yet collected): the first evidence guard of the new run detects it, pulls the evidence and stops — **a hit is never lost to an interruption**
- **Already hit and v7 flashed**: `adb shell getprop ro.debuggable` = `1` means root is already yours
- A stale singleton lock after a PC power loss is auto-detected and bypassed

## Reset and run again

Hit evidence is **never cleared by design** (it is the acceptance proof), so an immediate re-run stops right away. Before grinding again:

```bash
bash rc17_hunt_v2.sh reset
```

Note: after a hit the boot is already v7; to replay the whole flow from the start, flash the stock boot back first (see the maintenance chapter).

## Troubleshooting

| Symptom | Fix |
|---|---|
| Device offline / disappears for minutes and returns | USB enumeration flap, self-heals in 30–60 s; the script waits up to 180 s |
| Watch reboots repeatedly during the grind | **Normal** (failed rounds usually end with a DSP exception → watchdog reset) |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | A same-name app with a different signature exists: `adb uninstall com.gc.p2`, then reinstall |
| `adb connect <IP>:5555` times out but USB works | The watch's Wi-Fi power-save drops the link when the screen is off; use it with the screen on / while charging |
| Cannot enter recovery | Does not affect boot (boot untouched); dd the recovery back from Android under Permissive |
| Want fastboot | Unreachable on this ABL (BCB/buttons/reason all ignored) — do not waste time |

## Hit-rate note

Per-shot success is about **2.2%**; the mean is 35–45 minutes — the chain is a series of five low-probability races. The dominant variable is ADSP session-pool health (when degraded, the chain falls back to reusing old sessions and produces fewer shots); a **true battery cold-boot** (unplug → hold the side button 12 s to power off → boot → plug back in; a warm reboot does not help) improves it notably — the grind prompts for one every 25 rounds.
