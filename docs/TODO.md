# TODO

[Project README](../README.md)

> Table of content

- [Better define project scope](#better-define-project-scope)
- [Install Applications](#install-applications)
  - [Compliance As Code](#compliance-as-code)
    - [Interesting projects](#interesting-projects)
- [Setup and configurations](#setup-and-configurations)
  - [Kubernetes resources labels and annotations](#kubernetes-resources-labels-and-annotations)
  - [ansible directory layout](#ansible-directory-layout)

## Better define project scope

This project is an implementation example of what is defined in [sinetris/iam-introduction](https://github.com/sinetris/iam-introduction).

Clarify that the tools selected are only used for the sake of semplicity (and in some cases not the best tools for the job) to cover certain topics.

Add an higher level of abstraction overview and place the tools in the appropriate sub-set.

## Install Applications

- [x] [Gitea](https://gitea.io/): a painless self-hosted Git service
- [x] [Keycloak](https://www.keycloak.org/): IAM, IdP and SSO
- [x] [Hashicorp Vault](https://www.vaultproject.io/): secrets management
- [x] [Consul](https://www.consul.io/): zero trust networking
- [ ] [Harbor](https://goharbor.io/): artifacts registry (for Docker images and OPA policies)
  - [ ] [Notary](https://github.com/notaryproject/notary): trust over arbitrary collections of data
  - [ ] [Trivy](https://github.com/aquasecurity/trivy): vulnerability scanners
- [x] [Grafana](https://grafana.com/): dashboards for metrics, logs, tracing
- [x] [Prometheus](https://grafana.com/oss/prometheus/): monitoring system (metrics)
- [x] [Alertmanager](https://github.com/prometheus/alertmanager): alerts handling
- [ ] [Grafana Loki](https://grafana.com/oss/loki/): multi-tenant log aggregation system
  - [ ] [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/): agent to ships logs to Loki
- [ ] [Grafana Tempo](https://github.com/grafana/tempo): distributed tracing backend
- [ ] [Grafana OnCall](https://grafana.com/oss/oncall/): on-call management system
- [ ] [midPoint](https://evolveum.com/midpoint/): Identity Governance and Administration
- [ ] [Drone](https://www.drone.io/): CI/CD pipelines as code
  - [ ] [tfsec](https://github.com/liamg/tfsec): terrafrom security scanners
  - [ ] [renovate](https://github.com/renovatebot/renovate): automate dependency update
  - [ ] [Conftest](https://github.com/open-policy-agent/conftest): use OPA policies to test configurations
- [ ] [Wazuh](https://wazuh.com/): unified XDR and SIEM protection for endpoints and cloud workloads
- [ ] [Boundary](https://www.boundaryproject.io/): simple and secure remote access
- [ ] [Waypoint](https://www.waypointproject.io/): lower cognitive load for applications deployment
- [ ] [MailHog](https://github.com/mailhog/MailHog): Web and API based SMTP testing
- [ ] [Backstage](https://github.com/backstage/backstage): open platform for building developer portals
- [ ] [Fleet](https://github.com/fleetdm/fleet): device management (MDM)
- [ ] [Falco](https://falco.org/): threat detection
- [ ] [plantuml-server](https://github.com/plantuml/plantuml-server): diagrams as code
- [ ] [Restic](https://restic.net/): operating systems backup solution
- [ ] [Velero](https://velero.io/): Kubernetes resources and volumes backup solution
- [ ] [ERPNext](https://erpnext.com/): Enterprise Resource Planning
- [ ] [Community](https://github.com/documize/community): wiki and knowledge-base
- [ ] [Mattermost](https://mattermost.com/): Channels, Playbooks, Project & Task Management
- [ ] [Excalidraw](https://github.com/excalidraw/excalidraw): An open source virtual hand-drawn style whiteboard.

**Note:** A missing tick means that the application has yet to be added.

### Compliance As Code

- [SCAP][scap]: Security Content Automation Protocol
- [OpenSCAP][open-scap]: Open-source Security Compliance Solution
  > NIST certified SCAP toolkit
- [OSCAL](https://pages.nist.gov/OSCAL/): Open Security Controls Assessment Language
- [Trestle](https://github.com/IBM/compliance-trestle): Manage compliance as code using NIST's OSCAL standard
- [Open Policy Agent (OPA)](https://www.openpolicyagent.org/): Declarative Policy
  > Context-aware, Expressive, Fast, Portable
- [OPAL](https://github.com/permitio/opal): Open Policy Administration Layer

#### Interesting projects

- [PacBot](https://github.com/tmobile/pacbot): Policy as Code Bot (by T-Mobile)
- [MagTape](https://github.com/tmobile/magtape): Policy-as-Code for Kubernetes (by T-Mobile)


## Setup and configurations

- [x] move postgres to [base](../kubernetes/base/)
  - [x] use `StatefulSet`
- [x] move redis to [base](../kubernetes/base/)
  - [x] use `StatefulSet` 
- [ ] Setup **Gitea**
  - [x] certificate for [git.iam-demo.test](https://git.iam-demo.test)
  - [x] use [base/postgres](../kubernetes/base/postgres)
  - [x] use [base/redis](../kubernetes/base//redis)
  - [ ] initialize database and create admin credentials
- [x] use `.test` tld for external domains
- [x] use a separate DNS server resolver for external domains (Bind9)
- [ ] create a `.internal` DNS zone (like in [AWS][aws-internal-tld] or [Google Cloud][google-cloud-internal-tld])
- [ ] separate generation of external (loadbalancer) and internal certificates
- [ ] generate Certificate in a proper way
  - [ ] check [Vault PKI documentation][vault-pki]
  - [ ] use [Build Certificate Authority (CA) in Vault with an offline Root][vault-external-ca] based on [Build your own certificate authority (CA)][vault-pki-engine]
  - [ ] also check [cfssl](https://github.com/cloudflare/cfssl)
  - [ ] follow instructions from
        [Manage TLS Certificates in a Cluster][kubernetes-managing-tls]
        and [PKI certificates and requirements][kubernetes-pki-best-practices]
  - [x] ~~use in combination with [mkcert][mkcert] to install the root ca certs in client machines trust stores~~
        (not flexible enough for our usecase)
  - [x] useful code to generate [CA + intermediate certificate][k3s-custom-ca] can be found in k3s
- [x] install CA cherts chain in VMs
- [x] test generated CA certs for installed applications external domains from the `linux-desktop` VM
- [ ] [setup cert-manager to use Vault][cert-manager-vault]
- [ ] configure [Consul API Gateway](https://www.consul.io/docs/api-gateway)
  - [ ] follow the [API Gateway tutorial](https://learn.hashicorp.com/tutorials/consul/kubernetes-api-gateway)
  - [ ] and [other tutorials](https://learn.hashicorp.com/collections/consul/developer-mesh)
- [ ] introduce [Envoy](https://www.envoyproxy.io/docs/envoy/latest/intro/what_is_envoy)
- [ ] use [age][age]: good and simple encryption tool
- [ ] add proper `labels` and `annotations` (see [Kubernetes resources labels and annotations](#kubernetes-resources-labels-and-annotations))
- [ ] refactor [ansible directory layout](#ansible-directory-layout)
- [ ] follow [Good Practices for Ansible](https://redhat-cop.github.io/automation-good-practices/)
- [ ] use [MetalLB](https://github.com/metallb/metallb) as load-balancer

### Kubernetes resources labels and annotations

Add proper labels and annotations to kubernetes resources.

Exanmple:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: postgres
    app.kubernetes.io/instance: potgres-gitea
    app.kubernetes.io/version: "14.4"
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: gitea
  annotations:
    a8r.io/chat: "#gitops-team-on-call"
    a8r.io/owner: "gitops-team@example.com"
```

For more for annotations examples, check [Annotating Kubernetes Services for Humans](https://ambassadorlabs.github.io/k8s-for-humans/).

Note that you can query `labels` to select resources, but you cannot query `annotations`, which are just arbitrary key/value information and are not intended to be used to filter resources.

It is still possible to query annotations using [JSONPath](https://kubernetes.io/docs/reference/kubectl/jsonpath/), but it will be slower and less practical.

```sh
# Return the name metadata for services that have the annotation 'prometheus.io/scrape' set to 'true'
kubectl get service -A -o jsonpath='{.items[?(@.metadata.annotations.prometheus\.io/scrape=="true")].metadata.name}'
# Return the namespace, name, and creationTimestamp metadata for pods that have the annotation 'checksum/config' set.
# We use 'range' to print each entry on its own line in the format "<namespace>/<name>[tab]<creationTimestamp>".
kubectl get pods -A -o jsonpath='{range .items[?(@.metadata.annotations.checksum/config)]}{.metadata.namespace}{"/"}{.metadata.name}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}'
```

### ansible directory layout

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

[age]: <https://github.com/FiloSottile/age> "age"
[ambassador-k8s-annotations]: <https://ambassadorlabs.github.io/k8s-for-humans/> "Annotating Kubernetes"
[ansible]: <https://ansible.readthedocs.io/> "Ansible"
[ansible-lint]: <https://ansible.readthedocs.io/projects/lint/> "Ansible Lint"
[ansible-lxd]: <https://docs.ansible.com/ansible/latest/collections/community/general/lxd_container_module.html> "Ansible lxd module"
[aws-internal-tld]: <https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html> "AWS: DNS attributes for your VPC"
[cert-manager-vault]: <https://cert-manager.io/docs/configuration/vault/> "cert-manager Vault"
[cloud-init-lxd-tests]: <https://github.com/canonical/cloud-init/blob/main/tests/integration_tests/modules/test_lxd.py> "cloud-init lxd tests"
[consul-api-gateway]: <https://www.consul.io/docs/api-gateway> "Consul API Gateway"
[consul-api-gateway-tutorial]: <https://learn.hashicorp.com/tutorials/consul/kubernetes-api-gateway> "Consul API Gateway Tutorial"
[consul-mesh]: <https://learn.hashicorp.com/collections/consul/developer-mesh> "Consul Mesh"
[envoy-proxy]: <https://www.envoyproxy.io/docs/envoy/latest/intro/what_is_envoy> "Envoy proxy"
[external-dns]: <https://github.com/kubernetes-sigs/external-dns> "ExternalDNS"
[external-dns-coredns]: <https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/coredns.md> "Using ExternalDNS with CoreDNS"
[go-task]: <https://taskfile.dev/> "Task"
[google-cloud-internal-tld]: <https://cloud.google.com/compute/docs/internal-dns> "Google Cloud internal tld"
[k3s-custom-ca]: <https://raw.githubusercontent.com/k3s-io/k3s/master/contrib/util/generate-custom-ca-certs.sh> "k3s custom CA certs"
[kubectl]: <https://kubernetes.io/docs/reference/kubectl/> "Kubernetes CLI"
[kubernetes-managing-tls]: <https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/> "Kubernetes Manage TLS Certificates in a Cluster"
[kubernetes-pki-best-practices]: <https://kubernetes.io/docs/setup/best-practices/certificates/> "kubernetes PKI best practices"
[lxd]: <https://linuxcontainers.org/lxd/introduction/> "lxd"
[mkcert]: <https://github.com/FiloSottile/mkcert> "mkcert"
[open-scap]: <https://www.open-scap.org/> "OpenSCAP: NIST Certified SCAP 1.2 toolkit"
[pre-commit]: <https://pre-commit.com> "pre-commit hooks"
[scap]: <http://scap.nist.gov/> "Security Content Automation Protocol"
[vagrant]: <https://www.vagrantup.com/> "Vagrant"
[vault-external-ca]: <https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine-external-ca> "Vault external CA"
[vault-pki]: <https://www.vaultproject.io/docs/secrets/pki> "Vault PKI"
[vault-pki-engine]: <https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine> "Vault PKI engine"
[virtualbox]: <https://www.virtualbox.org/> "VirtualBox"
