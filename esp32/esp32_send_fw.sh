#!/bin/bash
# Send PUT request with firmware to the imp-agent
agentUrl=$1
agentEndPoint=$2
fileMaxLen=262144 # 256 KByte
splitSize=262144  # 256 KByte
splitDirName="splitDir"

if [[ "$agentEndPoint" == "finish" ]]; then
    curl -X PUT ${agentUrl}/esp32-${agentEndPoint}
fi

if [[ "$agentEndPoint" == "load" ]]; then
    flashOffs=$3
    fileName=$4
    hexStart0x=$(echo $flashOffs | cut -c1-2)

    if [[ "$hexStart0x" == "0x" ]]; then
        flashOffs=$(echo ${flashOffs##0x})
        flashOffs=$(printf '%d\n' "$((16#$flashOffs))")
    fi

    md5val=$(md5sum $fileName | awk '{ print $1 }')
    fileLen=$(ls -la $fileName | awk '{ print $5 }')

    if [[ $fileLen -gt $fileMaxLen ]]; then
        mkdir $splitDirName
        cd $splitDirName
        split -a 1 -b $splitSize $fileName
        echo $fileName
        for file in ./* ; do
            echo $fileName-$file;
            md5Part=$(md5sum $file | awk '{ print $1 }');
            fileLenPart=$(ls -la $file | awk '{ print $5 }');
            curl -X PUT -T ${file} ${agentUrl}/esp32-${agentEndPoint}?fileName=${fileName}'&'fileLen=${fileLenPart}'&'flashOffset=${flashOffs}'&'md5=${md5Part};
            flashOffs=$(($flashOffs + $splitSize));
            sleep 300;
        done
        cd ../
        rm -rf $splitDirName
    else
        curl -X PUT -T ${fileName} ${agentUrl}/esp32-${agentEndPoint}?fileName=${fileName}'&'fileLen=${fileLen}'&'flashOffset=${flashOffs}'&'md5=${md5val}
    fi
fi

# Example:
# esp32_send_fw.sh https://agent.electricimp.com/D7u-XXXXx6j1 load 0x00 bootloader/bootloader.bin
# esp32_send_fw.sh https://agent.electricimp.com/D7u-XXXXx6j1 load 0x8000 partition_table/partition-table.bin
# esp32_send_fw.sh https://agent.electricimp.com/D7u-XXXXx6j1 load 0x60000 esp-at.bin
# esp32_send_fw.sh https://agent.electricimp.com/D7u-XXXXx6j1 finish
