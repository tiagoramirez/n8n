# Prerequisites
## 1. Tools
```sh
sudo apt update && sudo apt upgrade -y
sudo apt install -y git docker.io docker-compose
```
## 2. Github
```sh
mkdir -p ~/.ssh
cat >> ~/.ssh/config << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github
    AddKeysToAgent yes
EOF
chmod 600 ~/.ssh/config
```
```sh
cat >> ~/.ssh/github << EOF
{{private SSH key}}
EOF
chmod 700 ~/.ssh/github
```
# Clone
```sh
git clone git@github.com:tiagoramirez/n8n.git &&
cd n8n
```
# Setup .env and modify it
```sh
cp .env.example .env
```
# Run n8n
```sh
docker-compose up -d
```
