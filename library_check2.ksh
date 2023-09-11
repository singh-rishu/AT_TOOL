#!/bin/bash
###################################################################
# ?2023 TEOCO. ALL RIGHTS RESERVED                                #
# Customization Option
# Author : Rishabh Singh
###################################################################
######### To Dispaly help prompt of script ########################
start1=$(date +%s)
mkdir -p tmp && rm -rf tmp/*  >/dev/null 2>&1
if [ $# -eq 0 ];
then
echo "$0: Missing arguments"
echo "Info: Use -help for help. [syntax : $0 -help]"
exit 1
fi
if [[ "$1" == "-help" ]];then
echo "
=================================================================================================================

Note : This script is works with library and library instance name.
        Syntax          : $0 <library or instance name>
        Example         : $0 conductor_TEST_TOGGLE_6
        Example2        : $0 TEST_TOGGLE

You can pass multiple arguments to this script at once.

Example  : $0 conductor_TEST_TOGGLE_1 conductor_TEST_TOGGLE_2
Example2 : $0 TEST_TOGGLE NOK_AAA_FPP

Info :
1. If any instance is in WARNING STATE or DvxChain is stuck then it will ask to restart it.
        2. Also it asks to creates a backup of the input dir before restarting the instance of warning state.
        3. If library is still in getting warning state after restart then again it asks to create a backup.
        4. if access or GD is inactive of any library instance, it will not show below info.
                a) Protocol of Library Instance.
                b) DvxChain status of library instance.
                c) Local Directory of Access.

=================================================================================================================
"
exit
fi
###################################################################
DVX2DIR=$(env | grep DVX2_IMP_DIR | sed 's/.*=//')/config/conductor.xml
SQL="sqlplus -S psa/ttipass@$ORACLE_SID"
cp /dev/null tmp/library_check.log
LOGFILE=`touch /tmp/library_check.log`
LIBRARY=`echo $@ \  | tr " " "\n" | grep -v '^[[:space:]]*$'`
if [[ -z "$LIBRARY" ]]; then
echo "Please enter a value.......
Exit1"
exit
fi
for LIB in $LIBRARY
do
if [[ "$LIB" == *"conductor"* ]];then
LibN=`grep -iw -C5 $LIB "$DVX2DIR" | grep NAME | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<NAME>*//' | sed 's/<.*//'| sort | uniq `
elif [[ "$LIB" != *"-"* ]];then
LibN=`grep -w -C5 $LIB "$DVX2DIR"  | grep TYPE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<TYPE>*//' | sed 's/<.*//' | sort | uniq `
fi

if [[ -z "$LibN"  ]]; then
echo "
============================================================================================================

Error : $LIB - Wrong Library Name or Not Exists

============================================================================================================
"
continue
elif [[ ! -z "$LibN"  ]]; then
ConductorName=`grep -w -C5 $LibN $DVX2DIR | grep NAME | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<NAME>*//' | sed 's/<.*//'`
fi

for COND in $ConductorName
do
LibN=`grep -w -C5 $LIB $DVX2DIR  | grep -w TYPE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<TYPE>*//' | sed 's/<.*//' | sort | uniq `
HostN=`grep -w -C5 $COND $DVX2DIR  | grep -w MACHINE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<MACHINE>*//' | sed 's/<.*//'`
Status=`grep -w -C5 $COND $DVX2DIR | egrep -w ACTIVE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<ACTIVE>*//' | sed 's/<.*//' | sed 's/1/Active/g' | sed 's/0/Inactive/g'`
AccessID=`grep -w -C5 $COND $DVX2DIR | grep -w PARAMETERS | awk '{gsub(/[[:blank:]]/,""); print}'`
LibINS=`grep -B5 -A15 -w $COND $DVX2DIR | grep -w LIBRARY_INSTANCE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<LIBRARY_INSTANCE>*//' | sed 's/<.*//' | sort | uniq`
LID=`grep -B5 -A15 -w $COND $DVX2DIR | grep -w ID | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<ID>*//' | sed 's/<.*//' | sort | uniq`
LIB_INS="${LibINS}_${LID}"
LIB_INS2="conductor_${LIB_INS}"
LibN=`echo $LibN |sort | uniq`
ConductorName=$COND
HostN=$HostN
Status=$Status

if [[ ( ! -z "$LibN" ) && ( -z $AccessID ) || ( ! -z "$LibN" ) && ( $AccessID != *"Access"* ) ]]
then
AccessID="NA"
elif [[ ( ! -z $AccessID ) && ( $AccessID == *"Access"* ) ]]
then
AccessID=`grep -w -C5 $COND $DVX2DIR | grep PARAMETERS | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/.*Access//' | sed 's/&quot.*//'`
fi

if [[ "$AccessID" != "NA" ]];then
VAL=`$SQL << EOD
spool /tmp/log.txt
SET PAGESIZE 500 LINESIZE 200 feedback off verify off
COL HOST_NAME FORMAT A40
COL PLUGIN_NAME FORMAT A35
select ACCESS_NUM,ACC_STATUS, ENABLE as GD_STATUS, HOST_NAME, PLUGIN_NAME from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and (access_num like '$AccessID' or access_name like '$AccessID');
exit;
EOD`

ACC_NUM=`awk '{print $1}' /tmp/log.txt | tr -s '\n'| tail -1`
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

VAL=`$SQL << EOD
spool /tmp/log2.txt
SET PAGESIZE 500 LINESIZE 200 feedback off verify off
COL ACCESS_NAME FORMAT A60
COL GD_NAME FORMAT A60
select ACCESS_NAME, GD_NAME from comm_db.MED_ACCESS A, COMM_DB.MED_SUBNET B , COMM_DB.MED_GENERIC_DRIVER C , comm_db.med_plugin D where A.SUBNET_NUM = B.SUBNET_NUM and B.IMPLEMENT_GD = C.GD_NAME and A.PLUGIN_NUM = D.PLUGIN_NUM and (access_num like '$AccessID' or access_name like '$AccessID');
exit;
EOD`

ACCESS_NAME=`awk '{print $1}' /tmp/log2.txt| tr -s '\n' | tail -1`
GD=`awk '{print $2}' /tmp/log2.txt | tr -s '\n'| tail -1`
fi

if [[ ( "$AccessID" != "NA" ) && ( "$GD_STATE" == "Active" ) && ( "$ACC_STATUS" == "Active" ) ]];then
echo "gd ${GD}
quit
" > /tmp/ii.o
gd_commander -gd < /tmp/ii.o > /tmp/ii.oo
RECNO=`grep ${GD} /tmp/ii.oo | grep -v "^${GD}" | grep -wv "^${ACC_NUM}" | grep -w "${ACC_NUM}" | cut -d' ' -f1`
echo "gd ${GD}
${RECNO}|-2|statsubscribers
quit
" > /tmp/ii.ooo
gd_commander -gd < /tmp/ii.ooo > /tmp/ii.oooo
cat /tmp/ii.oooo | grep -B2 -A11 "${LIB_INS2}" > /tmp/ii2.o
DVXCHAIN=`grep -i 'DvxChainStatus' /tmp/ii2.o | awk '{print $2}'`
PROTOCOL=`grep Protocol: /tmp/ii2.o | awk '{print $2}' | sed 's/"//g'`

function dvx_subscriber() {
echo "Dvx Chain Status : $DVXCHAIN
Protocol         : $PROTOCOL"
}

echo "gd ${GD}
quit
" > /tmp/gg6.o
gd_commander -gd < /tmp/gg6.o > /tmp/gg6.oo
RECNO=`grep ${GD} /tmp/gg6.oo | grep -v "^${GD}" | grep -wv "^${ACC_NUM}" | grep -w "${ACC_NUM}" | cut -d' ' -f1`
echo "gd ${GD}
${RECNO}|-2|stataccessd
quit
" > /tmp/gg6.ooo
gd_commander -gd < /tmp/gg6.ooo > /tmp/gg6.oooo
LDIR=`cat /tmp/gg6.oooo | grep -w '|LocalDir' | sort | uniq | cut -c 33-`
MASK=`cat /tmp/gg6.oooo | grep -w '|Mask' | sort | uniq | cut -c 33-`
ADMASK=`cat /tmp/gg6.oooo | grep -w '|AdvancedMask' | sort | uniq | cut -c 33-`
SFMASK=`cat /tmp/gg6.oooo | grep -w '|SubfolderMask' | sort | uniq | cut -c 33-`

fi

DVXCHAIN2=`cat /tmp/ii.oooo | tail -3 | tr -s '\n' | sed 's/gd_commander*//' | sed 's/.*>//'`
if [[ "$DVXCHAIN2" == *"no active subscribers"* ]];then
DVXCHAIN=$DVXCHAIN2
else
if [[ -z $DVXCHAIN ]];then
DVXCHAIN=NA
fi
fi

if [[ -z $PROTOCOL ]];then
PROTOCOL=NA
fi



if [[ "$AccessID" != "NA" ]];then
function access_details() {
echo "Access ID        : $AccessID
Access Name      : $ACCESS_NAME
Access Status    : $ACC_STATUS
GD Name          : $GD
GD Status        : $GD_STATE
GD HOST          : $HOST"
}
fi

if [[ ( ! -z $LDIR ) && ( $GD_STATE == Active ) && ( $ACC_STATUS == Active ) ]];then
function local_dir() {
echo "Local Dir        : $LDIR"
}
fi


CMD="ps -ef | grep -w $ConductorName | grep -iv grep"
LHOST=`grep $HostN CUSTOM/SERVER.cfg | awk '{print $1}'`
if [[ $Status == Active ]];then
cp /dev/null /tmp/tmp22.txt
ssh -q $LHOST exit
if [ $? -ne 0 ]
then
echo "
=======================================================================================================================================

Warning : SSH connection to $LHOST is Not OK , so couldn't find actual status of $ConductorName.

Info : Check SERVER.cfg file whether user and hostname are configured properly in this file or not.

======================================================================================================================================="
Status="Not Found"
else
ssh -q $LHOST << EOF > /tmp/tmp11.txt 2>/dev/null
$CMD
EOF
fi
fi

cat /tmp/tmp11.txt |grep -v "/bin/bash" | grep -w $ConductorName > /tmp/tmp22.txt
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
============================================================================================================

Libray Type      : $LibN
Name             : $ConductorName
Machine          : $HostN
Status           : $Status2
Library Instance : $LIB_INS"

if [[ ( $GD_STATE == Active ) && ( $ACC_STATUS == Active ) ]];then
        dvx_subscriber
        fi

if [[ "$AccessID" != "NA" ]];then
        access_details
        fi

if [[ ( ! -z $LDIR ) && ( $GD_STATE == Active ) && ( $ACC_STATUS == Active ) ]];then
        local_dir
        fi

echo "
============================================================================================================
"

mkdir -p tmp ; test -f tmp/library_check.log || touch tmp/library_check.log

function restart_library() {

conqt &>>tmp/library_check.log << EOF
gs c connect_of_ConductorService
ex c (define Conductor (service-factory "ConductorService"))
ex c (define con (Conductor))
ex c (con "DEACTIVATEINSTANCES" '(1 2 "$LibN" "$ConductorName"))
ex c (con "ACTIVATEINSTANCES" '(1 2 "$LibN" "$ConductorName"))
ex c (undefine con)
exit
echo "
============================================================================================================
"
EOF
sleep 10
STATUS_4=`grep -iw -C5 $ConductorName $DVX2DIR | grep ACTIVE | awk '{gsub(/[[:blank:]]/,""); print}' | sed 's/<ACTIVE>*//' | sed 's/<.*//' | sed 's/1/Active/g' | sed 's/0/Inactive/g'`
ssh -q $LHOST << EOF > /tmp/tmp5.txt 2>/dev/null
$CMD
EOF
cat /tmp/tmp5.txt |grep -v "/bin/bash" | grep -w $ConductorName > /tmp/tmp33.txt
if [[ ( "$STATUS_4" == "Active" ) && ( ! -s /tmp/tmp33.txt ) ]];then
STATUS=Warning
elif [[ ( "$STATUS_4" == "Active" ) && ( -s /tmp/tmp33.txt ) ]];then
STATUS=Active
fi
if [[ "$STATUS" == "Active" ]];then
echo "============================================================================================================

$ConductorName is Activated

Current Status   : $STATUS
Dvx Chain Status : $DVXCHAIN

============================================================================================================
"

elif [[ "$STATUS" == "Warning" ]];then
echo "============================================================================================================

Warning : $ConductorName is not restarted.

Current Status   : $STATUS
Dvx Chain Status : $DVXCHAIN

Cuase : May be there is some issue with $LibN library or GD subscription.
Info  : Check logs of $ConductorName in \$DVX2_LOG_DIR on $HostN Server.

============================================================================================================
"
fi
}

Status_3="Warning"
for Status_2 in $Status2
do
if [[ "$Status_2" == "$Status_3" ]];then
echo -n "$ConductorName is in $Status_2 State. Do you want to restart (y/n)? : "
read OPT
echo
if [[ ( "$OPT" != "n" ) && ( "$OPT" != "y" ) ]];then
echo "Wrong Input. Skipping......

============================================================================================================
"
elif [[ "$OPT" == "n" ]];then
echo "Skipping......

============================================================================================================
"
elif [[ "$OPT" == "y" ]];then
restart_library
fi
fi
done

DVXSTATUS="Stuck"
for DVXCHAIN2 in $DVXCHAIN
do

if [[ ( "$DVXCHAIN2" == "$DVXSTATUS" ) && ( "$Status_2" == "Active" ) ]];then
echo -n "DvxChain of $ConductorName is Stuck. Do you want to restart it (y/n)? : "
read OPT
echo
if [[ ( "$OPT" != "n" ) && ( "$OPT" != "y" ) ]];then
echo "Wrong Input. Skipping......

============================================================================================================
"
elif [[ "$OPT" == "n" ]];then
echo "Skipping......

============================================================================================================
"
elif [[ "$OPT" == "y" ]];then
restart_library
fi
fi
done
done
done

rm -rf tmp/*  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
