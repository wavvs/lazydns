#!/bin/bash
GREEN="\033[1;32m"
RESET="\033[0m"

script_path=$(dirname $(realpath -s $0))
bin_path=$script_path/bin 

GOPATH=$(go env GOPATH)
GOBIN=$(go env GOBIN)

if [ -z "$GOBIN" ]; then
    gobin=$GOPATH/bin
else
    gobin=$GOBIN
fi

cwd=$(pwd)

echo -e "${GREEN}[*] Installing Zdns${RESET}"
git clone https://github.com/zmap/zdns.git /tmp/zdns &> /dev/null
cd /tmp/zdns && go build -o $bin_path/zdns zdns/main.go
cd $cwd && rm -rf /tmp/zdns

echo -e "${GREEN}[*] Installing Amass${RESET}"
GO111MODULE=on go get -u github.com/OWASP/Amass/v3/... &> /dev/null
cp $gobin/amass $bin_path/amass

echo -e "${GREEN}[*] Installing Shuffledns${RESET}"
GO111MODULE=on go get -u github.com/projectdiscovery/shuffledns/cmd/shuffledns &> /dev/null
cp $gobin/shuffledns $bin_path/shuffledns

echo -e "${GREEN}[*] Installing Massdns${RESET}"
git clone https://github.com/blechschmidt/massdns.git /tmp/massdns &> /dev/null
cd /tmp/massdns && make --silent
cp /tmp/massdns/bin/massdns $bin_path
cd $cwd && rm -rf /tmp/massdns

echo -e "${GREEN}[*] Installing Dnsgen${RESET}"
pip3 install --disable-pip-version-check --quiet dnsgen

echo -e "${GREEN}[*] Installing Dnsvalidator${RESET}"
git clone https://github.com/vortexau/dnsvalidator.git /tmp/dnsvalidator &> /dev/null
cd /tmp/dnsvalidator && sudo python3 setup.py --quiet install &> /dev/null
cd $cwd && sudo rm -rf /tmp/dnsvalidator

echo -e "${GREEN}[*] Installing pv${RESET}"
sudo apt install pv -qq &> /dev/null

echo -e "${GREEN}[*] Installing jq${RESET}"
sudo apt install jq -qq &> /dev/null