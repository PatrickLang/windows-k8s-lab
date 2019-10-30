KUBEADM_VERSION="1.16.2"
KUBERNETES_VERSION="1.16.2"

# from https://kubernetes.io/docs/setup/independent/install-kubeadm/

# Add Kubernetes project repo
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Disable SELinux for now. Hopefully can enable it in the future
setenforce 0

# Install kubelet
yum install -y kubelet-$KUBERNETES_VERSION kubeadm-$KUBEADM_VERSION
systemctl enable kubelet && systemctl start kubelet

# Configure iptables to listen on bridge interface
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system