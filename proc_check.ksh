#!/bin/bash
#########################################################################
# ?2023 TEOCO. ALL RIGHTS RESERVED                                      #
# Customization Option
# Author : Rishabh Singh
#########################################################################
start1=$(date +%s)
mkdir -p tmp && rm -rf tmp/*  >/dev/null 2>&1
if [ $# -eq 0 ];
then
echo "$0: Missing arguments"
echo "Info: Use -help for help. [syntax : $0 -help]"
exit 1
fi

if [[ $1 == "-help" ]];then
        echo "
=================================================================================================

Info : This script is used to check process status.

        Syntax  : $0 <process name>
        Example : $0 fam_cor_trs_parent.connect

It Displays following information of given Access:

          1. Process Status.
          2. PID.
          3. Last Restart Time.
          4. Consuming Memory (Size).
          5. Consuming Memory (%).
          6. Consuming CPU (CPU).
          7. Command.

Info : If process is down, it will display script name with path to start that process.

Note : All process like connect, ears etc. shold configures in CUSTOM/PROC.cfg file.

=================================================================================================
"
exit
fi

PROCESS=$@
cp /dev/null tmp/proc_check.log

for PROC in $PROCESS
do
if [[ ! -z $PROC ]];then
GET_PROC=`grep -w $PROC CUSTOM/PROC.cfg | head -1 | awk '{print $2}'`
SCRIPT=`grep -wi $PROC CUSTOM/PROC.cfg | head -1 | awk '{print $1}'`
if [[ ! -z $GET_PROC ]];then
CH_PROC=`ps -ef | grep -w -m 1 "$GET_PROC" | grep -v 'grep' | grep -v "$0"`
echo $CH_PROC > tmp/proc_check.log
fi


echo "
========================================================================================================================
"
if [[ "$CH_PROC" != "" ]];then
echo "`date` : $GET_PROC service running, everything is fine"
PID=`echo $CH_PROC | awk '{print $2}'`
USER=`ps -eo pid,user | grep -w $PID | grep -v grep | awk '{print $2}'`
STIME=`ps -eo pid,lstart | grep -w $PID | grep -v grep | tr -s ' ' | cut -d' ' -f3-`
COMM=`ps -eo pid,comm | grep -w $PID | grep -v grep | awk '{print $2}'`
MEMS=`top -b -n 1 | grep -w $PID | grep -iv grep | awk '{print $6}'`
CPUP=`top -b -n 1 | grep -w $PID | grep -iv grep | awk '{print $9}'`
MEMP=`top -b -n 1 | grep -w $PID | grep -iv grep | awk '{print $10}'`

echo "
PID		: $PID
USER		: $USER
Start Time	: $STIME
Memory(Size)	: $MEMS
CPU(%)		: $CPUP %
Memory(%)	: $MEMP %
Command		: $COMM

Info : Process Details Captured in tmp/proc_check.log file for your reference."

elif [[ ( "$CH_PROC" == "" ) && ( ! -z $SCRIPT ) ]];then
echo "`date` : $GET_PROC is not running"
fi

if [[ ( "$CH_PROC" == "" ) && ( ! -z $SCRIPT ) ]];then
echo
echo "Run command to start \"$GET_PROC\" : \$INTEGRATION_DIR/$SCRIPT restart"


elif [[ ( "$proc" == "" ) && ( -z $SCRIPT ) ]];then
echo "`date` : \"$1\" Unknown Service, Please check CUSTOM/PROC.cfg file"
fi

echo "
========================================================================================================================
"
fi
done

rm -rf tmp/*  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
