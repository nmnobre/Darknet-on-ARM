#!/bin/sh

#### The help/usage message.
usage() {
	printf "usage: %s [-h] [-n nexec] [-o output_file] [-v] [-i nfetches] [-e prefetches]
	-h: prints this message
	-n nexec: total number of darknet executions (default: 1)
	-o output_file: the name of the file (to be placed in stats/) for darknet's stdout and sterr (default: darknet.out)
	-v: causes CPU frequencies to be fetched and printed (root permissions required on android: run '$ adb root' prior to '$ adb shell')
	-i nfetches: number of times the CPU frequencies are fetched per execution (default: 17)
	-e prefetches: number of CPU frequency fetches before darknet execution starts (default: 3)\n" $(basename $0) >&2
}

#### Customizable options (default values):

# Maximum number of darknet executions, maximum number of times the CPU frequencies are fetched per execution and the
# iteration which marks the start of darknet's execution.
NUM_EXECS=1
NUM_FETCH=17
EXEC_ITER=3

# The file to write darknet's stdout *and* stderr.
OUT_FILE=darknet.out

# Fetch and print CPU frequencies?
VERBOSE=false

####

while getopts ":n:o:vi:e:h" opt; do
  case $opt in
    n)
      NUM_EXECS=$OPTARG ;;
	o)
	  OUT_FILE=$OPTARG ;;
    v) 
	  VERBOSE=true ;;
    i)
	  NUM_FETCH=$OPTARG ;;
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
CPUS=$(cat /proc/cpuinfo | grep "processor" | tail -c 2)
SLEEP_SEC=2
TERMINATED=false

# The default executable is darknet_aarch64. If the instruction set architecure is detected to
# be x86-64 then the executable is changed to darknet_x86_64. Evidently, this assumes the 
# executables were already compiled and are available in the current directory.
EXEC=darknet_aarch64
if [ $(uname -m) = "x86_64" ]; then EXEC=darknet_x86_64; fi
EXEC="./$EXEC detect cfg/yolo.cfg pre-trained/yolo.weights data/dog.jpg"

# The output file's directory.
OUT_DIR=results
mkdir -p $OUT_DIR
OUT_FILE=$OUT_DIR/$OUT_FILE

####

for i in `seq 1 $NUM_EXECS`
do

	if [ $VERBOSE = false ]; then
		printf ">>> [$i] darknet execution started \n"
		$EXEC >>$OUT_FILE 2>&1
		printf ">>> [$i] darknet execution terminated \n"			
		continue
	fi

	for j in `seq 1 $NUM_FETCH`
	do

		if [ $j -gt $EXEC_ITER -a ! -z "$(kill -0 $! 2>&1 | grep process)" -a $TERMINATED = false ]; then
			printf ">>> [$i] darknet execution terminated \n"
			TERMINATED=true
		fi

		for k in `seq 0 $CPUS`
		do			
			if [ $(uname -m) = "x86_64" ]; then
				cat /proc/cpuinfo | grep "MHz" -m $((k+1)) | tail -1 | sed 's/^[^:]*: //g' | xargs printf "cpu $k: %s\t"
			else
				cat /sys/devices/system/cpu/cpu$k/cpufreq/cpuinfo_cur_freq | xargs printf "cpu $k: %s\t"
			fi
		done

		printf "\n"

		if [ $j -eq $EXEC_ITER ]; then
			$EXEC >>$OUT_FILE 2>&1 &
			printf ">>> [$i] darknet execution started; %s \n" "$(taskset -p $!)"
		fi

		sleep $SLEEP_SEC

	done

	TERMINATED=false
	printf ">>> [$i] %s\n" "$(cat $OUT_FILE | grep Predicted | tail -n 1)"

done

mv predictions* $OUT_DIR/