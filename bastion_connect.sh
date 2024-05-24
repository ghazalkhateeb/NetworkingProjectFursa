#!/bin/bash
#If the variable KEY_PATH doesn't exist, it prints an error message and exits with code 5.
if [ -z "$KEY_PATH" ]; then
    echo "KEY_PATH doesn't exist"
    exit 5
fi

#Check the number of command line arguments, if less than 1 print an error message and exit with code 5.
if [ $# -lt 1 ]; then
    echo "Please provide bastion IP address"
    exit 5

#Check if the number of command line arguments equal to 1.
#If only one argument is provided, it assumes that it's the public IP address.
elif [ $# -eq 1 ]; then
    #Connect to the public instance.
    ssh -i "$KEY_PATH" ubuntu@"$1"

#Check if the number of command line arguments equal to 2.
#If exactly two arguments are provided, it assumes the first argument is the pulic IP address and the second argument
#is the private instance IP address.
elif [ $# -eq 2 ]; then
    #Connect to the private instance via the public instance.
    ssh -i "$KEY_PATH" -t ubuntu@"$1" "ssh -i mykey.pem ubuntu@$2"


#If more than two arguments are provided, it assumes the first two arguments are the public IP address and the
#private instance IP address respectively, the third is a command.
else
    ssh -o StrictHostKeyChecking=accept-new -i "$KEY_PATH" ubuntu@$1 "ssh -i mykey.pem ubuntu@$2 '$3'"
fi



