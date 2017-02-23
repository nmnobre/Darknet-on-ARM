#!/bin/sh

# The help/usage message which must be improved to comply with the standard rules.
usage() {
	printf "usage: %s or taskset <mask> %s 
	<mask>: hexadecimal bitmask representing CPU affinity for %s.
	For example: write 03 to select processors #0 and #1 and 0F for processors #0, #1, #2 and #3\n" "$0" "$0" "$EXEC"
}

if [ $# -eq 0 ]; then
	usage
	exit 1
fi

#### Customizable options (default values):

# Maximum number of darknet executions, maximum number of times the CPU frequencies are fetched per execution and the
# iteration which marks the start of darknet's execution.
MAX_REP=1
MAX_ITERS=17
EXEC_ITER=3

# The file you which to write darknet's stdout *and* stderr.
OUT_FILE=darknet.out

# Fetch and print CPU frequencies?
VERBOSE=false

####

while getopts ":n:o:vi:e:h" opt; do
  case $opt in
    n)
      MAX_REP=$OPTARG ;;
	o)
	  OUT_FILE=$OPTARG ;;
    v) 
	  VERBOSE=true ;;
    i)
	  MAX_ITERS=$OPTARG ;;
	e)
	  EXEC_ITER=$OPTARG ;;
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

# These detect the maximum CPU ID available (= maximum number of CPUs - 1), the interval (in seconds) between CPU frequency
# fetches and set a control flag to prevent multiple execution termination detections.
CPUS=$(ls /sys/devices/system/cpu/cpu? -d | tail -c 2)
SLEEP_SEC=2
TERMINATED=false

# The default executable is darknet_arm and assumes that you are root (run 'adb root' prior to 'adb shell'). If the
# instruction set architecure is detected to be x86-64 then the executable is changed to darknet_x86_64 and the command
# fetching the CPU frequencies is prefixed with sudo. Evidently, this assumes the executables were already compiled and
# are available in the current directory.
EXEC=darknet_arm
EXEC_ROOT=
if [ $(uname -m) = "x86_64" ]; then
	EXEC=darknet_x86_64
	EXEC_ROOT="sudo -p '[sudo] password for %u is required to fetch CPU frequencies: '"
fi
EXEC="./$EXEC detect cfg/yolo.cfg pre-trained/yolo.weights data/dog.jpg"

# The output file's directory.
OUT_DIR=stats
rm -rf $OUT_DIR
mkdir $OUT_DIR
OUT_FILE=$OUT_DIR/$OUT_FILE

####

for k in `seq 1 $MAX_REP`
do

	if [ $VERBOSE = false ]; then
		printf ">>> [$k] darknet execution started \n"
		$EXEC >>$OUT_FILE 2>&1
		printf ">>> [$k] darknet execution terminated \n"			
		continue
	fi

	for i in `seq 1 $MAX_ITERS`
	do

		if [ $i -gt $EXEC_ITER -a ! -z "$(kill -0 $! 2>&1 | grep process)" -a $TERMINATED = false ]; then
			printf ">>> [$k] darknet execution terminated \n"
			TERMINATED=true
		fi

		for j in `seq 0 $CPUS`
		do
			eval $EXEC_ROOT cat /sys/devices/system/cpu/cpu$j/cpufreq/cpuinfo_cur_freq | xargs printf "cpu $j: %s\t"
		done

		printf "\n"

		if [ $i -eq $EXEC_ITER ]; then
			$EXEC >>$OUT_FILE 2>&1 &
			printf ">>> [$k] darknet execution started; %s \n" "$(taskset -p $!)"
		fi

		sleep $SLEEP_SEC

	done

	TERMINATED=false
	printf ">>> [$k] %s\n" "$(cat $OUT_FILE | grep Predicted | tail -n 1)"

done

mv predictions* $OUT_DIR/