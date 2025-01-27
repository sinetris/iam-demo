# TODO

[Project README](../README.md)

> Table of content

- [Documentation](#documentation)
  - [Project scope](#project-scope)
  - [Add Warning](#add-warning)
  - [Add an Infrastructure overview](#add-an-infrastructure-overview)
  - [Add Development instructions](#add-development-instructions)
  - [Add screenshots](#add-screenshots)
  - [Internal DNS server](#internal-dns-server)
- [Setup and configurations](#setup-and-configurations)
  - [Install Applications](#install-applications)
  - [Basic setup](#basic-setup)
  - [Compliance As Code](#compliance-as-code)
  - [Kubernetes resources labels and annotations](#kubernetes-resources-labels-and-annotations)
- [Future changes and alternatives](#future-changes-and-alternatives)
  - [Excluded Applications](#excluded-applications)
  - [Change configuration](#change-configuration)
    - [Basic changes](#basic-changes)
    - [Restructure Ansible code](#restructure-ansible-code)
      - [ansible directory layout](#ansible-directory-layout)
    - [Restructure Kubernetes code](#restructure-kubernetes-code)
      - [kubernetes directory layout](#kubernetes-directory-layout)
  - [Optional applications](#optional-applications)
    - [Interesting projects](#interesting-projects)
  - [Alternative to linux-desktop virtual machine](#alternative-to-linux-desktop-virtual-machine)
    - [Browser from host machine](#browser-from-host-machine)

## Documentation

The README should:

- [ ] be concise
- [ ] include a [warning](#add-warning)
- [ ] have a better description of the [project scope](#project-scope)
- [ ] include a link to this document
- [ ] contain links to the main topics covered in the project documentation folder
- [ ] include [FOSSA badge on GitHub][fossa-github-badge-pr]

The documentation folder should:

- [ ] have an [infrastructure overview](#add-an-infrastructure-overview)
- [ ] include [development instructions](#add-development-instructions)
- [ ] include [screenshots](#add-screenshots)

### Project scope

This project is an implementation example of what will be defined in
[sinetris/iam-introduction](https://github.com/sinetris/iam-introduction).

Add an overview and place the tools used in the appropriate sub-set.

Clarify that the tools selected are only used for the sake of semplicity (and
in some cases not the best tools for the job) to cover certain topics.

### Add Warning

Add a warning like the folowing in the [README](../README.md):

> **Warnings**
>
> This project, for the time being, is not intended to have any backward
> compatibility.
>
> Virtual machines are often destroyed and recreated.\
> Kubernetes resources are renamed, removed, modified, in ways that could
> compromise previous deployments.

### Add an Infrastructure overview

### Add Development instructions

- [ ] Hardware Requirements
- [ ] Dependencies
  - [Jsonnet][jsonnet]
  - [Windows App (aka: Microsoft Remote Desktop)][microsoft-remote-desktop]
  - [Multipass][multipass]
  - [pre-commit][pre-commit]

### Add screenshots

- [ ] Linux Desktop
  - [x] Terminal execute `~/bin/check-vm-config.sh`
  - [ ] Firefox bookmarks
  - [ ] Alertmanager
  - [x] Consul
  - [ ] Grafana
  - [ ] Forgejo
  - [ ] Keycloak
  - [ ] Mailpit
  - [x] midPoint
  - [ ] MinIO
  - [x] Prometheus
  - [x] Terrakube
  - [x] Vault
  - [ ] Traefik Dashboard
  - [x] Kubernetes Dashboard
- [x] Ansible Controller

### Internal DNS server

- [ ] document usage of `.internal` tld
- [ ] when using a real (owned) domains
  - [ ] ensure external DNS servers do not resolve internal domains
        (avoid cache problems)

## Setup and configurations

### Install Applications

- [x] [Forgejo][forgejo]: self-hosted Git service
- [x] [Keycloak][keycloak]: IAM, IdP and SSO
- [x] [Hashicorp Vault][vault]: secrets management
- [x] [Consul][consul]: zero trust networking
- [x] [Trivy][trivy]: vulnerability scanners
- [x] [Grafana][grafana]: dashboards for metrics, logs, tracing
- [x] [Prometheus][prometheus]: monitoring system (metrics)
- [x] [Alertmanager][alertmanager]: alerts handling
- [x] [Grafana Loki][grafana-loki]: multi-tenant log aggregation system
- [x] [Grafana Tempo][grafana-tempo]: distributed tracing backend
- [x] [Terrakube][terrakube]: Open source IaC Automation and Collaboration Software-
- [x] [midPoint][midpoint]: Identity Governance and Administration
- [ ] [Grafana OnCall][grafana-oncall]: on-call management system
- [ ] [Grafana k6][grafana-k6]: load testing tool
- [ ] [Wazuh][wazuh]: unified XDR and SIEM protection for endpoints and cloud workloads
- [ ] [HashiCorp Boundary][boundary]: simple and secure remote access
- [ ] [Waypoint][waypoint]: lower cognitive load for applications deployment
- [x] [Mailpit][mailpit]: Web and API based SMTP testing
- [ ] [Backstage][backstage]: open platform for building developer portals
- [ ] [Fleet][fleet]: device management (MDM)
- [ ] [ERPNext][erpnext]: Enterprise Resource Planning
- [ ] [Kyverno][kyverno]: Policy-as-Code (PaC) lifecycle for Kubernetes

> **Note:**
>
> - a missing tick means that the application has yet to be added
> - many applications still need to be [configured](#setup-and-configurations)
> - some applications have been moved to [Excluded Applications](#excluded-applications)

### Basic setup

- [x] move Postgres to [base](../kubernetes/base/)
  - [x] use `StatefulSet`
  - [x] use [Postgres base](../kubernetes/base/postgres/) in services
- [x] move Redis to [base](../kubernetes/base/)
  - [x] use `StatefulSet`
  - [x] use [Redis base](../kubernetes/base/redis/) in services
- [ ] setup **Forgejo**
  - [x] certificate for [git.iam-demo.test](https://git.iam-demo.test)
  - [x] use [base/postgres](../kubernetes/base/postgres)
  - [x] use [base/redis](../kubernetes/base//redis)
  - [x] setup ssh-git loadbalancer
  - [x] initialize database and create admin credentials
  - [ ] ensure the [Container Registry][forgejo-container-registry] is working properly
  - [ ] setup Keycloak as IdP
  - [ ] [Renovate][renovate]: automate dependency update
  - [ ] [Conftest][conftest]: use OPA policies to test configurations
  - [x] ensure all instances of Gitea are replaced by Forgejo (where possible)
- [x] use `.test` tld for external domains
- [x] use a separate DNS server resolver for external domains (Bind9)
- [ ] generate certificates in a proper way
  - [ ] check [Vault PKI documentation][vault-pki]
  - [ ] use [Build Certificate Authority (CA) in Vault with an offline Root][vault-external-ca]
        based on [Build your own certificate authority (CA)][vault-pki-engine]
  - [ ] check [CFSSL][cfssl]
  - [ ] apply instructions for Kubernetes certificates
    - [ ] [Manage TLS Certificates in a Cluster][kubernetes-managing-tls]
    - [ ] [PKI certificates and requirements][kubernetes-pki-best-practices]
  - [ ] ~~use in combination with [mkcert][mkcert] to install the root ca
        certs in client machines trust stores~~
      > not flexible enough for our usecase
  - [x] useful code to generate [CA + intermediate certificate][k3s-custom-ca]
        can be found in k3s
  - [ ] generate [Wazuh](../kubernetes/apps/wazuh/) certs using previously
        generated root CA certs
  - [x] install CA certificates chain in VMs
  - [x] test generated CA certificates for installed applications domains from
        the `linux-desktop` VM
- [x] setup [pre-commit][pre-commit] for this project repository
- [ ] configure [Loki][grafana-loki], [Prometheus][prometheus],
      [Grafana][grafana], [Tempo][grafana-tempo]
  - [x] install [Grafana Agent Flow][grafana-agent-flow] (DEPRECATED)
  - [x] replace [Grafana Agent Flow][grafana-agent-flow] with [Grafana Alloy][grafana-alloy]
  - [ ] use [Promtail][promtail] agent to ships logs to Loki from VMs
  - [ ] configure dashboards in Grafana
  - [x] use MinIO credentials and endpoint from Secret in Loki
  - [x] use MinIO credentials and endpoint from Secret in Tempo
- [ ] configure [Wazuh][wazuh]
  - [ ] generate arm64 and amd64 containers
  - [ ] push containers to internal registry
  - [ ] use new containers in Wazuh deployment
- [ ] configure [Consul][consul]
  - [ ] configure [Consul Service Mesh][consul-service-mesh]
  - [ ] configure [Consul API Gateway][consul-api-gateway]
  - [ ] check [Consul tutorials][consul-tutorials]
  - [ ] configure [Vault as the Secrets Backend for Consul][consul-vault]
- [ ] configure [Trivy][trivy]
  - [ ] configure [Trivy Policy Reporter Integration][trivy-policy-reporter] to
        send vulnerability and audit reports to [Loki as target in Policy Report][policy-reporter-loki]
- [ ] separate generation of external (loadbalancer) and internal certificates
- [ ] [setup cert-manager to use Vault][cert-manager-vault]
- [ ] use [age][age] (good and simple encryption tool) for secrets
- [ ] add proper [labels and annotations for Kubernetes resources](#kubernetes-resources-labels-and-annotations)
- [x] use separate [MinIO][minio] deployment
  - [x] move endpoints from to ConfigMap
  - [x] save MinIO credentials in Kubernetes Secret
- [ ] setup [FOSSA][fossa] and [.fossa.yml][fossa-yml] for the project repo
- [ ] setup `linux-desktop`
  - Firefox bookmarks
    - [x] add link to [Loki memberlist](https://loki.iam-demo.test/memberlist)
    - [x] add link to [Mailpit](https://mailpit.iam-demo.test)
    - [x] add link to [midPoint](https://midpoint.iam-demo.test)
    - [x] add link to [Terrakube UI](https://terrakube-ui.iam-demo.test)
    - [x] update link to [Kubernetes Dashboard](https://localhost:8443)

### Compliance As Code

- [ ] [OpenSCAP][open-scap]: Open-source Security Compliance Solution
  > NIST certified [SCAP][scap] toolkit
- [ ] [OSCAL][oscal]: Open Security Controls Assessment Language
- [ ] [Trestle][trestle]: Manage compliance as code using NIST's OSCAL standard
- [ ] [Open Policy Agent (OPA)][opa]: Declarative Policy
  > Context-aware, Expressive, Fast, Portable
- [ ] [OPAL][opal]: Open Policy Administration Layer

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

For more annotations examples, check [Annotating Kubernetes Services for Humans][ambassador-k8s-annotations].

Note that you can query `labels` to select resources, but you cannot query|
`annotations`, which are just arbitrary key/value information and are not
intended to be used to filter resources.

It is still possible to query annotations using [JSONPath][k8s-jsonpath], but
it will be slower and less practical.

```sh
# Return the name metadata for services that have the annotation 'prometheus.io/scrape' set to 'true'
kubectl get service -A -o jsonpath='{.items[?(@.metadata.annotations.prometheus\.io/scrape=="true")].metadata.name}'
# Return the namespace, name, and creationTimestamp metadata for pods that have the annotation 'checksum/config' set.
# We use 'range' to print each entry on its own line in the format "<namespace>/<name>[tab]<creationTimestamp>".
kubectl get pods -A -o jsonpath='{range .items[?(@.metadata.annotations.checksum/config)]}{.metadata.namespace}{"/"}{.metadata.name}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}'
```

## Future changes and alternatives

### Excluded Applications

- ~~[Harbor][harbor]: artifacts registry (for Docker images and OPA policies)~~\
  Harbor require too much work to deploy on ARM64 and we can use the already
  deployed [Forgejo OCI registry][forgejo-container-registry]
- ~~[Notary][notary]: trust over arbitrary collections of data~~
- ~~[Drone][drone]: CI/CD pipelines as code~~\
  Excluded because of the license change and the creation of [Gitness][gitness]
  (to be evalued)
- ~~[Gitea][gitea]: a painless self-hosted Git service~~\
  Excluded because domains and trademark of Gitea were transferred to a for-profit
  company without knowledge or approval of the community.\
  Switching to [Forgejo][forgejo-compare-to-gitea]
- ~~[MailHog][mailhog]: Web and API based SMTP testing~~\
  Not maintained anymore. Switching to [Mailpit][mailpit].

### Change configuration

#### Basic changes

- [ ] configure Vault for production
  - [ ] set `server.dev.enabled` to `false`
  - [ ] Vault `unseal`
  - [ ] Vault PKI
  - [ ] save secrets in [Vault][vault] (see [Kubernetes Secrets in Vault][vault-kubernetes-use-case])
- [ ] enable [Grafana Loki authentication][grafana-loki-auth]
- [ ] [restructure Ansible code](#restructure-ansible-code)
  - [ ] [ansible directory layout](#ansible-directory-layout)
  - [ ] create a dinamic Ansible inventory
  - [ ] follow [Good Practices for Ansible][ansible-good-practices]
- [ ] [restructure Kubernetes code](../kubernetes/)
  - [ ] [kubernetes directory layout](#kubernetes-directory-layout)
  - [ ] create a dinamic Ansible inventory
- [ ] restructure Networking
  - [ ] use [MetalLB][metallb] as load-balancer
  - [ ] evaluate the introduction of [Open vSwitch][open-vswitch]
  - [ ] evaluate the introduction of [Cilium][cilium]
  - [ ] evaluate the introduction of [Envoy][envoy-proxy]
  - [ ] create a `.internal` DNS zone (like in [AWS][aws-internal-tld] or
        [Google Cloud][google-cloud-internal-tld]) for domain accessible only
        from the internal network
  - [ ] add explanation on why `.internal` will not end up like `.dev`
  - [ ] add explanation on why is better to add a "sinkhole" for `.internal` domains
        not managed by us and why is better to use `.example` or `.test` TLDs to
        simulate real-life external domains
  - [ ] add "sinkhole" for any other `.internal` domains in our DNS server
  - [ ] use [ExternalDNS][external-dns] for [Traefik Proxy source][external-dns-traefik]
        to dynamically configure Bind9 using the [RFC 2136 provider][external-dns-rfc2136]
- [ ] add [tfsec][tfsec] (terrafrom security scanners) in CI pipelines
- [ ] change Cluster Domain in [k3s server][k3s-server-doc] from `cluster.local`
      to `iam-demo.local`
- [ ] evaluate [Artifact Hub][artifact-hub] as an artifacts registry

#### Restructure Ansible code

The project use [Ansible][ansible] to manage VMs and [bootsrap kubernetes](../kubernetes/).
The [Ansible code](../platform/ansible/) for the custom_roles and playbooks
needs to be restructured (add label, move tasks in the proper place, etc)
and would be better to move the custom roles in Ansible collections and use a
[dinamic Ansible inventory][ansible-dev-dynamic-inventory].

##### ansible directory layout

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

#### Restructure Kubernetes code

The project use [Kustomize][kustomize] to customize kubernetes application
configuration.

The code under [kubernetes](../kubernetes/) need to be restructured
(manage helm charts in kustomize, make components more flexible, etc).

Allow [multi-tenancy][kubernetes-multi-tenancy].

##### kubernetes directory layout

Make it easier to compose applications and deploy on multiple clusters and
different platforms.

```tree
├── base-resources
│   ├── postgres
│   │   ├── ...
│   │   └── kustomization.yaml
│   ├── redis
│   │   ├── ...
│   │   └── kustomization.yaml
│   └── ...
│       ├── ...
│       └── kustomization.yaml
├── components
│   ├── keycloak
│   │   ├── ...
│   │   └── kustomization.yaml
│   ├── git-server
│   │   ├── ...
│   │   └── kustomization.yaml
│   ├── tempo
│   │   ├── ...
│   │   └── kustomization.yaml
│   └── ...
│       ├── ...
│       └── kustomization.yaml
├── platform-overrides
│   ├── aws
│   │   ├── ...
│   │   └── kustomization.yaml
│   ├── nginx
│   │   ├── ...
│   │   └── kustomization.yaml
│   └── ...
│       ├── ...
│       └── kustomization.yaml
└── overlays
    ├── dev-minimal
    │   └── single-cluster
    │       └── kustomization.yaml
    └── dev-ha
        ├── tools-cluster
        │   └── kustomization.yaml
        └── biz-cluster
            └── kustomization.yaml
```

### Optional applications

- [ ] [woodpecker-ci]: CI/CD pipelines as code
- [ ] [Falco][falco]: threat detection
- [ ] [plantuml-server][plantuml-server]: diagrams as code
- [ ] [Restic][restic]: operating systems backup solution
- [ ] [Velero][velero]: Kubernetes resources and volumes backup solution
- [ ] [Community][community]: wiki and knowledge-base
- [ ] [Mattermost][mattermost]: Channels, Playbooks, Project & Task Management
- [ ] [Excalidraw][excalidraw]: open source virtual hand-drawn style whiteboard.

#### Interesting projects

- [ ] [PacBot][pacbot]: Policy as Code Bot (by T-Mobile)
- [ ] [MagTape][magtape]: Policy-as-Code for Kubernetes (by T-Mobile)

### Alternative to linux-desktop virtual machine

#### Browser from host machine

You can use the host machine (e.g. your laptop) instead of the `linux-desktop`
virtual machine.

**Pros:**

- Less resources used
- Probably faster

**Cons:**

- virtual machine IPs must be reachable from the host machine
- internal DNS server must be used for DNS resolution on the host machine
- self-signed CA root certificate must be installed on the host machine
- VPNs are likely to interfere with the previous steps
- most of the previous steps require administrative privileges, which are usually
  not allowed (whether it is an enforced policy or not) on company owned laptops
- configuration of the users' host machines will likely be very different (OS,
  network configuration, etc.)

[age]: <https://github.com/FiloSottile/age> "age"
[alertmanager]: <https://github.com/prometheus/alertmanager> "Alertmanager"
[ambassador-k8s-annotations]: <https://ambassadorlabs.github.io/k8s-for-humans/> "Annotating Kubernetes"
[ansible-dev-dynamic-inventory]: <https://docs.ansible.com/ansible/latest/dev_guide/developing_inventory.html> "Developing dynamic inventory for Ansible"
[ansible-good-practices]: <https://redhat-cop.github.io/automation-good-practices/> "Good Practices for Ansible"
[ansible]: <https://ansible.readthedocs.io/> "Ansible"
[artifact-hub]: <https://github.com/artifacthub/hub> "Artifact Hub"
[aws-internal-tld]: <https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html> "AWS: DNS attributes for your VPC"
[backstage]: <https://github.com/backstage/backstage> "Backstage"
[boundary]: <https://www.boundaryproject.io/> "HashiCorp Boundary"
[cert-manager-vault]: <https://cert-manager.io/docs/configuration/vault/> "cert-manager Vault"
[cfssl]: <https://github.com/cloudflare/cfssl> "Cloudflare's PKI and TLS toolkit (CFSSL)"
[cilium]: <https://cilium.io/> "cilium"
[community]: <https://github.com/documize/community> "Community"
[conftest]: <https://github.com/open-policy-agent/conftest> "Conftest"
[consul-api-gateway]: <https://www.consul.io/docs/api-gateway> "Consul API Gateway"
[consul-service-mesh]: <https://developer.hashicorp.com/consul/docs/connect> "Consul Service Mesh"
[consul-tutorials]: <https://developer.hashicorp.com/consul/tutorials> "Consul tutorials"
[consul-vault]: <https://developer.hashicorp.com/consul/docs/k8s/deployment-configurations/vault> "Vault as the Secrets Backend for Consul"
[consul]: <https://www.consul.io/> "Consul"
[drone]: <https://www.drone.io/> "Drone"
[envoy-proxy]: <https://www.envoyproxy.io/docs/envoy/latest/intro/what_is_envoy> "Envoy proxy"
[erpnext]: <https://erpnext.com/> "ERPNext"
[excalidraw]: <https://github.com/excalidraw/excalidraw> "Excalidraw"
[external-dns-rfc2136]: <https://github.com/kubernetes-sigs/external-dns/blob/v0.14.0/docs/tutorials/traefik-proxy.md> "ExternalDNS with RFC 2136"
[external-dns-traefik]: <https://github.com/kubernetes-sigs/external-dns/blob/v0.14.0/docs/tutorials/traefik-proxy.md> "ExternalDNS with Traefik"
[external-dns]: <https://github.com/kubernetes-sigs/external-dns> "ExternalDNS"
[falco]: <https://falco.org/> "Falco"
[fleet]: <https://github.com/fleetdm/fleet> "Fleet"
[forgejo-compare-to-gitea]: <https://forgejo.org/compare-to-gitea/> "Forgejo Comparison with Gitea"
[forgejo-container-registry]: <https://forgejo.org/docs/latest/user/packages/container/> "Forgejo Container Registry"
[forgejo]: <https://forgejo.org/> "Forgejo"
[fossa-github-badge-pr]: <https://docs.fossa.com/docs/quick-import#getting-a-badge-pull-request-githubcom-only> "FOSSA on GitHub.com - Getting a Badge Pull Request"
[fossa-yml]: <https://github.com/fossas/fossa-cli/blob/master/docs/references/files/fossa-yml.md> "FOSSA yaml configuration"
[fossa]: <https://fossa.com/> "Free Open Source Software Analysis"
[gitea]: <https://gitea.io/> "Gitea"
[gitness]: <https://gitness.com/> "Gitness"
[google-cloud-internal-tld]: <https://cloud.google.com/compute/docs/internal-dns> "Google Cloud internal tld"
[grafana-agent-flow]: <https://grafana.com/docs/agent/next/flow/> "Grafana Agent Flow"
[grafana-alloy]: <https://grafana.com/docs/alloy> "Grafana Alloy"
[grafana-k6]: <https://github.com/grafana/k6> "Grafana k6"
[grafana-loki-auth]: <https://grafana.com/docs/loki/latest/operations/authentication/?pg=blog&plcmt=body-txt> "Grafana Loki authentication"
[grafana-loki]: <https://grafana.com/oss/loki/> "Grafana Loki"
[grafana-oncall]: <https://grafana.com/oss/oncall/> "Grafana OnCall"
[grafana-tempo]: <https://github.com/grafana/tempo> "Grafana Tempo"
[grafana]: <https://grafana.com/> "Grafana"
[harbor]: <https://goharbor.io/> "Harbor"
[jsonnet]: <https://jsonnet.org> "Jsonnet"
[k3s-custom-ca]: <https://raw.githubusercontent.com/k3s-io/k3s/master/contrib/util/generate-custom-ca-certs.sh> "k3s custom CA certs"
[k3s-server-doc]: <https://docs.k3s.io/cli/server> "k3s server documentation"
[k8s-jsonpath]: <https://kubernetes.io/docs/reference/kubectl/jsonpath/> "Kubernetes JSONPath documentation"
[keycloak]: <https://www.keycloak.org/> "Keycloak"
[kubernetes-managing-tls]: <https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/> "Kubernetes Manage TLS Certificates in a Cluster"
[kubernetes-multi-tenancy]: <https://kubernetes.io/docs/concepts/security/multi-tenancy/> "Kubernetes multi-tenancy"
[kubernetes-pki-best-practices]: <https://kubernetes.io/docs/setup/best-practices/certificates/> "kubernetes PKI best practices"
[kustomize]: <https://kustomize.io/> "Kustomize"
[kyverno]: <https://kyverno.io/> "Kyverno"
[magtape]: <https://github.com/tmobile/magtape> "MagTape"
[mailhog]: <https://github.com/mailhog/MailHog> "MailHog"
[mailpit]: <https://github.com/axllent/mailpit> "Mailpit"
[mattermost]: <https://mattermost.com/> "Mattermost"
[metallb]: <https://github.com/metallb/metallb> "MetalLB"
[microsoft-remote-desktop]: <https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/remote-desktop-clients> "Microsoft Remote Desktop"
[midpoint]: <https://evolveum.com/midpoint/> "midPoint"
[minio]: <https://min.io/> "MinIO"
[mkcert]: <https://github.com/FiloSottile/mkcert> "mkcert"
[multipass]: <https://multipass.run/> "Canonical Multipass"
[notary]: <https://github.com/notaryproject/notary> "Notary"
[opa]: <https://www.openpolicyagent.org/> "Open Policy Agent (OPA)"
[opal]: <https://github.com/permitio/opal> "Open Policy Administration Layer (OPAL)"
[open-scap]: <https://www.open-scap.org/> "OpenSCAP: NIST Certified SCAP 1.2 toolkit"
[open-vswitch]: https://www.openvswitch.org/ "Open vSwitch"
[oscal]: <https://pages.nist.gov/OSCAL/> "OSCAL"
[pacbot]: <https://github.com/tmobile/pacbot> "PacBot"
[plantuml-server]: <https://github.com/plantuml/plantuml-server> "plantuml-server"
[policy-reporter-loki]: <https://kyverno.github.io/policy-reporter/core/targets/#grafana-loki> "Policy Reporter - Loki"
[pre-commit]: <https://pre-commit.com> "pre-commit hooks"
[prometheus]: <https://grafana.com/oss/prometheus/> "Prometheus"
[promtail]: <https://grafana.com/docs/loki/latest/clients/promtail/> "Promtail"
[renovate]: <https://github.com/renovatebot/renovate> "Renovate"
[restic]: <https://restic.net/> "Restic"
[scap]: <http://scap.nist.gov/> "Security Content Automation Protocol"
[terrakube]: <https://github.com/AzBuilder/terrakube> "Terrakube: Open source IaC Automation and Collaboration Software"
[tfsec]: <https://github.com/liamg/tfsec> "tfsec"
[trestle]: <https://github.com/IBM/compliance-trestle> "Trestle"
[trivy-policy-reporter]: <https://aquasecurity.github.io/trivy-operator/latest/tutorials/integrations/policy-reporter/> "Trivy Policy Reporter Integration"
[trivy]: <https://github.com/aquasecurity/trivy> "Trivy"
[vault-external-ca]: <https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine-external-ca> "Vault external CA"
[vault-kubernetes-use-case]: <https://www.vaultproject.io/use-cases/kubernetes> "Kubernetes Secrets in Vault"
[vault-pki-engine]: <https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine> "Vault PKI engine"
[vault-pki]: <https://www.vaultproject.io/docs/secrets/pki> "Vault PKI"
[vault]: <https://www.vaultproject.io/> "HashiCorp Vault"
[velero]: <https://velero.io/> "Velero"
[waypoint]: <https://www.waypointproject.io/> "Waypoint"
[wazuh]: <https://wazuh.com/> "Wazuh"
[woodpecker-ci]: <https://woodpecker-ci.org/> "Woodpecker CI"
