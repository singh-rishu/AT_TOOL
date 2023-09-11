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
echo "$0: Missing arguments
Info: Use -help for help. [syntax : $0 -help]"
exit 1
fi
###################################################################
if [ "$1" == "-help" ];then
echo "
==================================================================================================================

Info : This script is use to troubleshoot PM Base Collection Hadoop and Oracle Alerts.

How to Use:
        Syntax  : $0 -Option <Table_Name>
        Example : $0 -impala HWE_VUGW.MON_ME_15M or $0 -ora HWE_VUGW.PADP_ME_15M

Note :  You can pass multiple arguments at once
        Exaple  : $0 -impala HWI_VUGW.MON_ME_15M HWI_VUSN.GX_PER_ME_15M

Script shows following Informatios of table :
        1. Min, Max(I) and Max_Ins date & time of table.
        2. The time interval since the last time data was loaded into the table.
        3. The time interval of max(I) and max datetime_ins .
        4. Task id of table and latest tasks status from loadhadoop log and n2_scheduler_audit tabele.

Note : Run this script on main mediation server.

==================================================================================================================
"
exit 1
fi
###################################################################
HOSTNAME=`hostname`
HOSTNAME2=`cat CUSTOM/SERVER.cfg | awk '{print $1}' | cut -d'@' -f2 | head -1`
if [[ $HOSTNAME != $HOSTNAME2 ]];then
echo "${red}Error: ${reset}Wrong Machine. Run this script on main mediation server."
exit 1
fi
####################################################################
DVX2DIR=$(env | grep DVX2_IMP_DIR | sed 's/.*=//')/config/Dbl/
N2P_LOG_DIR=`env | grep N2P_LOG_DIR | awk -F "=" '{print $2}'`
SQL="sqlplus -S psa/ttipass@$ORACLE_SID"
test -f tmp/ttt.txt || touch tmp/ttt.txt > /dev/null
INPUT=$@
OPT=$(echo $INPUT | awk '{print $1}')
TB_NAME=$(echo $INPUT | cut -d' ' -f2-)
if [[ ( $OPT != "-impala" ) && ( $OPT != "-ora" ) ]];then
echo "Error: Wrong Argument. Please use -impala or -ora.
Info: Use -help for help."
exit 1
fi
####################################################################
if [[ ( "${TB_NAME}" == "-impala" && "${OPT}" == "-impala" ) || ( "${TB_NAME}" == "-ora" && "${OPT}" == "-ora" )  ]];then
echo "$0 : Missing argument.
Info: Use -help for help."
exit 1
fi
####################################################################

for TABLE_NAME in $TB_NAME
do
TBS_NAME=$(echo $TABLE_NAME | awk -F. '{print $2}')
grep -iwr -m 1 $TBS_NAME $DVX2DIR &>/dev/null
if [ $? -eq 1 ];then
echo $TBS_NAME >> tmp/tt.txt
grep -v '^[[:space:]]*$' tmp/tt.txt > tmp/ttt.txt
CMD1=FAIL
continue
fi

if [[ $OPT == "-impala" ]];then
PARTITION_ID=`echo "show partitions $TABLE_NAME;" | impala-shell -B --quiet 2>/dev/null | awk '{print $1,$3}' | awk ' $2 > 0 '|grep ^202 | sed -n '1p ; $p' | awk '{print "|"$1"|,"}' | sed "s/|/'/g" | paste -s | rev | cut -c 2- | rev`
echo "set request_pool=cognos;
select '$TABLE_NAME' as TABLE_NAME, min(datetime_i),max(datetime_i),max(datetime_ins),now() from "$TABLE_NAME" where partition_id in ($PARTITION_ID);" > /tmp/query.hql
/bin/impala-shell --quiet -B -f /tmp/query.hql  -o tmp/query_report.txt 2>> tmp/base_table_alert_check.log

elif [[ $OPT == "-ora" ]];then
VAL=`$SQL << EOD
spool tmp/query_reports.txt
alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
set echo off colsep ' ' pagesize 550 trimspool on linesize 200 feedback off timing off time off termout off headsep off heading off
COL TABLE_NAME FORMAT A45
COL MIN FORMAT A25
COL MAX FORMAT A25
COL MAX_INS FORMAT A25
COL Current_Time FORMAT A25
select '$TABLE_NAME' as TABLE_NAME, min(datetime) as MIN, max(datetime) as MAX, max(datetime_ins) as MAX_INS,sysdate as Current_Time from $TABLE_NAME;
quit;
EOD`

grep -v '^[[:space:]]*$' tmp/query_reports.txt | grep -iv "Session altered." | grep -iv "no rows selected" > tmp/query_report.txt 2>> tmp/base_table_alert_check.log
fi

TBN=`cat tmp/query_report.txt | awk '{print $1}' | awk -F. '{print $2}'`
MIN_D=`cat tmp/query_report.txt | awk '{print $2,$3}'`
MAX_D=`cat tmp/query_report.txt | awk '{print $4,$5}'`
MAX_INS=`cat tmp/query_report.txt | awk '{print $6,$7}' |sed 's/\..*$//'`
CTIME=`date '+%Y-%m-%d %H:%M:%S'`

if [[ ( "$MAX_D" == *"NULL"* ) || ( -z $MAX_D ) ]];then
MAX_D=NULL
MAX_INS=NULL
fi
if [[ ( "$MAX_INS" == *"NULL"* ) || ( -z $MAX_D ) ]];then
MAX_INS=NULL
fi
if [[ ( "$MIN_D" == *"NULL"* ) || ( -z $MIN_D ) ]];then
MIN_D=NULL
fi
if [[ ( "$MIN_D" == *"NULL"* ) || ( -z $MAX_D ) ]];then
MIN_D=NULL
fi
if [[ ( "$MAX_D" == *"NULL"* ) || ( -z $MAX_D ) ]];then
DELAY=NULL
fi
if [[ ( "$MAX_D" == *"NULL"* ) || ( -z $MAX_D ) ]];then
LAST_UPDATE=NULL
fi

if [[ ( "$MAX_D" != *"NULL"* ) && ( "$MAX_INS" != *"NULL"* ) ]];then
t1=$(date -d "$MAX_D" +%s)
t2=$(date -d "$MAX_INS" +%s)
((second=$t2-$t1))
((MINUTES=$second/60))
DELAY="${MINUTES}MM"

d1=$(date -d "$CTIME" +%s)
d2=$(date -d "$MAX_D" +%s)
((SEC=$d1-$d2))
((HOUR=$SEC/3600))
((MIN=$SEC/60%60))
((SECOND=$SEC%60))
((DAY=$HOUR/24))
((HOUR=$HOUR%24))
LAST_UPDATE="${DAY}DD:${HOUR}HH:${MIN}MM"
fi
SCHEMA=`echo $TABLE_NAME | awk -F. '{print $1}'`
#LIB_NAME=`grep -l -m1 $SCHEMA $DVX2DIR/*.dbl | head -1 | awk -F. '{print $1}' | awk -F/ '{print $NF}'`
LIB_NAME2=`$SQL << EOD
spool tmp/output.txt13
set LINESIZE 100 PAGESIZE 100 HEADING OFF
select LIBRARY_NAME from pmmconf_db.DA_TABLE_LIST where destination_table like '$TABLE_NAME';
exit;
EOD`
LIB_NAME=`grep -v '^[[:space:]]*$' tmp/output.txt13 | awk -F " " '{print $1}' | sort | uniq | head -1`
echo "$TBN|$MIN_D|$MAX_D|$MAX_INS|$CTIME|$DELAY|$LAST_UPDATE|$LIB_NAME" >> tmp/output.txt

done

if [[ ( -f tmp/output.txt ) && ( -s tmp/output.txt ) ]];then
echo "
========================================================================================================================================================================"
if [[ $OPT == "-impala" ]];then
echo "Table_Name|Min_DateTime_I|Max_DateTime_I|Max_DateTime_Ins|Current_DateTime|Delay|Last_Update|Library_Name" >  tmp/output2.txt
grep -v '^[[:space:]]*$' tmp/output.txt >> tmp/output2.txt
column -s "|" -t  tmp/output2.txt > tmp/output3.txt
echo "
----------------------------------------------------------------------------------------------------------------------------------------------------------------
`cat tmp/output3.txt | head -1`
----------------------------------------------------------------------------------------------------------------------------------------------------------------"
cat tmp/output3.txt | sed 1d

elif [[ $OPT == "-ora" ]];then
echo "Table_Name|Min_DateTime|Max_DateTime|Max_DateTime_Ins|Current_DateTime|Delay|Last_Update|Library_Name" >  tmp/output22.txt
grep -v '^[[:space:]]*$' tmp/output.txt >> tmp/output22.txt
column -s "|" -t  tmp/output22.txt > tmp/output33.txt
echo "
----------------------------------------------------------------------------------------------------------------------------------------------------------------
`cat tmp/output33.txt | head -1`
----------------------------------------------------------------------------------------------------------------------------------------------------------------"
cat tmp/output33.txt | sed 1d
fi
fi

if [[ ! -z $CMD1 ]];then
echo "
========================================================================================================================================================================

Error: Tables not found in Dbl file of library.

`cat -n tmp/ttt.txt`

Info: It may be wrong table name or it is not a base table.
"
fi
echo

if [[ -s tmp/base_table_alert_check.log ]];then
for TABLE_NAME2 in $TB_NAME
do
grep -iw "$TABLE_NAME2" tmp/base_table_alert_check.log > /dev/null
if [[ $? -ne 1 ]];then
echo "$TABLE_NAME2" > tmp/table.log
echo "Error : Unable to run query on tables below , check tmp/base_table_alert_check.log for more details.
"
cat -n tmp/table.log
echo
fi
done
fi
echo "========================================================================================================================================================================
"
if [[ $OPT == "-ora" ]];then
exit 1
fi

for TB_NAME2 in $TB_NAME
do
TBN=`echo $TB_NAME2 | awk -F. '{print $2}'`
VAL=`$SQL << EOD
spool tmp/tmk.txt
set echo off colsep ' ' pagesize 200 trimspool on linesize 500
COL Table_Name FORMAT A45
COL NEXT FORMAT A25
COL Current_Time FORMAT A25
select '$TBN' as Table_Name,TASK,STATE,NEXT,sysdate as Current_Time from config_db.n2_scheduler_task where info like '%$TBN%';
exit;
EOD`

grep -v '^[[:space:]]*$' tmp/tmk.txt | grep -iv "session altered" | grep -iv "no rows selected" > tmp/tmkk.txt 2>> tmp/base_table_alert_check.log
cat tmp/tmkk.txt

for TASK in `cat tmp/tmkk.txt | awk '{print $2}' | sed 1,2d`
do
VAL=`$SQL << EOD
spool tmp/tmk2.txt
alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
set echo off colsep ' ' pagesize 1000 trimspool on linesize 300
COL DEST FORMAT A15
COL SCHEDULER FORMAT A26
COL DISTRIBUTER FORMAT A26
COL WORKER FORMAT A26
COL WORKER_END FORMAT A26
COL STATE FORMAT A9
select * from config_db.n2_scheduler_audit where task = '${TASK}'  order by scheduler desc fetch first 5 rows only;
exit;
EOD`

grep -v '^[[:space:]]*$' tmp/tmk2.txt | grep -iv "session altered" | grep -iv "no rows selected" > tmp/tmk22.txt 2>> tmp/base_table_alert_check.log
grep "UpdateTaskState(${TASK}" $N2P_LOG_DIR/LoadHadoop* 2>/dev/null | awk '{print $1,$2,$(NF-1),$NF}' | awk -F/ '{print $NF}' | awk -F "UpdateTaskState" '{print $1,$2,$3}' | sed 's/:/|/' | sed 's/(/|/g' | sed 's/,/|/g' | sed 's/)//g'  | awk -F "|" '{print $2,"|",$1,"|",$3,"|",$4}' | sort -k1 -n | awk -F "|" '{print "$N2P_LOG_DIR/"$2,"|",$1,"|",$3,"|",$4}' | tail > tmp/task.log
sed 's/\/[[:blank:]]/\//g' tmp/task.log | grep -v '^[[:space:]]*$' > tmp/task2.log

echo "
 Log File Name|Date & Time|Task ID| Status
---------------------------------------------------------------------|-------------------------|-----------|-----------
" > tmp/pooq1.txt

cat tmp/task2.log >> tmp/pooq1.txt
column -t -s "|" tmp/pooq1.txt > tmp/pooq2.txt

echo "

Latest Tasks Status of \"$TBN\" in n2_scheduler_audit table :
----------------------------------------------------------------------------------------

`cat tmp/tmk22.txt`

Latets Tasks Status of \"$TBN\" in LoadHadoop Log :
----------------------------------------------------------------------------------------

`cat tmp/pooq2.txt`

====================================================

Current Date & Time : `date +"%Y-%m-%d %H:%M:%S"`

========================================================================================================================================================================
"
done
done

rm -rf tmp/*  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
