#!/bin/bash
###################################################################
# ?2023 TEOCO. ALL RIGHTS RESERVED                                #
# Customization Option
# Author : Rishabh Singh
###################################################################
######### To Dispaly help prompt of script ########################
start1=$(date +%s) 
mkdir -p tmp && rm -rf tmp/*  >/dev/null 2>&1
STATE=$1
N2P_LOG_DIR=`env | grep N2P_LOG_DIR | awk -F "=" '{print $2}'`

if [ $# -eq 0 ];
then
echo "$0: Missing arguments"
echo "Info: Use -help for help. [syntax : $0 -help]"
exit 1
fi
if [[ "$1" == "-help" ]];then 
echo "
==================================================================================================================================

Note : This script is use to check tasks status of Load Hadoop, thinout, TG and aggregation.

Arguments:
     -loadhadoop    :  To check Load hadoop tasks status.
     -aggr          :  To check aggregation tasks status.
     -aggrimpala    :  To check aggregation(Impala) tasks status.
     -tg            :  To check TG tasks status.
     -thinout       :  To check ThinOut Worker task status.

Syntax          : $0 -loadhadoop
Example         : $0 -loadhadoop -20 --- To check last 20 load hadoop tasks status.
Example2        : $0 -loadhadoop -fail  --- To check all failed & crashed load hadoop tasks.
Example3        : $0 -loadhadoop -fail -10 --- To check last 10 failed & crashed load hadoop tasks only.

Note : Run this script on main mediation server.

==================================================================================================================================
"
exit
fi
###################################################################
HOSTNAME=`hostname`
HOSTNAME2=`cat CUSTOM/SERVER.cfg | awk '{print $1}' | cut -d'@' -f2 | head -1`
if [[ $HOSTNAME != $HOSTNAME2 ]];then
echo "${red}Error: ${reset}Wrong Machine. Run this script on main mediation server."
exit 1
fi
###################################################################

date=`date "+%Y-%m-%d"`

if [[ ( "$STATE" != "-loadhadoop" ) && ( "$STATE" != "-aggr" ) && ( "$STATE" != "-tg" ) && ( "$STATE" != "-aggrimpala" )  && ( "$STATE" != "-thinout" ) ]]
	then
	echo "$0: Invalid Argument. 
Info: Use -help for help."
	exit 1
	fi

if [[ "$STATE" == "-loadhadoop" ]];then
CHECK="LoadHadoop"
fi

if [[ "$STATE" == "-aggr" ]];then
CHECK="TRAggr-"
fi

if [[ "$STATE" == "-tg" ]];then
CHECK="TG_REGULAR"
fi

if [[ "$STATE" == "-aggrimpala" ]];then
CHECK="TRAggrImpala"
fi

if [[ "$STATE" == "-thinout" ]];then
CHECK="ThinOut-worker"
fi

INT=^[-][0-9]+$
if [[ ! -z $3 ]];then
if ! [[ $3 =~ $INT ]];then
echo "Error: $3 invalid argument. 
Use a interger value with hyphen(-).
Info: Use -help for help."
exit 1
fi
fi



function get_time() {
SEC=`echo $(($(date -d "$TIME1" +%s) - $(date -d "$TIME2" +%s)))`
if (( $SEC<="59" )); then
SEC=$SEC ;GAP="$SEC Seconds Ago"
elif (( $SEC>="60" & $SEC<="3599" ));then
((MIN=$SEC/60));GAP="$MIN Minutes Ago"
elif (( $SEC>="3600" & $SEC<="86399" ));then
((HOUR=$SEC/3600));((MIN=$SEC/60%60));((SECOND=$SEC%60));GAP="$HOUR Hours : $MIN Minutes : $SECOND Seconds Ago"
elif (( $SEC>="86400" & $SEC<="2629799" ));then
((HOUR=$SEC/3600));((MIN=$SEC/60%60));((SECOND=$SEC%60));((DAY=$HOUR/24));((HOUR=$HOUR%24));GAP="$DAY Days : $HOUR Hours : $MIN Minutes Ago"
elif (( $SEC>="2629800" ));then
((HOUR=$SEC/3600));((MIN=$SEC/60%60));((SECOND=$SEC%60));((DAY=$HOUR/24));((MON=$DAY/31));((DAY=$DAY%31));((HOUR=$HOUR%24));GAP="$MON Months : $DAY Days : $HOUR Hours : $MIN Minutes Ago"
fi
echo $GAP
}


echo "
 Log File Name|Date & Time|Task ID| Status
-------------------------------------------------------------------|-------------------------|-----------|-----------
" > tmp/poo1.txt

OPT=$3
if [[ ( ! -z $1 ) && ( $2 == "-fail" ) ]];then
grep UpdateTaskState $N2P_LOG_DIR/$CHECK* 2>/dev/null | awk '{print $1,$2,$(NF-1),$NF}' | awk -F/ '{print $NF}' | awk '{print "$N2P_LOG_DIR/"$1,$2,$3,$4}' | sed 's/:/|/' | sed 's/UpdateTaskState(/|/g' | sed 's/,/|/g' | sed 's/)//' | sed 's/))//g' | sort -t "|" -k2 > tmp/poo.txt 2> /dev/null 
echo "
===============================================================================================================================

$CHECK Failed & Crashed Task Status :
--------------------------------------------
"
cat tmp/poo.txt |egrep -i 'fail|crash' | tail $OPT > tmp/foo.txt 
grep -v '^[[:space:]]*$' tmp/foo.txt >> tmp/poo1.txt
column -s "|" -t  tmp/poo1.txt > tmp/poo2.txt

if [[ ! -s tmp/poo.txt ]];then
echo "Warning : No Task Found"
else
cat tmp/poo2.txt
fi
echo "
===============================================================================================================================
"
TIME1=`date '+%Y-%m-%d %T %Z'`
echo "Server Time : $TIME1
"
CT=`cat tmp/poo2.txt | grep -iv grep | egrep -i 'fail|crash' | wc -l`
echo "Failed & Crashed Tasks Count : $CT"
echo "
===============================================================================================================================
"
end1=$(date +%s) 
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You "
exit 1
fi

if [[ ( ! -z $1 ) && ( $2 != "-fail" ) ]];then
if ! [[ $2 =~ $INT ]] && ! [[ -z $2 ]];then
echo "Error: $2 invalid argument. Use a interger value with hyphen(-).
Info: Use -help for help."
exit 1
elif [[ ( -z $2 ) || ( $2 =~ $INT ) ]];then
grep UpdateTaskState $N2P_LOG_DIR/$CHECK* 2>/dev/null | awk '{print $1,$2,$(NF-1),$NF}' | awk -F/ '{print $NF}' | awk '{print "$N2P_LOG_DIR/"$1,$2,$3,$4}' | sed 's/:/|/' | sed 's/UpdateTaskState(/|/g' | sed 's/,/|/g' | sed 's/)//' | sed 's/))//g' | sort -t "|" -k2 > tmp/poo.txt 2> /dev/null 
echo "
===============================================================================================================================

$CHECK Task Status :
-----------------------------------
"
grep -v '^[[:space:]]*$' tmp/poo.txt | tail $2 >> tmp/poo1.txt
column -s "|" -t tmp/poo1.txt > tmp/poo2.txt

if [[ ! -s tmp/poo.txt ]];then
echo "Warning : No Task Found"
else
cat tmp/poo2.txt
fi
echo "
===============================================================================================================================
"
if [[ -s tmp/poo.txt ]];then

TIME1=`date '+%Y-%m-%d %T %Z'`
echo "Server Time : $TIME1"
TIME2=`grep done tmp/poo.txt| tail -1 | awk -F "|" '{print $2}' | awk '{print $1,$2}'`
#TIME2=`echo $TIME2 | sed 's/done//' | sed 's/crash//' | sed 's/fail//'`
echo "
Last Task Was Done - `get_time` on $TIME2
"
TIME2=`grep fail tmp/poo.txt| tail -1 | awk -F "|" '{print $2}' | awk '{print $1,$2}'`
#TIME2=`echo $TIME2 | sed 's/done//' | sed 's/crash//' | sed 's/fail//'`
echo "Last Task Was failed - `get_time` on $TIME2
"
TIME2=`grep crash tmp/poo.txt | tail -1 | awk -F "|" '{print $2}' | awk '{print $1,$2}'`
#TIME2=`echo $TIME2 | sed 's/done//' | sed 's/crash//' | sed 's/fail//'`
echo "Last Task Was Crashed - `get_time` on $TIME2
"
CT=`cat tmp/poo2.txt | grep -iv grep | egrep -i 'fail|crash' | wc -l`
echo "Failed & Crashed Tasks Count in Selected Tasks : $CT"

echo "
===============================================================================================================================
"
fi
fi
fi

end1=$(date +%s) 
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You "
exit 1
