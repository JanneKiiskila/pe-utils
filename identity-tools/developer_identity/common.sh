#!/bin/bash

# Copyright (c) 2019, Arm Limited and affiliates.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cli_log() {
    script_name=${0##*/}
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "$timestamp $script_name LOG $1"
}

cli_error() {
    script_name=${0##*/}
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "$timestamp $script_name ERROR $1"
}

cli_warn() {
    script_name=${0##*/}
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "$timestamp $script_name WARN $1"
}

cli_debug() {
    if [ ! -z $VERBOSE ]; then
        script_name=${0##*/}
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "$timestamp $script_name DEBUG $1"
    fi
}