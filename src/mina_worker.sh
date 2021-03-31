#!/bin/bash

source ./src/generic.sh

if [ $arch = "64" ]; then
    arch="amd64"
else
    printf "install script for ${RED}AMD 64bits architecture${NC} only!\n"
    exit
fi

if [ -x "$(command -v docker)" ]; then
    echo "Docker already installed, skipping this step"
else
    source ./src/install_docker.sh
fi

if [ -z ${KEY_GENERATOR_VERSION+x} ]; then
    KEY_GENERATOR_VERSION=1.0.2-06f3c5c
    echo "KEY_GENERATOR_VERSION is unset. Using ${KEY_GENERATOR_VERSION}"
fi

if [ -z ${MINA_WORKER_VERSION+x} ]; then
    MINA_WORKER_VERSION=1.1.4-a8893ab
    echo "MINA_WORKER_VERSION is unset. Using ${MINA_WORKER_VERSION}"
fi

printf "${RED}Keypair ${NC}generation"

if [ -f "/root/keys/mina/my-wallet" ]; then
    printf "Keypair ${RED}already exists${NC} at /root/keys/mina\nChecking conformity\n"
    docker run --interactive --tty --rm --entrypoint=mina-validate-keypair --volume /root/keys/mina:/keys minaprotocol/generate-keypair:$KEY_GENERATOR_VERSION -privkey-path /keys/my-wallet
else
    printf "generating keys at ${RED}/root/keys/mina${NC}\n"
    docker run --interactive --tty --rm --volume /root/keys/mina:/keys minaprotocol/generate-keypair:$KEY_GENERATOR_VERSION -privkey-path /keys/my-wallet
    chmod 700 /root/keys/mina
fi

mkdir -p /root/.mina-config

printf "Re-enter one last time your ${RED}private key password${NC} (the one you choose when generating your key pair): \n"
read -sp 'Enter password: ' PRIVATE_PASS

if [ ! "$(docker ps -q -f name=mina_deamon)" ]; then
    if [ "$(docker ps -aq -f status=exited -f name=mina_deamon)" ]; then
        # cleanup
        docker rm mina_deamon
    fi

    echo "Launching mina_worker"

    docker run --name mina_deamon -d \
        -p 8302:8302 \
        --restart=always \
        --mount "type=bind,source=/root/keys/mina,dst=/keys,readonly" \
        --mount "type=bind,source=/root/.mina-config,dst=/root/.mina-config" \
        -e CODA_PRIVKEY_PASS="${PRIVATE_PASS}" \
        minaprotocol/mina-daemon-baked:${MINA_WORKER_VERSION} \
        daemon \
        --block-producer-key /keys/my-wallet \
        --insecure-rest-server \
        --file-log-level Info \
        --log-level Info \
        --peer-list-url https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt
fi

sleep 5

docker exec mina_deamon mina client status
