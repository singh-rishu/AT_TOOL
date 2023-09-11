#!/bin/bash
###################################################################
# ?2023 TEOCO. ALL RIGHTS RESERVED                                #
# Customization Option
# Author : Rishabh Singh
###################################################################
start1=$(date +%s)
green='\e[1;32m'
red='\e[1;31m'
purple='\e[1;35m'
reset='\033[0m'
mkdir -p tmp && rm -rf tmp/*  >/dev/null 2>&1
if [[ ( $1 != "-help" ) && ( ! -z $1 )]];then
echo "Invaid Input [ Use -help fot help ]"
exit
fi
if [[ $1 == "-help" ]];then
echo -e "$green
============================================================================ $reset"
echo "
It Displays Things Below:
	
	1. Partitions in Critical State (>80%).
	2. 10 Biggest Size of Files of that partition.
	3. 10 Highest files count of directories of that patition.

Syntax : $0"
echo -e "$green
============================================================================ 
$reset"
exit
fi
df -Ph | grep -v "Use%" | sed 's/%//g' | awk '$5 > 80 {print $6"|"$2"|"$3"|"$4"|"$5"%""|""NOK"}'  | sort -t "|" -k5n | column -t > tmp/part.txt
if [[ ( -f tmp/part.txt ) && (! -s tmp/part.txt ) ]];then
echo -e "$green
=============================================================================================== $reset"

df -Ph | grep -v "Use%" | sed 's/%//g' | awk '$5 < 80 {print $6"|"$2"|"$3"|"$4"|"$5"%""|""OK"}'  | sort -t "|" -k5n > tmp/part2.txt
echo -e "$purple
Partition|Total Size|Used|Available|Usage(%)|Status
----------------------------|------------|-------|-------------|---------|--------$reset" > tmp/header1.txt
cat tmp/part2.txt >> tmp/header1.txt
column -t -s "|" tmp/header1.txt
echo
echo -e "$green=============================================================================================== $reset"
echo -e "$green
Message : All Partition are in OK State

===============================================================================================
$reset"
exit
elif [[ ( -f tmp/part.txt ) && ( -s tmp/part.txt ) ]];then

echo -e "$red
=====================================================================================================================

Partitions in Critical State:
-----------------------------  $reset"
echo -e "$purple
Partition|Total Size|Used|Available|Usage(%)|Status
----------------------------|------------|-------------|---------|--------|--------$reset" > tmp/header3.txt
cat tmp/part.txt >> tmp/header3.txt
column -t -s "|" tmp/header3.txt

DISK=$(df -Ph | grep -v "Use%" | sed 's/%//g' | awk '$5 > 80 {print $6}' | column -t)
echo -e "$red
===================================================================================================================== 

20 Biggest Size of Files:
--------------------------- $reset"
for i in $DISK
do
echo -e "$green
=========================================
Partition: $i
=========================================$reset"
echo -e "$purple
File Size|Path of File
------------|------------------------------------------------------$reset" > tmp/header.txt
find $i -type f -size +5M 2>/dev/null | xargs du -sh 2>/dev/null | sort -rh | awk '{print $1"|"$2}'| head -n20 > tmp/filesize.txt
if [[ ( ! -f tmp/filesize.txt ) || ( ! -s tmp/filesize.txt ) ]];then
echo "Exception: Output not found for partition $i"
elif [[ ( -f tmp/filesize.txt ) && ( -s tmp/filesize.txt ) ]];then
cat tmp/filesize.txt >> tmp/header.txt
column -t -s "|" tmp/header.txt
fi
done
echo -e "$red
===================================================================================================================== 

20 Biggest files count of directories:
----------------------------------------$reset"
for i in $DISK
do
echo -e "$green
=========================================
Partition: $i
=========================================$reset"
find $i -type d -exec sh -c 'echo -n "{} | "; ls -1 "{}" | wc -l' \; 2>/dev/null | sort -k3 -nr | head -20 > tmp/filecount.txt
if [[ ( ! -f tmp/filecount.txt ) || ( ! -s tmp/filecount.txt ) ]];then
echo "Exception: Output not found for partition $i"
elif [[ ( -f tmp/filecount.txt ) && ( -s tmp/filecount.txt ) ]];then
echo -e "$purple
Path of Directory|File Count
------------------------------------------------------|------------$reset" > tmp/header2.txt
cat tmp/filecount.txt >> tmp/header2.txt
column -t -s "|" tmp/header2.txt
fi
done
echo -e "$red
=====================================================================================================================
$reset"
fi
rm -rf tmp/*  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
