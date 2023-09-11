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
######### To Dispaly help prompt of script ########################
if [ "$1" == "-help" ];then
echo "
==================================================================================================================

It Displays all relevant information with connection test details of given access.

How to Use:
        Syntax  : $0 <Access ID or Name>
        Example : $0 1201 or $0 R2L_USM_Houston3_PSMA2

Note :  You can use it for multiple access at once
        Exaple  : $0 1201 1205 USM_Houston3_PSMA2

Info :
       1. It also shows remote server details with dycrypted password of remote server of R2L access.
       2. If Access or GD is Inactive then it will start them.

Note : Run this script on main mediation server.

==================================================================================================================
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
########################################################################
SQL="sqlplus -S psa/ttipass@$ORACLE_SID"
DATE=`date '+%Y-%m-%d %R'`
DVX2DIR=$(env | grep DVX2_IMP_DIR | sed 's/.*=//')/config/conductor.xml
A=$@

for AC in `echo $A`
do
ACC_NUM=`$SQL << EOD
set echo off colsep ' ' pagesize 0 trimspool on headsep off linesize 100 heading off feedback off timing off time off termout off headsep off
select trim(ACCESS_NUM)  from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and (access_num like '$AC' or access_name like '$AC');
exit;
EOD`

acc="${ACC_NUM}"
#########################################################################
##### Condition: If Enterd Access ID or Name is Wrong ###################

if [[ -z "${acc}" ]]; then
echo "
===============================================================================================

Exception: ${AC} Access Not Found. Please Enter Correct Access ID or Name....

===============================================================================================
"
continue
fi
######## Query to Get Important Details of Access #########################
function access_status() {
VAR=`$SQL << EOD
spool /tmp/log.txt
SET PAGESIZE 500 LINESIZE 200 feedback off verify off
COL HOST_NAME FORMAT A40
COL PLUGIN_NAME FORMAT A35
select ACCESS_NUM, ACC_STATUS, ENABLE as GD_STATUS, HOST_NAME, PLUGIN_NAME from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and (access_num like '$acc' or access_name like '$acc');
exit;
EOD`

ACC_STATUS=`awk '{print $1}' /tmp/log.txt | tr -s '\n'| tail -1`
ACC_STATUS=`awk '{print $2}' /tmp/log.txt | tr -s '\n'| tail -1`
GD_STATUS=`awk '{print $3}' /tmp/log.txt| tr -s '\n' | tail -1`
if [ "${GD_STATUS}" == "1" ]
then
GD_STATE=Active
else
GD_STATE=Inactive
fi
HOST=`awk '{print $4}' /tmp/log.txt | tr -s '\n' | tail -1`
PLUGIN=`awk '{print $5}' /tmp/log.txt | tr -s '\n'| tail -1`
}
access_status
VAR=`$SQL << EOD
spool /tmp/log2.txt
SET PAGESIZE 500 LINESIZE 200 feedback off verify off
COL ACCESS_NAME FORMAT A60
COL GD_NAME FORMAT A60
select ACCESS_NAME, GD_NAME from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and (access_num like '$acc' or access_name like '$acc');
exit;
EOD`

ACCESS_NAME=`awk '{print $1}' /tmp/log2.txt| tr -s '\n' | tail -1`
GD=`awk '{print $2}' /tmp/log2.txt | tr -s '\n'| tail -1`


if [[ ( ! -z $ACC_NUM ) || ( ! -z $GD ) ]];then
function access_details() {
echo "Access ID                       : ${ACC_NUM}
Access Name                     : ${ACCESS_NAME}
Access Status                   : ${ACC_STATUS}
GD Name                         : ${GD}
GD Status                       : ${GD_STATE}
GD Host 			: ${HOST}						
Plugin                          : ${PLUGIN}"
}
fi

if [[ ( "$ACC_STATUS" == "Active" ) && ( "$GD_STATE" == "Active" ) ]];then
echo "gd ${GD}
quit
" > /tmp/gg.o

gd_commander -gd < /tmp/gg.o > /tmp/gg.oo
RECNO=`grep ${GD} /tmp/gg.oo | grep -v "^${GD}" | grep -wv "^${ACC_NUM}" | grep -w "${ACC_NUM}" | cut -d' ' -f1`
echo "gd ${GD}
${RECNO}|-2|conntest
quit
" > /tmp/gg.ooo

gd_commander -gd < /tmp/gg.ooo > /tmp/gg.oooo

function conn_test() {
echo "Access Connection Test Result  of Access $ACC_NUM:

   `tail -3 /tmp/gg.oooo | head -1`
   `tail -3 /tmp/gg.oooo | head -2 | tail -1`"
}
################################################
echo "gd ${GD}
quit
" > /tmp/gg1.o

gd_commander -gd < /tmp/gg1.o > /tmp/gg1.oo
RECNO=`grep ${GD} /tmp/gg1.oo | grep -v "^${GD}" | grep -wv "^${ACC_NUM}" | grep -w "${ACC_NUM}" | cut -d' ' -f1`
echo "gd ${GD}
${RECNO}|-2|stataccessd
quit
" > /tmp/gg1.ooo

gd_commander -gd < /tmp/gg1.ooo > /tmp/gg1.oooo

Host=$(cat /tmp/gg1.oooo | grep -i '|RemoteHost' | sort | uniq | cut -c 33- | head -1)
if [[ -z $Host ]];then
Host=NULL
fi
User=$(cat /tmp/gg1.oooo | grep -i '|RemoteUserName' | sort | uniq | cut -c 33- | head -1)
if [[ -z $User ]];then
User=NULL
fi
Pass=$(cat /tmp/gg1.oooo | grep -i '|RemotePassword' | sort | uniq | cut -c 33- | head -1)
if [[ -z $Pass ]];then
Pass=NULL
fi
Port=$(cat /tmp/gg1.oooo | grep -i '|RemotePort' | sort | uniq | cut -c 33- | head -1)
if [[ -z $Port ]];then
Port=NULL
fi
Dir2=$(cat /tmp/gg1.oooo | grep -i '|RemoteDir' | sort | uniq | cut -c 33- | head -1)
if [[ -z $Dir2 ]];then
Dir2=NULL
fi
LD=$(cat /tmp/gg1.oooo | grep -i '|LocalDir' | sort | uniq | cut -c 33- | head -1)
if [[ -z $LD ]];then
LD=NULL
fi
CT=$(cat /tmp/gg1.oooo | grep -i '^Creation_Time' | sort | uniq | cut -c 33- | head -1)
if [[ -z $CT ]];then
CT=NULL
fi
ATN=$(cat /tmp/gg1.oooo | grep -i '^Acc_Type_Name' | sort | uniq | cut -c 33- | head -1)
if [[ -z $ATN ]];then
ATN=NULL
fi
CF=$(cat /tmp/gg1.oooo | grep -i '^Connections_Failed' | sort | uniq | cut -c 33- | head -1)
if [[ -z $CF ]];then
CF=NULL
fi
CS=$(cat /tmp/gg1.oooo | grep -i '^Connections_Succeded' | sort | uniq | cut -c 33- | head -1)
if [[ -z $CS ]];then
CS=NULL
fi
CT2=$(cat /tmp/gg1.oooo | grep -i '^Connections_Total' | sort | uniq | cut -c 33- | head -1)
if [[ -z $CT2 ]];then
CT2=NULL
fi
TN=$(cat /tmp/gg1.oooo | grep -i '^Total_Notifications' | sort | uniq | cut -c 33- | head -1)
if [[ -z $TN ]];then
TN=NULL
fi
LCT=$(cat /tmp/gg1.oooo | grep -i '^Last_Connect_Time' | sort | uniq | cut -c 33- | head -1)
if [[ -z $LCT ]];then
LCT=NULL
fi
LNT=$(cat /tmp/gg1.oooo | grep -i '^Last_Notification_Time' | sort | uniq | cut -c 33- | head -1)
if [[ -z $LNT ]];then
LNT=NULL
fi
LPT=$(cat /tmp/gg1.oooo | grep -i '^Last_Pulse_Time' | sort | uniq | cut -c 33- | head -1)
if [[ -z $LPT ]];then
LPT=NULL
fi
SDir=`cat /tmp/gg1.oooo | grep -i '|SourceDir'  | sort | uniq | awk -F ":" '{print $2}'`
if [[ -z $SDir ]];then
SDir=NULL
fi

function access_runtime_details() {
echo "Access Type                     : ${ATN}
Access Creation Time            : ${CT}
Last Connect Time               : ${LCT}
Last Pulse Time                 : ${LPT}
Last Notification Time          : ${LNT}
Current Time			: ${DATE}
Total Notification              : ${TN}
Connection Failed               : ${CF}
Connection Succeded             : ${CS}
Connection Total                : ${CT2}"
}


PLUG1="FTCyclePlugin/LocalToGD"
PLUG2="FTCyclePlugin/RemoteToGD"

if [[ ( "${PLUGIN}" == "${PLUG1}" ) || ( "${PLUGIN}" == "${PLUG2}" ) ]];then
Conductor=`grep -iw -C5 $ACC_NUM $DVX2DIR | grep NAME | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<NAME>*//' | sed 's/<.*//'| sort | uniq | head -1`
LibN=`grep -iw -C5 $Conductor $DVX2DIR  | grep TYPE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<TYPE>*//' | sed 's/<.*//' | sort | uniq `
HostN=`grep -iw -C5 $Conductor $DVX2DIR  | grep MACHINE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<MACHINE>*//' | sed 's/<.*//'`
Status=`grep -iw -C5 $Conductor $DVX2DIR | grep ACTIVE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<ACTIVE>*//' | sed 's/<.*//' | sed 's/1/Active/g' | sed 's/0/Inactive/g'`

if [[ ! -z "$LibN"  ]]; then
function conductor_details() {
echo "Local Dir                       : ${LD}
Conductor Name                  : ${Conductor}
Library Name                    : ${LibN}
Machine                         : ${HostN}
Library Status                  : ${Status}"
}
fi
fi

PLUG3="FTCyclePlugin/RemoteToLocal"
PLUG4="FTCycleExtPlugin/RemoteToLocal"

if [[ "${PLUGIN}" == "${PLUG4}" ]];then
        Dir2=$SDir
        else
        Dir2=$Dir2
        fi

if [[ ( "${PLUGIN}" == "${PLUG3}" ) || ( "${PLUGIN}" == "${PLUG4}" ) ]];then
function remote_details() {
echo "Remote Host                     : ${Host}
Remote Port                     : ${Port}
Remote User                     : ${User}
Remote Password                 : ${Pass}
Remote Dir                      : ${Dir2}"
}

fi

fi

if [[ ( "$ACC_STATUS" == "Inactive" ) || ( "${GD_STATE}" == "Inactive" ) ]];then
function conn_test() {
echo "Access Connection Test Result of Access $ACC_NUM : FAILED

Note : If Access or GD status is inactive then Access Connection Test Will Be Fail.
       And if it is R2L access then it will also not show the details of the remote server."
}
fi

echo "
===============================================================================================
"
if [[ ! -z $ACC_NUM ]];then
access_details
fi

if [[ ( "${PLUGIN}" == "${PLUG1}" ) || ( "${PLUGIN}" == "${PLUG2}" ) ]];then
if [[ ! -z "$LibN"  ]]; then
conductor_details
fi
fi

if [[ ( "$ACC_STATUS" == "Active" ) && ( "$GD_STATE" == "Active" ) ]];then
access_runtime_details
fi

if [[ ( "${PLUGIN}" == "${PLUG3}" ) || ( "${PLUGIN}" == "${PLUG4}" ) ]];then
if [[ ( "$ACC_STATUS" == "Active" ) && ( "$GD_STATE" == "Active" )]];then
remote_details
fi
fi
echo "
===============================================================================================
"
conn_test
echo "
===============================================================================================
"
SQL="sqlplus -S psa/ttipass@$ORACLE_SID"

for AC_STATUS in $ACC_STATUS
do
if [[ "$AC_STATUS" == "Inactive" ]];then
echo -n "Access $ACC_NUM is Inactive, Do You Want to start it (y/n) : "
read opt3
if [[ ( "$opt3" != "n" ) && ( "$opt3" != "y" ) ]];then
echo "
Wrong Input. Skipping.....

===============================================================================================
"
continue
elif [[ "$opt3" == "n" ]];then
echo "
Skipping.....

===============================================================================================
"
continue
elif [[ "$opt3" == "y" ]]; then
VAR=`$SQL << EOD
spool /tmp/log.txt
update comm_db.med_access set acc_status = 'Active'  where acc_status = 'Inactive' and access_num in ( select e.access_num from comm_db.med_access e, comm_db.med_subnet f,comm_db.med_generic_driver g where e.subnet_num = f.subnet_num and f.implement_gd = g.gd_name and access_num like '$ACC_NUM');
commit;
exit;
EOD`
sleep 15
access_status
if [[ ${GD_STATE} == Active ]];then
echo "
===============================================================================================

Access $ACC_NUM is started sucessfully.........

Access Status                   : ${ACC_STATUS}
GD Status                       : ${GD_STATE}"
fi
fi
echo "
===============================================================================================
"
fi
done

for GD_STATUS in $GD_STATE
do
if [[ "$GD_STATUS" == "Inactive" ]];then
echo -n "GD $GD is Inactive, Do You Want to start it (y/n) : "
read opt3
if [[ ( "$opt3" != "n" ) && ( "$opt3" != "y" ) ]];then
echo "
Wrong Input. Skipping.....

===============================================================================================
"
continue
elif [[ "$opt3" == "n" ]];then
echo "
Skipping.....

===============================================================================================
"
continue
elif [[ "$opt3" == "y" ]]; then
VAL=`$SQL << EOD
spool /tmp/log.txt
update COMM_DB.MED_GENERIC_DRIVER set ENABLE = '1'  where ENABLE = '0' and gd_name in (select c.gd_name from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B ,COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and access_num like '$ACC_NUM');
commit;
exit;
EOD`
sleep 15
access_status
if [[ ${GD_STATE} == Active ]];then
echo "
===============================================================================================

GD $GD is restarted sucessfully.........

Access Status                   : ${ACC_STATUS}
GD Status                       : ${GD_STATE}"
fi
fi
echo "
===============================================================================================
"
fi
done
done

rm -rf tmp/*  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
