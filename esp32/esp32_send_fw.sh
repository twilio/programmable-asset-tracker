#!/bin/bash

agentUrl=$1
agentEndPoint=$2
fileName=$3
# offset=$4
# offsetHex=$(printf '%d\n' "$((16#$offset))")

val=$(md5sum $fileName | awk '{ print $1 }')
base64Val=$(echo $val | base64)
# cp $fileName $fileName.bac
# v=`awk -v n=$offsetHex 'BEGIN{printf "%08X", n;}'`
# echo -n -e "\\x${v:6:2}\\x${v:4:2}\\x${v:2:2}\\x${v:0:2}" >> $fileName
curl -H "Content-MD5: $base64Val" -T $fileName $agentUrl$agentEndPoint
# rm $fileName
# mv $fileName.bac $fileName
