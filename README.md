# IAM Demo

Identity and Access Management (IAM) demo infrastructure.

- [📜 Introduction](#-introduction)
- [🐣 Getting started](#-getting-started)
  - [🔗 Dependencies](#-dependencies)
  - [🔧 Setup](#-setup)
  - [💻 Access the cluster from linux desktop vm](#-access-the-cluster-from-linux-desktop-vm)
- [📄 License](#-license)

## 📜 Introduction

Use [Multipass][multipass] to start an [ansible][ansible] controller instance, a [Kubernetes][kubernetes] cluster, and a linux desktop with [Xfce Desktop Environment][xfce].

## 🐣 Getting started

### 🔗 Dependencies

- [Jsonnet][jsonnet]
- [Multipass][multipass]

### 🔧 Setup

```sh
./bunch-up -a
```

### 💻 Access the cluster from linux desktop vm

Use any RDP client (like [Microsoft Remote Desktop][microsoft-remote-desktop] or [FreeRDP][freerdp]) to connect to the
`linux-desktop` VM.

Open a terminal in the `linux-desktop` VM and type:

```sh
export HOST_TO_CHECK=iam-control-plane.iam-demo.test
echo | openssl s_client -showcerts -servername ${HOST_TO_CHECK} -connect ${HOST_TO_CHECK}:443 2>/dev/null | openssl x509 -inform pem -noout -text
```

to check that local certificates are configured correctly.

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

## 📄 License

Distributed under the terms of the Apache License (Version 2.0).

See [LICENSE](LICENSE) for details.

[ansible]: <https://ansible-lint.readthedocs.io/installing/> "Ansible"
[freerdp]: <https://www.freerdp.com/> "FreeRDP: A Remote Desktop Protocol Implementation"
[jsonnet]: <https://jsonnet.org> "Jsonnet"
[kubernetes]: <https://kubernetes.io> "Kubernetes CLI"
[microsoft-remote-desktop]: <https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/remote-desktop-clients> "Microsoft Remote Desktop"
[multipass]: <https://multipass.run/> "Canonical Multipass"
[xfce]: <https://www.xfce.org/> "Xfce Desktop Environment"
