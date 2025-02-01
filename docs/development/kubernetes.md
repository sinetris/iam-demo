# Kubernetes development tips

[Back to README](README.md)

- [Labels and Annotations](#labels-and-annotations)
  - [Add proper labels and annotations](#add-proper-labels-and-annotations)
  - [Querying Annotations](#querying-annotations)

## Labels and Annotations

Both **labels** and **annotations** are metadata in key/value string pairs attached
to objects, where the key is unique to each object.

The main difference is that **labels are intended to specify identifying
attributes** to filter, group, or operate on resources and is easy and efficient
to work with them using [label query selectors][k8s-labels-selectors].

In short, labels are optimized for filtering resources and thus have more
constraints, whereas annotations are intended to contain additional
non-identifying information (used, for example, also by humans) and have fewer
constraints but, as a result, may be less efficient when queried.

Note that annotations can also be used by tools (see, for example,
[Annotated Ingress in cert-manager][cert-manager-annotated-ingress]).

### Add proper labels and annotations

The annotations and labels keys consist of two segments: a prefix (optional) and
a name, separated by a slash (`/`). If specified, the prefix must be a DNS subdomain.

The use of `kubernetes.io` and `k8s.io` domains and subdomains as prefixes is
reserved. When adding non-standard labels and annotations, it is advisable to
omit the prefix or use your own domain. In the following example we omit the
prefix for the `environment` label and use the domain `iam-demo.test` as a prefix
for internal annotations.

```yaml
metadata:
  labels:
    environment: production
    app.kubernetes.io/name: postgres
    app.kubernetes.io/instance: forgejo-postgres
    app.kubernetes.io/version: "16"
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: forgejo
  annotations:
    iam-demo.test/chat: "#gitops-team-on-call"
    iam-demo.test/owner: "gitops-team@iam-demo.test"
```

Check [Recommended Labels][k8s-common-labels] in [Kubernetes Documentation][k8s-docs].

For more annotations examples, check [Annotating Kubernetes Services for Humans][ambassador-k8s-annotations].

### Querying Annotations

You can query annotations using [JSONPath][k8s-jsonpath], it may be slower and
less practical, but it has its use cases.

> **Note:**\
> The use of dots (`.`) has a special meaning in JSONPath and we must use a
> backslash (`\`) to escape them in annotations keys.\
> For example, `prometheus.io/scrape` becomes `prometheus\.io/scrape`.

Here are a couple of examples:

- Return the `name` metadata for services that have the `prometheus.io/scrape`
  annotation set to `true`.

  ```ShellSession
  user@host:~$ kubectl get service -A -o jsonpath='{.items[?(@.metadata.annotations.prometheus\.io/scrape=="true")].metadata.name}'
  kube-dns prometheus-kube-state-metrics prometheus-prometheus-node-exporter
  ```

- Return the `namespace`, `name`, and `creationTimestamp` metadata for pods that
  have the annotation `checksum/config` set.\
  We use `range` to print each entry on its own line in the format
  `<namespace>/<name>[tab]<creationTimestamp>`.

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
[k8s-labels-selectors]: <https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/> "Kubernetes - Labels and Selectors"
[cert-manager-annotated-ingress]: <https://cert-manager.io/docs/usage/ingress/> "cert-manager Annotated Ingress resource"
