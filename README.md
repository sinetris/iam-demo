# IAM Demo

Identity and Access Management (IAM) demo infrastructure.

## Start the cluster

**Setup for MacOS**

```shell
# Install dependencies and create certificates
./bunch-up.sh --setup
# Start and configure clusters and DNS resolver for .test domains
./bunch-up.sh --bootstrap
# Provision applications in clusters
./bunch-up.sh --provision
```

## Troubleshooting

https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/

```shell
kubectl apply -f https://k8s.io/examples/admin/dns/dnsutils.yaml
kubectl get pods dnsutils
kubectl exec -i -t dnsutils -- nslookup kubernetes.default
# debug container with nice tooling
kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot
```

## Portainer

```shell
# Create a docker volume for portainer
docker volume create portainer_data
# Create certificated for the portainer domain
mkdir -p $HOME/.config/certs/portainer.test
mkcert -key-file "$HOME/.config/certs/portainer.test/key.pem" \
      -cert-file "$HOME/.config/certs/portainer.test/cert.pem" \
     'portainer.test'
# Start portainer
docker run -d -p 8000:8000 -p 9443:9443 \
    --name portainer --restart always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    -v $HOME/.config/certs:/certs \
    portainer/portainer-ce:latest \
    --sslcert /certs/portainer.test/cert.pem \
    --sslkey /certs/portainer.test/key.pem \
    --ssl
# Install portainer agent in kubernetes cluster
curl -L https://downloads.portainer.io/ce2-13/portainer-agent-k8s-lb.yaml -o portainer-agent-k8s.yaml
kubectl apply -f portainer-agent-k8s.yaml
# Get the Kubernetes control plane IP
docker container inspect iam-demo-basic-control-plane  --format '{{ .NetworkSettings.Networks.kind.IPAddress }}'
# Open portainer in a browser
open 'https://portainer.test:9443/#!/endpoints'
# Click 'Add environment' and use: 'Name: iam-demo-basic', 'Environment URL: <control plane ip>:
```
