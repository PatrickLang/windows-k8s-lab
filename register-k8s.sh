cat >/etc/systemd/system/kube-apiserver.service <<EOL

[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop %n
ExecStartPre=-/usr/bin/docker rm %n
ExecStartPre=/usr/bin/docker pull registry.centos.org/centos/kubernetes-apiserver
ExecStart=/usr/bin/docker run --rm --net=host -p 443:443 -v /etc/kubernetes:/etc/kubernetes:z --name %n registry.centos.org/centos/kubernetes-apiserver

[Install]
WantedBy=multi-user.target
EOL

cat >/etc/systemd/system/kube-controller-manager.service <<EOL
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop %n
ExecStartPre=-/usr/bin/docker rm %n
ExecStartPre=/usr/bin/docker pull registry.centos.org/centos/kubernetes-controller-manager
ExecStart=/usr/bin/docker run --rm --net=host -v /etc/kubernetes:/etc/kubernetes:z --name %n registry.centos.org/centos/kubernetes-controller-manager

[Install]
WantedBy=multi-user.target
EOL

cat >/etc/systemd/system/kube-scheduler.service <<EOL
[Unit]
Description=Kubernetes Scheduler Plugin
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop %n
ExecStartPre=-/usr/bin/docker rm %n
ExecStartPre=/usr/bin/docker pull registry.centos.org/centos/kubernetes-scheduler
ExecStart=/usr/bin/docker run --rm --net=host -v /etc/kubernetes:/etc/kubernetes:z --name %n registry.centos.org/centos/kubernetes-scheduler

[Install]
WantedBy=multi-user.target
EOL
