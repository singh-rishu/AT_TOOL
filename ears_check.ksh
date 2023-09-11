#!/bin/ksh
###################################################################
# ?2023 AMDOCS. ALL RIGHTS RESERVED                                #
# Customization Option
# Author : Rishabh Singh
###################################################################

WLS=$($NRPE_DIR/auto-conf/get_wl_conf.ksh)


RES=$?
if [ "$RES" != "0" ]; then
        echo "There are no Weblogic configuration"
        echo "$WLS"
        exit 2
fi

for WL in $WLS; do
        echo $WL | awk -F\| '{print $1 " " $2 " " $3 " "$4 " "$5}' | read WL_NAME WL_HOST WL_PORT WL_USER_AUTO WL_PASS_AUTO
        #echo "$WL_NAME | $WL_HOST | $WL_PORT | $WL_USER_AUTO | $WL_PASS_AUTO"
        if [ "$WL_USER" = "" ]; then
                WL_USER=$WL_USER_AUTO
        fi
        if [ "$WL_PASS" = "" ]; then
                WL_PASS=$WL_PASS_AUTO
        fi
        #oif echo $WL_NAME
        if [ "$WL_NAME" = "WLAdminServer" ]
        then
        continue
        fi
        WL_WARNING=20
        WL_CRITICAL=10
        RES=$($NRPE_DIR/plugins/netrac/check_weblogic ear not_used $WL_HOST $WL_PORT $WL_NAME $WL_WARNING $WL_CRITICAL)


RES=`echo $RES | sed 's/heap used/heap used '$WL_NAME'/'`


if [ "$HTML" = "1" ]; then
                HeapFreeCurrent=$(echo $RES | sed 's/.*HeapFreeCurrent is \(.*\) , HeapSizeMax.*/\1/g')
                HeapSizeMax=$(echo $RES | sed 's/.*HeapSizeMax is \(.*\), HeapFreeCurrentPercent.*/\1/g')
                HeapFreeCurrentPercent=$(echo $RES | sed 's/.*HeapFreeCurrentPercent is \(.*\) %/\1/g')
                STATUS=$(echo $RES | awk '{print $1}')
                echo "$WL_NAME${CSV_DELIM}$STATUS${CSV_DELIM}$HeapFreeCurrent${CSV_DELIM}$HeapSizeMax${CSV_DELIM}$HeapFreeCurrentPercent" >> $FULLRESFILE
                RES1=$(echo $RES | awk '{print $1}')
                if [ "$RES1" != "OK" ]; then
                        ERR=1
                        echo "<font color=red>$WL_NAME $RES</font><br>"
                fi
        else
                echo $RES
        fi

done

