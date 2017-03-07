#!/bin/sh

# The help/usage message.
usage() {
	printf "usage: %s [-h] [-s seconds]
	-h: prints this message
	-s seconds: interval (in seconds) between CPU frequency fetches (default: 2) \n" $(basename $0) >&2
}

#### Customizable options (default values):

# Interval (in seconds) between CPU frequency fetches.
SLEEP_SEC=2

####

while getopts ":s:h" opt; do
  case $opt in
    s)
      SLEEP_SEC=$OPTARG ;;
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

#### You shouldn't need to touch these:

# These detect the maximum CPU ID available (= maximum number of CPUs - 1),
# and the interval (in seconds) between CPU frequency fetches.
CPUS=$(cat /proc/cpuinfo | grep "processor" | tail -c 2)

####

while true
do

	for i in `seq 0 $CPUS`
	do			
		if [ $(uname -m) = "x86_64" ]; then
			cat /proc/cpuinfo | grep "MHz" -m $((i+1)) | tail -1 | sed 's/^[^:]*: //g' | xargs printf "cpu $i: %s\t"
		else
			cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_cur_freq | xargs printf "cpu $i: %s\t"
		fi
	done

	printf "\n"
	sleep $SLEEP_SEC

done