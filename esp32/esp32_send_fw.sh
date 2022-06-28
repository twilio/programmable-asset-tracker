#!/bin/bash
# Send PUT request with firmware to the imp-agent
agentUrl=$1
agentEndPoint=$2

if [[ "$agentEndPoint" == "reboot" ]]; then
    curl -X PUT ${agentUrl}/esp32-${agentEndPoint}
fi

if [[ "$agentEndPoint" == "load" ]]; then
    flashOffs=$3
    fileName=$4

    md5val=$(md5sum $fileName | awk '{ print $1 }')
    fileLen=$(ls -la $fileName | awk '{ print $5 }')

    curl -X PUT -T ${fileName} ${agentUrl}/esp32-${agentEndPoint}?fileName=${fileName}'&'fileLen=${fileLen}'&'flashOffset=${flashOffs}'&'deflate=false'&'md5=${md5val}
fi

# Example: 
# esp32_send_fw.sh https://agent.electricimp.com/D7u-XXXXx6j1 load 0x00 bootloader.bin 
# esp32_send_fw.sh https://agent.electricimp.com/D7u-XXXXx6j1 load 0x8000 partition-table.bin 
# esp32_send_fw.sh https://agent.electricimp.com/D7u-XXXXx6j1 reboot