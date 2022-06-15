#!/bin/bash
# Send PUT erquest with firmware to the imp-agent
agentUrl=$1
agentEndPoint=$2
fileName=$3

val=$(md5sum $fileName | awk '{ print $1 }')
base64Val=$(echo $val | base64)
curl -H "Content-MD5: $base64Val" -T $fileName $agentUrl$agentEndPoint

# Example: 
# esp32_send_fw.sh https://agent.electricimp.com/D7u-XXXXx6j1 /esp32-bootloader bootloader.bin 
# esp32_send_fw.sh https://agent.electricimp.com/D7u-XXXXx6j1 /esp32-partition-table partition-table.bin 