# IAM Demo

Identity and Access Management (IAM) demo infrastructure.

## Start the cluster

**Setup** - _Tested on a MacBook with Intel processor and macOS Monteray_

```bash
# Install dependencies and create certificates
./bunch-up --setup
# Start and configure clusters and DNS resolvers for .test domains
./bunch-up --bootstrap
# Provision resources in the clusters
./bunch-up --provision
```

## Applications

- [x] [Gitea](https://gitea.io/): a painless self-hosted Git service
- [x] [Keycloak](https://www.keycloak.org/): IAM, IdP and SSO
- [x] [Vault](https://www.vaultproject.io/): secrets management
- [x] [Consul](https://www.consul.io/): zero trust networking
- [ ] [Open Policy Agent (OPA)](https://www.openpolicyagent.org/): general-purpose policy engine
- [ ] [Harbor](https://goharbor.io/): artifacts registry (for Docker images and OPA policies)
  - [x] [Notary](https://github.com/notaryproject/notary): trust over arbitrary collections of data
  - [ ] [Trivy](https://github.com/aquasecurity/trivy): vulnerability scanners
- [x] [Grafana](https://grafana.com/): dashboards for metrics, logs, tracing
- [ ] [Prometheus](https://grafana.com/oss/prometheus/): monitoring system (metrics)
- [x] [Grafana Loki](https://grafana.com/oss/loki/): multi-tenant log aggregation system
  - [ ] [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/): agent to ships logs to Loki
- [ ] [Grafana Tempo](https://github.com/grafana/tempo): distributed tracing backend
- [ ] [Grafana OnCall](https://grafana.com/oss/oncall/): on-call management system
- [ ] [Concourse CI](https://concourse-ci.org/): CI/CD pipelines as code
  - [ ] [tfsec](https://github.com/liamg/tfsec): terrafrom security scanners
  - [ ] [renovate](https://github.com/renovatebot/renovate): automate dependency update
  - [ ] [Conftest](https://github.com/open-policy-agent/conftest): use OPA policies to test configurations
- [ ] [Wazuh](https://wazuh.com/): unified XDR and SIEM protection for endpoints
and cloud workloads
- [ ] [plantuml-server](https://github.com/plantuml/plantuml-server):  diagrams as code
- [ ] [Boundary](https://www.boundaryproject.io/): simple and secure remote access
- [ ] [Waypoint](https://www.waypointproject.io/): lower applications lifecicle cognitive load
- [ ] [MailHog](https://github.com/mailhog/MailHog): Web and API based SMTP testing
- [ ] [Fleet](https://github.com/fleetdm/fleet): UEM/MDM
- [ ] [Falco](https://falco.org/): threat detection
- [ ] [ERPNext](https://erpnext.com/): Enterprise Resource Planning
- [ ] [Community](https://github.com/documize/community): wiki and knowledge-base
- [ ] [Mattermost](https://mattermost.com/): Channels, Playbooks, Project & Task Management
- [ ] [midPoint](https://evolveum.com/midpoint/): Identity Governance

## To Do

- [ ] generate PKI in a proper way
  - [ ] check [Vault documentation](https://www.vaultproject.io/docs/secrets/pki)
  - [ ] also check [cfssl](https://github.com/cloudflare/cfssl)
  - [ ] follow instructions from
        [Manage TLS Certificates in a Cluster](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
        and [PKI certificates and requirements](https://kubernetes.io/docs/setup/best-practices/certificates/)
  - [ ] use in combination with [mkcert](https://github.com/FiloSottile/mkcert) to make local development easier
- [ ] configure [Consul API Gateway](https://www.consul.io/docs/api-gateway)
  - [ ] follow the [API Gateway tutorial](https://learn.hashicorp.com/tutorials/consul/kubernetes-api-gateway)
  - [ ] and [other tutorials](https://learn.hashicorp.com/collections/consul/developer-mesh)
- [ ] introduce [Envoy](https://www.envoyproxy.io/docs/envoy/latest/intro/what_is_envoy)
- [ ] use [age](https://github.com/FiloSottile/age), a good and simple encryption tool


## Troubleshooting

A good start is [Monitoring, Logging, and Debugging](https://kubernetes.io/docs/tasks/debug/) in [Kubernetes Documentation](https://kubernetes.io/docs/home/).

### Debugging DNS Resolution

From your host you can check if a domain can be resolved properly using:

```bash
# Example: check if we can resolve "git.iam-demo.test"
dscacheutil -q host -a name git.iam-demo.test
```

To check from inside your cluster, start a pod and run commands from it:

```bash
# Start the pod
kubectl apply -f https://k8s.io/examples/admin/dns/dnsutils.yaml
# Verify that it's running
kubectl get pods dnsutils
# Check if it can resolve the domain (for example: "git.iam-demo.test")
kubectl exec -i -t dnsutils -- nslookup git.iam-demo.test
# There is also a nice project that include the most used tools.
# If you don't want (or are not allowed) to run "untrusted" images, you can create
# your own starting from the source code from https://github.com/nicolaka/netshoot
kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot
```

More info can be found in the Kubernetes documentation in [Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/).
