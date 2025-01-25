# IAM Demo

Identity and Access Management (IAM) demo infrastructure.

- [📜 Introduction](#-introduction)
- [🐣 Getting started](#-getting-started)
  - [⚙️ Setup](#️-setup)
    - [Dependencies](#dependencies)
    - [Run](#run)
  - [🔧 Development](#-development)
  - [💻 Linux desktop VM](#-linux-desktop-vm)
    - [Connect using Remote Desktop](#connect-using-remote-desktop)
    - [Test self-signed certificates](#test-self-signed-certificates)
    - [Complete Setup (required to run only once)](#complete-setup-required-to-run-only-once)
      - [Configure environment variables and shell completion](#configure-environment-variables-and-shell-completion)
      - [Configure Forgejo ssh keys](#configure-forgejo-ssh-keys)
  - [🧑‍💻 Access Kubernetes cluster](#-access-kubernetes-cluster)
    - [Connecting from the console](#connecting-from-the-console)
    - [Connect using linux-desktop browser](#connect-using-linux-desktop-browser)
      - [Traefik Dashboard](#traefik-dashboard)
      - [Kubernetes Dashboard](#kubernetes-dashboard)
- [Troubleshooting](#troubleshooting)
- [Screenshots](#screenshots)
- [TODO](#todo)
- [📄 License](#-license)

## 📜 Introduction

Use [Multipass][multipass] to start an [ansible][ansible] controller
instance, a [Kubernetes][kubernetes] cluster, and a linux desktop with
[Xfce Desktop Environment][xfce].

## 🐣 Getting started

### ⚙️ Setup

#### Dependencies

- [Jsonnet][jsonnet]
- [Multipass][multipass]

#### Run

```sh
./bunch-up -a
```

### 🔧 Development

See [development](docs/development/) documentation.

### 💻 Linux desktop VM

#### Connect using Remote Desktop

Use any RDP client (like [Microsoft Remote Desktop][microsoft-remote-desktop]
or [FreeRDP][freerdp]) to connect to the `linux-desktop` virtual machine.

- user: **iamadmin**
- password: **iamadmin**

The IP Address is the first entry from `ipv4` when running the following command:

```sh
./platform/vm-generator/generated/vms-status.sh linux-desktop
```

#### Test self-signed certificates

The ansible scripts should have installed the self-signed root certificate
inside the linux-desktop virtual machine.

To test that the services are running and using the proper DNS and certificates,
open a terminal in the `linux-desktop` VM and type:

```sh
~/bin/check-vm-config.sh
```

#### Complete Setup (required to run only once)

##### Configure environment variables and shell completion

Open a terminal and type:

```sh
# Configure iam-demo-tech k8s cluster as default
echo 'export KUBECONFIG=~/.kube/config-iam-demo-tech' | sudo tee --append /etc/bash.bashrc
# Add kubectl completion
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl
# Add kustomize completion
kustomize completion bash | sudo tee /etc/bash_completion.d/kustomize
# Add helm completion
helm completion bash | sudo tee /etc/bash_completion.d/helm
# Open a new shell tab or start a new shell to apply the changes
exec $SHELL
```

##### Configure Forgejo ssh keys

Open a terminal to generate the ssh keys.

```sh
ssh-keygen -t ed25519 -C "iamadmin@iam-demo.test"
```

Open a [Forgejo](https://git.iam-demo.test) in a browser and login using the
credentials from [Connect using linux-desktop browser](#connect-using-linux-desktop-browser).

Open a terminal and copy your public ssh key in the clipboard.

```sh
cat ~/.ssh/id_ed25519.pub | tee >(xclip -selection clipboard); echo ''
```

Open [Manage SSH Keys in Forgejo](https://git.iam-demo.test/user/settings/keys)
in a browser and paste the public key.

### 🧑‍💻 Access Kubernetes cluster

#### Connecting from the console

Access `ansible-controller` shell using:

```sh
./platform/vm-generator/generated/vm-shell.sh ansible-controller
```

or connect to `linux-desktop` [using Remote Desktop](#connect-using-remote-desktop)
and open a terminal.

You can also access `linux-desktop` shell using:

```sh
./platform/vm-generator/generated/vm-shell.sh linux-desktop
```

To check the Kubernetes configuration, type:

```sh
kubectl config view
```

The output should be like the following:

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://iam-control-plane.iam-demo.test:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
```

The [kubernetes](kubernetes/) folder is mounted inside the `ansible-controller`
under `/kubernetes`.

#### Connect using linux-desktop browser

Connect to `linux-desktop` [using Remote Desktop](#connect-using-remote-desktop).

Open Firefox inside the VM, and use the following URLs:
(**Note:** you can find them in Firefox bookmarks)

- Grafana: <https://grafana.iam-demo.test>
  - user: admin
  - password: grafana-admin
- Forgejo: <https://git.iam-demo.test>
  - user: forgejo-admin
  - password: forgejopw123!
- Prometheus: <https://prometheus.iam-demo.test>
- Alertmanager: <https://alertmanager.iam-demo.test>
- Consul: <https://consul.iam-demo.test>
- Keycloak: <https://keycloak.iam-demo.test>

To access Traefik or Kubernetes dashboards, follow the instructions in the
respective subsections.

##### Traefik Dashboard

Open a terminal and start port forwarding using:

```sh
KUBECONFIG=~/.kube/config-iam-demo-tech
kubectl port-forward \
  --namespace kube-system \
  $(kubectl get pods \
    --namespace kube-system \
    --selector "app.kubernetes.io/name=traefik" \
    --output=name) \
  9000:9000
```

Open <http://127.0.0.1:9000/dashboard/> in a browser.

##### Kubernetes Dashboard

Generate a token, print it and copy it to the clipboard:

```sh
kubectl -n kubernetes-dashboard create token admin-user | tee >(xclip -selection clipboard); echo ''
```

Start the proxy:

```sh
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```

Access the kubernetes-dashboard in a web broser opening:

<https://localhost:8443/>

## Troubleshooting

- [Troubleshooting](docs/troubleshooting/README.md)

## Screenshots

- [Screenshots](docs/screenshots.md)

## TODO

- [TODO](docs/TODO.md)

## 📄 License

Distributed under the terms of the Apache License (Version 2.0).

See [LICENSE](LICENSE) for details.

[ansible]: <https://ansible.readthedocs.io/> "Ansible"
[freerdp]: <https://www.freerdp.com/> "FreeRDP: A Remote Desktop Protocol Implementation"
[jsonnet]: <https://jsonnet.org> "Jsonnet"
[kubernetes]: <https://kubernetes.io> "Kubernetes CLI"
[microsoft-remote-desktop]: <https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/remote-desktop-clients> "Microsoft Remote Desktop"
[multipass]: <https://multipass.run/> "Canonical Multipass"
[xfce]: <https://www.xfce.org/> "Xfce Desktop Environment"
