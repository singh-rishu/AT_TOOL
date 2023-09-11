#!/bin/bash
###################################################################
# ?2023 TEOCO. ALL RIGHTS RESERVED                                #
# Customization Option
# Author : Rishabh Singh
###################################################################
start1=$(date +%s)
mkdir -p tmp && rm -rf tmp/*  >/dev/null 2>&1

if [[ "$1" == "-help" ]];then
echo "
=====================================================================================================================

This Script is use to check date & time of last received file in helix from EMS.

   Syntax   : $0 <Access ID>
   Syntax 2 : $0 1201 760

Note : 1201 & 760 is Access ID. You can use multiple access at once.

Info : It also shows following details of access:
	1. Last one file creation time on EMS of access.
	2. Last one file receive time on Helix System.
	3. Difference in minutues between current server time and last one receive file time of access.
	4. Difference in minutues between last one file Creation time on EMS and receive time on Helix System.

Note : It checks and shows all details from File History (Plugin Persistence Dir) of access.

=====================================================================================================================
"
exit
fi
rm -rf tmp/*.txt > /dev/null

todate=`date "+%Y-%m-%d %T"`
tdate=`date "+%Y-%m-%d"`
PERSISTENCE_DIR=$(env | grep ft_cycle_persistence | sed s/.*=//)
FileHistory="/"${PERSISTENCE_DIR}"//*/*.ftha"
ACN=$@
for FH in $FileHistory
do

fdate=`tail -1 $FH 2>/dev/null | awk -F "|" '{print  $(NF-1)}'`
lcdate=`tail -1 $FH 2>/dev/null | awk -F "|" '{print  $NF}'`

ACC=`ls -lrth $FH 2>/dev/null | sed '/Backup_acc/s/.*Backup_acc\([^ ][^ ]*\)[ ]*.*/\1/' | sed 's/.....$//'`

if [[ ( $fdate == *"File"* ) || ( $lcdate == *"File"* ) ]]
then
fdate=NULL
lcdate=NULL
differ=NULL
delay=NULL
elif [[ ( $fdate != *"File"* ) || ( $lcdate != *"File"* ) ]];then

d1=$(date -d "$todate" '+%s')
d2=$(date -d "$lcdate" '+%s')
d3=$(date -d "$fdate" '+%s')
min=$(((d1 - d2)/60)) 
min2=$(((d2 - d3)/60))
differ=`echo $min Minutes Ago`
delay=`echo $min2 Minutes`
fi

echo "$ACC|$todate|$fdate|$lcdate|$differ|$delay" >> tmp/foo1.txt
done

echo "
Access ID|Server Current Time|File Creation Time (EMS)|File Received Time (Helix)|File Received (Helix)|Delay (EMS to Helix)
---------|---------------------|----------------------------|--------------------------|--------------------------|-------------------------
" > tmp/foo2.txt

if [[ ( -f tmp/foo1.txt ) && ( -s tmp/foo1.txt ) ]];then
if [[ -z $ACN ]];then
grep -v '^[[:space:]]*$'  tmp/foo1.txt >> tmp/foo2.txt
column -t -s "|" tmp/foo2.txt > tmp/foo3.txt
echo
cat tmp/foo3.txt

elif [[ ! -z $ACN ]];then
for ACNN in $ACN
do
cat tmp/foo1.txt | grep -w ^$ACNN >> tmp/foo3.txt
done
cat tmp/foo3.txt >> tmp/foo2.txt
column -t -s "|" tmp/foo2.txt > tmp/foo4.txt
echo
cat tmp/foo4.txt
fi
echo
rm -rf tmp/*  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
else
echo "$0: Warning: No Access Found"
exit 1
fi
