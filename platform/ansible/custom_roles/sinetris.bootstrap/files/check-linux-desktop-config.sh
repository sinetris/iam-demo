#!/usr/bin/env bash
set -Eeuo pipefail

base_domain=iam-demo.test
check_hostnames_on_port=( \
  'iam-control-plane 6443' \
  'git 443' \
  'grafana 443' \
  'prometheus 443' \
  'alertmanager 443' \
  'consul 443' \
  'keycloak 443' \
)

bold_text=$(tput bold)
good_result_text=$(tput setaf 2)
bad_result_text=$(tput setaf 3)
info_result_text=$(tput setaf 4)
reset_text=$(tput sgr0)
for hostname_and_port in "${check_hostnames_on_port[@]}"; do
  splitted_host_port=( $hostname_and_port )
  fqdn_to_check=${splitted_host_port[0]}.${base_domain}
  port_to_check=${splitted_host_port[1]}
  echo "${info_result_text}Check ${bold_text}${fqdn_to_check}:${port_to_check}${reset_text}"
  cmd_output=$(echo | openssl s_client -showcerts -servername ${fqdn_to_check} \
      -connect "${fqdn_to_check}:${port_to_check}" 2>/dev/null \
      | openssl x509 -inform pem -noout -nocert -checkhost ${fqdn_to_check} 2>/dev/null) \
    && exit_status=$? || exit_status=$?
  if [[ $cmd_output =~ "does match certificate" ]]; then
    echo " ${bold_text}${good_result_text}[OK]${reset_text}"
    echo "   '${good_result_text}${fqdn_to_check}${reset_text}' on port '${good_result_text}${port_to_check}${reset_text}'"
  elif [ "${exit_status}" -ne "0" ]; then
    echo " ${bold_text}${bad_result_text}[Error]${reset_text}"
    echo "   ${bad_result_text}Can not check certificate for${reset_text} '${bold_text}${bad_result_text}${fqdn_to_check}:${port_to_check}${reset_text}'"
  else
    echo " ${bold_text}${bad_result_text}[Error]${reset_text}"
    echo "   '${bad_result_text}${cmd_output}${reset_text}'"
  fi
done
