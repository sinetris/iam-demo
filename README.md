# IAM Demo

Identity and Access Management (IAM) demo infrastructure.

- [📜 Introduction](#-introduction)
- [🐣 Getting started](#-getting-started)
  - [🔩 Dependencies](#-dependencies)
  - [🔧 Setup](#-setup)
  - [💻 Linux desktop VM](#-linux-desktop-vm)
    - [Connect using Remote Desktop](#connect-using-remote-desktop)
    - [Test self-signed certificates](#test-self-signed-certificates)
  - [🧑‍💻 Access Kubernetes cluster](#-access-kubernetes-cluster)
    - [Connecting from the console](#connecting-from-the-console)
    - [Connect using linux-desktop browser](#connect-using-linux-desktop-browser)
      - [Traefik Dashboard](#traefik-dashboard)
      - [Kubernetes Dashboard](#kubernetes-dashboard)
- [📄 License](#-license)

## 📜 Introduction

Use [Multipass][multipass] to start an [ansible][ansible] controller
instance, a [Kubernetes][kubernetes] cluster, and a linux desktop with
[Xfce Desktop Environment][xfce].

## 🐣 Getting started

### 🔩 Dependencies

- [Jsonnet][jsonnet]
- [Multipass][multipass]

### 🔧 Setup

```sh
./bunch-up -a
```

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

### 🧑‍💻 Access Kubernetes cluster

#### Connecting from the console

Access `ansible-controller` shell using:

```sh
./platform/vm-generator/generated/vm-shell.sh ansible-controller
```

or connect to `linux-desktop` [using Remote Desktop](#connect-using-remote-desktop)
and opening a terminal.

You can also access `linux-desktop` shell using:

```sh
./platform/vm-generator/generated/vm-shell.sh linux-desktop
```

To check the Kubernetes configuration, type:

```sh
export KUBECONFIG=~/.kube/config-iam-demo-tech
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

The [kubernetes](kubernetes/) folder is mounted inside the `ansible-controller` under `/kubernetes`.

#### Connect using linux-desktop browser

Connect to `linux-desktop` [using Remote Desktop](#connect-using-remote-desktop).

Open Firefox inside the VM, and use the following URLs:
(**Note:** you can find them in Firefox bookmarks)

- Grafana: <https://grafana.iam-demo.test>
  - user: admin
  - password: grafana-admin
- Prometheus: <https://prometheus.iam-demo.test>
- Alertmanager: <https://alertmanager.iam-demo.test>
- Consul: <https://consul.iam-demo.test>
- Keycloak: <https://keycloak.iam-demo.test>

To access Traefik or Kubernetes dashboards, follow the instructions in the respective subsections.

##### Traefik Dashboard

Open a terminal and start port forwarding using:

```sh
export KUBECONFIG=~/.kube/config-iam-demo-tech
kubectl port-forward \
  --namespace tools \
  $(kubectl get pods \
    --namespace tools \
    --selector "app.kubernetes.io/name=traefik" \
    --output=name) \
  9000:9000
```

Open <http://127.0.0.1:9000/dashboard/> in a browser.

##### Kubernetes Dashboard

Generate a token, print it and copy it to the clipboard:

```sh
export KUBECONFIG=~/.kube/config-iam-demo-tech
kubectl -n kubernetes-dashboard create token admin-user | tee >(xclip -selection clipboard); echo ''
```

Start the proxy:

```sh
export KUBECONFIG=~/.kube/config-iam-demo-tech
kubectl proxy
```

Access the board in a web broser opening:

<http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/>

## 📄 License

Distributed under the terms of the Apache License (Version 2.0).

See [LICENSE](LICENSE) for details.

[ansible]: <https://ansible.readthedocs.io/> "Ansible"
[ansible-lint]: <https://ansible.readthedocs.io/projects/lint/> "Ansible Lint"
[freerdp]: <https://www.freerdp.com/> "FreeRDP: A Remote Desktop Protocol Implementation"
[jsonnet]: <https://jsonnet.org> "Jsonnet"
[kubernetes]: <https://kubernetes.io> "Kubernetes CLI"
[microsoft-remote-desktop]: <https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/remote-desktop-clients> "Microsoft Remote Desktop"
[multipass]: <https://multipass.run/> "Canonical Multipass"
[xfce]: <https://www.xfce.org/> "Xfce Desktop Environment"
