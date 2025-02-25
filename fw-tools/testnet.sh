#!/usr/bin/env bash
#
# Copyright (c) 2022 Izuma Networks
# 
# Check connectivity to Izuma Cloud services
# - Via multiple ports (443, 5864)
# - Please note for bootstrap and LwM2M by default 5864 (CoAP)
#   is used, but Client/Edge has config "CUSTOM_PORT" which
#   allows you to use port 443 as well.
# - k8s and gateway service is available only via port 443.
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_DIR="$SCRIPT_DIR/credentials"
temp=$(mktemp -d /tmp/IzumaNetTest-XXXXX)
bootT=$temp/bootstrap.txt
k8T=$temp/k8s.txt
gwT=$temp/gateway.txt
LWT=$temp/test-lwm2m.txt
L3T=$temp/layer3.txt
L4T=$temp/layer4.txt

VERBOSE=0
DONTDELETE=0

port=5684
NORM="\u001b[0m"
#BOLD="\u001b[1m"
#REV="\u001b[7m"
#UND="\u001b[4m"
#BLACK="\u001b[30m"
RED="\u001b[31m"
GREEN="\u001b[32m"
YELLOW="\u001b[33m"
#BLUE="\u001b[34m"
#MAGENTA="\u001b[35m"
#MAGENTA1="\u001b[35m"
#MAGENTA2="\u001b[35m"
#MAGENTA3="\u001b[35m"
#CYAN="\u001b[36m"
#WHITE="\u001b[37m"
#ORANGE="$YELLOW"
#ERROR="${REV}Error:${NORM}"

clihelp::success() {
    echo -e "[${GREEN}   OK   ${NORM}]\t$1"
}
clihelp::failure() {
    echo -e "[${RED} FAILED ${NORM}]\t$1"
}
clihelp::warning() {
    echo -e "[${YELLOW}  WARN   ${NORM}]\t$1"
}

verbose() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo "$1"
    fi
}

test_bootstrap() {
    verbose "Test bootstrap server connection (port $port)"
    verbose "--------------------------------------------"
    verbose "Uses openssl to connect to bootstrap server using device credentials."
    verbose "Write openssl output to $bootT."
    echo | openssl s_client -CAfile "$CRED_DIR/bootstrap.pem" -key "$CRED_DIR/device01_key.pem" -cert "$CRED_DIR/device01_cert.pem" -connect tcp-bootstrap.us-east-1.mbedcloud.com:"$port" 2>"$bootT" >"$bootT"

    # get openssl return code
    RESULT=$(grep 'Verify return code' "$bootT")
    if [ -z "$RESULT" ]; then
        clihelp::failure "openssl failed with: $(cat "$bootT")"
    fi
    # print result
    CODE=$(echo "$RESULT" | awk -F' ' '{print $4}')
    if [ "$CODE" = 0 ]; then
        clihelp::success "TLS to bootstrap server (port $port)"
    else
        clihelp::failure "TLS to bootstrap server (port $port)"
        echo "--------------"
        echo "$RESULT"
        echo "--------------"
    fi
}

test_lwm2m() {
    verbose "Test LwM2M server connection (port $port)"
    verbose "----------------------------------------"
    verbose "Uses openssl to connect to LwM2M server using device credentials."
    verbose "Write openssl output to $LWT."
    echo | openssl s_client -CAfile "$CRED_DIR/lwm2m.pem" -key "$CRED_DIR/device01_key.pem" -cert "$CRED_DIR/device01_cert.pem" -connect lwm2m.us-east-1.mbedcloud.com:"$port" 2>"$LWT" >"$LWT"
    # get openssl return code
    RESULT=$(grep "Verify return code" "$LWT")

    if [ -z "$RESULT" ]; then
        clihelp::failure "openssl failed with: $(cat "$LWT")"
        exit
    fi
    # print result
    CODE=$(echo "$RESULT" | awk -F' ' '{print $4}')

    if [ "$CODE" = 0 ]; then
        clihelp::success "TLS to LwM2M server (port $port)"
    else
        clihelp::failure "TLS to LwM2M server (port $port)"
        echo "--------------"
        echo "$RESULT"
        echo "--------------"
    fi
}

test_k8s() {
    verbose "Test k8s server connection (port $port)"
    verbose "-------------------------------------"
    verbose "Uses openssl to connect to k8s server."
    verbose "Write openssl output to $k8T."
    echo | openssl s_client -connect k8s.us-east-1.mbedcloud.com:"$port" 2>"$k8T" >"$k8T"

    # get openssl return code
    RESULT=$(grep 'Verify return code' "$bootT")
    if [ -z "$RESULT" ]; then
        clihelp::failure "openssl failed with: $(cat "$k8T")"
    fi
    # print result
    CODE=$(echo "$RESULT" | awk -F' ' '{print $4}')
    if [ "$CODE" = 0 ]; then
        clihelp::success "TLS to k8s server (port $port)"
    else
        clihelp::failure "TLS to k8s server (port $port)"
        echo "--------------"
        echo "$RESULT"
        echo "--------------"
    fi
}

test_gateway() {
    verbose "Test gateway server connection (port $port)"
    verbose "------------------------------------------"
    verbose "Uses openssl to connect to gateway server."
    verbose "Write openssl output to $gwT."
    echo | openssl s_client -connect gateways.us-east-1.mbedcloud.com:"$port" 2>"$gwT" >"$gwT"

    # get openssl return code
    RESULT=$(grep 'Verify return code' "$gwT")
    if [ -z "$RESULT" ]; then
        clihelp::failure "openssl failed with: $(cat "$gwT")"
    fi
    # print result
    CODE=$(echo "$RESULT" | awk -F' ' '{print $4}')
    if [ "$CODE" = 0 ]; then
        clihelp::success "TLS to gateway server (port $port)"
    else
        clihelp::failure "TLS to gateway server (port $port)"
        echo "--------------"
        echo "$RESULT"
        echo "--------------"
    fi
}


test_L3() {
    _url() {
        if [[ $(ping -q -c 1 "$1" >>"$L3T" 2>&1) -eq 0 ]]; then
            clihelp::success "ping $1"
        else
            clihelp::failure "ping $1"
        fi
    }
    verbose "Test Layer 3 (requires icmp ping)"
    verbose "---------------------------------"
    _url bootstrap.us-east-1.mbedcloud.com
    _url lwm2m.us-east-1.mbedcloud.com
}

test_L4() {
    _nc() {
        if [[ $(nc -v -w 1 "$1" "$2" >>"$L4T" 2>&1) -eq 0 ]]; then
            clihelp::success "netcat $1 $2"
        else
            clihelp::failure "netcat $1 $2"
        fi
    }
    verbose "Test Layer 4 (requires nc)"
    verbose "--------------------------"
    _nc bootstrap.us-east-1.mbedcloud.com 443
    _nc bootstrap.us-east-1.mbedcloud.com 5684
    _nc lwm2m.us-east-1.mbedcloud.com 443
    _nc lwm2m.us-east-1.mbedcloud.com 5684
    _nc k8s.us-east-1.mbedcloud.com 443
    _nc gateways.us-east-1.mbedcloud.com 443
}

main() {
    test_L3
    test_L4
    test_bootstrap
    test_lwm2m
    port=443
    test_bootstrap
    test_lwm2m
    # K8S and Gateway server only operate on port 443
    test_k8s
    test_gateway
    if [[ "$DONTDELETE" -eq 0 ]]; then
        rm -rf "$temp"
    else
        echo "Your files are preserved at $temp"
    fi
}

displayHelp() {
    echo "Usage: $0 -options"
    echo "  -d do not delete temporary storage"
    echo "  -v verbose output"
    exit
}

argprocessor() {
    while getopts "hHdv" optsin; do
        case "${optsin}" in
            #
            d) DONTDELETE=1 ;;
            #
            h) displayHelp ;;
            #
            H) displayHelp ;;
            #
            v) VERBOSE=1 ;;
            #
            \?)
                echo -e "Option -$OPTARG not allowed.\n "
                displayHelp
                ;;
                #
        esac
    done
    shift $((OPTIND - 1))
    if [[ $# -ne 0 ]]; then
        displayHelp
    else
        shift
        main "$@"
    fi
}
argprocessor "$@"
