# Troubleshooting Kubernetes

[Back to README](README.md)

## Inspect pods

```sh
# select the pod you want to access
pod_namespace=tools
pod_labels=app.kubernetes.io/instance=gitea,app.kubernetes.io/name=gitea
# extract the pod name
pod_name=$(kubectl get pods -n "${pod_namespace}" -l "${pod_labels}" -o jsonpath="{.items[0].metadata.name}")
# check logs
kubectl logs -n "${pod_namespace}" "${pod_name}"
# describe pod
kubectl describe pod -n "${pod_namespace}" "${pod_name}"
# access the pod shell
kubectl exec  --stdin --tty -n "${pod_namespace}" "${pod_name}" -- /bin/bash
```

## Start a throw away pod

```sh
kubectl run postgres-tmp -n tools --rm -i --tty --image "postgres:16.2" -- /bin/bash
```

In case the pod isn't automatically deleted, delete it using:

```sh
kubectl delete -n tools pod postgres-tmp
```
