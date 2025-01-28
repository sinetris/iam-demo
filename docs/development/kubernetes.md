# Kubernetes development tips

[Back to README](README.md)

- [Labels and Annotations](#labels-and-annotations)
  - [Querying Annotations Examples](#querying-annotations-examples)

## Labels and Annotations

Add proper labels and annotations to kubernetes resources.

Exanmple:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: postgres
    app.kubernetes.io/instance: forgejo-postgres
    app.kubernetes.io/version: "16"
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: forgejo
  annotations:
    a8r.io/chat: "#gitops-team-on-call"
    a8r.io/owner: "gitops-team@example.com"
```

Check [Recommended Labels][k8s-common-labels] in [Kubernetes Documentation][k8s-docs].

For more annotations examples, check [Annotating Kubernetes Services for Humans][ambassador-k8s-annotations].

You can query `labels` to select resources, but `annotations`, which are just
arbitrary key/value information, are not intended to be queried to filter resources.

In short, `labels` are optimised for automation and therefore have more
constraints, whereas `annotations` are intended to contain information for humans
and have fewer constraints but, as a result, can be less efficient when queried.

### Querying Annotations Examples

You can query annotations using [JSONPath][k8s-jsonpath], it may be slower and
less practical, but it has its use cases.

Here are a couple of examples:

Return the `name` metadata for services that have the `prometheus.io/scrape`
annotation set to `true`.

```ShellSession
user@host:~$ kubectl get service -A -o jsonpath='{.items[?(@.metadata.annotations.prometheus\.io/scrape=="true")].metadata.name}'
kube-dns prometheus-kube-state-metrics prometheus-prometheus-node-exporter
```

> **Note:**\
> When the annotation key contains a dot (`.`), a backslash (`\`) must be used to
> escape it.\
> For example, `prometheus.io/scrape` becomes `prometheus\.io/scrape`.

Return the `namespace`, `name`, and `creationTimestamp` metadata for pods that
have the annotation `checksum/config` set.

We use `range` to print each entry on its own line in the format `<namespace>/<name>[tab]<creationTimestamp>`.

```ShellSession
user@host:~$ kubectl get pods -A -o jsonpath='{range .items[?(@.metadata.annotations.checksum/config)]}{.metadata.namespace}{"/"}{.metadata.name}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}'
kubernetes-dashboard/kubernetes-dashboard-api-56b7bf465b-6987g	2025-01-22T00:44:31Z
kubernetes-dashboard/kubernetes-dashboard-auth-7449d65877-cs5pm	2025-01-22T00:44:31Z
observability/loki-0	2025-01-27T11:53:18Z
observability/loki-gateway-747d4f745d-pc74w	2025-01-27T11:53:18Z
observability/prometheus-grafana-5cc7498664-98mxr	2025-01-25T09:34:22Z
tools/minio-0	2025-01-21T15:06:16Z
```

[ambassador-k8s-annotations]: <https://ambassadorlabs.github.io/k8s-for-humans/> "Annotating Kubernetes"
[k8s-docs]: <https://kubernetes.io/docs/home/> "Kubernetes Documentation"
[k8s-jsonpath]: <https://kubernetes.io/docs/reference/kubectl/jsonpath/> "Kubernetes JSONPath documentation"
[k8s-common-labels]: <https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/> "Kubernetes - Recommended Labels"
