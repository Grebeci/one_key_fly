#!/bin/bash

export VULTR_API_KEY=""
function vps_firewall_strategy() {

  
  curl "https://api.vultr.com/v2/domains" \
  -X GET \
  -H "Authorization: Bearer ${VULTR_API_KEY}"
}

