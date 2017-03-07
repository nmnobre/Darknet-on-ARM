#!/bin/sh

#### You shouldn't need to touch these:

# These detect the maximum CPU ID available (= maximum number of CPUs - 1) and the maximum/minimum
# allowed CPU frequencies.
CPUS=$(cat /proc/cpuinfo | grep "processor" | tail -c 2)
MAX_B_FREQ=0; MIN_B_FREQ=0
MAX_L_FREQ=0; MIN_L_FREQ=0
for i in `seq 0 $CPUS`
do
	MAX_FREQ=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq)
	MIN_FREQ=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_min_freq)		
	if [ $MAX_FREQ -gt $MAX_B_FREQ ]; then
		MAX_L_FREQ=$MAX_B_FREQ; MIN_L_FREQ=$MIN_B_FREQ
		MAX_B_FREQ=$MAX_FREQ; MIN_B_FREQ=$MIN_FREQ
	elif [ $MAX_FREQ -lt $MAX_B_FREQ ]; then
		MAX_L_FREQ=$MAX_FREQ; MIN_L_FREQ=$MIN_FREQ
	fi
done

#### The help/usage message.

usage() {
	printf "usage: %s [-h] -g governor -G governor [-f freq] [-F freq]
	-h: prints this message
	-g governor: the governor of the low-power cluster cores (%s)
	-G governor: the governor of the high-performance cluster cores (%s)
	-f freq: the frequency of the low-power cluster cores (%uMHz - %uMHz)
	-F freq: the frequency of the high-performance cluster cores (%uMHz - %uMHz)

	Root permissions required: run '$ adb root' prior to '$ adb shell'
	For some reason, sometimes(?!) the device resets the frequencies \n" \
	$(basename $0) "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)" \
	"$(cat /sys/devices/system/cpu/cpu$CPUS/cpufreq/scaling_available_governors)" \
	$((MIN_L_FREQ/1000)) $((MAX_L_FREQ/1000)) $((MIN_B_FREQ/1000)) $((MAX_B_FREQ/1000)) >&2
}

#### Parse options

if [ $# -lt 1 ] ; then
   usage
   exit 1
fi

while getopts ":g:G:f:F:h" opt; do
  case $opt in
    g)
      L_GOVERNOR=$OPTARG ;;
    G)
	  B_GOVERNOR=$OPTARG ;;
	f)
	  L_FREQ=$((OPTARG*1000)) ;;
    F) 
	  B_FREQ=$((OPTARG*1000)) ;;
    h)
	  usage
	  exit 1 ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1 ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      exit 1 ;;
  esac
done

####

for i in `seq 0 $CPUS`
do
	MAX_FREQ=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq)
	if [ $MAX_FREQ -eq $MAX_B_FREQ ]; then
		echo $B_GOVERNOR > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
		if [ ! -z "$B_FREQ" ]; then echo $B_FREQ > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_setspeed; fi
	elif [ $MAX_FREQ -eq $MAX_L_FREQ ]; then
		echo $L_GOVERNOR > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
		if [ ! -z "$L_FREQ" ]; then echo $L_FREQ > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_setspeed; fi
	fi
done