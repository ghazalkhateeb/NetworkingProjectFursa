#!/bin/bash

#Check if public instance IP is provided.
if [ $# -ne 1 ]; then
    echo "public instance IP doesn't provided"
    exit 1
fi

SERVER_IP=$1

#Step 1: Client Hello(Client -> Server).
#Constructs a JSON string representing the Client Hello message and assigns it to the variable CLIENT_HELLO.
#The message includes the TLS version, supported cipher suites, and a message indicating it's a Client Hello.
CLIENT_HELLO=$(cat <<EOF
{
   "version": "1.3",
   "ciphersSuites": [
      "TLS_AES_128_GCM_SHA256",
      "TLS_CHACHA20_POLY1305_SHA256"
   ],
   "message": "Client Hello"
}
EOF
)

#This line prints an informational message indicating that the Client Hello message is being sent to the server.
echo "Sending Client Hello to $SERVER_IP..."

#Sends the Client Hello message to the server using curl.
#It posts the JSON data to http://<server-ip>:8080/clienthello and stores the response in the variable SERVER_HELLO.
SERVER_HELLO=$(curl -s -X POST -H "Content-Type: application/json" -d "$CLIENT_HELLO" "$SERVER_IP:8080/clienthello")


#Checks if the SERVER_HELLO variable is empty, indicating no response from the server.
#If true, it prints a message indicating no response and exits with a status code of 1.
if [ -z "$SERVER_HELLO" ]; then
    echo "No response from server."
    exit 1
fi

#Prints the received Server Hello message.
echo "Received Server Hello: $SERVER_HELLO"

#Extracts the session ID and server certificate, storing them in variables SESSION_ID and SERVER_CERT, respectively.
SESSION_ID=$(echo "$SERVER_HELLO" | jq -r '.sessionID')
SERVER_CERT=$(echo "$SERVER_HELLO" | jq -r '.serverCert')

#Save the server certificate in a file named cert.pem.
echo "$SERVER_CERT" > cert.pem


#Step 3: Server Certificate Verification.
#Downloads the CA certificate (cert-ca-aws.pem) from the provided URL and verifies the server certificate (cert.pem)
#using the CA certificate.
wget "https://alonitac.github.io/DevOpsTheHardWay/networking_project/cert-ca-aws.pem"

if [ $? -ne 0 ];then
    echo "Server Certificate is invalid."
    exit 5
fi

openssl verify -CAfile cert-ca-aws.pem cert.pem

#Check if certificate verification was successful.
if [ $? -ne 0 ];then
    echo "Server Certificate is invalid."
    exit 5
fi
rm cert-ca-aws.pem


#Step 4: Client-Server master-key exchange.
#These lines generate a random 32-byte master key using openssl rand,
#encrypt it using the server's certificate with openssl smime, and encode the encrypted key in base64 format.
#Then, it constructs a JSON payload for the key exchange, including the session ID, encrypted master key, and a sample message.
MASTER_KEY=$(openssl rand -base64 32)
echo "$MASTER_KEY" > master_key.txt

ENCRYPTED_MASTER_KEY=$(openssl smime -encrypt -aes-256-cbc -in master_key.txt -outform DER cert.pem | base64 -w 0)
KEY_EXCHANGE=$(cat <<EOF
{
    "sessionID": "$SESSION_ID",
    "masterKey": "$ENCRYPTED_MASTER_KEY",
    "sampleMessage": "Hi server, please encrypt me and send to client!"
}
EOF
)


#This line sends a POST request to the server's /keyexchange endpoint with the JSON payload containing the encrypted master key
#and session ID, and stores the server's response in the variable KEY_EXCHANGE_RESPONSE.
echo "Sending encrypted master key to server..."
KEY_EXCHANGE_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "$KEY_EXCHANGE" "$SERVER_IP:8080/keyexchange")


#This block checks if the KEY_EXCHANGE_RESPONSE variable is empty, indicating that there was no response from the server.
#If true, it prints an error message and exits with a non-zero exit status (1).
if [ -z "$KEY_EXCHANGE_RESPONSE" ]; then
    echo "No response from server."
    exit 1
fi

#This line prints the received response from the server to the console.
echo "Received response from server: $KEY_EXCHANGE_RESPONSE"

#Step 6: Client verification message.
#These lines parse the encrypted sample message from the server's response using jq, decode it from base64 format,
#and then decrypt it using openssl enc with the generated master key.
#If the decrypted sample message matches the expected value,
#it prints a success message indicating that the TLS handshake has been completed successfully.
#Otherwise, it prints an error message and exits with a non-zero exit status (6).
ENCRYPTED_SAMPLE_MESSAGE=$(echo "$KEY_EXCHANGE_RESPONSE" | jq -r '.encryptedSampleMessage')
DECODED_SAMPLE_MESSAGE_CLEAN=$(echo "$ENCRYPTED_SAMPLE_MESSAGE" | base64 -d | tr -d '\0')
DECRYPTED_SAMPLE_MESSAGE=$(echo "$DECODED_SAMPLE_MESSAGE_CLEAN" | openssl enc -d -aes-256-cbc -pbkdf2 -k "$MASTER_KEY" 2>/dev/null)

EXPECTED_RESULT=$"Hi server, please encrypt me and send to client!"

if [ "$DECRYPTED_SAMPLE_MESSAGE" != "$EXPECTED_RESULT" ]; then
    echo "Server symmetric encryption using the exchanged master-key has failed."
    exit 6
fi
echo "Client-Server TLS handshake has been completed successfully."
















