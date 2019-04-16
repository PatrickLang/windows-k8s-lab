# Building a Kubernetes Windows + Linux cluster

Using Flannel and ContainerD

This requires:

- Windows Server or Windows 10 1803 or later
- Hyper-V role installed
- Vagrant & Packer. Get each with [chocolatey](https://chocolatey.org)

## Bringing up the First node and creating the cluster

```powershell
vagrant up master
```

Choose a external Hyper-V switch when prompted

Once that finishes, you'll see the kubeadm output.

Connect with `vagrant ssh master` for the next step

```bash
# Get kubectl config into a more usable location
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get node # this should work now
```

Normally, the Vagrant synced folders would make this easy but there's a few limitations with Vagrant on Windows. Instead, a manual step is needed to copy the node join info back to the host before starting the next VMs.

```powershell
if ((test-path tmp) -eq $false) { mkdir tmp }
vagrant ssh -c 'cat /vagrant/tmp/join.sh' master | out-file -encoding ascii "tmp/join.sh"
# this is temporary, the containerd setup script needs it until kubeadm is ready
vagrant ssh -c 'cat ~/.kube/config' master | out-file "tmp/config" -encoding ascii 
```

## Another Linux nodde

Now, bring up the second Linux node:
`vagrant up nodea`

It will join automatically :)


## Adding the Windows VM

### Building the Windows VM

Microsoft licensing doesn't allow users to share VMs publically. This means you'll have to build your own base VM, but Packer makes it easy. Download the trial ISO from https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2019

Clone [StefanScherer/packer-windows](https://github.com/StefanScherer/packer-windows), checkout the `my` branch, then run `build_windows_2019_docker.ps1`.

The last lines will look like this with Hyper-V:

```none
Build 'hyperv-iso' finished.

==> Builds finished. The artifacts of successful builds are:
--> hyperv-iso: VM files in directory: output-hyperv-iso
```

Run `vagrant box add --name WindowsServer2019Docker windows_2019_docker_hyperv.box`

### Building the needed binaries

> TODO: ContainerD with CRI plugin

> TODO: Windows CNI meta-plugins


### Joining the Windows node

> This is a work in progress. It's hacky and uses scripts that will be thrown away and rewritten.

Run `vagrant up win1`, and give your username & password when prompted. This is needed for the VM to mount `c:\vagrant` over SMB on your machine.

Connect to the `k8s-win1` VM with Hyper-V Manager

Log in as user `vagrant` password `vagrant`

On the cmd prompt, run `start powershell`

In the new PowerShell window, run `./start.ps1 -config ~\.kube\config`

After some time it will get in a loop with messages saying "Waiting for the Network to be created" followed by a bunch of lines in yellow. Hit ctrl-c to kill it.

Run `./start.ps1 -config ~\.kube\config` again. It should run to completion with the last line reading "Starting kubeproxy"

Make sure the node joined by running

`vagrant ssh master`

Once in bash, run `kubectl get node`

It should show all 3 nodes joined

```bash
$ kubectl get node
NAME                 STATUS   ROLES    AGE   VERSION
master.localdomain   Ready    master   97m   v1.14.1
nodea.localdomain    Ready    <none>   61m   v1.14.1
win1                 Ready    <none>   20m   v1.14.1
```

### Running a Windows pod

From the same SSH session, run

```bash
kubectl create -f https://raw.githubusercontent.com/PatrickLang/Windows-K8s-Samples/master/iis/iis-2019.yaml
```

> Current point of investigation

The pod will start, but currently can't be reached from the Linux nodes