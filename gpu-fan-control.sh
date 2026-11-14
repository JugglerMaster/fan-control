#!/bin/bash
# Control NCT6791 case fans (pwm1=2-pin GPU fan in DC mode, pwm2=case fan 2)
# based on NVIDIA GPU temperature.

set -u

HWMON=""
for d in /sys/class/hwmon/hwmon*; do
  if [ "$(cat "$d/name" 2>/dev/null)" = "nct6791" ]; then
    HWMON="$d"; break
  fi
done
if [ -z "$HWMON" ]; then
  echo "nct6791 hwmon not found" >&2
  exit 1
fi

PWM1="$HWMON/pwm1"   # GPU fan (2-pin, DC mode)
PWM2="$HWMON/pwm2"   # case fan 2
GPU=0

# set power limit to 120 W (persisted via this service)
nvidia-smi -pl 120 >/dev/null 2>&1 || true

# ensure manual mode
echo 0 > "$HWMON/pwm1_mode" 2>/dev/null || true
echo 1 > "$HWMON/pwm1_enable" 2>/dev/null || true
echo 1 > "$HWMON/pwm2_enable" 2>/dev/null || true

MIN=77    # ~30%
MAX=255   # 100%

while true; do
  temp=$(nvidia-smi -i "$GPU" --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
  if [ -z "$temp" ] || ! [[ "$temp" =~ ^[0-9]+$ ]]; then
    echo "$MAX" > "$PWM1" 2>/dev/null
    echo "$MAX" > "$PWM2" 2>/dev/null
    sleep 5
    continue
  fi

  if [ "$temp" -le 35 ]; then
    duty=$MIN
  elif [ "$temp" -ge 75 ]; then
    duty=$MAX
  else
    duty=$(( MIN + (temp-35)*(MAX-MIN)/(75-35) ))
  fi

  echo "$duty" > "$PWM1" 2>/dev/null
  echo "$duty" > "$PWM2" 2>/dev/null
  echo "$(date '+%F %T') GPU=${temp}C pwm=${duty}" >> /var/log/gpu-fan-control.log
  sleep 5
done
