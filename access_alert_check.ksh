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
=====================================================================================================================================================

Info : This script is used to troubleshoot RDR/AccessSilence alert.

        Syntax  : $0 <Access ID or Name>
        Example : $0 1997  or $0 Email_log_folder_R2L

It Displays following information of given Access:

          1. Access ID, Name, Status, Connection Test Details.
          2. GD Name, Status, Host Name of GD.
          3. Library Instance Name, Library Type, Status and library Host of L2G/R2G access.
          4. Details of last 10 files recived from given access.
          5. Remote Server Details with Password.
          6. It checks whether remote server is reachable or not.
              6.1. If the remote server is unreachable it will not connect to that server.             
              6.2. If remote server is reachable then it checks if ssh connection is ok or not.
              6.3. If ssh connection is ok then it will try to connect remote server via SSH Protocol.
              6.4. If ssh connection is not ok then it will try to  connect remote server via SFTP Protocol.
          7. It connects remote server and check relevant files as well.
          8. If there is more than one remote IP/HOST with one access then it will connect to those servers also and check the files.
          7. If it's unable to connect local or remote server then it's show error.

Plugins Support:
          1. FTCyclePlugin/LocalToGD       
          2. FTCycleExtPlugin/RemoteToLocal
          3. FTCyclePlugin/RemoteToRemote  
          4. FTCyclePlugin/LocalToRemote   
          5. FTCyclePlugin/RemoteToLocal   
          6. FTCyclePlugin/LocalToLocal  

Note : Run this script on main mediation server.

=====================================================================================================================================================
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
acc=$1
SQL="sqlplus -S psa/ttipass@$ORACLE_SID"
DVX2DIR=$(env | grep DVX2_IMP_DIR | sed 's/.*=//')/config/conductor.xml

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

Exception: Access $1 Not Found. Try Again with different Access....

=======================================================================
"
exit
fi
#########################################################################
PLUGIN_L2G="FTCyclePlugin/LocalToGD"
PLUGIN_R2G="FTCyclePlugin/RemoteToGD"
PLUGIN_R2L="FTCyclePlugin/RemoteToLocal"
PLUGIN_EXTR2L="FTCycleExtPlugin/RemoteToLocal"
PLUGIN_L2R="FTCyclePlugin/LocalToRemote"
PLUGIN_R2R="FTCyclePlugin/RemoteToRemote"
PLUGIN_L2L="FTCyclePlugin/LocalToLocal"
######## Query to Get Important Details of Access #########################

VAL=`$SQL << EOD
spool tmp/log.txt
SET PAGESIZE 500 LINESIZE 200 feedback off verify off
COL HOST_NAME FORMAT A40
COL PLUGIN_NAME FORMAT A35
select ACC_STATUS, ENABLE as GD_STATUS, HOST_NAME, PLUGIN_NAME from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and (access_num like '$acc' or access_name like '$acc');
exit;
EOD`

ACC_STATUS=`awk '{print $1}' tmp/log.txt | tr -s '\n'| tail -1`
GD_STATUS=`awk '{print $2}' tmp/log.txt| tr -s '\n' | tail -1`
if [ "${GD_STATUS}" == "1" ]
then
GD_STATE=Active
else
GD_STATE=Inactive
fi
HOST=`awk '{print $3}' tmp/log.txt | tr -s '\n' | tail -1`
PLUGIN=`awk '{print $4}' tmp/log.txt | tr -s '\n'| tail -1`

VAL=`$SQL << EOD
spool tmp/log2.txt
SET PAGESIZE 500 LINESIZE 200 feedback off verify off
COL ACCESS_NAME FORMAT A60
COL GD_NAME FORMAT A60
select ACCESS_NAME, GD_NAME from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and (access_num like '$acc' or access_name like '$acc');
exit;
EOD`

ACCESS_NAME=`awk '{print $1}' tmp/log2.txt| tr -s '\n' | tail -1`
GD=`awk '{print $2}' tmp/log2.txt | tr -s '\n'| tail -1`

if [[ ( "$ACC_STATUS" == "Active" ) && ( "$GD_STATE" == "Active" ) ]]
then
echo "gd ${GD}
quit
" > /tmp/gg.o

gd_commander -gd < /tmp/gg.o > /tmp/gg.oo
RECNO=`grep ${GD} /tmp/gg.oo | grep -v "^${GD}" | grep -vw "^${ACC_NUM}" | grep -w "${ACC_NUM}" | cut -d' ' -f1`
echo "gd ${GD}
${RECNO}|-2|conntest
quit
" > /tmp/gg.ooo

gd_commander -gd < /tmp/gg.ooo > /tmp/gg.oooo  2>/dev/null

echo "gd ${GD}
quit
" > /tmp/gg9.o

gd_commander -gd < /tmp/gg9.o > /tmp/gg9.oo
RECNO=`grep "${GD}" /tmp/gg9.oo | grep -v "^${GD}" | grep -wv "^${ACC_NUM}" | grep -w "${ACC_NUM}" | cut -d' ' -f1`
echo "gd ${GD}
${RECNO}|-2|stataccessd
quit
" > /tmp/gg9.ooo

gd_commander -gd < /tmp/gg9.ooo > /tmp/gg9.oooo 2>/dev/null

if [[ ( -f /tmp/gg9.oooo ) && ( -s /tmp/gg9.oooo ) ]];then
ACC_TYPE=`cat /tmp/gg9.oooo | grep -i '^Acc_Type_Name' | sort | uniq | awk -F ":" '{print $2}'`
LOCAL_DIR=`cat /tmp/gg9.oooo | grep -i '|LocalDir' | sort | uniq | awk -F ":" '{print $2}'`
DESTINATION_DIR=`cat /tmp/gg9.oooo | grep -i '|DestinationDir' | sort | uniq | awk -F ":" '{print $2}'`
PROTOCOLL=`cat /tmp/gg9.oooo | grep '^Protocol' | sort | uniq | awk -F ":" '{print $2}' | head -1`
ADMask=`cat /tmp/gg9.oooo | grep -m 1  '|AdvancedMask' | sort | uniq | awk -F ":" '{print $2}'`
MASK=`cat /tmp/gg9.oooo | grep '|Mask' | sort | uniq | awk -F ":" '{print $2}'`
LSF=`cat /tmp/gg9.oooo | grep -m 1 '|LookInSubfolders' | sort | uniq | awk -F ":" '{print $2}'`
SFMASK=`cat /tmp/gg9.oooo | grep -m 1  '|SubfolderMask' | sort | uniq | awk -F ":" '{print $2}'`
SFFP=`cat /tmp/gg9.oooo | grep -m 1  '|SourceFileFinishPolicy' | sort | uniq | awk -F ":" '{print $2}'`
CF=`cat /tmp/gg9.oooo | grep -m 1  '^Connections_Failed' | sort | uniq | awk -F ":" '{print $2}'`
CSS=`cat /tmp/gg9.oooo | grep -m 1  '^Connections_Succeded' | sort | uniq | awk -F ":" '{print $2}'`
CTT=`cat /tmp/gg9.oooo | grep -m 1  '^Connections_Total' | sort | uniq | awk -F ":" '{print $2}'`
LPT=`cat /tmp/gg9.oooo | grep -m 1 '^Last_Pulse_Time' | sort | uniq |  sed 's/:/|/' |  awk -F "|" '{print $2}'`
LCT=`cat /tmp/gg9.oooo | grep -m 1  '^Last_Connect_Time' | sort | uniq |  sed 's/:/|/' |  awk -F "|" '{print $2}'`
LDT=`cat /tmp/gg9.oooo | grep -m 1  '^Last_Disconnect_Time' | sort | uniq |  sed 's/:/|/' |  awk -F "|" '{print $2}'`
LNT=`cat /tmp/gg9.oooo | grep -m 1  '^Last_Notification_Time' | sort | uniq |  sed 's/:/|/' |  awk -F "|" '{print $2}'`
LRT=`cat /tmp/gg9.oooo | grep -m 1  '^Last_Receive_Time' | sort | uniq |  sed 's/:/|/' |  awk -F "|" '{print $2}'`

if [[ ( $PLUGIN == $PLUGIN_L2L ) || ( $PLUGIN == $PLUGIN_R2R ) ]];then
SDir=`cat /tmp/gg9.oooo | grep -m 1  '|SourceDir'  | sort | uniq | awk -F ":" '{print $2}'`
fi

if [[ $PLUGIN == $PLUGIN_R2R ]];then
DES_HOST=`cat /tmp/gg9.oooo | grep -m 1  '|DestinationHost'  | sort | uniq | awk -F ":" '{print $2}'`
DES_PORT=`cat /tmp/gg9.oooo | grep -m 1  '|DestinationPort'  | sort | uniq | awk -F ":" '{print $2}'`
DES_USER=`cat /tmp/gg9.oooo | grep -m 1  '|DestinationUserName'  | sort | uniq | awk -F ":" '{print $2}'`
DES_PASS=`cat /tmp/gg9.oooo | grep -m 1  '|DestinationPassword' | sort | uniq | awk -F ":" '{print $2}'`
SOU_HOST=`cat /tmp/gg9.oooo | grep -m 1  '|SourceHost'  | sort | uniq | awk -F ":" '{print $2}'`
SOU_PORT=`cat /tmp/gg9.oooo | grep -m 1  '|SourcePort'  | sort | uniq | awk -F ":" '{print $2}'`
SOU_USER=`cat /tmp/gg9.oooo | grep -m 1  '|SourceUserName'  | sort | uniq | awk -F ":" '{print $2}'`
SOU_PASS=`cat /tmp/gg9.oooo | grep -m 1  '|SourcePassword' | sort | uniq | awk -F ":" '{print $2}'`
fi

if [[ "${PLUGIN}" == "${PLUGIN_R2G}" ]] || [[ "${PLUGIN}" == "${PLUGIN_EXTR2L}" ]] || [[ "${PLUGIN}" == "${PLUGIN_R2L}" ]] || [[ "${PLUGIN}" == "${PLUGIN_L2R}" ]] || [[ "${PLUGIN}" == "${PLUGIN_R2R}" ]];then
RHost=`cat /tmp/gg9.oooo | grep -m 1  '|RemoteHost' | sort | uniq | awk -F ":" '{print $2}'`
RUser=`cat /tmp/gg9.oooo | grep -m 1  '|RemoteUserName' | sort | uniq | awk -F ":" '{print $2}'`
RPass=`cat /tmp/gg9.oooo | grep -m 1  '|RemotePassword' | sort | uniq | awk -F ":" '{print $2}'`
RPort=`cat /tmp/gg9.oooo | grep -m 1  '|RemotePort' | sort | uniq | awk -F ":" '{print $2}'`
RDir=`cat /tmp/gg9.oooo | grep -m 1  '|RemoteDir' | sort | uniq | awk -F ":" '{print $2}'`
SDir=`cat /tmp/gg9.oooo | grep -m 1  '|SourceDir'  | sort | uniq | awk -F ":" '{print $2}'`
REXP=`cat /tmp/gg9.oooo | grep -m 1  '|Regexp' | sort | uniq | awk -F ":" '{print $2}'`
Plugin_Name=`cat /tmp/gg9.oooo |  grep -m 1  '^Plugin_Name' | sort | uniq | awk -F ":" '{print $2}'`
fi
fi

if [[ -z $MASK ]];then
MASK2=NULL
else 
MASK2=$MASK
fi

if [[ -z $SFMASK ]];then
SFMASK2=NULL
else
SFMASK2=$SFMASK
fi

if [[ -z $ADMask ]];then
ADMask2=NULL
else
ADMask2=$ADMask
	fi

if [[ -z $REXP ]];then
	REXP2=NULL
else
REXP2=$REXP
	fi

if [[ -z $LSF ]];then
LSF=NULL
fi

if [[ $LSF == 0 ]];then
LSF=No
elif [[ $LSF == 1 ]];then
LSF=Yes
fi

function access_paramters() {
echo "      Advance Mask             : $ADMask2
      Mask                     : $MASK2
      LookIn Subfolders        : $LSF
      Subfolder Mask           : $SFMASK2"
}
function access_paramters2() {
echo "      SourceFileFinishPolicy   : $SFFP
      Last Pulse Time          : $LPT
      Last Connect Time        : $LCT
      Last Notification Time   : $LNT"
}

echo "
=====================================================================================================================================

Access & GD Status :
      Access Status : ${ACC_STATUS}
      GD Status     : ${GD_STATE}

Access Connection Test Result :
         `tail -3 /tmp/gg.oooo | head -1`
         `tail -3 /tmp/gg.oooo | head -2 | tail -1`

=====================================================================================================================================
"
else
echo "
=====================================================================================================================================

Access & GD Status :
      Access Status : ${ACC_STATUS}
      GD Status     : ${GD_STATE}

Access Connection Test Result :
      Connection Test : Failed

Info : 
   1. If Access or GD is inactive then Access connection test will always fail.
   2. And if it's R2L access then it will not connect to remote server.

=====================================================================================================================================
"
fi

echo "Access Details Are Given Below :"
echo "----------------------------------

      Access Number            : $ACC_NUM
      Access Name              : $ACCESS_NAME
      Access Status            : $ACC_STATUS
      GD Name                  : $GD
      GD Status                : $GD_STATE
      Host                     : $HOST
      Plugin                   : $PLUGIN"
if [[ ( "$ACC_STATUS" == "Active" ) && ( "$GD_STATE" == "Active" ) ]];then
echo "      Access Type              : $ACC_TYPE
      Protocol                 : $PROTOCOLL"
if [[ ! -z $LOCAL_DIR ]];then
echo "      Local Dir                : $LOCAL_DIR"
fi
if [[ ! -z $DESTINATION_DIR ]];then
echo "      Destination Dir          : $DESTINATION_DIR"
fi
if [[ "${PLUGIN}" == "${PLUGIN_L2G}" ]] || [[ "${PLUGIN}" == "${PLUGIN_L2R}" ]];then
access_paramters
fi
access_paramters2
fi
echo "
=====================================================================================================================================
"
###############################################################################

if [[ ( "${PLUGIN}" == "${PLUGIN_L2G}" ) || ( "${PLUGIN}" == "${PLUGIN_R2G}" ) ]]
then
Conductor=`grep -iw -C5 $ACC_NUM $DVX2DIR | grep NAME | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<NAME>*//' | sed 's/<.*//'| sort | uniq | head -1`
LibN=`grep -iw -C5 $Conductor $DVX2DIR  | grep TYPE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<TYPE>*//' | sed 's/<.*//' | sort | uniq `
HostN=`grep -iw -C5 $Conductor $DVX2DIR  | grep MACHINE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<MACHINE>*//' | sed 's/<.*//'`
Status=`grep -iw -C5 $Conductor $DVX2DIR | grep ACTIVE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<ACTIVE>*//' | sed 's/<.*//' | sed 's/1/Active/g' | sed 's/0/Inactive/g'`

if [[ -z "$LibN"  ]]; then
Conductor=NA
LIB=NA
LibN=NA
HostN=NA
Status=NA
fi
echo "Library Instance Details :
-------------------------------

      Conductor Name        : ${Conductor}
      Library Name          : ${LibN}
      Machine               : ${HostN}
      Status                : ${Status}

=====================================================================================================================================
"
fi
###############################################################################
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
###############################################################################
####################  Need to change usr value according to project ###########
#BASE_DIR=`env | grep ^BASE_DIR | awk -F= '{print $2}' | rev | cut -c 3- | rev`
#BASE_DIR=${BASE_DIR}${HOST:20:22}
LHOST=`grep $HOST CUSTOM/SERVER.cfg | awk '{print $1}'`
BASE_DIR=`grep $HOST CUSTOM/SERVER.cfg | awk '{print $2}'`
RAW_DATA_DIR="/teoco/rdr_med01/raw_data/"
PERSISTENCE_DIR=`env | grep ^PLUGIN_FT_PERSISTENCE_DIR | awk -F= '{print $2}' | awk -F/ '{print $4,$5,$6,$7,$8}' | sed 's/ /\//g'`
###############################################################################
ssh -q $LHOST exit
if [ $? -ne 0 ]
then
echo "SSH connection to $LHOST is Not OK, so couldn't check files in persistence directory

Info : Check CUSTOM/SERVER.cfg file.

====================================================================================================================================="
else
###############################################################################
echo "Details of Last 10 Files in Persistence Dir (Local Server) : "
echo "--------------------------------------------------------------"
ssh -q -t ${LHOST} '
echo
cd  '${BASE_DIR}'
less '${PERSISTENCE_DIR}'/acc'${acc}'/FileHistoryManager_Backup_acc'${acc}'.ftha | tail -n 100
exit
' >tmp/foo.txt 2>/dev/null

if [[ ! -f tmp/foo.txt ]] || [[ `cat tmp/foo.txt` == *"No such file or directory"* ]] || [[ ! -s tmp/foo.txt ]];then
FILESTATE=ERROR
echo "
Exception: `cat tmp/foo.txt | tail -1`

Root Cuase: 
   1. Please verify if the history file for access $ACC_NUM exists in the plugin persistence directory.
   2. Please verify on the communication admin that GD $GD is running on which server.
   3. Could not run command on \"$LHOST\"
"

elif [[ -f tmp/foo.txt ]] && [[ `cat tmp/foo.txt` != *"No such file or directory"* ]] && [[ -s tmp/foo.txt ]];then
dosome=`cat tmp/foo.txt | tail -1 | awk -F "|" '{print  $NF}'` 2>/dev/null

if [[ "$dosome" == *"Last Change Date"*  ]];then

echo "
Exception : No file history/record found in persistence directory for this access.
Info  : This script only shows the file history of File Transfer Protocol accesses.

Root Cause :

   1. There is no record available for a single file in persistence directory for this access.
   2. Since This Access has been Created Not a Singal Data has been Fetched by it.
   3. It is not a file transfer protocol (FTP/SFTP) access.
"
dosome=0

elif [[ "$dosome" != *"Last Change Date"* ]];then
echo
cat tmp/foo.txt | tail
TIME2=`date --date="$dosome" '+%Y-%m-%d %R'`
TIME1=`date "+%Y-%m-%d %R %Z"`

echo "
=====================================================================================================================================

Current Date & Time on Local Host : $TIME1" ;echo

if [[ ( "$FILESTATE" != "ERROR" ) && ( "$FILESTATE2" != "ERROR" ) ]];then
when="on $TIME2"
echo "Last file was received - `get_time` $when"
echo
fi
fi
fi
echo "====================================================================================================================================="

#################################################################################################################
####################### Local to Remote Plugin ##################################################################
if [[  "${PLUGIN}" == "${PLUGIN_L2R}" ]];then
echo $LOCAL_DIR | grep -o RAW_DATA_DIR >/dev/null
if [[ $? -eq 0 ]];then
LOCAL_DIR2=`echo $LOCAL_DIR | sed 's/$RAW_DATA_DIR//g' | cut -c 2-`
LOCAL_DIR=${RAW_DATA_DIR}/${LOCAL_DIR2}
fi
MASKL=`echo $MASKL | awk '{print $1}'`
ssh -q -t ${LHOST} '
echo
echo "Present Working Directory : '${LOCAL_DIR}'"
echo
cd '${LOCAL_DIR}'
echo "=============================================="
echo "Files in Local Directory:"
echo "==============================================";echo
ls -lrht --time-style="+%Y-%m-%d %H:%M %R %Z" '${MASK}' | sort -k6 | tail -n 10
echo
echo "====================================================================================================================================="
echo
echo Local Host Name : `hostname`
echo
echo Current Date Time on Local Host : `date "+%Y-%m-%d %H:%M %R %Z"`
echo 
echo "====================================================================================================================================="
'  2>/dev/null
fi
fi

####################################################################################################################
####################### Local to Local Plugin ######################################################################
if [[ "${PLUGIN}" == "${PLUGIN_L2L}" ]];then
echo
echo -n "Do You Want to check Files in Source and Destination Directory(y/n) : "
read opt3
if [[ ( "$opt3" != "n" ) && ( "$opt3" != "y" ) ]];then
end1=$(date +%s)
echo "
Wrong Input. Skipping.....

=====================================================================================================================================

Elapsed Time: $(($end1-$start1)) seconds

Thank you"
exit 1
elif [[ "$opt3" == "n" ]];then
end1=$(date +%s)
echo "
Skipping.....

=====================================================================================================================================

Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1

elif [[ "$opt3" == "y" ]]; then

if [[ ( "$ACC_STATUS" == "Active" ) && ( "$GD_STATE" == "Active" ) ]];then
echo "
=====================================================================================================================================

Details of Local Server :
----------------------------
      
      Host Name             : $HOST
      Source Dir            : $SDir
      Advanced Mask         : $ADMask2
      Mask                  : $MASK2
      Looking Sub Folders   : $LSF
      Sub Folder Mask       : $SFMASK2

=====================================================================================================================================
"
ssh -q -t ${LHOST} '
echo "Present Working Directory : '${DESTINATION_DIR}'"
echo
echo "======================================"
echo "Files in Destination Dir:"
echo "======================================"
echo
cd '${DESTINATION_DIR}'
find . -type f | egrep "'${ADMask}'" | ls -lrth --time-style="+%Y-%m-%d %R %Z" | tail
echo
echo "====================================================================================================================================="
echo
echo "Present Working Directory : '${SDir}'"
echo
echo "======================================"
echo "Files in Source Dir:"
echo "======================================"
echo
cd '${SDir}'
find . -type f | egrep "'${ADMask}'" | ls -lrth --time-style="+%Y-%m-%d %R %Z" | tail
echo
echo "====================================================================================================================================="
echo
echo "Local Host Name : `hostname`"
echo
echo Current Date Time on Local Host : `date "+%Y-%m-%d %R %Z"`
echo
' > tmp/local_filelist.txt 2>/dev/null
cat tmp/local_filelist.txt
if [[ ( -f tmp/local_filelist.txt  )&& ( -s tmp/local_filelist.txt ) ]];then
TIME2=`cat tmp/local_filelist.txt | grep -m1 -A12 Files | tail -1 | awk '{print $6,$7,$8}'`
if [[ ( ! -z $TIME2 ) && ( $TIME2 != *"="* ) ]];then
TIME1=`date "+%Y-%m-%d %R %Z"`
echo "Last file was received - `get_time` on $TIME2 (Destination Dir)"
echo
fi
TIME2=`cat tmp/local_filelist.txt | grep -m2 -A12 Files | tail -1 | awk '{print $6,$7,$8}'`
if [[ ( ! -z $TIME2 ) && ( $TIME2 != *"="* ) ]];then
TIME1=`date "+%Y-%m-%d %R %Z"`
echo "Last file was received - `get_time` on $TIME2 (Source Dir)"
fi
fi
cat  tmp/local_filelist.txt > tmp/local_filelist.log
echo "
=====================================================================================================================================

Logs is Captured in tmp/local_filelist.log file.

=====================================================================================================================================
"
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
else
echo "
=====================================================================================================================================
"
echo "Exception: If Access or GD is inactive, it will not get the Remote Server details."
fi
fi
fi

####################################################################################################################
####################### Remote to Remote Plugin ######################################################################
if [[ "${PLUGIN}" == "${PLUGIN_R2R}" ]];then
echo
echo -n "Do You Want to check Files in Both Remote Directory(y/n) : "
read opt3
if [[ ( "$opt3" != "n" ) && ( "$opt3" != "y" ) ]];then
end1=$(date +%s)
echo "
Wrong Input. Skipping.....

=====================================================================================================================================

Elapsed Time: $(($end1-$start1)) seconds

Thank you"
exit 1
elif [[ "$opt3" == "n" ]];then
end1=$(date +%s)
echo "
Skipping.....

=====================================================================================================================================

Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1

elif [[ "$opt3" == "y" ]]; then

if [[ ( "$ACC_STATUS" == "Active" ) && ( "$GD_STATE" == "Active" ) ]];then
echo "
=====================================================================================================================================

Details of Destination Remote Server :
---------------------------------------

      Destination Host      : $DES_HOST
      Destination Port      : $DES_PORT
      Destination User Name : $DES_USER
      Destination Password  : $DES_PASS
      Destination Dir       : $DESTINATION_DIR
	 
Details of Source Remote Server :
-----------------------------------
     
      Source Host           : $SOU_HOST
      Source Port           : $SOU_PORT
      Source User Name      : $SOU_USER
      Source Password       : $SOU_PASS
      Source Dir            : $SDir
      Advanced Mask         : $ADMask2
      Mask                  : $MASK2
      Looking Sub Folders   : $LSF
      Sub Folder Mask       : $SFMASK2

=====================================================================================================================================
"
grep $DES_HOST CUSTOM/SERVER.cfg > /dev/null
if [ $? -eq 1 ];then
CMD="find . -maxdepth 1 -type f -exec ls -lrht --time-style='+%Y-%m-%d %R %Z' {} + | egrep -i "'${ADMask}'" | sort -k6 | tail -n 10"
else
CMD="ls -lrht --time-style='+%Y-%m-%d %R %Z' | egrep -i '${ADMask}' | tail -n 10"
fi

ssh -q -t -o ConnectTimeout=240 -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p ${DES_PORT} $DES_USER@$DES_HOST << EOF > tmp/R2L_FILE.txt 2>/dev/null
echo Present Working Directory : '${DESTINATION_DIR}'
echo
echo ======================================
echo Files in Destination Directory:
echo ======================================
echo
cd '${DESTINATION_DIR}'
${CMD}
echo
echo ======================================
echo "Remote Host Name :"
echo "---------------------"
hostname
echo
echo "Current Date Time on Remote Host :"
echo "----------------------------------"
date '+%Y-%m-%d %R %Z'
EOF

ssh -q -t -o ConnectTimeout=240 -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p ${SOU_PORT} $SOU_USER@$SOU_HOST << EOF > tmp/R2L_FILE2.txt 2>/dev/null
echo Present Working Directory : '${SDir}'
echo
echo ======================================
echo Files in Source Directory:
echo ======================================
echo
cd '${SDir}'
find . -maxdepth 1 -type f -exec ls -lrht --time-style='+%Y-%m-%d %R %Z' {} + 2>/dev/null | egrep -i "${ADMask}" | sort -k6 | tail -n 10
echo
echo ======================================
echo "Remote Host Name :"
echo "---------------------"
hostname
echo
echo "Current Date Time on Remote Host :"
echo "----------------------------------"
date '+%Y-%m-%d %R %Z'
EOF

cat tmp/R2L_FILE.txt | grep -iv "Bad file descriptor" | grep -iv "job control in this shell" > tmp/R2L_FILES.txt
cat tmp/R2L_FILE2.txt | grep -iv "Bad file descriptor" | grep -iv "job control in this shell" | grep -iv "failed login attempt" | grep -iv "Last failed login:" > tmp/R2L_FILES2.txt

FILESTATE_DES=`cat tmp/R2L_FILES.txt | grep -A2 "Present Working Directory " | grep -iv "Present Working Directory"`
FILESTATE_SOU=`cat tmp/R2L_FILES2.txt | grep -A2 "Present Working Directory " | grep -iv "Present Working Directory"`

if [[ -z $FILESTATE_DES ]];then
echo "
=====================================================================================================================================

Error: Could Not Run Command on Destination Server.
"
else
echo "
=====================================================================================================================================

`cat tmp/R2L_FILES.txt`"
fi
echo "====================================================================================================================================="

if [[ -z $FILESTATE_SOU ]];then
echo "
Error: Could Not Run Command on Source Server.
"
else
echo "
`cat tmp/R2L_FILES2.txt`"
fi
echo "=====================================================================================================================================
"
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
else
echo "
=====================================================================================================================================
"
echo "Exception: If Access or GD is inactive, it will not get the Remote Server details."
fi
fi
fi

####################################################################################################################
######################################## R2L, EXT/R2L and L2R Access ###############################################
if [[ "${PLUGIN}" == "${PLUGIN_R2L}" ]] || [[ "${PLUGIN}" == "${PLUGIN_EXTR2L}" ]] ||  [[  "${PLUGIN}" == "${PLUGIN_L2R}" ]]
then
echo
echo -n "Do You Want to Connect Remote Host/EMS(y/n) : "
read opt3
if [[ ( "$opt3" != "n" ) && ( "$opt3" != "y" ) ]];then
end1=$(date +%s)
echo "
Wrong Input. Skipping.....

=====================================================================================================================================

Elapsed Time: $(($end1-$start1)) seconds

Thank you"
exit 1
elif [[ "$opt3" == "n" ]];then
end1=$(date +%s)
echo "
Skipping.....

=====================================================================================================================================

Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1

elif [[ "$opt3" == "y" ]]; then

if [[ ( "$ACC_STATUS" == "Active" ) && ( "$GD_STATE" == "Active" ) ]];then
echo "
=====================================================================================================================================

Details of Remote Server :
----------------------------

      Remote Host           : $RHost
      Remote UserName       : $RUser
      Remote Password       : $RPass
      Remote Port           : $RPort"

if [[ "${PLUGIN}" == "${PLUGIN_R2L}" ]];then
echo "      Remote Dir            : $RDir
      Advanced Mask         : $ADMask2"
fi
echo "      Mask                  : $MASK2"
if [[ "${PLUGIN}" == "${PLUGIN_EXTR2L}" ]];then
echo "      Source Dir            : $SDir
      Regular Exp           : $REXP2"
fi
echo "      Looking Sub Folders   : $LSF
      Sub Folder Mask       : $SFMASK2"
else
echo "
=====================================================================================================================================
"
echo "Exception: If Access or GD is inactive, it will not get the Remote Server details."
fi

echo "
=====================================================================================================================================
"
if [[ -z $RHost ]];then
echo "Exception: There is no details of Remote Server , So could not connect.

Info: Try to restart this Access ($ACC_NUM) or GD ($GD) on communication admin.

====================================================================================================================================="
fi
############################################################################################################
############################## Condition when Source Dir is root ###########################################
if [[ ( "${SDir}" == "/" ) || ( "${RDir}" == "/" ) ]] && [[ "$dosome" != *"Last Change Date"* ]] ;then
ROOT_PATH="YES"
if [[ "${PLUGIN}" == "${PLUGIN_EXTR2L}" ]];then
SDir=`grep '\S' tmp/foo.txt | rev | cut -d '/' -f3- | rev | sort | uniq | head -1`
SDir=`echo /${SDir}`
SDir2=`grep '\S' tmp/foo.txt | rev | cut -d '/' -f3- | rev | sort | uniq | tail -1`
SDir2=`echo /${SDir2}`
REXP=`grep '\S' tmp/foo.txt | awk -F "|" '{print $1}' | awk -F "/" '{print $NF}' | grep -oiP '(?<=MeContext=)[^ ]*' | awk -F "," '{print $1}' | sort | uniq | sed 's/^/*/g' | sed 's/$/*/g' | tr "\n" "|" | rev | cut -c 2- | rev`
grep '\S' tmp/foo.txt | awk -F "|" '{print $1}' | awk -F "/" '{print $NF}' | grep -oiP '(?<=MeContext=)[^ ]*' | awk -F "," '{print $1}' | sort | uniq > tmp/element.txt 2>/dev/null
elif [[ "${PLUGIN}" == "${PLUGIN_R2L}" ]];then
RDir=`grep '\S' tmp/foo.txt | rev | cut -d '/' -f3- | rev | sort | uniq | tail -1`
fi
grep '\S' tmp/foo.txt | rev | cut -d '/' -f3- | rev | sort | uniq |grep '\S' > tmp/foso.txt 2>/dev/null
sed -i 's/^/\//' tmp/foso.txt 2>/dev/null

if [[ ( -f tmp/foso.txt ) && ( -s tmp/foso.txt ) ]];then
echo "Info: Access's Source Directory is root (/). But Access always collects files of below Elements from below Remote Dir.

Remote Dir:
`cat -n tmp/foso.txt`

Elements Name:
`cat -n tmp/element.txt`

But script checks files in the first & Last path of above Remote dir list. 
You can connect manually and check files in all remote paths for deep investigation.

You can run below command on Remote Server to check files in other Remote Directories.
Command: ls -lRrht *<Element_Name>* | tail

=====================================================================================================================================
"
fi
fi
############################################################################################################
####################################### Commands for EMS ###################################################
echo $RHost | sed 's/,/\n/g' > tmp/foo.txt
MASK2=`echo $MASK | cut -c -1`
if [[ "$MASK2" == "{" ]];then
REXP=`echo $MASK | cut -c 2- | rev | cut -c 2- | rev | sed 's/,/|/g'`
fi

ECMD="
echo Present Working Directory : ${SDir}
echo
echo ======================================
echo Files in Source Dir:
echo ======================================
echo
cd ${SDir}
"
ECMD2="find . -type f | egrep '"${REXP}"' | xargs ls -lrht --time-style='+%Y-%m-%d %R %Z' | sort -k6 | tail"
#if [[ $ROOT_PATH == YES ]];then
#ECMD2="find . -type f | xargs ls -lrht --time-style='+%Y-%m-%d %R %Z' | egrep '"${REXP}"' | sort -k6 | tail"
#fi

if [[ ( $ROOT_PATH == YES ) && ( ! -z $SDir2 ) ]];then
ECMD3="
echo
echo =====================================================================================================================================
echo
echo Present Working Directory : ${SDir2}
echo
echo ======================================
echo Files in Second Source Dir:
echo ======================================
echo
cd ${SDir2}
find . -type f | egrep '"${REXP}"' | xargs ls -lrht --time-style='+%Y-%m-%d %R %Z' | sort -k6 | tail
"
elif [[ ( $ROOT_PATH == No ) || ( -z $SDir2 ) ]];then
ECMD3=""
fi

CMD="
echo Present Working Directory : '${RDir}'
echo
echo ==============================================
echo Files in Current Directory:
echo ==============================================
echo
cd '${RDir}'
find . -maxdepth 1 -type f -exec ls -lrht --time-style='+%Y-%m-%d %R %Z' {} + 2>/dev/null | egrep -i '"${ADMask}"' | sort -k6 | tail -n 10
"

if [[ ( "${LSF}" == "1" ) || ( "${LSF}" == "Yes" ) ]];then
CMD2="
echo
echo ==============================================
echo Files in Sub Directories :
echo ==============================================
echo
find . -depth 2 -type f -exec ls -lrht --time-style='+%Y-%m-%d %R %Z' {} + 2>/dev/null | egrep -i '"${SFMASK}"' | sort -k6 | tail -n 10 
echo
"
elif [[ ( -z "${LSF}" ) || ( "${LSF}" == "No" ) ]];then
CMD2=""
fi

CMD3="
echo
echo "====================================================================================================================================="
echo
"
############################################################################################################

function Connection_EMS() {

timeout 5 bash -c "</dev/tcp/$RHost/$RPort" &> /dev/null
if [ $? -ne 0 ]
then
echo "
=========================================================================================

$RHost : Not Reachable, so couldn't connect.

=========================================================================================
"
exit
fi

if [ $? -ne 1 ]
then
echo "$RHost is Reachable, Enter Password to Check SSH Connection.......
"
ssh -q -t $RUser@$RHost exit
if [ $? -ne 1 ]
then
echo "
SSH connection to $RHost is OK, Enter Password Again to Check RD.......
"
############################################################################################################
############### SSH Connection to EMS   ####################################################################
if [[ "${PLUGIN}" == "${PLUGIN_L2R}" ]];then
grep $RHost CUSTOM/SERVER.cfg >/dev/null
if [ $? -eq 0 ] ;then
ssh -q -t -o ConnectTimeout=240 -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p ${RPort} $RUser@$RHost ' 
echo Present Working Directory : '${RDir}' ;echo
cd '${RDir}'
echo "=============================================="
echo "Files in Remote Directory:"
echo "==============================================";echo
ls -lrht --time-style="+%Y-%m-%d %R %Z" '${MASK}' | sort -k6 | tail -n 10
echo
echo "====================================================================================================================================="
echo
echo "Remote Host Name :"
echo "---------------------"
hostname
echo
echo "Current Date Time on Remote Host :"
echo "----------------------------------"
date "+%Y-%m-%d %R %Z"
' > tmp/EMS_FileList.txt 2>/dev/null
else
PLUGIN4=EMS
fi
fi

if [[ ( "${PLUGIN}" == "${PLUGIN_R2L}" ) || ( "${PLUGIN4}" == "EMS" ) ]];then
ssh -q -t -o ConnectTimeout=240 -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p ${RPort} $RUser@$RHost << EOF > tmp/EMS_FileList.txt 2>/dev/null
$CMD
$CMD2
$CMD3
echo "Remote Host Name :"
echo "---------------------"
hostname
echo
echo "Current Date Time on Remote Host :"
echo "----------------------------------"
date '+%Y-%m-%d %R %Z'
EOF
fi

if [[ "${PLUGIN}" == "${PLUGIN_EXTR2L}" ]];then
ssh -q -t -o ConnectTimeout=240  -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p ${RPort} $RUser@$RHost << EOF > tmp/EMS_FileList.txt 2>/dev/null
$ECMD
$ECMD2
$ECMD3
$CMD3
echo "Remote Host Name :"
echo "---------------------"
hostname
echo
echo "Current Date Time on Remote Host :"
echo "----------------------------------"
date '+%Y-%m-%d %R %Z'
EOF
fi

##########################################################################################
######################### Files Listing ##################################################
##find . -type f -exec ls -lrht --time-style='+%Y-%m-%d %H:%M' {} + 2>/dev/null | egrep -i "${REXP}" | sort -k6 | tail -n 10
cat tmp/EMS_FileList.txt | egrep -v "Bad file descriptor|Thus no job control in this shell" | grep -iv "login failed" | grep -iv "ssh:notty" | grep -iv "failed login attempt" > tmp/EMS_FileList_ssh.txt 2>/dev/null
FILESTATE=`cat tmp/EMS_FileList_ssh.txt | grep -m1 -A3 Files | tail -1`
FILESTATE2=`cat tmp/EMS_FileList_ssh.txt | grep -m2 -A3 Files | tail -1`
if [[ -z $FILESTATE ]] && [[ -z $FILESTATE2 ]];then
echo "
=====================================================================================================================================

Error: Could not run command on Remote Server.

=====================================================================================================================================
"
fi
if [[ ! -z $FILESTATE ]] ;then
if [[ "${PLUGIN}" == "${PLUGIN_EXTR2L}" ]] && [[ ( -z "${ROOT_PATH}" ) || ( "${ROOT_PATH}" != "YES" ) ]];then
EMSHOST=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | grep -A2 ^Remote | tail -1`
TIME2=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | tail -8 | head -1 | awk '{print $6,$7,$8}'`
TIME1=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | tail -1`
echo "
=====================================================================================================================================

Latest 10 Files in Remote Dir [ SSH Protocol ]:
---------------------------------------------------

`cat tmp/EMS_FileList_ssh.txt | grep -B5 -A15 "Files"`

Remote/EMS Host Name : $EMSHOST

Current Date & Time on EMS : $TIME1

Last file was received - `get_time` on $TIME2 on Remote Server

=====================================================================================================================================
"

elif [[ "${PLUGIN}" == "${PLUGIN_L2R}" ]];then
EMSHOST=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | grep -A2 ^Remote | tail -1`
TIME2=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | tail -8 | head -1 | awk '{print $6,$7,$8}'`
TIME1=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | tail -1`
echo "
=====================================================================================================================================

Latest 10 Files in Remote Dir [ SSH Protocol ]:
---------------------------------------------------

`cat tmp/EMS_FileList_ssh.txt | grep -B5 -A15 "Files"`
Remote/EMS Host Name : $EMSHOST

Current Date & Time on EMS : $TIME1

Last file was received - `get_time` on $TIME2 on Remote Server

=====================================================================================================================================
"
elif [[ "${PLUGIN}" == "${PLUGIN_EXTR2L}" ]] && [[ ! -z "${ROOT_PATH}" ]] && [[ "${ROOT_PATH}" == "YES" ]];then
EMSHOST=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | grep -A2 -m 1 ^Remote | tail -1`
TIME2=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | head -14 | tail -1 | awk '{print $6,$7,$8}'`
TIME1=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | tail -1`
echo "
=====================================================================================================================================

Latest 10 Files in Remote Dir [ SSH Protocol ]:
---------------------------------------------------

`cat tmp/EMS_FileList_ssh.txt | grep -B5 -A14 "Files"`

Remote/EMS Host Name : $EMSHOST

Current Date & Time on EMS : $TIME1

Last file was received - `get_time` on $TIME2 on Remote Server ($SDir)"
TIME2=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | tail -8 | head -1 | awk '{print $6,$7,$8}'`
echo "
Last file was received - `get_time` on $TIME2 on Remote Server ($SDir2)

=====================================================================================================================================
"

elif [[ "${PLUGIN}" == "${PLUGIN_R2L}" ]];then
EMSHOST=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | grep -A2 ^Remote | tail -1`
TIME2=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | tail -8 | head -1 | awk '{print $6,$7,$8}'`
TIME1=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | tail -1`
echo "
=====================================================================================================================================

Latest 10 Files in Remote Dir [ SSH Protocol ]:
---------------------------------------------------

`cat tmp/EMS_FileList_ssh.txt | grep -B5 -A14 "Files"`

Remote/EMS Host Name : $EMSHOST

Current Date & Time on EMS : $TIME1

Last file was received - `get_time` on $TIME2 on Remote Server (Current Directory)"
if [[ $LSF == No ]];then
echo "
=====================================================================================================================================
"
elif [[ $LSF == Yes ]];then
TIME2=`grep -v '^[[:space:]]*$' tmp/EMS_FileList_ssh.txt | tail -8 | head -1 | awk '{print $6,$7,$8}'`
echo "
Last file was received - `get_time` on $TIME2 on Remote Server (Sub Directory)

=====================================================================================================================================
"
fi
fi

cat tmp/EMS_FileList_ssh.txt | grep -iv cat | grep -iv exit >> tmp/EMS_FileList_ssh.log
echo "Logs is captured in tmp/EMS_FileList_ssh.log

=====================================================================================================================================
"
fi
else
############################################################################################################
##############   SFTP Connection to EMS  ###################################################################

echo $ADMask | sed 's/|/\n/g' | sed -e "s/^\.\*//g" | sed 's/.$//' > tmp/AMASK.txt
echo $SFMASK | sed 's/|/\n/g' | sed -e "s/^\.\*//g" | sed 's/.$//' > tmp/SMASK.txt
ADMask=`cat tmp/AMASK.txt | head -1`
SFMASK=`cat tmp/SMASK.txt| head -1`

echo "
=========================================================================================

SSH connection to $RHost is Not OK, so trying with SFTP

=========================================================================================
"
sftp -oPort=${Port} $RUser@$RHost << EOF > tmp/EMS_FileList3.txt 2>/dev/null
cd $Dir2
pwd
ls -lrth *${ADMask}*
ls -lrth *${SFMASK}*
date
EOF

sed 1,2d tmp/EMS_FileList3.txt > tmp/EMS_FileList_sftp.txt
echo "
=====================================================================================================================================

Files in Remote Dir [ SFTP Protocol ]  :
-----------------------------------------

`cat tmp/EMS_FileList_sftp.txt | sed 's/sftp>/\n/g' | grep -iv lrth`

=====================================================================================================================================

Logs is captured in tmp/EMS_FileList_sftp.txt
"
############################################################################################################
fi
fi
}

for RHost in `cat tmp/foo.txt`
do
Connection_EMS
done

elif [[ "$opt3" != "n" ]]; then
echo "ERROR: Invalid Input"
fi
fi

end1=$(date +%s) 
if [[ $PLUGIN == $PLUGIN_L2G ]];then
echo ""
fi
echo "Elapsed Time: $(($end1-$start1)) seconds"
echo
echo "Thank You"
exit 0
