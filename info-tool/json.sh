#!/bin/bash

#
# Copyright (c) 2017-2021, Pelion IoT and affiliates.
# Copyright (c) 2014 Florian Kalis
# 
# SPDX-License-Identifier: MIT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#


#---------------------------------------------------------------------------------------------------------------------------
# json utils, currently only importer
#---------------------------------------------------------------------------------------------------------------------------

JSON_INPUT=""
JSON_INPUT_LENGTH=""
JSON_DELINATION="_"
JSON_OUTFILE=""


PRIVATE_JSON_output_entry() {
    local one=${1//-/}
    echo "$one=\"$2\"" >> "$JSON_OUTFILE"
}

PRIVATE_JSON_parse_array() {
    local current_path="${1:+$1$JSON_DELINATION}$2"
    local current_scope="root"
    local current_index=0

    while [ "$chars_read" -lt "$JSON_INPUT_LENGTH" ]; do
        [ "$preserve_current_char" == "0" ] && chars_read=$((chars_read+1)) && read -r -s -n 1 c
        preserve_current_char=0
        c=${c:-' '}

        case "$current_scope" in
            "root") # Waiting for new object or value
                case "$c" in
                    '{')
                        PRIVATE_JSON_parse_object "$current_path" "$current_index"
                        current_scope="entry_separator"
                        ;;
                    ']')
                        return
                        ;;
                    [\"tfTF\-0-9])
                        preserve_current_char=1 # Let the parse value function decide what kind of value this is
                        PRIVATE_JSON_parse_value "$current_path" "$current_index"
                        preserve_current_char=1 # Parse value has terminated with a separator or an array end, but we can handle this only in the next while iteration
                        current_scope="entry_separator"
                        ;;
                        
                esac
                ;;
            "entry_separator")
                [ "$c" == "," ] && current_index=$((current_index+1)) && current_scope="root"
                [ "$c" == "]" ] && return
                ;;
        esac
    done
}

PRIVATE_JSON_parse_value() {
    local current_path="${1:+$1$JSON_DELINATION}$2"
    local current_scope="root"

    while [ "$chars_read" -lt "$JSON_INPUT_LENGTH" ]; do
        [ "$preserve_current_char" == "0" ] && chars_read=$((chars_read+1)) && read -r -s -n 1 c
        preserve_current_char=0
        c=${c:-' '}

        case "$current_scope" in
            "root") # Waiting for new string, number or boolean
                case "$c" in
                    '"') # String begin
                        current_scope="string"
                        current_varvalue=""
                        ;;
                    [\-0-9]) # Number begin
                        current_scope="number"
                        current_varvalue="$c"
                        ;;
                    [tfTF]) # True or false begin
                        current_scope="boolean"
                        current_varvalue="$c"
                        ;;
                    "[") # Array begin
                        PRIVATE_JSON_parse_array "" "$current_path"
                        return
                        ;;
                    "{") # Object begin
                        PRIVATE_JSON_parse_object "" "$current_path"
                        return
                esac
                ;;
            "string") # Waiting for string end
                case "$c" in
                    '"') # String end if not in escape mode, normal character otherwise
                        [ "$current_escaping" == "0" ] && PRIVATE_JSON_output_entry "$current_path" "$current_varvalue" && return
                        [ "$current_escaping" == "1" ] && current_varvalue="$current_varvalue$c"
                        ;;
                    '\') # Escape character, entering or leaving escape mode
                        current_escaping=$((1-current_escaping))
                        current_varvalue="$current_varvalue$c"
                        ;;
                    *) # Any other string character
                        current_escaping=0
                        current_varvalue="$current_varvalue$c"
                        ;;
                esac
                ;;
            "number") # Waiting for number end
                case "$c" in
                    [,\]}]) # Separator or array end or object end
                        PRIVATE_JSON_output_entry "$current_path" "$current_varvalue"
                        preserve_current_char=1 # The caller needs to handle this char
                        return
                        ;;
                    [\-0-9.]) # Number can only contain digits, dots and a sign
                        current_varvalue="$current_varvalue$c"
                        ;;
                    # Ignore everything else
                esac
                ;;
            "boolean") # Waiting for boolean to end
                case "$c" in
                    [,\]}]) # Separator or array end or object end
                        PRIVATE_JSON_output_entry "$current_path" "$current_varvalue"
                        preserve_current_char=1 # The caller needs to handle this char
                        return
                        ;;
                    [a-zA-Z]) # No need to do some strict checking, we do not want to validate the incoming json data
                        current_varvalue="$current_varvalue$c"
                        ;;
                    # Ignore everything else
                esac
                ;;
        esac
    done
} #end_PRIVATE_JSON_parse_value

PRIVATE_JSON_parse_object() {
    local current_path="${1:+$1$JSON_DELINATION}$2"
    local current_scope="root"

    while [ "$chars_read" -lt "$JSON_INPUT_LENGTH" ]; do
        [ "$preserve_current_char" == "0" ] && chars_read=$((chars_read+1)) && read -r -s -n 1 c
        preserve_current_char=0
        c=${c:-' '}

        case "$current_scope" in
            "root") # Waiting for new field or object end
                [ "$c" == "}" ]  && return
                [ "$c" == "\"" ] && current_scope="varname" && current_varname="" && current_escaping=0
                ;;
            "varname") # Reading the field name
                case "$c" in
                    '"') # String end if not in escape mode, normal character otherwise
                        [ "$current_escaping" == "0" ] && current_scope="key_value_separator"
                        [ "$current_escaping" == "1" ] && current_varname="$current_varname$c"
                        ;;
                    '\') # Escape character, entering or leaving escape mode
                        current_escaping=$((1-current_escaping))
                        current_varname="$current_varname$c"
                        ;;
                    *) # Any other string character
                        current_escaping=0
                        current_varname="$current_varname$c"
                        ;;
                esac
                ;;
            "key_value_separator") # Waiting for the key value separator (:)
                [ "$c" == ":" ] && PRIVATE_JSON_parse_value "$current_path" "$current_varname" && current_scope="field_separator"
                ;;
            "field_separator") # Waiting for the field separator (,)
                [ "$c" == ',' ] && current_scope="root"
                [ "$c" == '}' ] && return
                ;;
        esac
    done
} #end_PRIVATE_JSON_parse_object

PRIVATE_JSON_STARTparse() {
    chars_read=0
    preserve_current_char=0

    while [ "$chars_read" -lt "$JSON_INPUT_LENGTH" ]; do
        read -r -s -n 1 c
        c=${c:-' '}
        chars_read=$((chars_read+1))

        # A valid JSON string consists of exactly one object
        [ "$c" == "{" ] && PRIVATE_JSON_parse_object "" "" && return
        # ... or one array
        [ "$c" == "[" ] && PRIVATE_JSON_parse_array "" "" && return
        
    done
}


#/    Desc:       parses a json file to something sourceable
#/    $1:         file.json
#/    $2:         output file
#/    Output:     just the file specified in $2
#/    Example:    json_toShFile ./wigwag/FACTORY/QRScan/cfg.json .jsn
#/                source .jsn
json_toShFile(){
    JSON_OUTFILE="$2"
    echo "" > $JSON_OUTFILE
    #log "debug" "myoutfile is $JSON_OUTFILE"
    JSON_INPUT=$(cat "$1")
    JSON_INPUT_LENGTH="${#JSON_INPUT}"
    PRIVATE_JSON_STARTparse "" "" <<< "${JSON_INPUT}"
} #end_json_toShFile