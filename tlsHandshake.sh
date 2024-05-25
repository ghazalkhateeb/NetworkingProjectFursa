#!/bin/bash

# check i fprovided ip addres
if [ $# -ne 1 ]; then
  echo "Please add the server ip as argument"
  exit 1
fi

#STEP 1-2 the client sends a Client Hello message to the server and take the response back
curl -s  -X POST -H "Content-Type: application/json"   -d '{"version": "1.3", "ciphersSuites": ["TLS_AES_128_GCM_SHA256", "TLS_CHACHA20_POLY1305_SHA256"], "message": "Client Hello"}'   http://$1:8080/clienthello > respon


if [ $? -ne 0 ];then
    echo "Server Certificate is invalid."
    exit 5
fi

jq -r '.serverCert' respon > cert.pem

# var to hold session id
sessionID=$(jq -r '.sessionID' respon)
# to remove respon
rm respon

#STEP 3 Server Certificate Verification



# here i verify the exit code in the 2 command th wget and openssl and exit 5 if error happened
# to check if cert.pem is valid
wget "https://alonitac.github.io/DevOpsTheHardWay/networking_project/cert-ca-aws.pem"

# check exit code if it faild exit with code 5
if [ $? -ne 0 ];then
    echo "Server Certificate is invalid."
    exit 5
fi

openssl verify -CAfile cert-ca-aws.pem cert.pem

# check exit code if it faild exit with code 5
if [ $? -ne 0 ];then
    echo "Server Certificate is invalid."
    exit 5
fi

rm cert-ca-aws.pem

#STEP 4-5 Client-Server master-key exchange GENERATE NEW KEY TO SEND TO SERVER AND RECEIVE RESPONSE BACK

openssl rand -base64 32 > master-key

# var to hold master key and the encrypted master key
MASTER_KEY=$(cat master-key)
MASTER_KEY_ENC=$(openssl smime -encrypt -aes-256-cbc -in master-key -outform DER cert.pem | base64 -w 0)

rm cert.pem
rm master-key
# body of the request
sampleMessagesent="Hi server, please encrypt me and send to client!"
body="{\"sessionID\": \"$sessionID\",\"masterKey\": \"$MASTER_KEY_ENC\",\"sampleMessage\": \"$sampleMessagesent\"}"


# send message and save the respon
SAMPLE_MESSAGE_REC=$(curl -s -X POST -H "Content-Type: application/json" -d "$body" "$1":8080/keyexchange | jq -r '.encryptedSampleMessage')

# DECREPT THE MESSAGE
DECREPT_MESSAGE=$(echo "$SAMPLE_MESSAGE_REC" | base64 -d | openssl enc -d -aes-256-cbc -pbkdf2 -k "$MASTER_KEY")


#STEP 6 Client verification message

#compare the 2 strings
if [[ "$DECREPT_MESSAGE" == "$sampleMessagesent" ]]; then
    echo "Client-Server TLS handshake has been completed successfully"
else
    echo "Server symmetric encryption using the exchanged master-key has failed."
    exit 6
fi