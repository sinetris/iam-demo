# TODO

[Project README](../README.md)

> Table of content

- [Documentation](#documentation)
  - [Better define project scope](#better-define-project-scope)
  - [Add Infrastructure overview](#add-infrastructure-overview)
  - [Add screenshots](#add-screenshots)
- [Install Applications](#install-applications)
  - [Compliance As Code](#compliance-as-code)
    - [Interesting projects](#interesting-projects)
- [Setup and configurations](#setup-and-configurations)
  - [Kubernetes resources labels and annotations](#kubernetes-resources-labels-and-annotations)
  - [Restructure Ansible](#restructure-ansible)
    - [ansible directory layout](#ansible-directory-layout)
- [Future changes](#future-changes)

## Documentation

### Better define project scope

This project is an implementation example of what is defined in [sinetris/iam-introduction](https://github.com/sinetris/iam-introduction).

Clarify that the tools selected are only used for the sake of semplicity (and in some cases not the best tools for the job) to cover certain topics.

Add an higher level of abstraction overview and place the tools in the appropriate sub-set.

### Add Infrastructure overview

### Add screenshots

## Install Applications

- [x] [Gitea][gitea]: a painless self-hosted Git service
- [x] [Keycloak][keycloak]: IAM, IdP and SSO
- [x] [Consul][consul]: zero trust networking
- [ ] [Harbor][harbor]: artifacts registry (for Docker images and OPA policies)
  - [ ] [Notary][notary]: trust over arbitrary collections of data
  - [ ] [Trivy][trivy]: vulnerability scanners
- [x] [Grafana][grafana]: dashboards for metrics, logs, tracing
- [x] [Prometheus][prometheus]: monitoring system (metrics)
- [x] [Alertmanager][alertmanager]: alerts handling
- [x] [Grafana Loki][grafana-loki]: multi-tenant log aggregation system
- [ ] [Grafana Tempo][grafana-tempo]: distributed tracing backend
- [ ] [Grafana OnCall][grafana-oncall]: on-call management system
- [ ] [Grafana k6][grafana-k6]: load testing tool
- [ ] [midPoint][midpoint]: Identity Governance and Administration
- [ ] [Drone][drone]: CI/CD pipelines as code
  - [ ] [Renovate][renovate]: automate dependency update
  - [ ] [Conftest][conftest]: use OPA policies to test configurations
- [ ] [Wazuh][wazuh]: unified XDR and SIEM protection for endpoints and cloud workloads
- [ ] [Hashicorp Vault][vault]: secrets management
- [ ] [HashiCorp Boundary][boundary]: simple and secure remote access
- [ ] [Waypoint][waypoint]: lower cognitive load for applications deployment
- [ ] [MailHog][mailhog]: Web and API based SMTP testing
- [ ] [Backstage][backstage]: open platform for building developer portals
- [ ] [Fleet][fleet]: device management (MDM)
- [ ] [Falco][falco]: threat detection
- [ ] [plantuml-server][plantuml-server]: diagrams as code
- [ ] [Restic][restic]: operating systems backup solution
- [ ] [Velero][velero]: Kubernetes resources and volumes backup solution
- [ ] [ERPNext][erpnext]: Enterprise Resource Planning
- [ ] [Community][community]: wiki and knowledge-base
- [ ] [Mattermost][mattermost]: Channels, Playbooks, Project & Task Management
- [ ] [Excalidraw][excalidraw]: An open source virtual hand-drawn style whiteboard.

**Note:** A missing tick means that the application has yet to be added.

### Compliance As Code

- [SCAP][scap]: Security Content Automation Protocol
- [OpenSCAP][open-scap]: Open-source Security Compliance Solution
  > NIST certified SCAP toolkit
- [OSCAL][oscal]: Open Security Controls Assessment Language
- [Trestle][trestle]: Manage compliance as code using NIST's OSCAL standard
- [Open Policy Agent (OPA)][opa]: Declarative Policy
  > Context-aware, Expressive, Fast, Portable
- [OPAL][opal]: Open Policy Administration Layer

#### Interesting projects

- [PacBot][pacbot]: Policy as Code Bot (by T-Mobile)
- [MagTape][magtape]: Policy-as-Code for Kubernetes (by T-Mobile)


## Setup and configurations

- [x] move postgres to [base](../kubernetes/base/)
  - [x] use `StatefulSet`
- [x] move redis to [base](../kubernetes/base/)
  - [x] use `StatefulSet` 
- [ ] Setup **Gitea**
  - [x] certificate for [git.iam-demo.test](https://git.iam-demo.test)
  - [x] use [base/postgres](../kubernetes/base/postgres)
  - [x] use [base/redis](../kubernetes/base//redis)
  - [x] setup ssh-git loadbalancer
  - [x] initialize database and create admin credentials
- [x] use `.test` tld for external domains
- [x] use a separate DNS server resolver for external domains (Bind9)
- [ ] generate Certificate in a proper way
  - [ ] check [Vault PKI documentation][vault-pki]
  - [ ] use [Build Certificate Authority (CA) in Vault with an offline Root][vault-external-ca] based on [Build your own certificate authority (CA)][vault-pki-engine]
  - [ ] check [CFSSL][cfssl] 
  - [ ] apply instructions for Kubernetes certificates
    - [ ] [Manage TLS Certificates in a Cluster][kubernetes-managing-tls]
    - [ ] [PKI certificates and requirements][kubernetes-pki-best-practices]
  - [x] ~~use in combination with [mkcert][mkcert] to install the root ca certs in client machines trust stores~~
      > not flexible enough for our usecase
  - [x] useful code to generate [CA + intermediate certificate][k3s-custom-ca] can be found in k3s
  - [ ] generate [Wazuh](../kubernetes/apps/wazuh/) certs using previously generated root CA certs
  - [x] install CA certificates chain in VMs
  - [x] test generated CA certificates for installed applications domains from the `linux-desktop` VM
- [ ] setup [pre-commit][pre-commit] for this project repository
- [ ] configure [Wazuh][wazuh]
  - [ ] generate amd64 and arm64 containers
  - [ ] push containers to registry
  - [ ] use new containers in Wazuh deployment
- [ ] configure [Consul][consul]
  - [ ] configure [Consul Service Mesh][consul-service-mesh]
  - [ ] configure [Consul API Gateway][consul-api-gateway]
  - [ ] check [Consul tutorials][consul-tutorials]
- [ ] create a `.internal` DNS zone (like in [AWS][aws-internal-tld] or [Google Cloud][google-cloud-internal-tld])
- [ ] separate generation of external (loadbalancer) and internal certificates
- [ ] [setup cert-manager to use Vault][cert-manager-vault]
- [ ] introduce [Envoy][envoy-proxy]
- [ ] use [age][age] (good and simple encryption tool) for secrets
- [ ] add proper [labels and annotations for Kubernetes resources](#kubernetes-resources-labels-and-annotations)
- [ ] configure [Loki][grafana-loki]
  - [ ] [Promtail][promtail]: agent to ships logs to Loki
  - [ ] configure dashboards in Grafana
- [ ] better configuration for [MinIO][minio]
  - [ ] save MinIO credentials in Kubernetes Secret 
  - [ ] use `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY` environment variables in services
- [ ] save secrets in [Vault][vault] (see [Kubernetes Secrets in Vault][vault-kubernetes-use-case])
- [ ] restructure [Ansible](../platform/ansible/) code
  - [ ] [ansible directory layout](#ansible-directory-layout)
  - [ ] create a dinamic Ansible inventory
  - [ ] follow [Good Practices for Ansible][ansible-good-practices]
- [ ] use [MetalLB][metallb] as load-balancer
- [ ] add [tfsec][tfsec] (terrafrom security scanners) in CI pipelines
- [ ] change Cluster Domain in [k3s server][k3s-server-doc] from `cluster.local` to `iam-demo.local`

### Kubernetes resources labels and annotations

Add proper labels and annotations to kubernetes resources.

Exanmple:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: postgres
    app.kubernetes.io/instance: gitea-potgres
    app.kubernetes.io/version: "14.4"
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: gitea
  annotations:
    a8r.io/chat: "#gitops-team-on-call"
    a8r.io/owner: "gitops-team@example.com"
```

For more for annotations examples, check [Annotating Kubernetes Services for Humans][ambassador-k8s-annotations].

Note that you can query `labels` to select resources, but you cannot query `annotations`, which are just arbitrary key/value information and are not intended to be used to filter resources.

It is still possible to query annotations using [JSONPath][k8s-jsonpath], but it will be slower and less practical.

```sh
# Return the name metadata for services that have the annotation 'prometheus.io/scrape' set to 'true'
kubectl get service -A -o jsonpath='{.items[?(@.metadata.annotations.prometheus\.io/scrape=="true")].metadata.name}'
# Return the namespace, name, and creationTimestamp metadata for pods that have the annotation 'checksum/config' set.
# We use 'range' to print each entry on its own line in the format "<namespace>/<name>[tab]<creationTimestamp>".
kubectl get pods -A -o jsonpath='{range .items[?(@.metadata.annotations.checksum/config)]}{.metadata.namespace}{"/"}{.metadata.name}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}'
```

### Restructure Ansible

#### ansible directory layout

```yaml
ansible.cfg
custom_roles/               # -- locally created roles --
  common/                   # role common to all hosts (hierarchy valid for all roles)
    tasks/                  # tasks files
      main.yaml             #  'main.yaml' can include other files
    handlers/               # handlers file
      main.yaml             #  'main.yaml' can include other files
    templates/              # files used with the template resource
      my_file.j2            #  (templates end in '.j2')
    files/                  # files to be copied as they are
      static.txt            #  (just an example)
    vars/                   # variables associated with this role
      main.yaml             #
    defaults/               # default lower priority variables for this role
      main.yaml             #
    meta/                   # role dependencies and optional info
      main.yaml             #
    library/                # roles can also include custom modules
    module_utils/           # roles can also include custom module_utils
    lookup_plugins/         # other types of plugins ('lookup' in this case)
  my_namespace.my_role/     # -- same structure as 'common' --
inventories/                # -- inventory files --
  production                # inventory file for production
  staging                   # inventory file for staging
  group_vars/               # groups configurations
    group1.yaml             # common configurations for group1 for all stages
    group2.yaml
    production_group1.yaml  # configurations for group1 for production
    production_group2.yaml
    staging_group1.yaml     # configurations for group1 for staging
    staging_group2.yaml
  host_vars/
    host-prod1.yaml
    host-prod2.yaml
    host-staging1.yaml
    host-staging2.yaml
playbooks/                  # -- playbook files --
  tasks/                    # shared tasks for playbooks
    task1.txt               #  (just an example)
    task2.txt               #  (just an example)
library/                    # -- custom modules (optional) --
module_utils/               # -- custom module_utils to support modules (optional) --
filter_plugins/             # -- filter plugins (optional) --
roles/                      # -- downloaded roles defined in 'requirements.yaml' --
  requirements.yaml
```

## Future changes

- [ ] use [Gitness][gitness] instead of [Gitea][gitea] and [Drone][drone]

[age]: <https://github.com/FiloSottile/age> "age"
[alertmanager]: <https://github.com/prometheus/alertmanager> "Alertmanager"
[ambassador-k8s-annotations]: <https://ambassadorlabs.github.io/k8s-for-humans/> "Annotating Kubernetes"
[ansible-good-practices]: <https://redhat-cop.github.io/automation-good-practices/> "Good Practices for Ansible"
[ansible-lint]: <https://ansible.readthedocs.io/projects/lint/> "Ansible Lint"
[ansible-lxd]: <https://docs.ansible.com/ansible/latest/collections/community/general/lxd_container_module.html> "Ansible lxd module"
[ansible]: <https://ansible.readthedocs.io/> "Ansible"
[aws-internal-tld]: <https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html> "AWS: DNS attributes for your VPC"
[backstage]: <https://github.com/backstage/backstage> "Backstage"
[boundary]: <https://www.boundaryproject.io/> "HashiCorp Boundary"
[cert-manager-vault]: <https://cert-manager.io/docs/configuration/vault/> "cert-manager Vault"
[cfssl]: <https://github.com/cloudflare/cfssl> "Cloudflare's PKI and TLS toolkit (CFSSL)"
[cloud-init-lxd-tests]: <https://github.com/canonical/cloud-init/blob/main/tests/integration_tests/modules/test_lxd.py> "cloud-init lxd tests"
[community]: <https://github.com/documize/community> "Community"
[conftest]: <https://github.com/open-policy-agent/conftest> "Conftest"
[consul-api-gateway]: <https://www.consul.io/docs/api-gateway> "Consul API Gateway"
[consul-service-mesh]: <https://developer.hashicorp.com/consul/docs/connect> "Consul Service Mesh"
[consul-tutorials]: <https://developer.hashicorp.com/consul/tutorials> "Consul tutorials"
[consul]: <https://www.consul.io/> "Consul"
[drone]: <https://www.drone.io/> "Drone"
[envoy-proxy]: <https://www.envoyproxy.io/docs/envoy/latest/intro/what_is_envoy> "Envoy proxy"
[erpnext]: <https://erpnext.com/> "ERPNext"
[excalidraw]: <https://github.com/excalidraw/excalidraw> "Excalidraw"
[external-dns-coredns]: <https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/coredns.md> "Using ExternalDNS with CoreDNS"
[external-dns]: <https://github.com/kubernetes-sigs/external-dns> "ExternalDNS"
[falco]: <https://falco.org/> "Falco"
[fleet]: <https://github.com/fleetdm/fleet> "Fleet"
[gitea]: <https://gitea.io/> "Gitea"
[gitness]: <https://gitness.com/> "Gitness"
[go-task]: <https://taskfile.dev/> "Task"
[google-cloud-internal-tld]: <https://cloud.google.com/compute/docs/internal-dns> "Google Cloud internal tld"
[grafana-k6]: <https://github.com/grafana/k6> "Grafana k6"
[grafana-loki]: <https://grafana.com/oss/loki/> "Grafana Loki"
[grafana-oncall]: <https://grafana.com/oss/oncall/> "Grafana OnCall"
[grafana-tempo]: <https://github.com/grafana/tempo> "Grafana Tempo"
[grafana]: <https://grafana.com/> "Grafana"
[harbor]: <https://goharbor.io/> "Harbor"
[k3s-custom-ca]: <https://raw.githubusercontent.com/k3s-io/k3s/master/contrib/util/generate-custom-ca-certs.sh> "k3s custom CA certs"
[k3s-server-doc]: <https://docs.k3s.io/cli/server> "k3s server documentation"
[k8s-jsonpath]: <https://kubernetes.io/docs/reference/kubectl/jsonpath/> "Kubernetes JSONPath documentation"
[keycloak]: <https://www.keycloak.org/> "Keycloak"
[kubectl]: <https://kubernetes.io/docs/reference/kubectl/> "Kubernetes CLI"
[kubernetes-managing-tls]: <https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/> "Kubernetes Manage TLS Certificates in a Cluster"
[kubernetes-pki-best-practices]: <https://kubernetes.io/docs/setup/best-practices/certificates/> "kubernetes PKI best practices"
[lxd]: <https://linuxcontainers.org/lxd/introduction/> "lxd"
[magtape]: <https://github.com/tmobile/magtape> "MagTape"
[mailhog]: <https://github.com/mailhog/MailHog> "MailHog"
[mattermost]: <https://mattermost.com/> "Mattermost"
[metallb]: <https://github.com/metallb/metallb> "MetalLB"
[midpoint]: <https://evolveum.com/midpoint/> "midPoint"
[minio]: <https://min.io/> "MinIO"
[mkcert]: <https://github.com/FiloSottile/mkcert> "mkcert"
[notary]: <https://github.com/notaryproject/notary> "Notary"
[opa]: <https://www.openpolicyagent.org/> "Open Policy Agent (OPA)"
[opal]: <https://github.com/permitio/opal> "Open Policy Administration Layer (OPAL)"
[open-scap]: <https://www.open-scap.org/> "OpenSCAP: NIST Certified SCAP 1.2 toolkit"
[oscal]: <https://pages.nist.gov/OSCAL/> "OSCAL"
[pacbot]: <https://github.com/tmobile/pacbot> "PacBot"
[plantuml-server]: <https://github.com/plantuml/plantuml-server> "plantuml-server"
[pre-commit]: <https://pre-commit.com> "pre-commit hooks"
[prometheus]: <https://grafana.com/oss/prometheus/> "Prometheus"
[promtail]: <https://grafana.com/docs/loki/latest/clients/promtail/> "Promtail"
[renovate]: <https://github.com/renovatebot/renovate> "Renovate"
[restic]: <https://restic.net/> "Restic"
[scap]: <http://scap.nist.gov/> "Security Content Automation Protocol"
[tfsec]: <https://github.com/liamg/tfsec> "tfsec"
[trestle]: <https://github.com/IBM/compliance-trestle> "Trestle"
[trivy]: <https://github.com/aquasecurity/trivy> "Trivy"
[vagrant]: <https://www.vagrantup.com/> "Vagrant"
[vault-external-ca]: <https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine-external-ca> "Vault external CA"
[vault-kubernetes-use-case]: <https://www.vaultproject.io/use-cases/kubernetes> "Kubernetes Secrets in Vault"
[vault-pki-engine]: <https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine> "Vault PKI engine"
[vault-pki]: <https://www.vaultproject.io/docs/secrets/pki> "Vault PKI"
[vault]: <https://www.vaultproject.io/> "HashiCorp Vault"
[velero]: <https://velero.io/> "Velero"
[virtualbox]: <https://www.virtualbox.org/> "VirtualBox"
[waypoint]: <https://www.waypointproject.io/> "Waypoint"
[wazuh]: <https://wazuh.com/> "Wazuh"
