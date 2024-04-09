#!/bin/bash

HOME_DIR=$(cd "$(dirname "$0")" || exit; pwd)
CONF_DIR=${HOME_DIR}/conf
UTILS_DIR=${HOME_DIR}/utils

source ${UTILS_DIR}/colorprint.sh

# 全局配置信息，必须依赖外部传入
export DOMAIN="${DOMAIN}"
export CF_TOKEN_DNS="${CF_TOKEN_DNS}"
export ZONE_ID="${ZONE_ID}"
export CF_Key="${CF_Key}"
export CF_Email="${CF_Email}"
export GIST_V2RAY_TOKEN="${GIST_V2RAY_TOKEN}"
export GIST_ID="${GIST_ID}"

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