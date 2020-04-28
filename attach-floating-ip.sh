#!/bin/bash
#
# This script will contact UpCloud API and attaches the
# floating IP to the interface it's currently configured in.
#
# This script uses curl and jq, so they need to be installed on the system it is run in.
#
# Antti Myyrä (antti.myyra@upcloud.com / @gmail.com)
# License: MIT, https://tldrlegal.com/license/mit-license
#

function valid_ipv4()
{
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function program_availability()
{
    local PROGRAM=$1

    if ! command -v $PROGRAM > /dev/null; then
        echo "Program $PROGRAM not available in \$PATH, is it installed?"
        exit 1
    fi
}

program_availability ip
program_availability curl
program_availability jq

UPCLOUD_CREDENTIALS_FILE=$HOME/.upcloud-credentials

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 FLOATING_IP"
    echo "Example: $0 1.2.3.4"
    exit 1
fi

FLOATING_IP=$1
if ! valid_ipv4 $FLOATING_IP; then
    echo "Invalid IPv4 address: $FLOATING_IP"
    exit 1
fi

if [[ ! -f $UPCLOUD_CREDENTIALS_FILE ]]; then
    echo "UpCloud credentials file not available, unable to proceed."
    echo "Create the following file: $UPCLOUD_CREDENTIALS_FILE"
    echo
    echo "Credentials should be configured in this format:"
    echo "API_USERNAME=replace_with_username"
    echo "API_PASSWORD=replace_with_password"

    exit 1
fi

source $UPCLOUD_CREDENTIALS_FILE
if [ -z "$API_USERNAME" ]; then
    echo "API_USERNAME not defined in $UPCLOUD_CREDENTIALS_FILE"
    exit 1
fi
if [ -z "$API_PASSWORD" ]; then
    echo "API_PASSWORD not defined in $UPCLOUD_CREDENTIALS_FILE"
    exit 1
fi

CUR_IFACE=""
IP_FOUND=0
IP_ADDRS=$(ip a|grep -E 'inet|state')
IFS=$'\n'
for LINE in $IP_ADDRS
do
        if [[ $LINE == *"state"* ]]; then
            CUR_IFACE=$(echo $LINE|cut -d':' -f2|tr -d ' ')
        fi

        if [[ $LINE == *"$FLOATING_IP"* ]]; then
            IP_FOUND=1
            break
        fi
done

if [ $IP_FOUND == 0 ]; then
    echo "Floating ip not found from server interfaces. Is it configured?"
    exit 1
fi

MAC=$(cat /sys/class/net/$CUR_IFACE/address)
if [ $? != 0 ]; then
    echo "Unable to fetch MAC address for interface $CUR_IFACE"
    exit 1
fi

echo "Attaching floating IP $FLOATING_IP to server interface $CUR_IFACE (MAC: $MAC)"
PATCH_DATA='{"ip_address":{"mac":"'"$MAC"'"}}'

API_RESPONSE=$(echo $PATCH_DATA|curl -s --write-out "HTTPSTATUS:%{http_code}" -u "$API_USERNAME:$API_PASSWORD" -X PATCH -H "Content-Type:application/json" --data-binary @- https://api.upcloud.com/1.3/ip_address/$FLOATING_IP)
if [ $? != 0 ]; then
    echo "API request failed. Please check your network connectivity & DNS settings."
    exit 1
fi

HTTP_BODY=$(echo $API_RESPONSE | sed -e 's/HTTPSTATUS\:.*//g')
HTTP_STATUS=$(echo $API_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ $HTTP_STATUS -eq 202 ]; then
    echo "Floating IP successfully attached to $MAC"
else
    ERR_MSG=$(echo $HTTP_BODY|jq .error.error_message)
    echo "API returned an error with status $HTTP_STATUS"
    echo "Error message: $ERR_MSG"
fi
