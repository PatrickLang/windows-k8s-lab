



## Building a 1-node Linux-based cluster with Minikube on Windows 10

Download links & Quickstart at https://github.com/kubernetes/minikube


### Starting up Minikube

```powershell
minikube start --vm-driver hyperv
```

```none
Starting local Kubernetes v1.7.0 cluster...
Starting VM...
Getting VM IP address...
Moving files into cluster...
Setting up certs...
Starting cluster components...
Connecting to cluster...
Setting up kubeconfig...
Kubectl is now configured to use the cluster.
```

### Run first container

```powershell
kubectl run hello-minikube --image=gcr.io/google_containers/echoserver:1.4 --port=8080

>kubectl get pod
NAME                             READY     STATUS    RESTARTS   AGE
hello-minikube-180744149-m4m1n   1/1       Running   0          2m

kubectl expose deployment hello-minikube --type=NodePort

>minikube service hello-minikube --url
http://192.168.1.156:31007
PS 08/05/2017 16:21:32 C:\minikube
>(Invoke-WebRequest -UseBasicParsing $(minikube service hello-minikube --url)).Content
CLIENT VALUES:
client_address=172.17.0.1
command=GET
real path=/
query=nil
request_version=1.1
request_uri=http://192.168.1.156:8080/

SERVER VALUES:
server_version=nginx: 1.10.0 - lua: 10001

HEADERS RECEIVED:
host=192.168.1.156:31007
user-agent=Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1.15063.483
BODY:
-no body in request-
PS 08/05/2017 16:22:01 C:\minikube

```



### Getting access to services running under Minikube

```
>minikube service list
|-------------|----------------------|----------------------------|
|  NAMESPACE  |         NAME         |            URL             |
|-------------|----------------------|----------------------------|
| default     | hello-minikube       | http://192.168.1.156:31007 |
| default     | kubernetes           | No node port               |
| kube-system | kube-dns             | No node port               |
| kube-system | kubernetes-dashboard | http://192.168.1.156:30000 |
|-------------|----------------------|----------------------------|
```



## Building a 2 node Windows/Linux cluster



### Setting up the Linux master with Centos 7

Get a clean Centos 7 image up

```powershell
vagrant box add centos/7
# Choose hyperv provider when prompted
vagrant init centos/7
vagrant up
```

Install Docker/Moby

First, connect to the VM with `vagrant ssh`. The following commands will be run in the Centos VM over SSH.

```bash
sudo yum install docker
sudo systemctl start docker
sudo docker version
sudo systemctl enable docker
```

> TODO: this gets docker-1.12.6-32.git88a4867.el7.centos.x86_64 - good/bad?





Run these in containers:

- kubernetes-apiserver
- kubernetes-controller-manager
- kubernetes-scheduler

```bash
chmod +x register-k8s.sh
sudo ./register-k8s.sh
sudo systemctl start kube-controller-manager
sudo systemctl start kube-scheduler
sudo systemctl start kube-apiserver
```


Info from [link](https://wiki.centos.org/SpecialInterestGroup/Atomic/ContainerizedMaster)


### Joining the Windows node

Steps to be adapted from https://kubernetes.io/docs/getting-started-guides/windows/ or https://github.com/apprenda/kubernetes-ovn-heterogeneous-cluster

Find latest binaries at:
https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG.md

Using [1.7.3](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG.md/#downloads-for-v173):
- [Windows node](https://dl.k8s.io/v1.7.3/kubernetes-node-windows-amd64.tar.gz)




## References

- [Minikube support for Windows added in April 2016](https://github.com/kubernetes/minikube/issues/28)
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [Getting Started Guide - Windows](https://kubernetes.io/docs/getting-started-guides/windows/)

## Bonus points for later

- [Update Vagrant Deployer for Kubernetes Ansible](https://github.com/kubernetes/contrib/tree/master/ansible/vagrant) to work on Hyper-V
- [Update CentOS Atomic Host box for Hyper-V](https://wiki.centos.org/SpecialInterestGroup/Atomic/Download)