#!/bin/bash -xe
# 
for i in "$@"
  do
   case $i in
    -m=*|--mastercount=*)
    MASTERS=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -n=*|--workercount=*)
    NODES=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -mt=*|--mastertype=*)
    MASTER_TYPE=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -nt=*|--workertype=*)
    NODE_TYPE=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -r=*|--region=*)
    K8S_REGION=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -d=*|--maindomain=*)
    ROOT_ZONE_NAME=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -s=*|--stack=*)
    STACKNAME=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -l=*|--lantype=*)
    NET=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -nv=*|--workervolume=*)
    NODE_VOL=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -mv=*|--mastervolume=*)
    MASTER_VOL=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -t=*|--topology=*)
    TOPOLOGY=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -v=*|--kopsversion=*)
    KOPSVERSION=$(echo $i | cut -d'=' -f 2)
    shift
    ;;
    -env=*|--environment=*)
    ENV_NAME=$(echo $i | cut -d'=' -f 2)
    shift
    ;;

    *)
          # unknown option
    ;;
   esac
  done

  echo 'Starting Terraform conf generation'
  DNSZONE=$STACKNAME.$ROOT_ZONE_NAME
  DNSZONE_ID=$(aws route53 list-hosted-zones | jq '.HostedZones[] | select((.Name=='\"$DNSZONE.\"')).Id' | awk -F '"' '{print($2)}' | awk -F '/' '{print($3)}')
  MASTERZONES=$K8S_REGION'a,'$K8S_REGION'b,'$K8S_REGION'c'
  ZONES=$MASTERZONES
  KOPSNAME=$STACKNAME.$ROOT_ZONE_NAME
  ACCOUNT_ID=$(aws sts get-caller-identity | jq -r ".Account")
  
  echo "creating zones list for master"
  if [[ $MASTERS -eq 1 ]]; then
    MASTERZONES=$K8S_REGION'a'
  fi
  if [[ $MASTERS -eq 2 ]]; then
    MASTERZONES=$K8S_REGION'a,'$K8S_REGION'b'
  fi

  echo 'Creating terraform config with KOPS'
  K8DIR=/opt/k8s
  S3BUCKET=$STACKNAME'-configuration-files-'$ACCOUNT_ID'-'$K8S_REGION
  S3DIR='s3://'$S3BUCKET'/'$ENV_NAME'/kops-state'
  mkdir $K8DIR/kops || true
  sudo chown ubuntu $K8DIR -R

  #--------------   RUN KOPS   --------------
   kops create cluster --state=$S3DIR --networking $NET --ssh-public-key /home/ubuntu/.ssh/id_rsa.pub \
   --node-size=$NODE_TYPE --node-count $NODES --node-volume-size=$NODE_VOL \
   --master-size=$MASTER_TYPE --master-count $MASTERS --master-volume-size=$MASTER_VOL \
   --master-zones=$MASTERZONES --zones=$ZONES  --topology=$TOPOLOGY --cloud=aws  --authorization RBAC \
   --cloud-labels 'env=$STACKNAME' --dns-zone=$DNSZONE --name=$KOPSNAME --kubernetes-version=$KOPSVERSION --target=terraform --out=$K8DIR/kops/$ENV_NAME
               
  echo "
    variable \"env\" { default = \"$ENV_NAME\" }
    variable \"stack-name\" { default = \"$STACKNAME\" }
    variable \"domain-name\" { default = \"$DNSZONE\" }
    variable \"aws-account\" { default = \"$ACCOUNT_ID\" }
    variable \"hosterdzoneid\" { default = \"$DNSZONE_ID\" }
    variable \"region\" { default = \"$K8S_REGION\" }

    terraform {
        backend \"s3\" { 
          bucket = \"$S3BUCKET\"
          key    = \"$ENV_NAME\terraform-state\" 
          region = \"$K8S_REGION\" 
        } 
      }

    module \"main\" {
      source  = \"./kops/$ENV_NAME\"
    }" >> "$K8DIR/$ENV_NAME.auto_generated_config.tf"
   
  echo "Sync data to s3"
  aws s3 sync $K8DIR $S3DIR/generated-data-backup