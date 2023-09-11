#!/bin/bash
TIMEOUT=5
MYHOST=`hostname`
for SERVER in `cat SERVER.cfg | awk '{print $1}' | awk -F "@" '{print $2}' | grep -iv $MYHOST`
do
timeout 5 bash -c "</dev/tcp/$SERVER/22" &> /dev/null
    if [ $? -eq 0 ]; then

        echo "$SERVER is Available."
    else

        echo "$SERVER is Unavailable."
    fi
done



