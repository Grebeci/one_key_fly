#!/bin/bash

export V2RAY_POER="60822"
export SQUID_HTTPS_PORT="22806"
export DOMAIN="${DOMAIN}"
export CF_Key="${CF_Key}"
export CF_Email="${CF_Email}"
export LOCALNET="219.143.130.34/8"
export CF_TOKEN_DNS="${CF_TOKEN_DNS}"
export ZONE_ID="${ZONE_ID}"

function check_vars() {
    VARIABLES=("V2RAY_POER" "VASQUID_HTTPS_PORTR2" "DOMAIN" "CF_Key" "CF_Email" "LOCALNET" "CF_TOKEN_DNS" "ZONE_ID")
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
check_vars