# Ansible

## Running ansible

Connect to the `ansible-controller` instance.

Inside the instance, move to the `ansible` folder

```bash
cd /ansible
```

Check that ansible can connect to all hosts:

```bash
ansible -m ping all
```

Run all needed playbooks:

```bash
# There is a playbook that include all the others playbooks
# in the order they are supposed to be executed.
ansible-playbook playbooks/all-setup -vvv
# If you prefer, you can run them one by one
ansible-playbook playbooks/bootstrap-ansible-controller -vvv
ansible-playbook playbooks/bootstrap-bind -vvv
ansible-playbook playbooks/basic-bootstrap -vvv
ansible-playbook playbooks/k3s-bootstrap -vvv
ansible-playbook playbooks/k3s-copy-config -vvv
ansible-playbook playbooks/k3s-base-provisioning -vvv
ansible-playbook playbooks/k3s-apps-provisioning -vvv
```

### Examples of useful Ansible commands

#### Ansible Playbooks options

```sh
# you can use `--limit <group>` or `--limit <host>`
ansible-playbook playbooks/distro-update --limit linux-desktop

# list hosts we will interact with using `--list-hosts`
ansible-playbook playbooks/k3s-all-setup --list-hosts

# dry run (do not make changes) using `--check`
ansible-playbook playbooks/playground --check

# run in vervose mode using `-v` (more "v" -> more verbosity)
ansible-playbook -vv playbooks/playground

# check yaml syntax using `--syntax-check <playbook>`
ansible-playbook --syntax-check <playbook>

# Run step by step
ansible-playbook --step <playbook>
```

#### Generic useful Ansible commands

```sh
# List facts for Ansible inventory hosts or groups.
#  Select a group (e.g. all, k3s_cluster, dns_servers) or host
#  (e.g. ansible-controller, iam-control-plane, linux-desktop)
ansible_target=k3s_cluster
ansible "${ansible_target:?}" -m setup

# Create an ansible vault string secret
ansible-vault encrypt_string

# list hosts with defined variables
ansible-inventory --list --yaml
```

### Edit your inventory for an environment

For example, in `inventory/config`:

```yaml
---
all:
  children:
    production:
      hosts: &hosts
        ansible-controller:
        iam-control-plane:
        linux-desktop:
    apt:
      hosts:
        <<: *hosts
    iam_cluster:
      children:
        iam_cluster_production:
          hosts:
            iam-control-plane:
    k3s_cluster:
      children:
        k3s_workers:
          hosts:
        k3s_control_planes:
          hosts:
            iam-control-plane:
  hosts:
    <<: *hosts
```

## Connect to the cluster

Ensure you are connected to the right cluster

```sh
export KUBECONFIG=~/.kube/config-${cluster_name}
kubectl config view
```

Get a list of nodes

```sh
kubectl get node
```

Get a list of pods

```sh
kubectl get pods -o wide -A
```

## Ansible code playground

You can use the `playground` playbook to experiment with ansible code and check
that it works as expected.

**Note:** The `playground` playbook should not change a system behavior.

Run:

```sh
ANSIBLE_STDOUT_CALLBACK=debug ansible-playbook -vvv playbooks/playground
```

## TODO

Follow [Good Practices for Ansible](https://redhat-cop.github.io/automation-good-practices/).
