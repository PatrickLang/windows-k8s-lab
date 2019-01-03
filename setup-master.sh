export cidr='10.244.0.0/16'
export masterip=`ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`

kubeadm init --pod-network-cidr=$cidr

kubectl apply -f /vagrant/kube-flannel-hostgw.yml

export digest=`openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'`
export token=`kubeadm token list | grep "default bootstrap" | awk '{print $1}'`

if [ ! -d /vagrant/tmp ]
then
    mkdir /vagrant/tmp
fi
echo "kubeadm join --token $token $masterip:6443 --discovery-token-ca-cert-hash sha256:$digest" > /vagrant/tmp/join.sh