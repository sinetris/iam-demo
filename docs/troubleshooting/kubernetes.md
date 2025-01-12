# Troubleshooting Kubernetes

[Back to README](README.md)

- [Check K3S](#check-k3s)
- [Inspect pods](#inspect-pods)
  - [Inspect crashing pods](#inspect-crashing-pods)
- [Start a throw away pod](#start-a-throw-away-pod)
- [Helm](#helm)
  - [List Environment Variables](#list-environment-variables)
  - [List chart repositories](#list-chart-repositories)
  - [List all releases](#list-all-releases)
  - [Generate yaml values and templates](#generate-yaml-values-and-templates)
- [Kustomize](#kustomize)

## Check K3S

```sh
k3s check-config
```

## Inspect pods

```sh
# Examples to select the pod you want to access
# - Forgejo
pod_namespace=tools
pod_labels=app.kubernetes.io/instance=forgejo,app.kubernetes.io/name=forgejo
pod_container=configure-forgejo
# - consul
pod_namespace=tools
pod_labels=app=consul,component=server
# - grafana
pod_namespace=observability
pod_labels=app.kubernetes.io/name=grafana

# extract the pod name
pod_name=$(kubectl get pods -n "${pod_namespace:?}" -l "${pod_labels:?}" -o jsonpath="{.items[0].metadata.name}")

# check logs
kubectl logs -n "${pod_namespace:?}" "${pod_name:?}"
# describe pod
kubectl describe pod -n "${pod_namespace:?}" "${pod_name:?}"
# access the pod shell
kubectl exec  --stdin --tty -n "${pod_namespace:?}" "${pod_name:?}" --container="${pod_container:-}" -- /bin/sh
```

### Inspect crashing pods

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-service
spec:
  containers:
  - name: my-instance
    # keep the image you want to debug, we use 'ubuntu:latest' as an example
    image: ubuntu:latest
      # add/replace 'command' and 'args'
      # Do nothing so we can debug (troubleshooting-start) ->
      command: [ "/bin/bash", "-c", "--" ]
      args: [ "while true; do sleep 30; done;" ]
      # <- (troubleshooting-end)
```

## Start a throw away pod

```sh
kubectl run postgres-tmp -n tools --rm -i --tty --image "postgres:16.2" -- /bin/bash
```

In case the pod isn't automatically deleted, delete it using:

```sh
kubectl delete -n tools pod postgres-tmp
```

## Helm

To get help for Helm commands, you can use  `helm [command] [sub-command] --help`.

Examples:

```sh
helm --help
helm show --help
helm show values --help
# etc.
```

### List Environment Variables

To list all available environment variables (and their default values, if not
overridden), you can use:

```sh
helm env
```

### List chart repositories

Chart repositories are installed from the Ansible controller.

Connect to the `ansible-controller` instance and run:

```sh
helm repo list
```

### List all releases

You can list releases from any machine that can connect to the kubernetes cluster.

By default, `helm list` will show `deployed` releases in the `default`
namespace.

To list releases in any status (deployed, failed, pending, etc.) from all the
namespaces, use:

```sh
helm list --all-namespaces --all
```

### Generate yaml values and templates

You can easily display default `values.yaml` for a specific chart version.

Example:

```sh
helm show values loki --repo https://grafana.github.io/helm-charts --version '5.43.3' > loki-defaults.yaml
```

To generate Helm chart `values.yaml` and resources files, you can use the
following script as an example:

```sh
# begin configuration ->
# - Select the Helm chart -
helm_repo_name=grafana
helm_chart_name=loki
helm_repo_url=https://grafana.github.io/helm-charts
# - Select release name and namespace -
release_name=loki
release_namespace=observability
# <- end configuration

# - Set variables -
generated_chart_path=.tmp/${release_name:?}
generated_default_values_file=${generated_chart_path:?}/default-values.yaml
generated_release_values_file=${generated_chart_path:?}/release-values.yaml
generated_override_values_file=${generated_chart_path:?}/override-values.yaml

# - Extract Helm Chart values from existing release -
helm get values --namespace ${release_namespace:?} ${release_name:?} > ${generated_release_values_file:?}

# - Generate Helm Chart default values from new repo -
mkdir --verbose --parent ${generated_chart_path:?}
helm repo add ${helm_repo_name:?} ${helm_repo_url:?}
helm repo update
helm show values "${helm_repo_name:?}/${helm_chart_name:?}" > ${generated_default_values_file:?}

# - Copy Helm Chart default values to override values (if file doesn't exist) -
[ ! -f "${generated_override_values_file:?}" ] \
  && cp ${generated_default_values_file:?} ${generated_override_values_file} \
  || echo "Skipping! File '${generated_override_values_file}' already exist."

# - Generate resources yaml files using override values -
helm template \
  ${release_name:?} "${helm_repo_name:?}/${helm_chart_name:?}" \
  --namespace ${release_namespace:?} \
  --create-namespace \
  --dependency-update \
  --include-crds \
  --validate \
  -f ${generated_override_values_file:?} \
  --output-dir ${generated_chart_path:?}
```

## Kustomize

SSH into `ansible-controller` and move into `/kubernetes` folder:

```sh
./platform/vm-generator/generated/vm-shell.sh ansible-controller
cd /kubernetes
```

Apply a folder:

```sh
# select resource folder
kustomization_resource=apps/registry-stack/
# dry-run
kustomize build ${kustomization_resource:?} | kustomize cfg cat
# apply
kustomize build ${kustomization_resource:?} | kubectl apply -f -
# delete
kustomize build ${kustomization_resource:?} | kubectl delete -f -
```
