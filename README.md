


## Building a 2 node Windows/Linux cluster

Once you have some of the basics down with Kubernetes, it's time to build a larger cluster with both Windows & Linux nodes.

![2 node diagram](images/2node-diagram.png)

This tutorial will create a Kubernetes master running in a Linux VM, which can also be used to run containers. Once the master is up, the Windows host will be added to the same cluster. The same steps could be used to join other existing machines as well, or you could create even more VMs to join as needed.


### Prerequisites

- Windows 10 Anniversary Update, Windows Server 2016 or later
- Hyper-V role installed - [Quick Start here](https://docs.microsoft.com/en-us/virtualization/#pivot=main&panel=windows)
- [Vagrant](https://www.vagrantup.com/downloads.html) 1.9.3 or later for Windows 64-bit


### Step 1 - Start the Kubernetes master

`vagrant up master`

This also has Vagrant provisioner steps to:

- Install docker from Centos package repo
- Install latest versions of kubectl & kubeadm from Kubernetes package repo
- Initialize a simple cluster with `kubeadm init`


The last provisioner step in the `Vagrantfile` runs `install-k8s.sh` which will install all the packages, set up a Kubernetes cluster, and configure Flannel as the networking plugin. 
These steps were adapted from the [official guide](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/)


```none
 master: Your Kubernetes control-plane has initialized successfully!
    master:
    master: To start using your cluster, you need to run the following as a regular user:
    master:
    master:   mkdir -p $HOME/.kube
    master:   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    master:   sudo chown $(id -u):$(id -g) $HOME/.kube/config
    master:
    master: You should now deploy a pod network to the cluster.
    master: Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
    master:   https://kubernetes.io/docs/concepts/cluster-administration/addons/
    master:
    master: Then you can join any number of worker nodes by running the following on each as root:
    master:
    master: kubeadm join 172.17.164.78:6443 --token pscf3u.vpzv01lj754z4b7s \
    master:     --discovery-token-ca-cert-hash sha256:f1f160335a526dc970e77d924cb10181d73d211c114ed95bd7ea5ba77041a10c
    master: podsecuritypolicy.policy/psp.flannel.unprivileged created
    master: clusterrole.rbac.authorization.k8s.io/flannel created
    master: clusterrolebinding.rbac.authorization.k8s.io/flannel created
    master: serviceaccount/flannel created
    master: configmap/kube-flannel-cfg created
    master: daemonset.apps/kube-flannel-ds-amd64 created
    master: daemonset.apps/kube-flannel-ds-arm64 created
    master: daemonset.apps/kube-flannel-ds-arm created
    master: daemonset.apps/kube-flannel-ds-ppc64le created
    master: daemonset.apps/kube-flannel-ds-s390x created
```

Now, you'll need to copy a few things off that are needed for the next VMs. Ideally this would all work with Vagrant's file sharing, but I haven't been able to get SMB clients to work for the Linux VMs.


#### Getting the kubeadm join script

Normally, the Vagrant synced folders would make this easy but there's a few limitations with Vagrant on Windows. Instead, a manual step is needed to copy the node join info back to the host before starting the next VMs.

```powershell
if ((test-path tmp) -eq $false) { mkdir tmp }
vagrant ssh -c 'cat /vagrant/tmp/join.sh' master | out-file -encoding ascii "tmp/join.sh"
```


### Managing the Kubernetes cluster from Windows

Now, it's time to get the Kubernetes client config file needed out of the VM and onto your Windows machine

```powershell
mkdir ~/.kube
vagrant ssh  -c 'cat ~/.kube/config' master | out-file ~/.kube/config -encoding ascii
```

If you don't already have kubectl.exe on your machine and in your path, there's a few different 
ways you can do it. The `kubernetes-cli` [choco package](https://chocolatey.org/packages/kubernetes-cli) 
is probably the easiest - `choco install kubernetes-cli`. If you want to do this manually - look for the `kubernetes-client-windows-amd64.tgz` download in the [Kubernetes 1.10 release notes](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.10.md#client-binaries)

> Tip: Later you can use `choco upgrade kubernetes-cli` to get a new release

Now, `kubectl get node` should work on the Windows host.

### Joining a Linux node

The `Vagrantfile` also includes another Linux VM called "nodea". After setting up the master, be sure you
ran the extra step to copy `join.sh` back to the host before going forward.

`vagrant up nodea` will bring up the Linux node. You can check with `kubectl get node` running from either the master VM, or by running kubectl locally with the config that was copied earlier.


```none
kubectl get node
NAME                 STATUS   ROLES    AGE     VERSION
master.localdomain   Ready    master   9m10s   v1.16.2
nodea.localdomain    Ready    <none>   43s     v1.16.2
```

It may take a minute or two for `nodea` to show the `Ready` state since it still needs to start the flannel daemonset and kube-proxy.

### Run a Linux service to test it out

If you are still SSH'd to a Linux node, go ahead and type `exit` to disconnect. Next we'll bring it all together and use kubectl on Windows to deploy a service to the Linux nodes, then connect to it.

These next steps will show:

1. Creating a deployment `hello` that will run a container called `echoserver`
2. Creating a service that's accessible on the node's IP 
3. Connecting and making sure it works

```powershell
kubectl run hello --image=gcr.io/google_containers/echoserver:1.10 --port=8080
kubectl get pod -o wide
```

Now you should have a pod running:

    NAME                     READY     STATUS    RESTARTS   AGE       IP           NODE
    hello-794f7449f5-rmdjt   1/1       Running   0          25m       10.244.1.4   nodea.localdomain

If not, wait and check again. It may take from a few seconds to a few minutes depending on how fast your host and internet connection are.

```powershell
kubectl expose deploy hello --type=NodePort
kubectl get service
```

Now it has a service listening on each node's external IP, but the port (31345 in this example) will vary

    NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
    hello        NodePort    10.111.75.166   <none>        8080:31345/TCP   20h
    kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP          1d

You can easily get each Linux node's IP from Hyper-V Manager, with `Get-VMNetwork`, or `vagrant ssh-config`. Get the IP of each node, and try to access the service running on the nodeport:

```powershell
(Invoke-WebRequest -UseBasicParsing http://192.168.1.139:31345).RawContent
```

Which will return something like this:

    HTTP/1.1 200 OK
    Transfer-Encoding: chunked
    Connection: keep-alive
    Content-Type: text/plain
    Date: Thu, 28 Dec 2017 10:42:59 GMT
    Server: nginx/1.10.0

    CLIENT VALUES:
    client_address=10.244.1.1
    command=GET
    real path=/
    query=nil
    request_version=1.1
    request_uri=http://192.168.1.139:8080/

    SERVER VALUES:
    server_version=nginx: 1.10.0 - lua: 10001

    HEADERS RECEIVED:
    host=192.168.1.139:31345
    user-agent=Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1.16299.98
    BODY:
    -no body in request-


Try another cluster node's external IP if you want to make sure the Kubernetes cluster network is working ok. The client_address will change showing you accessed it from a different cluster node.

    HTTP/1.1 200 OK
    Transfer-Encoding: chunked
    Connection: keep-alive
    Content-Type: text/plain
    Date: Thu, 28 Dec 2017 10:44:56 GMT
    Server: nginx/1.10.0

    CLIENT VALUES:
    client_address=10.244.0.0
    command=GET
    real path=/
    query=nil
    request_version=1.1
    request_uri=http://192.168.1.138:8080/

    SERVER VALUES:
    server_version=nginx: 1.10.0 - lua: 10001

    HEADERS RECEIVED:
    connection=Keep-Alive
    host=192.168.1.138:31345
    user-agent=Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1.16299.98
    BODY:
    -no body in request-


Now the service is up and running on nodea! Once you're done, delete the service and deployment to clean
everything back up.

```bash
kubectl delete deploy hello
kubectl delete service hello
```


### Building the Windows VM

Microsoft licensing doesn't allow users to share VMs publically. This means you'll have to build your own base VM, but Packer makes it easy. Normally there is a trial ISO available, but it's still not ready for Windows Server 2019 according to the [Windows Server Blog](https://cloudblogs.microsoft.com/windowsserver/2018/11/13/update-on-windows-server-2019-availability/). Until then, you'll need a paid MSDN account where you can download the ISO and get a product key to use as a developer.

Clone [patricklang/packer-windows](https://github.com/StefanScherer/packer-windows), checkout the `ws2019-core-hyperv` branch, then modify a few things:

1. In `answer_files\2019_core\Autounattend.xml` uncomment `<Key>...</Key>`, and set a real product key there. This is needed until the Windows Server 2019 trial ISO is released.

```xml
                <ProductKey>
                    <!--
                        Windows Server Insider product key
                        See https://blogs.windows.com/windowsexperience/2017/07/13/announcing-windows-server-insider-preview-build-16237/
                    -->
                    <!--<Key></Key>-->
                    <WillShowUI>OnError</WillShowUI>
                </ProductKey>
```
2. Modify `build_windows_2019_docker.sh` if you're using VMWare Fusion on Mac. Set `--var iso_url=/path/to/en_windows_server_2019_x64_dvd_4cb967d8.iso` and `--var iso_checksum=4C5DD63EFEE50117986A2E38D4B3A3FBAF3C1C15E2E7EA1D23EF9D8AF148DD2D`. If you're using Hyper-V, use `build_windows_2019_docker.ps1` as-is.

3. Now, you can build the VM by running one of those two scripts.

The last lines will look like this with Hyper-V:

```none
Build 'hyperv-iso' finished.

==> Builds finished. The artifacts of successful builds are:
--> hyperv-iso: VM files in directory: output-hyperv-iso
```

Run `vagrant box add --name WindowsServer2019Docker windows_2019_docker_hyperv.box`

### Joining the Windows node

This is a bit rough right now, code improvements are welcome!

1. First, bring up the Windows VM with `vagrant up win1`. It will ask for your username & password to connect to the SMB files.
1. Once the VM is up, connect to it with Hyper-V Manager. Log in with user/pass `vagrant`
1. In the command window, run `powershell`.
1. Now, run `cd \vagrant ; .\install-k8s.ps1`

> Note: if this fails, one workaround is to just copy the 1 file needed into the VM from the host:
> `Copy-VMFile -VMName K8s-win1 -SourcePath .\install-k8s.ps1 -DestinationPath c:\Users\vagrant\install-k8s.ps1 -FileSource Host`
> Then run `.\install-k8s.ps1`

    After a few seconds to a minute, it will ask if you want to create a SSH key. Choose yes, and hit enter twice to leave the passphrase blank.

    ```none
    Do you wish to generate a SSH Key & Add it to the Linux control-plane node [Y/n] - Default [Y]:
    Generating public/private rsa key pair.
    Enter file in which to save the key (C:\Users\vagrant/.ssh/id_rsa):
    Created directory 'C:\Users\vagrant/.ssh'.
    Enter passphrase (empty for no passphrase):
    Enter same passphrase again:
    ```

    After that, it will drop back to a PowerShell prompt.

1. Run `Get-Content ~/.ssh/id_rsa.pub` to get the SSH key. It will start with `ssh-rsa AAAA...` and end with `vagrant@win1`. Copy that whole string to the clipboard by highlighting, then right clicking the mouse.

1. Back on the Windows machine, run this, pasting the contents of the clipboard instead of copying the word `<paste>`

    ```powershell
    $sshPublicKey = "<paste>"
    vagrant ssh -c "echo $sshPublicKey >> ~/.ssh/authorized_keys" master
    ```

1. Now, you'll need a few more details from `./tmp/join.sh` - the kubeadm join token, ca-cert-hash, and apiserver IP. Open that up or `cat` it so you can copy/paste from it.
1. In the Win1 VM - run `notepad c:\k\kubeconfig.json`

    Scroll down to the "ControlPlane" section, and copy in the missing info from join.sh:

    ```
                        "ControlPlane":  {
                                                "IpAddress":  "kubemasterIP",
                                                "Username":  "vagrant",
                                                "KubeadmToken":  "token",
                                                "KubeadmCAHash":  "discovery-token-ca-cert-hash"
                                            },
    ```

    Save & close notepad.

1. Now run `.\KubeCluster.ps1 -ConfigFile .\Kubecluster.json -join` in the VM.

    It will connect to get needed info from the master VM. type `yes` then enter when prompted

    ```none
    The authenticity of host '172.17.164.78 (172.17.164.78)' can't be established.
    ECDSA key fingerprint is SHA256:l2+PM2C2GoSuxIjjTb6HpWDJtZspghwrJsI/qOFwHzc.
    Are you sure you want to continue connecting (yes/no)?
    ```

    After a few seconds to minutes, it will show that it has joined the cluster:

    ```none

    Waiting for service [Kubeproxy] to be running
    NAME                 STATUS   ROLES    AGE   VERSION
    master.localdomain   Ready    master   39m   v1.16.2
    nodea.localdomain    Ready    <none>   31m   v1.16.2
    win1                 Ready    <none>   20s   v1.16.2
    Node win1 successfully joined the cluster
    ```


## References

- [Guide for adding Windows Nodes in Kubernetes](https://kubernetes.io/docs/setup/production-environment/windows/user-guide-windows-nodes/)
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)