#!/bin/bash -xe
#decode
sudo -H -u ubuntu bash -c "sed -i -e 's/ //g' /opt/id_rsa.enc"
sudo -H -u ubuntu bash -c "fold -w65 /opt/id_rsa.enc | tee /opt/id_rsa"
sudo -H -u ubuntu bash -c "openssl enc -aes-256-cbc -d -a -md md5 -in /opt/id_rsa -out /home/ubuntu/.ssh/id_rsa -k $(cat key)"
#generate open key
sudo -H -u ubuntu bash -c "chmod 400 /home/ubuntu/.ssh/id_rsa"
sudo -H -u ubuntu bash -c "ssh-keygen -y -f /home/ubuntu/.ssh/id_rsa > /home/ubuntu/.ssh/id_rsa.pub"
sudo -H -u ubuntu bash -c "chown ubuntu /home/ubuntu/.ssh/id_rsa"
sudo -H -u ubuntu bash -c "chown ubuntu /home/ubuntu/.ssh/id_rsa.pub"
sudo rm key -f