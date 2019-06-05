# Use a release number from https://github.com/kubernetes/kubernetes/releases/
$kubernetesVersion = "v1.14.2"


$nodeUrl = "https://dl.k8s.io/$kubernetesVersion/kubernetes-node-windows-amd64.tar.gz" # kubelet, kube-proxy, kubectl, kubeadm
# $clientUrl = "https://dl.k8s.io/$kubernetesVersion/kubernetes-client-windows-amd64.tar.gz" # kubectl

$kubeDir = "c:\k"


# These functions are copied and modified from https://github.com/Azure/aks-engine/blob/master/parts/k8s/windowskubeletfunc.ps1 and https://github.com/Azure/aks-engine/blob/master/parts/k8s/kuberneteswindowsfunctions.ps1
# See https://github.com/Azure/aks-engine/blob/master/LICENSE
# MIT License

# Copyright (c) 2016 Microsoft Azure

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


function DownloadFileOverHttp
{
    Param(
        [Parameter(Mandatory=$true)][string]
        $Url,
        [Parameter(Mandatory=$true)][string]
        $DestinationPath
    )
    $secureProtocols = @()
    $insecureProtocols = @([System.Net.SecurityProtocolType]::SystemDefault, [System.Net.SecurityProtocolType]::Ssl3)

    foreach ($protocol in [System.Enum]::GetValues([System.Net.SecurityProtocolType]))
    {
        if ($insecureProtocols -notcontains $protocol)
        {
            $secureProtocols += $protocol
        }
    }
    [System.Net.ServicePointManager]::SecurityProtocol = $secureProtocols

    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest $Url -UseBasicParsing -OutFile $DestinationPath -Verbose
    $ProgressPreference = $oldProgressPreference
    Write-Output "Downloaded file to $DestinationPath"
}

# https://stackoverflow.com/a/34559554/697126
function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

function
Get-KubeBinaries {
    Param(
        [Parameter(Mandatory = $true)][string]
        $KubeBinariesURL,
        $PathInTar = "kubernetes\node\bin\*",
        $KubeDir
    )

    if ($computerInfo.WindowsVersion -eq "1709") {
        Write-Error "Server version 1709 does not support using kubernetes binaries in tar file."
        return
    }

    $tempdir = New-TemporaryDirectory
    $binaryPackage = "$tempdir\k.tar.gz"
    for ($i = 0; $i -le 10; $i++) {
        DownloadFileOverHttp -Url $KubeBinariesURL -DestinationPath $binaryPackage
        if ($?) {
            break
        }
        else {
            Write-Output $Error[0].Exception.Message
        }
    }

    # using tar to minimize dependencies
    # tar should be avalible on 1803+
    tar -xzf $binaryPackage -C $tempdir

    # copy binaries over to kube folder
    $windowsbinariespath = $KubeDir
    if (!(Test-path $windowsbinariespath)) {
        mkdir $windowsbinariespath
    }
    cp $([System.IO.Path]::Combine($tempdir, $PathInTar)) $windowsbinariespath -Recurse

    #remove temp folder created when unzipping
    del $tempdir -Recurse
}

function
New-InfraContainer {
    Param(
        [Parameter(Mandatory = $true)][string]
        $KubeDir
    )
    cd $KubeDir
    $computerInfo = Get-ComputerInfo
    $windowsBase = if ($computerInfo.WindowsVersion -eq "1709") {
        "microsoft/nanoserver:1709"
    }
    elseif ($computerInfo.WindowsVersion -eq "1803") {
        "microsoft/nanoserver:1803"
    }
    elseif ($computerInfo.WindowsVersion -eq "1809") {
        "mcr.microsoft.com/windows/nanoserver:1809"
    }
    else {
        "mcr.microsoft.com/nanoserver-insider"
    }

    "FROM $($windowsBase)" | Out-File -encoding ascii -FilePath Dockerfile
    "CMD cmd /c ping -t localhost" | Out-File -encoding ascii -FilePath Dockerfile -Append
    docker build -t kubletwin/pause .
}


Get-KubeBinaries -KubeBinariesURL $nodeUrl -PathInTar "kubernetes\node\bin\*" -KubeDir $kubeDir
# Get-KubeBinaries -KubeBinariesURL $clientUrl -PathInTar "kubernetes\client\bin\*"

New-InfraContainer -KubeDir $kubeDir

# Set up kubelet and kube-proxy services
# TODO use better --kubeconfig path once kubeadm updated
$kubeletArgs = "--pod-infra-container-image=kubeletwin/pause --kubeconfig=C:\var\lib\kubelet\config.yaml" 
# --network-plugin=

sc.exe create kubelet binPath= "$([System.IO.Path]::Combine($kubeDir, "kubelet.exe")) --windows-service $($kubeletArgs)"
sc.exe create kube-proxy binPath= "$([System.IO.Path]::Combine($kubeDir, "kube-proxy.exe")) --windows-service"