#!/bin/bash
###################################################################
# Teoco Support Script to Troubleshoot RDR Alerts                       #
# Need public key enabled ssh between nodes                             #
# ?2023 TEOCO. ALL RIGHTS RESERVED                                      #
# Customization Option
# Author : Rishabh Singh
###################################################################
## run this script like access_alert_check.ksh <Access Name or ID>   #####
## for example ./access_alert_check.ksh 1997  ############################
## ./access_alert_check.ksh Email_log_folder_R2L   #######################
###################################################################
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

Info : This script is used to troubleshoot rdr report alert of L2G/R2G access in samsung.

        Syntax  : $0 <Access ID or Name>
        Example : $0 1997  or $0 Email_log_folder_R2L

It Displays following information of given Access:

          1. Access ID, Name, Status, Connection Test Details.
          2. GD Name, Status, Host Name of GD.
          3. Library Instance Name, Library Type, Status and library Host of L2G/R2G access.
          4. Details of last 5 files recived from given access.
          5. Remote Server Details with Password
	  6. File Count of Local Dir of Access.

=================================================================================================
"
exit
fi
acc=$1
SQL="sqlplus -S psa/ttipass@$ORACLE_SID"

ACC_NUM=`$SQL << EOD
set echo off colsep ' ' pagesize 0 trimspool on headsep off linesize 100 heading off feedback off timing off time off termout off headsep off
select trim(ACCESS_NUM)  from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and (access_num like '$acc' or access_name like '$acc');
exit;
EOD`

acc="${ACC_NUM}"
#########################################################################
##### Condition: If Enterd Access ID or Name is Wrong ###################
if [[ -z "${acc}" ]]; then
    echo "
=======================================================================

ERROR: Access $1 Not Found. Try Again with different Access....

=======================================================================
"
exit
fi
######## Query to Get Important Details of Access #########################

VAL=`$SQL << EOD
spool /tmp/log.txt
SET PAGESIZE 500 LINESIZE 200 feedback off verify off
COL HOST_NAME FORMAT A40
COL PLUGIN_NAME FORMAT A35
select ACC_STATUS, ENABLE as GD_STATUS, HOST_NAME, PLUGIN_NAME from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and (access_num like '$acc' or access_name like '$acc');
exit;
EOD`

ACC_STATUS=`awk '{print $1}' /tmp/log.txt | tr -s '\n'| tail -1`
GD_STATUS=`awk '{print $2}' /tmp/log.txt| tr -s '\n' | tail -1`
if [ "${GD_STATUS}" == "1" ]
then
GD_STATE=Active
else
GD_STATE=Inactive
fi
HOST=`awk '{print $3}' /tmp/log.txt | tr -s '\n' | tail -1`
PLUGIN=`awk '{print $4}' /tmp/log.txt | tr -s '\n'| tail -1`
MY_HOST=`hostname`
	
VAL=`$SQL << EOD
spool /tmp/log2.txt
SET PAGESIZE 500 LINESIZE 200 feedback off verify off
COL ACCESS_NAME FORMAT A60
COL GD_NAME FORMAT A60
select ACCESS_NAME, GD_NAME from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and (access_num like '$acc' or access_name like '$acc');
exit;
EOD`

ACCESS_NAME=`awk '{print $1}' /tmp/log2.txt| tr -s '\n' | tail -1`
GD=`awk '{print $2}' /tmp/log2.txt | tr -s '\n'| tail -1`

plugin="FTCyclePlugin/LocalToGD"
plugin1="FTCyclePlugin/RemoteToGD"


if [[ ( $PLUGIN != $plugin ) && ( $PLUGIN != $plugin1 ) ]];then
echo "
================================================================

It is not a L2G access, scripts works for L2G Access only.

================================================================
"
exit 1
fi


if [[ "$HOST" != "$MY_HOST" ]];then
echo "
=============================================================================================================

GD $GD is running on $HOST, so run this script on $HOST for better output.

=============================================================================================================
"
exit 1
fi

if [[ ( $PLUGIN != $plugin ) && ( $PLUGIN != $plugin1 ) ]];then
echo "
================================================================

It is not a L2G access, scripts works for L2G Access only.

================================================================
"
exit 1
fi


if [[ ( "$ACC_STATUS" == "Active" ) && ( "$GD_STATE" == "Active" ) ]];then
echo "gd ${GD}
quit
" > /tmp/gg.o
gd_commander -gd < /tmp/gg.o > /tmp/gg.oo
RECNO=`grep ${GD}  /tmp/gg.oo | grep -v "^${GD}" | grep -wv "^${ACC_NUM}" | grep -w "${ACC_NUM}" | cut -d' ' -f1`
echo "gd ${GD}
${RECNO}|-2|conntest
quit
" > /tmp/gg.ooo
gd_commander -gd < /tmp/gg.ooo > /tmp/gg.oooo

echo "gd ${GD}
quit
" > /tmp/tmy.o

gd_commander -gd < /tmp/tmy.o > /tmp/tmy.oo
RECNO=`grep ${GD} /tmp/tmy.oo | grep -v "^${GD}" | grep -wv "^${ACC_NUM}" | grep -w "${ACC_NUM}" | cut -d' ' -f1`
echo "gd ${GD}
${RECNO}|-2|stataccessd
quit
" > /tmp/tmy.ooo

gd_commander -gd < /tmp/tmy.ooo > /tmp/tmy.oooo

ACC_TYPE=`cat /tmp/tmy.oooo | grep -i 'Acc_Type_Name' | sort | uniq | awk -F ":" '{print $2}'`
LOCAL_DIR=`cat /tmp/tmy.oooo | grep -i -m 1 '|LocalDir' | sort | uniq | awk -F ":" '{print $2}'`
PROTOCOLL=`cat /tmp/tmy.oooo | grep 'Protocol' | sort | uniq | awk -F ":" '{print $2}' | head -1`
LSF=`cat /tmp/tmy.oooo | grep -m 1 '|LookInSubfolders' | sort | uniq | awk -F ":" '{print $2}'`
MASKL=`cat /tmp/tmy.oooo | grep -m 1  '|Mask' | sort | uniq | awk -F ":" '{print $2}'`
SFFP=`cat /tmp/tmy.oooo | grep -m 1  '|SourceFileFinishPolicy' | sort | uniq | awk -F ":" '{print $2}'`
SFMASK=`cat /tmp/tmy.oooo | grep -m 1  '|SubfolderMask' | sort | uniq | awk -F ":" '{print $2}'`

DVX2DIR="/teoco/sa_root_med01/implementation/DVX2/config/conductor.xml"
ssh med@seamed01 << EOD > /tmp/lib_details.txt 2>/dev/null
grep -iw -B5 -A11 "Access $ACC_NUM" $DVX2DIR
exit
EOD

Conductor=`grep -iw NAME /tmp/lib_details.txt | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<NAME>*//' | sed 's/<.*//'| sort | uniq | head -1`
LibN=`grep -iw LIBRARY_TYPE /tmp/lib_details.txt | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<LIBRARY_TYPE>*//' | sed 's/<.*//' | sort | uniq`
HostN=`grep -iw  MACHINE  /tmp/lib_details.txt | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<MACHINE>*//' | sed 's/<.*//'`
Status=`grep -iw  ACTIVE  /tmp/lib_details.txt | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<ACTIVE>*//' | sed 's/<.*//' | sed 's/1/Active/g' | sed 's/0/Inactive/g'`

CMD="ps -ef | grep -i $Conductor"

if [[ $HostN != $MY_HOST ]];then
ssh -q med@$HostN << EOF > /tmp/tmp121.txt 2>/dev/null
$CMD
EOF
else
ps -ef | grep -i $Conductor > /tmp/tmp121.txt 2>/dev/null
fi

cat /tmp/tmp121.txt | grep -iv "bash" | grep -v grep | grep -i "$ConductorName" > /tmp/tmp22.txt
if [[ "$Status" == "Inactive" ]];then
Status2=Inactive
elif [[ ( "$Status" == "Active" ) && ( ! -s /tmp/tmp22.txt ) ]];then
Status2=Warning
elif [[ ( "$Status" == "Active" ) && ( -s /tmp/tmp22.txt ) ]];then
Status2=Active
else
Status2=$Status
fi


echo "
============================================================================================================================================

Access & GD Status :
      Access Status : ${ACC_STATUS}
      GD Status     : ${GD_STATE}

Access Connection Test Result :
         `tail -3 /tmp/gg.oooo | head -1`
         `tail -3 /tmp/gg.oooo | head -2 | tail -1`

============================================================================================================================================
"
else
echo "
============================================================================================================================================

Access & GD Status :
      Access Status : ${ACC_STATUS}
      GD Status     : ${GD_STATE}

Access Connection Test Result :
      Connection Test : Failed

Info : If Access or GD is inactive, the Access connection test will always fail.

============================================================================================================================================
"
fi

echo "Access Details Are Given Below :"
echo "----------------------------------

      Access Number            : $ACC_NUM
      Access Name              : $ACCESS_NAME
      GD Name                  : $GD
      Plugin                   : $PLUGIN
      Local Dir                : $LOCAL_DIR
      Mask                     : $MASKL
      LookIn Subfolders        : $LSF
      Subfolder Mask           : $SFMASK
      SourceFileFinishPolicy   : $SFFP
      Conductor Name           : ${Conductor}
      Library Name             : ${LibN}
      Machine                  : ${HostN}
      Status                   : ${Status2}"

echo "
============================================================================================================================================
"
###############################################################################

###############################################################################
####################  Need to change usr value according to project ###########
BASE_DIR=`env | grep ^BASE_DIR | awk -F= '{print $2}'`
PERSISTENCE_DIR=`env | grep ^PLUGIN_FT_PERSISTENCE_DIR | awk -F= '{print $2}' | awk -F/ '{print $4,$5,$6,$7,$8}' | sed 's/ /\//g'`
###############################################################################
echo "Details of Latest 5 Files in Persistence (Local) Dir: "
echo "----------------------------------------------------"

less ${BASE_DIR}/${PERSISTENCE_DIR}/acc${acc}/FileHistoryManager_Backup_acc${acc}.ftha | tail >/tmp/foo.txt 2>/dev/null

dosome=`cat /tmp/foo.txt | tail -1 | awk -F "|" '{print  $NF}'`
if [[ ( "$dosome" == *"Last Change Date"* ) ]];then
echo "
Info  : No file history found in persistence directory for this access.
Note  : This script only shows the file history of File Transfer Protocol accesses.

Below are the possible reasons for missing file history :

   1. Access history file does not exist in the persistence directory or has not been created.
   2. Access history file exists in persistence directory but there is no record available for any file in it.
   3. Since This Access has been Created Not a Singal Data has been Fetched by it.
   4. It is not a file transfer protocol (FTP/SFTP) access."
dosome=0
else
echo
cat /tmp/foo.txt | tail | tail -n 5
tdate=`date "+%Y-%m-%d %T"`
d1=$(date -d "$tdate" +%s)
d2=$(date -d "$dosome" +%s)
((SEC=$d1-$d2))

if (( $SEC<="59" )); then
SEC=$SEC
GAP="$SEC Seconds Ago"

elif (( $SEC>="60" & $SEC<="3599" ));then
((MIN=$SEC/60))
GAP="$MIN Minutes Ago"

elif (( $SEC>="3600" & $SEC<="86399" ));then
((HOUR=$SEC/3600))
((MIN=$SEC/60%60))
((SECOND=$SEC%60))

GAP="$HOUR Hours : $MIN Minutes : $SECOND Seconds Ago"

elif (( $SEC>="86400" & $SEC<="2629799" )) ;then
((HOUR=$SEC/3600))
((MIN=$SEC/60%60))
((SECOND=$SEC%60))
((DAY=$HOUR/24))
((HOUR=$HOUR%24))
GAP="$DAY Days : $HOUR Hours : $MIN Minutes Ago"

elif (( $SEC>="2629800" )) ;then
((HOUR=$SEC/3600))
((MIN=$SEC/60%60))
((SECOND=$SEC%60))
((DAY=$HOUR/24))
((MON=$DAY/31))
((DAY=$DAY%31))
((HOUR=$HOUR%24))
GAP="$MON Months : $DAY Days : $HOUR Hours : $MIN Minutes Ago"

fi
fi

echo "
============================================================================================================================================

Current Date & Time on Local Host : `date "+%Y-%m-%d %T"` ";echo

if [[ ( "$dosome" != *"Last Change Date"* ) ]];then
when="on $dosome"
echo Last file was received - $GAP $when
echo
fi
###################################################################
GD_RDR_DIR=`env | grep GD_RDR_DIR | awk -F= '{print $2}'`
LDIR=`echo $LOCAL_DIR | sed 's/$GD_RDR_DIR//g'`
LOCAL_DIR=$GD_RDR_DIR/$LDIR
###################################################################
echo "============================================================================================================================================

File Count for Access $ACC_NUM
---------------------------------------------------
"
find $LOCAL_DIR -type d -exec sh -c 'echo -n PATH :  "{} || File Count : "; ls -1 "{}" | egrep "$SFMASK" | wc -l' \;

echo "
============================================================================================================================================
"


rm -rf tmp/*  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
