#!/bin/bash

export V2RAY_POER="60822"
export SQUID_HTTPS_PORT="22806"
export DOMAIN="${DOMAIN}"
export CF_Key="${CF_Key}"
export CF_Email="${CF_Email}"
export LOCALNET="${LOCALNET}"
export CF_TOKEN_DNS="${CF_TOKEN_DNS}"
export ZONE_ID="${ZONE_ID}"
export V2RAY_PASSWORD="${V2RAY_PASSWORD:-$(uuid)}" 
export VULTR_API_KEY="${VULTR_API_KEY}"

function check_vars_vps() {
    VARIABLES=("V2RAY_POER" "SQUID_HTTPS_PORT" "DOMAIN" "CF_Key" "CF_Email" "LOCALNET" "CF_TOKEN_DNS" "ZONE_ID" "V2RAY_PASSWORD")
    empty_count=0

    for var in "${VARIABLES[@]}"; do
    value=$(eval echo \$$var)
    if [ -z "$value" ]; then
        echo "$var is empty"
        empty_count=$((empty_count + 1))
    else
        echo "$var has value: $value"
    fi
    done
    [[ $empty_count -ge 1 ]] && exit 2
}

function check_vars() {
    VARIABLES=("V2RAY_POER" "SQUID_HTTPS_PORT" "DOMAIN" "CF_Key" "CF_Email" "LOCALNET" "CF_TOKEN_DNS" "ZONE_ID" "V2RAY_PASSWORD"  "VULTR_API_KEY")
    empty_count=0

    for var in "${VARIABLES[@]}"; do
    value=$(eval echo \$$var)
    if [ -z "$value" ]; then
        echo "$var is empty"
        empty_count=$((empty_count + 1))
    else
        echo "$var has value: $value"
    fi
    done
    [[ $empty_count -ge 1 ]] && exit 2
}