#!/usr/bin/env bash
set -Eeo pipefail

declare -a available_clusters=()
declare -a available_tools=('kind' 'k3d')
declare -a selected_clusters
selected_tool='kind'

while IFS='' read -r line; do available_clusters+=("$line"); done < \
  <(find clusters -type d -maxdepth 1 -mindepth 1 -exec basename {} \;)

__usage=$(
  cat <<-END
    Usage: $(tput bold)$0 [OPTIONS]$(tput sgr0)

    Manage k8s clusters.

    Options:
      -b, --bootstrap                   Create clusters
      -p, --provision                   Provision clusters using the
      -d, --delete                      Delete clusters
      -t, --tool <tool>                 Tools to use to create clusters
        $(tput setaf 3)If tool is not set, default to: $(tput sgr0)$(tput setaf 6)$(tput bold)${selected_tool}$(tput sgr0)
        $(tput setaf 3)Available tools: $(tput sgr0)$(tput setaf 6)$(tput bold)${available_tools[*]}$(tput sgr0)
      -c, --clusters $(tput setaf 3)<CL1> <...> <CLn>  $(tput sgr0)Limit clusters to selected
        $(tput setaf 3)If clusters is not set, default to: $(tput sgr0)
          $(tput setaf 6)$(tput bold)${available_clusters[*]}$(tput sgr0)
      -h                                This help
END
)

function usage {
  echo -e "$__usage"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

function check_dependency {
  if ! [ -x "$(command -v "$1")" ]; then
    echo -e "$(tput setaf 2)Error: $(tput bold)$1$(tput sgr0)$(tput setaf 2) is not installed.$(tput sgr0)" >&2
    exit 1
  fi
}

function check_if_function_exist {
  declare -f "" >/dev/null
}

function create_cluster {
  local tool=$1
  local cluster_name=$2
  local cluster_context="${tool}-${cluster_name}"
  local cmd_output
  local exit_status
  check_dependency 'kubectl'
  cmd_output=$(kubectl cluster-info --context "${cluster_context}" 2>&1) && exit_status=$? || exit_status=$?
  echo "exit_status: '$exit_status'"
  local check="error: context \"${cluster_context}\" does not exist"
  if [[ $cmd_output =~ $check ]]; then
    check_dependency "$tool"
    echo -en "$(tput setaf 4)-- Creating clusters: $(tput bold)$cluster_name$(tput sgr0)$(tput setaf 4) using "
    echo -e "$(tput bold)$tool$(tput sgr0)\n"
    case $tool in
      kind)
        cluster_config_file="clusters_config/${cluster_name}.yaml"
        if [ -f "$cluster_config_file" ]; then
          echo "$(tput setaf 2)✓$(tput sgr0) Using: $cluster_config_file"
          kind create cluster --wait 5m --config="$cluster_config_file" --name "$cluster_name"
        else
          kind create cluster --wait 5m --name "$cluster_name"
        fi
        ;;
      k3d)
        k3d cluster create "$cluster_name"
        ;;
      *)
        echo -e "$(tput setaf 1)Cluster creation not implemented for $(tput bold)$1$(tput sgr0)" >&2
        exit 1
        ;;
    esac
  elif [ "$exit_status" -ne "0" ]; then
    echo -e "$(tput setaf 1)kubectl error for $(tput bold)$cluster_name$(tput sgr0).\n" >&2
    echo -e "$(tput setaf 5)$cmd_output$(tput sgr0).\n" >&2
    exit 2
  else
    echo -e "$(tput setaf 3)Cluster $(tput setaf 6)$(tput bold)$cluster_name$(tput sgr0)$(tput setaf 3) already exist$(tput sgr0)"
  fi
}

function cluster_provisioning {
  local cluster_name=$1
  check_dependency 'kubectl'
  echo "$(tput setaf 3)Provisioning $(tput setaf 6)$(tput bold)$cluster_name$(tput sgr0)"
  kubectl kustomize "clusters/$cluster_name"
  kubectl apply -k "clusters/$cluster_name"
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s
}

function delete_cluster {
  local tool=$1
  local cluster_name=$2
  # change in generic function
  echo kind delete cluster --name "${cluster_name}"
  case $tool in
    kind)
      kind delete cluster --name "$cluster_name"
      ;;
    k3d)
      k3d cluster delete "$cluster_name"
      ;;
    *)
      echo -e "$(tput setaf 1)Cluster creation not implemented for $(tput bold)$1$(tput sgr0)" >&2
      exit 1
      ;;
  esac
}

function array_contains_element {
  local array="$1[@]"
  local seeking=$2
  local contained
  local element
  contained=1
  for element in "${!array}"; do
    if [[ $element == "$seeking" ]]; then
      contained=0
      break
    fi
  done
  return $contained
}

function chech_clusters {
  local _selected_clusters="$1[@]"
  local _available_clusters="$2[@]"
  local element
  for element in "${!_selected_clusters}"; do
    if ! array_contains_element "$_available_clusters" "$element"; then
      echo -en "$(tput setaf 1)Cluster $(tput bold)$element$(tput sgr0)" >&2
      echo -e "$(tput setaf 1) not present in $(tput bold)${!_available_clusters}$(tput sgr0)" >&2
      return 0
    fi
  done
  return 1
}

function clusters_bootstrap {
  local clusters="$1[@]"
  local cluster
  echo -e "$(tput setaf 3)Bootsrapping Clusters: $(tput setaf 6)$(tput bold)${!clusters}$(tput sgr0)"
  for cluster in "${!clusters}"; do
    echo -e "$(tput setaf 3)Bootsrap: $(tput setaf 6)$(tput bold)${cluster}$(tput sgr0)"
    create_cluster "${selected_tool}" "${cluster}"
  done
}

function clusters_provisioning {
  local clusters="$1[@]"
  local cluster
  echo -e "$(tput setaf 3)Provisioning Clusters: $(tput setaf 6)$(tput bold)${!clusters}$(tput sgr0)"
  for cluster in "${!clusters}"; do
    cluster_provisioning "${cluster}"
  done
}

function clusters_delete {
  local clusters="$1[@]"
  local cluster
  echo -e "$(tput setaf 3)Deleting Clusters: $(tput setaf 6)$(tput bold)${!clusters}$(tput sgr0)"
  for cluster in "${!clusters}"; do
    echo -e "$(tput setaf 3)Deleting Clusters: $(tput setaf 6)$(tput bold)${cluster}$(tput sgr0)"
    delete_cluster "${selected_tool}" "${cluster}"
  done
}

bootstrap=false
provision=false
delete=false
all_available_clusters=true
while [ "$1" != "" ]; do
  case $1 in
    -d | --delete)
      shift
      delete=true
      ;;
    -b | --bootstrap)
      shift
      bootstrap=true
      ;;
    -t | --tool)
      shift
      if array_contains_element available_tools "$1"; then
        selected_tool="$1"
        shift
      else
        echo -en "$(tput setaf 1)Tool $(tput bold)$1$(tput sgr0)" >&2
        echo -e "$(tput setaf 1) not present in $(tput bold)${available_tools[*]}$(tput sgr0)" >&2
        usage
        exit 1
      fi
      ;;
    -c | --clusters)
      shift
      while [ "$1" != "" ]; do
        if [[ "${1::1}" == "-" ]]; then
          break
        else
          all_available_clusters=false
          selected_clusters+=("$1")
          shift
        fi
      done
      ;;
    -p | --provision)
      shift
      provision=true
      ;;
    -h | --help)
      shift
      usage
      exit 0
      ;;
    *)
      echo -e "$(tput setaf 1)Unexpected argument: $(tput bold)$1$(tput sgr0)" >&2
      usage
      exit 1
      ;;
  esac
done

if $all_available_clusters; then
  selected_clusters=("${available_clusters[@]}")
else
  echo "checking ${selected_clusters[*]}"
  if chech_clusters selected_clusters available_clusters; then
    usage
    exit 1
  fi
fi
if $delete; then
  clusters_delete selected_clusters
  exit 0
fi
if $bootstrap; then
  clusters_bootstrap selected_clusters
fi
if $provision; then
  clusters_provisioning selected_clusters
fi

exit 0
