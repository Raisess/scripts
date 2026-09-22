#!/bin/bash

# ==========================================
# PC Hardware Information v3
# Arch Linux
# ==========================================

# 2-space indentation
# Focus: reliable memory channel detection

# ---------- Helper functions ----------

print_header() {
  echo
  echo "=========================================="
  echo "$1"
  echo "=========================================="
}

# ---------- CPU information ----------

print_header "CPU / PROCESSOR"

CPU_MODEL=$(lscpu | sed -n 's/^Model name:[[:space:]]*//p')
CPU_CORES=$(lscpu | sed -n 's/^Core(s) per socket:[[:space:]]*//p')
CPU_THREADS=$(lscpu | sed -n 's/^CPU(s):[[:space:]]*//p')
THREADS_PER_CORE=$(lscpu | sed -n 's/^Thread(s) per core:[[:space:]]*//p')

echo "Model:              $CPU_MODEL"
echo "Physical cores:     $CPU_CORES"
echo "Logical CPUs:       $CPU_THREADS"
echo "Threads per core:   $THREADS_PER_CORE"

# Current CPU frequency
CPU_FREQ=$(awk '
  {
    sum += $1
    count++
  }
  END {
    if (count > 0)
      printf "%.0f", sum / count
  }
' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null)

if [[ -n "$CPU_FREQ" ]]; then
  CPU_FREQ_GHZ=$(awk "BEGIN {printf \"%.2f\", $CPU_FREQ / 1000000}")
  echo "Current frequency:  $CPU_FREQ_GHZ GHz"
else
  echo "Current frequency:  N/A"
fi

# Maximum CPU frequency
MAX_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)

if [[ -n "$MAX_FREQ" ]]; then
  MAX_FREQ_GHZ=$(awk "BEGIN {printf \"%.2f\", $MAX_FREQ / 1000000}")
  echo "Maximum frequency:  $MAX_FREQ_GHZ GHz"
else
  echo "Maximum frequency:  N/A"
fi

# CPU usage
CPU_USAGE=$(top -bn1 | awk '/Cpu\(s\)/ {
  gsub(",", ".", $8)
  print 100 - $8
}')

if [[ -n "$CPU_USAGE" ]]; then
  printf "CPU usage:          %.1f%%\n" "$CPU_USAGE"
else
  echo "CPU usage:          N/A"
fi

# CPU temperature
if command -v sensors &>/dev/null; then
  CPU_TEMP=$(sensors 2>/dev/null |
    grep -E 'Package id 0|Tctl|Tdie|CPU Temperature' |
    head -1)

  if [[ -n "$CPU_TEMP" ]]; then
    echo "Temperature:        $CPU_TEMP"
  else
    echo "Temperature:        Not detected"
  fi
else
  echo "Temperature:        lm_sensors not installed"
fi


# ---------- RAM information ----------

print_header "MEMORY / RAM"

RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
RAM_USED=$(free -h | awk '/^Mem:/ {print $3}')
RAM_AVAILABLE=$(free -h | awk '/^Mem:/ {print $7}')

echo "Total:              $RAM_TOTAL"
echo "Used:               $RAM_USED"
echo "Available:          $RAM_AVAILABLE"

# Check dmidecode
if command -v dmidecode &>/dev/null; then

  MODULES=$(sudo dmidecode --type memory 2>/dev/null)

  echo
  echo "Memory modules:"
  echo "------------------------------------------"

  # Parse installed memory devices
  echo "$MODULES" | awk '
    /^Memory Device$/ {
      if (size != "") {
        printf "Slot:               %s\n", locator
        printf "Capacity:           %s\n", size
        printf "Type:               %s\n", type
        printf "Speed:              %s\n", speed
        printf "Configured speed:   %s\n", configured_speed
        echo_separator = 1
      }

      if (echo_separator)
        print ""

      locator = "N/A"
      size = ""
      type = "N/A"
      speed = "N/A"
      configured_speed = "N/A"
      echo_separator = 0
    }

    /^[[:space:]]*Size:/ {
      if ($2 != "No")
        size = $2 " " $3
    }

    /^[[:space:]]*Locator:/ {
      locator = $2
    }

    /^[[:space:]]*Type:/ {
      if ($2 != "Unknown")
        type = $2
    }

    /^[[:space:]]*Speed:/ {
      if ($2 != "Unknown")
        speed = $2 " " $3
    }

    /^[[:space:]]*Configured Memory Speed:/ {
      if ($3 != "Unknown")
        configured_speed = $3 " " $4
    }

    END {
      if (size != "") {
        printf "Slot:               %s\n", locator
        printf "Capacity:           %s\n", size
        printf "Type:               %s\n", type
        printf "Speed:              %s\n", speed
        printf "Configured speed:   %s\n", configured_speed
      }
    }
  '

  # ---------- RAM summary ----------

  echo
  echo "Memory summary:"
  echo "------------------------------------------"

  RAM_TYPE=$(echo "$MODULES" |
    awk -F': ' '
      /^[[:space:]]*Type:/ && $2 != "Unknown" {
        print $2
        exit
      }
    ')

  RAM_SPEED=$(echo "$MODULES" |
    awk -F': ' '
      /^[[:space:]]*Configured Memory Speed:/ && $2 != "Unknown" {
        print $2
        exit
      }
    ')

  RAM_MODULE_COUNT=$(echo "$MODULES" |
    awk '
      /^Memory Device$/ {
        active = 1
        size = ""
      }

      /^[[:space:]]*Size:/ && $2 != "No" {
        size = $2
      }

      /^$/ {
        if (size != "")
          count++

        size = ""
      }

      END {
        if (size != "")
          count++

        print count + 0
      }
    ')

  echo "Total capacity:     $RAM_TOTAL"
  echo "Memory type:        ${RAM_TYPE:-N/A}"
  echo "Memory speed:       ${RAM_SPEED:-N/A}"
  echo "Installed modules:  $RAM_MODULE_COUNT"


  # ==========================================
  # MEMORY CHANNEL DETECTION
  # ==========================================

  echo
  echo "Memory channel:"
  echo "------------------------------------------"

  CHANNEL="UNKNOWN"
  CHANNEL_SOURCE="None"

  # ------------------------------------------
  # Method 1: dmidecode Interleaved Data Depth
  # ------------------------------------------

  INTERLEAVE=$(echo "$MODULES" |
    grep -i "Interleaved Data Depth" |
    grep -v "Unknown" |
    head -1)

  if [[ -n "$INTERLEAVE" ]]; then

    INTERLEAVE_VALUE=$(echo "$INTERLEAVE" |
      grep -oE '[0-9]+' |
      tail -1)

    if [[ "$INTERLEAVE_VALUE" == "2" ]]; then
      CHANNEL="DUAL CHANNEL"
      CHANNEL_SOURCE="DMI / SMBIOS"
    elif [[ "$INTERLEAVE_VALUE" == "1" ]]; then
      CHANNEL="SINGLE CHANNEL"
      CHANNEL_SOURCE="DMI / SMBIOS"
    fi
  fi


  # ------------------------------------------
  # Method 2: SMBIOS memory controller data
  # ------------------------------------------

  if [[ "$CHANNEL" == "UNKNOWN" ]]; then

    CONTROLLER_INFO=$(echo "$MODULES" |
      grep -iE \
      "Interleaved|Memory Controller|Maximum Memory Module Size" |
      grep -v "Unknown")

    if echo "$CONTROLLER_INFO" | grep -qi "2"; then
      CHANNEL="DUAL CHANNEL"
      CHANNEL_SOURCE="SMBIOS memory controller"
    fi
  fi


  # ------------------------------------------
  # Method 3: EDAC
  # ------------------------------------------

  # Linux EDAC can expose the memory controller/channel
  # topology on some platforms.
  if [[ "$CHANNEL" == "UNKNOWN" ]] &&
     [[ -d /sys/devices/system/edac/mc ]]; then

    EDAC_CHANNELS=$(find \
      /sys/devices/system/edac/mc \
      -type d \
      -name "csrow*" \
      2>/dev/null |
      wc -l)

    if [[ "$EDAC_CHANNELS" -ge 2 ]]; then
      CHANNEL="DUAL CHANNEL"
      CHANNEL_SOURCE="Linux EDAC"
    fi
  fi


  # ------------------------------------------
  # Method 4: Intel RAPL / kernel topology
  # ------------------------------------------
  #
  # This is NOT used to claim Dual Channel.
  # It is intentionally informational only.
  #
  # The presence of multiple populated DIMMs does
  # NOT prove Dual Channel.

  if [[ "$CHANNEL" == "UNKNOWN" ]]; then

    if [[ "$RAM_MODULE_COUNT" -eq 1 ]]; then
      CHANNEL="SINGLE CHANNEL"
      CHANNEL_SOURCE="One installed memory module"
    fi
  fi


  # ------------------------------------------
  # Final result
  # ------------------------------------------

  case "$CHANNEL" in

    "DUAL CHANNEL")
      echo "Configuration:      DUAL CHANNEL"
      echo "Detection source:   $CHANNEL_SOURCE"
      ;;

    "SINGLE CHANNEL")
      echo "Configuration:      SINGLE CHANNEL"
      echo "Detection source:   $CHANNEL_SOURCE"
      ;;

    *)
      echo "Configuration:      UNKNOWN"
      echo "Detection source:   No reliable data available"
      echo
      echo "Note:"
      echo "Two memory modules do NOT automatically mean"
      echo "Dual Channel. The motherboard must confirm it."
      ;;

  esac

else

  echo
  echo "dmidecode is not installed."
  echo "RAM module and channel information unavailable."

fi


# ---------- Virtualization ----------

print_header "VIRTUALIZATION"

if grep -q "vmx" /proc/cpuinfo; then
  echo "CPU virtualization: Supported"
  echo "Technology:         Intel VT-x"
elif grep -q "svm" /proc/cpuinfo; then
  echo "CPU virtualization: Supported"
  echo "Technology:         AMD-V"
else
  echo "CPU virtualization: Not detected"
fi

if [[ -e /dev/kvm ]]; then
  echo "KVM:                Available"
else
  echo "KVM:                Not available"
fi


# ---------- Final ----------

echo
echo "=========================================="
echo "                  DONE"
echo "=========================================="
