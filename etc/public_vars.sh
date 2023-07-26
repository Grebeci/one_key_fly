#!/bin/bash

HOME_DIR=$(cd "$(dirname "$0")" || exit; pwd)
ETC_DIR=${HOME_DIR}/etc
source "${ETC_DIR}"/colorprint.sh

export V2RAY_PORT="60822"
export V2RAY_PASSWORD="${V2RAY_PASSWORD:-$(uuid)}"
export VPS_IP="${VPS_IP}"
export SQUID_HTTPS_PORT="22806"
export DOMAIN="${DOMAIN}"
export CF_Key="${CF_Key}"
export CF_Email="${CF_Email}"
export LOCALNET="${LOCALNET}"
export CF_TOKEN_DNS="${CF_TOKEN_DNS}"
export ZONE_ID="${ZONE_ID}"

export VULTR_API_KEY="${VULTR_API_KEY}"
export REGION_ID="${REGION_ID}"

# Given any number of parameters, check if there is a value for each parameter
function check_vars() {

    local VARIABLES=("$@")
    local empty_count=0

    for var in "${VARIABLES[@]}"; do
    value=$(eval echo \$$var)
    if [ -z "$value" ]; then
        _err "$var is empty"
        # if there is no value, let user input
        empty_count=$((empty_count + 1))
    else
        _info "$var has value: $value"
    fi
    done

    [[ $empty_count -ge 1 ]] && return 1
    return 0
}

#function check_vars () {
#    VARIABLES=( "VPS_IP" "V2RAY_POER" "V2RAY_PASSWORD")
#    empty_count=0
#
#    for var in "${VARIABLES[@]}"; do
#    value=$(eval echo \$$var)
#    if [ -z "$value" ]; then
#        _err "$var is empty"
#        empty_count=$((empty_count + 1))
#    else
#        echo "$var has value: $value"
#    fi
#    done
#    [[ $empty_count -ge 1 ]] && return 1
#}
#
#function check_vars() {
#    VARIABLES=("V2RAY_POER" "SQUID_HTTPS_PORT" "DOMAIN" "CF_Key" "CF_Email" "LOCALNET" "CF_TOKEN_DNS" "ZONE_ID" "V2RAY_PASSWORD"  "VULTR_API_KEY" "REGION_ID")
#    empty_count=0
#
#    for var in "${VARIABLES[@]}"; do
#    value=$(eval echo \$$var)
#    if [ -z "$value" ]; then
#        _err "$var is empty"
#        empty_count=$((empty_count + 1))
#    else
#        echo "$var has value: $value"
#    fi
#    done
#    [[ $empty_count -ge 1 ]] && return 1
#}
#
#check_vars_domain() {
#    VARIABLES=("DOMAIN" "CF_Key" "CF_Email" "LOCALNET" "CF_TOKEN_DNS" "ZONE_ID" "V2RAY_PASSWORD")
#    empty_count=0
#
#    for var in "${VARIABLES[@]}"; do
#    value=$(eval echo \$$var)
#    if [ -z "$value" ]; then
#        _err "$var is empty"
#        empty_count=$((empty_count + 1))
#    else
#        echo "$var has value: $value"
#    fi
#    done
#    [[ $empty_count -ge 1 ]] && return 1
#}