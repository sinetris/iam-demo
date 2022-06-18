#!/usr/bin/env bash
set -Eeo pipefail

project="iam-demo"

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
      -s, --setup                       Install requirements
      -b, --bootstrap                   Create clusters
      -p, --provision                   Provision clusters using the
      -d, --delete                      Delete clusters
      -t, --tool <tool>                 Tools to use to create clusters
        $(tput setaf 3)If tool is not set, default to: $(tput sgr0)$(tput setaf 6)$(tput bold)${selected_tool}$(tput sgr0)
        $(tput setaf 3)Available tools: $(tput sgr0)$(tput setaf 6)$(tput bold)${available_tools[*]}$(tput sgr0)
      -c, --clusters $(tput setaf 3)<CL1> <...> <CLn>  $(tput sgr0)Limit clusters to selected
        $(tput setaf 3)If clusters is not set, default to: $(tput sgr0)
          $(tput setaf 6)$(tput bold)${available_clusters[*]}$(tput sgr0)
      --add-ca                          Install development CA locally
      -h, --help                        This help
END
)

function usage {
  echo -e "$__usage"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

green_tick="$(tput setaf 2)$(tput bold)✓$(tput sgr0)"

function check_dependency {
  if ! [ -x "$(command -v "$1")" ]; then
    echo -e "$(tput setaf 2)Error: $(tput bold)$1$(tput sgr0)$(tput setaf 2) is not installed.$(tput sgr0)" >&2
    exit 1
  fi
}

dev_ca_certs_path="$HOME/.dev_ca_certs"
dev_ca_certs_path_crt="${dev_ca_certs_path}/${project}.crt.pem"
dev_ca_certs_path_key="${dev_ca_certs_path}/${project}.key.pem"

function generate_certs {
  local cluster_name=$1
  local domains_certs_path="./data/certs/domains"
  local domain="${project}"'.test'
  local current_dir
  current_dir=$(pwd)
  echo -e "Project ${project} - Generate or use CA certs in '${dev_ca_certs_path}'"
  echo -e "Generate certs for ${domain} in '${domains_certs_path}'"
  mkdir -p "${dev_ca_certs_path}"
  mkdir -p "${domains_certs_path}"
  if ! [ -d "${domains_certs_path}/${domain}" ]; then
    cd "${domains_certs_path}" \
      && /usr/local/bin/minica \
        -ca-cert "${dev_ca_certs_path_crt}" \
        -ca-key "${dev_ca_certs_path_key}" \
        -domains "${domain}",'*.'"${domain}" \
      && chmod -vR go-rwx "${dev_ca_certs_path}" \
      && cd "${current_dir}"
  fi
}

function add_ca_locally_mac {
  # Add project CA cert to KeyChain
  security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db "${dev_ca_certs_path_crt}"
}

function create_cluster {
  local tool=$1
  local cluster_name=$2
  local cluster_context="${tool}-${cluster_name}"
  local cmd_output
  local exit_status
  check_dependency 'kubectl'
  cmd_output=$(kubectl cluster-info --context "${cluster_context}" 2>&1) && exit_status=$? || exit_status=$?
  local check="error: context \"${cluster_context}\" does not exist"
  if [[ $cmd_output =~ $check ]]; then
    check_dependency "$tool"
    echo -en "$(tput setaf 4)-- Creating clusters: $(tput bold)$cluster_name$(tput sgr0)$(tput setaf 4) using "
    echo -e "$(tput bold)$tool$(tput sgr0)"
    case $tool in
      kind)
        cluster_config_file="clusters_config/${tool}/${cluster_name}.yaml"
        if [ -f "$cluster_config_file" ]; then
          echo "${green_tick} Using: $cluster_config_file"
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

function project_setup_mac {
  check_dependency 'brew'
  if command -v docker &>/dev/null; then
    echo "- docker ${green_tick}"
  else
    # Install via Homebrew
    brew install docker
  fi
  if brew list $selected_tool &>/dev/null; then
    echo "- $selected_tool ${green_tick}"
  else
    # Install via Homebrew
    brew install $selected_tool
  fi
  if brew list docker-mac-net-connect &>/dev/null; then
    echo "- docker-mac-net-connect ${green_tick}"
  else
    # Install via Homebrew
    brew install chipmk/tap/docker-mac-net-connect
    # Run the service and register it to launch at boot
    brew services restart chipmk/tap/docker-mac-net-connect
  fi
  if command -v kubectl &>/dev/null; then
    echo "- kubectl ${green_tick}"
  else
    # Install via Homebrew
    brew install kubectl
  fi
  if brew list minica &>/dev/null; then
    echo "- minica ${green_tick}"
  else
    # Install via Homebrew
    brew install minica
  fi
}

function cluster_provisioning {
  local tool=$1
  local cluster_name=$2
  local cluster_context="${tool}-${cluster_name}"
  check_dependency 'kubectl'
  echo "$(tput setaf 3)Provisioning $(tput setaf 6)$(tput bold)$cluster_name$(tput sgr0)"
  generate_certs "$cluster_name"
  kubectl kustomize "clusters/$cluster_name"  --context "${cluster_context}"
  kubectl apply --context "${cluster_context}" -k "clusters/$cluster_name"
  kubectl wait --context "${cluster_context}" --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s
}

function delete_cluster {
  local tool=$1
  local cluster_name=$2
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
  contained=false
  for element in "${!array}"; do
    if [[ $element == "$seeking" ]]; then
      contained=true
      break
    fi
  done
  $contained
}

function chech_clusters {
  local _selected_clusters="$1[@]"
  local _available_clusters="$2[@]"
  local element
  valid_clusters=true
  for element in "${!_selected_clusters}"; do
    if ! array_contains_element "$_available_clusters" "$element"; then
      echo -en "$(tput setaf 1)Cluster $(tput bold)$element$(tput sgr0)" >&2
      echo -e "$(tput setaf 1) not present in available clusters: $(tput bold)${!_available_clusters}$(tput sgr0)" >&2
      valid_clusters=false
    fi
  done
  $valid_clusters
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
    cluster_provisioning "$selected_tool" "${cluster}"
  done
}

function clusters_delete {
  local clusters="$1[@]"
  local cluster
  echo -e "$(tput setaf 3)Clusters to delete: $(tput setaf 6)$(tput bold)${!clusters}$(tput sgr0)"
  for cluster in "${!clusters}"; do
    delete_cluster "${selected_tool}" "${cluster}"
  done
}

setup=false
bootstrap=false
provision=false
delete=false
add_ca_locally=false
all_available_clusters=true
while [ "$1" != "" ]; do
  case $1 in
    -s | --setup)
      shift
      setup=true
      ;;
    -b | --bootstrap)
      shift
      bootstrap=true
      ;;
    -p | --provision)
      shift
      provision=true
      ;;
    -d | --delete)
      shift
      delete=true
      ;;
    -t | --tool)
      shift
      if array_contains_element available_tools "$1"; then
        selected_tool="$1"
        shift
      else
        echo -en "$(tput setaf 1)Tool $(tput bold)$1$(tput sgr0)" >&2
        echo -e "$(tput setaf 1) not present in available tools: $(tput bold)${available_tools[*]}$(tput sgr0)" >&2
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
    --add-ca)
      shift
      add_ca_locally=true
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
  echo "Checking clusters $(tput bold)${selected_clusters[*]}$(tput sgr0)"
  if ! chech_clusters selected_clusters available_clusters; then
    usage
    exit 1
  fi
fi
if $delete; then
  clusters_delete selected_clusters
  exit 0
fi
if $setup; then
  echo "$(tput bold)Setup$(tput sgr0)"
  case "$OSTYPE" in
    darwin*) project_setup_mac ;;
    *)
      echo "Setup step not implemented for '$OSTYPE'"
      echo "Please install docker, $selected_tool, kubectl"
      ;;
  esac
fi
if $add_ca_locally; then
  echo "Adding CA to local host"
  case "$OSTYPE" in
    darwin*) add_ca_locally_mac ;;
    *) echo "Step not implemented for '$OSTYPE'" ;;
  esac
fi
if $bootstrap; then
  clusters_bootstrap selected_clusters
fi
if $provision; then
  clusters_provisioning selected_clusters
fi

exit 0
