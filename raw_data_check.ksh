#!/bin/bash
###################################################################
# Teoco Support Script to Troubleshoot RDR Alerts                       #
# Need public key enabled ssh between nodes                             #
# ?2023 TEOCO. ALL RIGHTS RESERVED                                      #
# Customization Option
# Author : Rishabh Singh
###################################################################
start1=$(date +%s)
if [ $# -eq 0 ];
then
echo "$0: Missing arguments
Info: Use -help for help. [syntax : $0 -help]"
exit 1
fi
mkdir -p tmp
rm -rf tmp/* > /dev/null
touch tmp/acc_id.txt > /dev/null
cp /dev/null tmp/acc_id.txt > /dev/null
green='\e[1;32m'
red='\e[1;31m'
reset='\033[0m'
###################################################################
if [ "$1" == "-help" ];then
echo -e "$green
================================================================================================================================================== $reset "
echo "
Info : This script is use to check access and library details of given element/file/enodeb name.

How to Use:
        Syntax  : $0 <element_Name>
        Example : $0 050096LNBTS

Note :  You can pass one arguments at once

Script shows following Information:
        1. Access ID, Name, Status, GD Name, Status, Host and Plugin Name that collects file of given element/file/enodeb name.
        2. Library, Instance, Status and Host Name that processes file of given element/file/enodeb name.

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
###################################################################
FILE_NAME=$1
SQL="sqlplus -S psa/ttipass@$ORACLE_SID"
DVX2DIR=$(env | grep DVX2_IMP_DIR | sed 's/.*=//')/config/conductor.xml
PERSISTENCE_DIR=`env | grep ^PLUGIN_FT_PERSISTENCE_DIR | awk -F= '{print $2}' | awk -F/ '{print $4,$5,$6,$7,$8}' | sed 's/ /\//g'`
PLUGIN_L2G="FTCyclePlugin/LocalToGD"
PLUGIN_R2G="FTCyclePlugin/RemoteToGD"
IFS=$'\n'
for EACH in `cat CUSTOM/SERVER.cfg |grep -iv mon | grep -iv j2ee | grep -iv web`
do
HOST=`echo $EACH | awk '{print $1}'`
BASE_DIR=`echo $EACH | awk '{print $2}'`
unset IFS
ssh -q -t ${HOST} 'cd  '$BASE_DIR';grep -rli "'$FILE_NAME'" '$PERSISTENCE_DIR'/acc*' >> tmp/acc_id.txt 2>/dev/null
done

grep -v '^[[:space:]]*$' tmp/acc_id.txt 2>/dev/null | grep -iv grep | grep -i "FileHistoryManager_Backup" | sed 's/acc//g' | cut -d'/' -f6 | sort | uniq > tmp/ACCESS 2>/dev/null

if [[ ( ! -f tmp/ACCESS ) || ( ! -s tmp/ACCESS ) ]];then
echo -e "$red
====================================================================================================================================================================================
$reset "
echo -e "${red}Info:${reset} No Access/File found for \"$FILE_NAME\""
echo -e "$red
====================================================================================================================================================================================
$reset "
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
elif [[ ( -f tmp/ACCESS ) && ( -s tmp/ACCESS ) ]];then
echo -e "$red
====================================================================================================================================================================================$reset "
echo -e "${red}
Info:${reset} Found below Access for ${green}\"$FILE_NAME\"${reset}
"
#for ACCESSD2 in `cat tmp/ACCESS`
#do
#echo -e "${red}Access :${reset} $ACCESSD2"
#done
awk 1 ORS=' | ' tmp/ACCESS | rev | cut -c 3- | rev | awk -v RS="|" '{printf $0 (NR%15?RS:"\n")}' | sed 's/^ *//g'
echo -e "$red
====================================================================================================================================================================================
$reset "
fi

for ACC in $(cat tmp/ACCESS | cut -d' ' -f1 )
do
ACC_NUM=`$SQL << EOD
set echo off colsep ' ' pagesize 0 trimspool on headsep off linesize 100 heading off feedback off timing off time off termout off headsep off
select trim(ACCESS_NUM)  from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and access_num like '$ACC';
exit;
EOD`

if [[ -z "${ACC_NUM}" ]]; then
echo -e "${red}Exception:${reset} Access $ACC Not Found in DB"
continue
elif [[ ! -z "${ACC_NUM}" ]]; then
VAL=`$SQL << EOD
spool tmp/log.txt
set echo off colsep ' ' pagesize 500 trimspool on linesize 200 heading off feedback off timing off time off termout off headsep off
COL HOST_NAME FORMAT A30
COL PLUGIN_NAME FORMAT A30
select ACCESS_NUM,ACC_STATUS,ENABLE as GD_STATUS, HOST_NAME, PLUGIN_NAME from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and access_num like '$ACC_NUM';
exit;
EOD`
grep -v '^[[:space:]]*$'  tmp/log.txt > tmp/log2.txt

VAL2=`$SQL << EOD
spool tmp/log.txt2
set echo off colsep ' ' pagesize 500 trimspool on linesize 200 heading off feedback off timing off time off termout off headsep off
COL GD_NAME FORMAT A55
COL ACCESS_NAME FORMAT A55
select ACCESS_NAME,GD_NAME from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and access_num like '$ACC_NUM';
exit;
EOD`
grep -v '^[[:space:]]*$'  tmp/log.txt2 > tmp/log2.txt2

ACC_NO=`cat tmp/log2.txt | awk '{print $1}'`
ACC_NAME=`cat tmp/log2.txt2 | awk '{print $1}'`
ACC_ST=`cat tmp/log2.txt | awk '{print $2}'`
GD=`cat tmp/log2.txt2 | awk '{print $2}'`
GD_ST=`cat tmp/log2.txt | awk '{print $3}'`
if [[ "${GD_ST}" == "1" ]];then
GD_ST=Active
elif [[ "${GD_ST}" == "0" ]];then
GD_ST=Inactive
fi
HOST=`cat tmp/log2.txt | awk '{print $4}'`
PLUGIN=`cat tmp/log2.txt | awk '{print $5}'`

for PLUGIN_NAME in $PLUGIN
do
if [[ ( "${PLUGIN_NAME}" == "${PLUGIN_L2G}" ) || ( "${PLUGIN_NAME}" == "${PLUGIN_R2G}" ) ]];then
LIB_NAME=`grep -iw -C9  $ACC_NO $DVX2DIR | grep NAME | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<NAME>*//' | sed 's/<.*//'| sort | uniq  | grep -v '^[[:space:]]*$'| head -1`
LIB_TYPE=`grep -iw -B5 -A15  $LIB_NAME $DVX2DIR  | grep TYPE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<TYPE>*//' | sed 's/<.*//' | sort | uniq | grep -v '^[[:space:]]*$'`
LIB_HOST=`grep -iw -B5 -A15 $LIB_NAME $DVX2DIR  | grep MACHINE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<MACHINE>*//' | sed 's/<.*//' | grep -v '^[[:space:]]*$'`
LIB_STATUS=`grep -iw -B5 -A15 $LIB_NAME $DVX2DIR | grep ACTIVE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<ACTIVE>*//' | sed 's/<.*//' | sed 's/1/Active/g' | sed 's/0/Inactive/g' | grep -v '^[[:space:]]*$'`
LIB_ID=`grep -iw -B5 -A15 $LIB_NAME $DVX2DIR | grep -w ID | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<ID>*//' | sed 's/<.*//' | sort | uniq | grep -v '^[[:space:]]*$'`
LIB_IN=`grep -iw -B5 -A15 $LIB_NAME $DVX2DIR | grep -w LIBRARY_INSTANCE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<LIBRARY_INSTANCE>*//' | sed 's/<.*//' | sort | uniq | grep -v '^[[:space:]]*$'`
LIB_IN2="${LIB_IN}_${LIB_ID}"
LIB_INS="conductor_${LIB_IN2}"

if [[ -z "$LIB_NAME"  ]]; then
LIB_NAME=NA
LIB_TYPE=NA
LIB_HOST=NA
LIB_STATUS=NA
LIB_INS=NA
fi
IFS=$'\n'
echo "$ACC_NO|$LIB_TYPE|$LIB_NAME|$LIB_INS|$LIB_STATUS|$LIB_HOST" >> tmp/libs.txt
unset IFS
fi
done

IFS=$'\n'
echo "$ACC_NO|$ACC_NAME|$ACC_ST|$GD|$GD_ST|$HOST|$PLUGIN" >> tmp/log3.txt
unset IFS
fi
done

if [[ ( -f tmp/ACCESS ) && ( -s tmp/ACCESS ) ]];then
echo -e "$green
====================================================================================================================================================================================$reset "
echo -e "$red
Access details that collects files of element/enodeb : $FILE_NAME
-------------------------------------------------------------------------
$reset"
echo "
Access ID|Access Name|Status|GD Name|Status|Host|Plugin
----------|------------------------------------|----------|----------------------------------|----------|---------------------------|---------------------------------
" > tmp/acc_header.txt
grep -v '^[[:space:]]*$' tmp/log3.txt >> tmp/acc_header.txt
grep -v '^[[:space:]]*$' tmp/acc_header.txt > tmp/acc_mainoutout.txt
column -s "|" -t tmp/acc_mainoutout.txt
echo -e "$green
====================================================================================================================================================================================
$reset "
fi

if [[ ( -f tmp/libs.txt ) && ( -s tmp/libs.txt ) ]];then
echo -e "${red}Library Details that Processes files of element/enodeb : $FILE_NAME
----------------------------------------------------------------------------
$reset"
echo "
Access ID|Library Type|Library Name |Library Instance|Status|Host
----------|-------------------------------------|-------------------------------|------------------------------------|----------|---------------------------
" > tmp/lib_header.txt
grep -v '^[[:space:]]*$' tmp/libs.txt >> tmp/lib_header.txt
grep -v '^[[:space:]]*$' tmp/lib_header.txt > tmp/lib_mainoutout.txt
column -s "|" -t tmp/lib_mainoutout.txt
echo -e "$green
====================================================================================================================================================================================
$reset "
elif [[ ( ! -f tmp/libs.txt ) || ( ! -s tmp/libs.txt ) ]];then
echo -e "${red}Error:${reset} No L2G/R2G Access found for \"$FILE_NAME\"."
echo -e "$green
====================================================================================================================================================================================
$reset "
fi

end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
