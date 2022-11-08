#!/bin/bash

# MIT License

# Copyright (C) 2022, Twilio, Inc. <help@twilio.com>

# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

minimized_json=""
in_quotes=0

# Read all lines from the file passed. CR and LF are wiped here
while IFS="" read -r str || [ -n "$str" ]; do
    # Iterate over every character in a line
    for (( i=0; i<${#str}; i++ )); do
        if [[ "${str:$i:1}" == '"' ]]; then
            # If the character is a quote ("), invert the in_quotes flag and escape this quote
            in_quotes=$((1 - $in_quotes))
            minimized_json+='\"'
        else
            # If inside quotes, don't remove anything. Otherwise, get rid of white spaces
            if [[ $in_quotes == 1 || "${str:$i:1}" != " " && "${str:$i:1}" != $'\t' ]]; then
                minimized_json+="${str:$i:1}"
            fi
        fi
    done
done < $1

printf '"DEFAULT_CFG": "%s"\n' "$minimized_json"

# Example:
# ./json2string.sh default-cfg.json
