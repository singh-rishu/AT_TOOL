#!/bin/bash
###################################################################
# ?2023 TEOCO. ALL RIGHTS RESERVED                                #
# Customization Option
# Author : Rishabh Singh
###################################################################
start1=$(date +%s)
mkdir -p tmp && rm -rf tmp/*  >/dev/null 2>&1
if [ $# -eq 0 ];
then
echo "$0: Missing arguments"
echo "Info: Use -help for help. [syntax : $0 -help]"
exit 1
fi
if [[ $1 == "-help" ]] ;then
echo "
==========================================================================================

Parameters:
        mem      :  To check Memory Utilization & Top 10 highest memory using process.
        cpu      :  To check Utilization of all cpu & Top 10 highest memory using process.
        swap     :  To check Swap Utilization & Top 10 highest swap using process.
        cpu -all :  To check status of all processors

Systax  : $0 <parameter>
Example : $0 cpu

==========================================================================================
"
exit
fi

input=$1
if [[ ( "$input" != "mem" ) && ( "$input" != "cpu" ) && ( "$input" != "swap" ) ]]
        then
        echo "Please enter correct argument(mem/cpu/swap). [ Use -help for help ]."
        exit
        fi

if [ $input == mem ]
        then
        STAT="MEM"
        echo "
==========================================================================================================

Memory & Swap Utilization:
---------------------------

`free -gh | head -1`
            ----------------------------------------------------------------------
`free -gh | tail -2`

==========================================================================================================
"
fi

if [ $input == swap ]
        then
echo "
==========================================================================================================

Memory & Swap Utilization:
---------------------------

`free -gh | head -1`
            ----------------------------------------------------------------------
`free -gh | tail -2`

==========================================================================================================

Top 10 Highest Swap Consuming Processes:
------------------------------------------

      PID  CMD                                      Usage (KB)
     ----- --------------------                 ------------------
`find /proc -maxdepth 2 -path "/proc/[0-9]*/status" 2>/dev/null -readable -exec awk -v FS=":" '{process[$1]=$2;sub(/^[ \t]+/,"",process[$1]);} END {if(process["VmSwap"] && process["VmSwap"] != "0 kB") printf "%10s %-30s %20s\n",process["Pid"],process["Name"],process["VmSwap"]}' '{}' \; | sort -k3 -nr | head -10`

==========================================================================================================
"
exit
fi

if [ $input == cpu ]
        then
        STAT="CPU"
CPU_DETAIL=`mpstat | head -1`
CPU_TIME=`mpstat | tail -2 | awk '{print $1,$2}' | tail -1`
CPU_COUNT=`mpstat | tail -2 | awk '{print $3}' | tail -1`
CPU_USE=`mpstat | tail -2 | awk '{print $4}' | tail -1`
CPU_FREE=`mpstat | tail -2 | awk '{print $13}' | tail -1`

echo "
==========================================================================================================

CPU Utilization :
------------------

$CPU_DETAIL

      Time                 CPU            Usage(%)              Free(%)
--------------------     -------        ------------          -----------
  $CPU_TIME                $CPU_COUNT             $CPU_USE %               $CPU_FREE %

==========================================================================================================
"
fi
echo "Top 10 Highest $STAT Consuming Process:
--------------------------------------------------
"
if [[ "$2" != "-all" ]];then
top $2 -b -n 1 -o %"${STAT}"| grep -A11 -m 1 PID | grep -v grep | sed 's/-DN/EAR/g'
elif [[ "$2" == "-all" ]];then
top $3 -b -n 1 -o %"${STAT}"| grep -A11 -m 1 PID | grep -v grep | sed 's/-DN/EAR/g'
fi
echo "
==========================================================================================================
"
if [[ ( "$input" == "cpu" ) && ( "$2" != "-all" ) ]];then
echo "Note: Use -all option to check status of all processors. (Syntax : $0 cpu -all)"
echo

elif [[ ( "$input" == "cpu" ) && ( "$2" == "-all" ) ]];then

echo "Report of all processors :"
echo "------------------------------"

mpstat -P ALL | grep -iv linux
echo "
==========================================================================================================
"
fi

rm -rf tmp/*  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
