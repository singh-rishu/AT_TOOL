#!/bin/bash
MYHOST=`hostname`
for HOST in `cat SERVER.cfg | awk '{print $1}'| grep -iv $MYHOST`
do
ssh -q $HOST exit
if [ $? -ne 0 ]
then
echo "SSH connection to $HOST is Not OK"
else
echo "SSH connection to $HOST is OK"
fi
done


