#!/bin/bash -xe
for i in "$@"
 do
  case $i in
   -v=*|--kopsversion=*)
   KOPSVERSION=$(echo $i | cut -d'=' -f 2)
   shift
   ;;
   *)
         # unknown option
   ;;
  esac
 done
echo "Pre-configuring env" | tee -a /tmp/start_log.txt 
TERRAFORM_VERSION='0.11.10'
KUBECTL_VERSION=$KOPSVERSION
KOPSVERSION=$(echo $KOPSVERSION | awk -F '.' '{print($1"."$2".0")}')
TERRAFORM_HELM_PROVIDER='0.6.0'
sudo mkdir /opt/k8s || true
sudo chown ubuntu /opt/ -R
cd /opt/bastion
echo "Generating ssh key for user Ubuntu"

#install kops
sudo wget -O kops https://github.com/kubernetes/kops/releases/download/$KOPSVERSION/kops-linux-amd64
sudo chmod +x ./kops && sudo mv ./kops /usr/local/bin/
#install kubectl
sudo wget 'https://dl.k8s.io/v'$KUBECTL_VERSION'/kubernetes-client-linux-amd64.tar.gz' && sudo tar xvf kubernetes-client-linux-amd64.tar.gz
sudo mv kubernetes/client/bin/kubectl /usr/local/bin/ && sudo chmod +x /usr/local/bin/kubectl
#install helm
sudo curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > /tmp/get_helm.sh
sudo chmod 700 /tmp/get_helm.sh && sudo /tmp/get_helm.sh
#install terraform
sudo wget 'https://releases.hashicorp.com/terraform/'$TERRAFORM_VERSION'/terraform_'$TERRAFORM_VERSION'_linux_amd64.zip'
sudo wget 'https://github.com/terraform-providers/terraform-provider-helm/releases/download/v'$TERRAFORM_HELM_PROVIDER'/terraform-provider-helm_v'$TERRAFORM_HELM_PROVIDER'_linux_amd64.tar.gz'
sudo unzip 'terraform_'$TERRAFORM_VERSION'_linux_amd64.zip' && sudo mv terraform /usr/local/bin/terraform
sudo tar -xvf terraform-provider-helm_v*.*
sudo mkdir -p /home/ubuntu/.terraform.d/plugins/ || true
sudo mv terraform-provider-helm_linux_amd64/terraform-provider-helm /home/ubuntu/.terraform.d/plugins/ || true
#configure aliases
if [[ $(grep kubectl /etc/bash.bashrc | wc -l) = 0 ]]; then
 echo "alias kb='kubectl'" | sudo tee -a /etc/bash.bashrc
 echo "alias kb-pods='kubectl get pods --all-namespaces'" | sudo tee -a /etc/bash.bashrc
 echo "alias kb-svc='kubectl get services --all-namespaces'" | sudo tee -a /etc/bash.bashrc
 echo "alias kb-dp='kubectl describe pods'" | sudo tee -a /etc/bash.bashrc
 echo "alias kb-ds='kubectl describe service'" | sudo tee -a /etc/bash.bashrc
 fi
echo "Pre-configuring env done" | tee -a /tmp/start_log.txt