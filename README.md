# GPU-driven case fan control (ASUS Z97M-PLUS / NCT6791D)

## What works
- The board's Super I/O is a Nuvoton NCT6791D. The stock `nct6775` kernel
  module refuses to load because ACPI claims the 0x290-0x29f range.
- A patched (unsigned) copy of `nct6775.ko` is installed in
  `/lib/modules/$(uname -r)/extra/` and loaded via `/etc/modules-load.d/nct6775.conf`.
  It exposes `/sys/class/hwmon/.../nct6791` with `pwm1`, `pwm2`, `pwm3`.
- `pwm1` = 2-pin GPU fan (set to DC mode, `pwm1_mode=0`).
- `pwm2` = case fan 2 (PWM mode).
- `pwm3` = CPU fan (left to BIOS smart-fan).

## Power limit
- Set to 120 W via `nvidia-smi -pl 120`, applied at service start for persistence.

## Control script
`/usr/local/bin/gpu-fan-control.sh` (run by systemd unit `gpu-fan-control.service`):
- reads GPU temp via `nvidia-smi`
- linear curve 35 C -> 30 %, 75 C -> 100 % for both pwm1 and pwm2
- fail-safe: full speed if `nvidia-smi` fails
- logs to `/var/log/gpu-fan-control.log`

## 2-pin fan behavior
ASUS sends a full 12 V spin-up pulse, then ramps voltage down in DC mode.
That is normal and harmless. Set the header to **DC mode** (not PWM/Auto) in BIOS
or via `pwmX_mode=0`, otherwise a 2-pin fan runs at full speed.

## Maintenance
- The patched module is kernel-version specific and unsigned. After a kernel
  update, rebuild `nct6775_patched_unsigned.ko` and reinstall to `extra/`.
- Adjust curve thresholds in the script as needed.
