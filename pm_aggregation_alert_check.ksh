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
green='\e[1;32m'
red='\e[1;31m'
reset='\033[0m'
###################################################################
if [ "$1" == "-help" ];then
echo -e "$green
================================================================================================================================================== $reset "
echo "
Info : This script is use to troubleshoot PM Aggregation Hadoop and Oracle Alerts.

How to Use:
        Syntax  : $0 -Option <Table_Name>
        Example : $0 -impala HWE_VUGW.MON_ME_15M or $0 -ora HWE_VUGW.PADP_ME_15M

Note :  You can pass multiple arguments at once.
        Exaple  : $0 -impala HWI_VUGW.MON_ME_15M HWI_VUSN.GX_PER_ME_15M

Script shows following Informatios of table :
        1. Min, Max(I) and Max_Ins date & time of table.
        2. The time interval since the last time data was loaded into the table.
        3. The time interval of max(I) and max datetime_ins .
        4. Task id of table and latest tasks status from impala aggr log.
        5. If table is custom SQL table then it will store Custom SQL query in a file and show all tables name only.
        6. If table is not custom SQL Table then i will show flow of loading(Raw and Source table name).
        7. It checks file count of last 5 days of table of Custom SQL and Source and Raw table.

Note : Run this script on main mediation server.
"
echo -e "$green================================================================================================================================================== $reset
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

function check_loading() {
if [[ $OPT == "-impala" ]];then
PARTITION_ID=`echo "show partitions $TABLE_NAME;" | impala-shell -B --quiet 2>/dev/null | awk '{print $1,$3}' | awk ' $2 > 0 '|grep ^202 | sed -n '1p ; $p' | awk '{print "|"$1"|,"}' | sed "s/|/'/g" | paste -s | rev | cut -c 2- | rev`
#PARTITION_ID=`date --date= +%Y%m%d00`
echo "set request_pool=cognos;
select '$TABLE_NAME' as TABLE_NAME, min(datetime_i),max(datetime_i),max(datetime_ins),now() from "$TABLE_NAME" where partition_id in ($PARTITION_ID);"> tmp/query.hql
/bin/impala-shell --quiet -B -f tmp/query.hql  -o tmp/query_report.txt 2>> tmp/base_table_alert_check.log

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
if [[ ( "$MIN_D" == *"NULL"* ) || ( -z $MIN_D ) ]];then
MIN_D=NULL
fi
if [[ ( "$MAX_INS" == *"NULL"* ) || ( -z $MAX_D ) ]];then
MAX_INS=NULL
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
LIB_NAME2=`$SQL << EOD
spool tmp/output.txt13
set LINESIZE 100 PAGESIZE 100 HEADING OFF
select LIBRARY_NAME from pmmconf_db.DA_TABLE_LIST where destination_table like '$TABLE_NAME';
exit;
EOD`

LIB_NAME=`grep -v '^[[:space:]]*$' tmp/output.txt13 | awk -F " " '{print $1}' | sort | uniq | head -1`
echo "$TABLE_NAME|$MIN_D|$MAX_D|$MAX_INS|$CTIME|$DELAY|$LAST_UPDATE|$LIB_NAME" >> tmp/output.txt
}

if [[ $OPT == "-impala" ]];then
DB_TY=IMPALA
elif [[ $OPT == "-ora" ]];then
DB_TY=ORACLE
fi

for TABLE_NAME in $TB_NAME
do
TBS_NAME=`echo $TABLE_NAME | awk -F. '{print $2}'`

TB_EXIST=`$SQL << EOD
set echo off colsep ' ' trimspool on feedback off timing off time off termout off headsep off heading off
select TABLE_NAME from dba_tables where table_name like '$TBS_NAME';
quit;
EOD`

TB_TYPE=`$SQL << EOD
set echo off colsep ' ' trimspool on feedback off timing off time off termout off headsep off heading off
select mt_table_name_new,mt_aggr_from_tablename_new from pmmconf_db.pmm_rule_management where db_type = '$DB_TY' and mt_task_id in (select task from config_db.n2_scheduler_task where  suspended = 0) and (mt_table_name_new like '$TBS_NAME' or mt_aggr_from_tablename_new like '$TBS_NAME');
quit;
EOD`

if [[ ( ! -z $TB_EXIST ) && ( ! -z $TB_TYPE ) ]];then
check_loading
elif [[ ( -z $TB_EXIST ) && ( -z $TB_TYPE ) ]];then
echo $TABLE_NAME >> tmp/ttt.txt
TB_EXIST2=ERROR
elif [[ ( ! -z $TB_EXIST ) && ( -z $TB_TYPE ) ]];then
echo $TABLE_NAME >> tmp/ttt2.txt
TB_TYPE2=ERROR
fi
done

if [[ ! -z $TB_EXIST2 ]];then
echo -e " $red
========================================================================================================================================================================
$reset"
echo -e "${red}Exception: Tables not found. It is a wrong table name.
$reset "
cat -n tmp/ttt.txt
echo
fi
if [[ ( -z $TB_EXIST2 ) && ( ! -z $TB_TYPE2 ) ]];then
echo ""
fi
if [[ ( ! -z $TB_EXIST2 ) || ( ! -z $TB_TYPE2 ) ]];then
echo -e "${red}========================================================================================================================================================================
$reset"
fi
if [[ ! -z $TB_TYPE2 ]];then
echo -e "${red}Exception: It is not a aggregated Table, please run pm_base_collection_alert_check.ksh script for base tables.
$reset "
cat -n tmp/ttt2.txt
echo -e "$green
Info: This script is works with only aggregated tables. Use -help argument for more details.${reset}"
echo -e " $red
========================================================================================================================================================================
$reset"
fi

if [[ ( -f tmp/output.txt ) && ( -s tmp/output.txt ) ]];then
if [[ $OPT == "-impala" ]];then
echo "Table_Name|Min_DateTime_I|Max_DateTime_I|Max_DateTime_Ins|Current_DateTime|Delay|Last_Update|Library_Name" >  tmp/output2.txt
elif [[ $OPT == "-ora" ]];then
echo "Table_Name|Min_DateTime|Max_DateTime|Max_DateTime_Ins|Current_DateTime|Delay|Last_Update|Library_Name" >  tmp/output2.txt
fi
grep -v '^[[:space:]]*$' tmp/output.txt >> tmp/output2.txt
column -s "|" -t  tmp/output2.txt > tmp/output3.txt

echo -e "${red}
======================================================================================================================================================================== $reset"
if [[ $OPT == "-impala" ]];then
DB_TYPE=IMPALA
N2LOG_TYPE="TRAggrImpala"
N2LOG_TYPE2="TRAggrImpala"
echo "
----------------------------------------------------------------------------------------------------------------------------------------------------------------
`cat tmp/output3.txt | head -1`
----------------------------------------------------------------------------------------------------------------------------------------------------------------"
grep -v '^[[:space:]]*$' tmp/output3.txt | sed 1d
echo
elif [[ $OPT == "-ora" ]];then
DB_TYPE=ORACLE
N2LOG_TYPE="TRAggr-"
N2LOG_TYPE2="TRAggr"
echo "
----------------------------------------------------------------------------------------------------------------------------------------------------------------
`cat tmp/output3.txt | head -1`
----------------------------------------------------------------------------------------------------------------------------------------------------------------"
cat tmp/output3.txt | sed 1d
echo
fi
echo -e "$green========================================================================================================================================================================
$reset"
fi

if [[ -s tmp/base_table_alert_check.log ]];then
for TABLES in $TB_NAME
do
grep -iw "$TABLES" tmp/base_table_alert_check.log > /dev/null
if [[ $? -ne 1 ]];then
echo "$TABLES" >> tmp/table.log
fi
done
if [[ -s tmp/table.log ]];then
echo -e "${red}Error : Unable to run query on tables below , check tmp/base_table_alert_check.log for more details.
$reset"
cat -n tmp/table.log
echo -e "$green
========================================================================================================================================================================
$reset"
rm -rf tmp/table.log
fi
fi

rm -rf tmp/*.txt tmp/*hql
for TB_NAME2 in $TB_NAME
do
SCHEMA=`echo $TB_NAME2 | awk -F. '{print $1}'`
TBN=`echo $TB_NAME2 | awk -F. '{print $2}'`
VAL=`$SQL << EOD
spool tmp/tmk.txt
set echo off pagesize 1000 linesize 100
COL mt_table_name_new FORMAT A45
COL db_type FORMAT A9
COL CUSTOM_SQL FORMAT A12
select mt_table_name_new,mt_task_id,mt_rule_id,db_type,CASE WHEN IS_CUSTOM_SQL ='1' THEN 'YES' ELSE 'NO' END AS CUSTOM_SQL from PMMCONF_DB.PMM_RULE_MANAGEMENT where DB_TYPE like '$DB_TYPE' and MT_TABLE_NAME_NEW like '$TBN';
exit;
EOD`

grep -v '^[[:space:]]*$' tmp/tmk.txt | grep -iv "session altered" | grep -iv "no rows selected" > tmp/tmkk.txt 2>> tmp/base_table_alert_check.log

for TASK in `cat tmp/tmkk.txt | awk '{print $2}' | sed 1,2d`
do
VAL=`$SQL << EOD
spool /tmp/tmk2.txt
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
grep -v '^[[:space:]]*$' /tmp/tmk2.txt | grep -iv "session altered" | grep -iv "no rows selected" > /tmp/tmk22.txt 2>> tmp/base_table_alert_check.log
###################################
grep "UpdateTaskState(${TASK}" $N2P_LOG_DIR/$N2LOG_TYPE* 2>/dev/null | awk '{print $1,$2,$(NF-1),$NF}' | awk -F/ '{print $NF}' | awk -F "UpdateTaskState" '{print $1,$2,$3}' | sed 's/:/|/' | sed 's/(/|/g' | sed 's/,/|/g' | sed 's/)//g'  | awk -F "|" '{print $2,"|",$1,"|",$3,"|",$4}' | sort -k1 -n | awk -F "|" '{print "$N2P_LOG_DIR/"$2,"|",$1,"|",$3,"|",$4}' | tail > tmp/task.log 2>/dev/null
sed 's/\/[[:blank:]]/\//g' tmp/task.log | grep -v '^[[:space:]]*$' > tmp/task2.log 2>/dev/null

echo -e "${red}Details of $TB_NAME2
-----------------------------------------------
$reset"
echo -e " $red
 Log File Name|Date & Time|Task ID| Status
---------------------------------------------------------------------|-------------------------|-----------|-----------$reset " > tmp/pooq1.txt

cat tmp/task2.log >> tmp/pooq1.txt
column -t -s "|" tmp/pooq1.txt > tmp/pooq2.txt

echo "`cat tmp/tmkk.txt`
"
echo -e "$red
Latest Tasks Status of Task ID \"$TASK\" in n2_scheduler_audit table :
------------------------------------------------------------------------
$reset"
cat /tmp/tmk22.txt
echo
echo

echo -e "${red}Latets Tasks Status of Task ID \"$TASK\" in $N2LOG_TYPE2 Log :
--------------------------------------------------------------- $reset "

if [[ ( -f tmp/task2.log ) && ( -s tmp/task2.log ) ]];then
cat tmp/pooq2.txt
echo
else
echo "
Exception: No recent log file found for $TASK ID
"
fi

echo -e "$green====================================================
$reset "
echo -e "${red}Current Date & Time : `date +"%Y-%m-%d %H:%M:%S"` $reset"
echo -e "$green
========================================================================================================================================================================$reset"
######################################################################################
CUTM_SQL=`cat tmp/tmkk.txt | awk '{print $5}' | sed 1,2d`
if [[ "$CUTM_SQL" == "YES" ]];then
VAL=`$SQL << EOD
spool tmp/table_name2.txt
set linesize 200 pagesize 5000 set pause on
set long 2000000
select CUSTOM_SQL from PMMCONF_DB.PMM_RULE_MANAGEMENT where MT_TABLE_NAME_NEW like '$TBN' and DB_TYPE like '$DB_TYPE';
exit;
EOD`
grep -v '^[[:space:]]*$' tmp/table_name2.txt | grep -iv "session altered" | grep -iv "no rows selected" > tmp/custom_sql.query 2>> tmp/base_table_alert_check.log

grep -A1 -w ^FROM tmp/custom_sql.query | grep -oP '(?<=FROM )[^ ]*' > tmp/table_name.txt 2>/dev/null
if [[ ( -f tmp/table_name.txt ) && ( ! -s tmp/table_name.txt ) ]];then
grep -A1 -w ^FROM tmp/custom_sql.query | awk '{print $1}' | tail -1 > tmp/table_name.txt
fi
echo -e "$red
Tables of Custom Sql of \"$TB_NAME2\":
---------------------------------------------------------------------
$reset "
cat -n tmp/table_name.txt 2>/dev/null
echo
echo -e "${red}Info: Custom SQL Query is stored in tmp/custom_sql.query file for your reference. ${reset}"

echo -e "$green
========================================================================================================================================================================$reset
"
echo "Checking file count of last 5 days in tables of Custom SQL that have \"$SCHEMA\" schema............"
elif [[ "$CUTM_SQL" == "NO" ]];then
rm -rf tmp/flow.txt
FLOW=`$SQL << EOD
spool tmp/flow.txt
set echo off colsep ' ' pagesize 500 trimspool on linesize 100 feedback off timing off time off termout off heading off
select flow from pmmconf_db.DA_TABLE_LIST where destination_table like '$TB_NAME2';
exit;
EOD`

FLOW=`sed 's/\// >> /g' tmp/flow.txt | sed 's/>>//'`
grep -v '^[[:space:]]*$' tmp/flow.txt | sed 's/\//\n/g' | grep -iv "session altered" | grep -iv "no rows selected" >  tmp/table_name.txt 2>> tmp/base_table_alert_check.log

echo "
Flow of loading in \"$TB_NAME2\":
-------------------------------------------------------------------
$FLOW >> $TB_NAME2"

echo -e "$green
========================================================================================================================================================================$reset
"
echo "Checking file count of last 5 days in RAW & Source tables............."

fi
done

if [[ ( -f tmp/table_name.txt ) && ( -s tmp/table_name.txt ) ]];then
for TABLE_NAME4 in `cat tmp/table_name.txt | grep ^$SCHEMA`
do
if [[ $OPT == "-impala" ]];then
PARTITION_ID2=`date --date="5 days ago" +%Y%m%d00`
echo "set request_pool=cognos;
select '$TABLE_NAME4' as TABLE_NAME,trunc(datetime_i,'dd') as DATETIME_I, count(1) as FILE_COUNT, now() as now from $TABLE_NAME4 where partition_id >= '$PARTITION_ID2' group by trunc(datetime_i,'dd') order by trunc(datetime_i,'dd') desc;"> tmp/query.hql
/bin/impala-shell --quiet -B -f tmp/query.hql  -o tmp/query_report.txt --print_header '--output_delimiter=|' 2>> tmp/base_table_alert_check.log

elif [[ $OPT == "-ora" ]];then
VAL=`$SQL << EOD
spool tmp/query_report2.txt
alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
set echo off colsep ' ' pagesize 550 trimspool on linesize 200 feedback off timing off time off termout off headsep off
COL TABLE_NAME FORMAT A45
COL datetime FORMAT A24
COL now FORMAT A25
select '$TABLE_NAME4' as TABLE_NAME,trunc(datetime,'dd') as DateTime, count(1) as File_Count, sysdate as now from $TABLE_NAME4 where datetime > sysdate -5  group by trunc(datetime,'dd') order by trunc(datetime,'dd') desc;
quit;
EOD`
grep -v '^[[:space:]]*$' tmp/query_report2.txt | grep -iv "Session altered." | grep -iv "no rows selected" > tmp/query_report.txt 2>> tmp/base_table_alert_check.log

fi

if [[ ( -f tmp/query_report.txt ) && ( -s tmp/query_report.txt ) ]];then
grep -v '^[[:space:]]*$' tmp/query_report.txt > tmp/output.txt
column -s "|" -t  tmp/output.txt > tmp/output2.txt
echo
STATUS_TB=`cat tmp/output2.txt | sed 1d`
if [[ -z $STATUS_TB ]];then
echo -e "${red}Error:${reset} Unable to run query on $TABLE_NAME4."
fi
if [[ ! -z $STATUS_TB ]];then
if [[ $OPT == "-impala" ]];then
echo "------------------------------------------------------------------------------------------------------------------------
`cat tmp/output2.txt | head -1 | tr a-z A-Z`
------------------------------------------------------------------------------------------------------------------------"
cat tmp/output2.txt | sed 1d

elif [[ $OPT == "-ora" ]];then
echo "------------------------------------------------------------------------------------------------------------------------
`cat tmp/output2.txt | head -1`
------------------------------------------------------------------------------------------------------------------------"
cat tmp/output2.txt | sed 1,2d
fi
fi
fi
done

echo -e "$red
========================================================================================================================================================================$reset
"
fi
done

#rm -rf tmp/*txt  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
