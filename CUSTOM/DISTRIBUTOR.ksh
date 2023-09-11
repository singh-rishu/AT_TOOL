#!/bin/bash
start1=$(date +%s)
mkdir -p tmp && rm -rf tmp/*  >/dev/null 2>&1
DIR=AT_TOOL
CMD="mkdir -p ~/$DIR"
MYHOST=`hostname`
for HOST in `cat SERVER.cfg | awk '{print $1}' | grep -iv $MYHOST`
do
ssh -q $HOST exit
    if [ $? -eq 0 ]; then
ssh $HOST $CMD
scp -rp ../* $HOST:~/AT_TOOL/ &> /dev/null
echo "Scripts have been transferred to $HOST"
else
echo "$HOST is Not Available"
fi
done

echo

rm -rf tmp/*  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
