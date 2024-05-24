#!/bin/bash

#Check if private instance IP is provided.
if [ $# -ne 1 ]; then
    echo "private instance IP doesn't provided"
    exit 1
fi

#assigns the value of the first argument provided to the variable private_instance_ip.
private_instance_ip=$1

#Check if the file mykey.pem exists.
if [ -e mykey.pem ]; then
  #If mykey.pem exists, rename it to my_old_key.pem.
  mv mykey.pem my_old_key.pem
  #Rename the corresponding public key file to my_old_key.pem.pub.
  mv mykey.pem.pub my_old_key.pem.pub
fi

#Generate a new SSH key pair named mykey.pem and mykey.pem.pub.
ssh-keygen -t rsa -b 4096 -f mykey.pem -N ""

#Copy the content of the public key mykey.pem.pub to the authorized_keys file on the private instance.
cat mykey.pem.pub | ssh -o StrictHostKeyChecking=accept-new -i my_old_key.pem ubuntu@$private_instance_ip "cat > ~/.ssh/authorized_keys"











