.PHONY = zdns amass massdns dnsgen dnsvalidator pv jq

curr_dir = $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
bin_dir = $(curr_dir)bin
$(shell mkdir -p $(bin_dir))
gopath=$(shell go env GOPATH)
gobin=$(shell go env GOPATH)


all: zdns amass massdns dnsgen dnsvalidator pv jq clean

zdns:
	@echo "[Installing ZDNS]"
	git clone https://github.com/zmap/zdns.git /tmp/zdns
	cd /tmp/zdns && go build -o $(bin_dir)/zdns zdns/main.go
	cd $(curr_dir)

amass:
	@echo "[Installing AMASS]"
	git clone https://github.com/OWASP/Amass.git /tmp/amass
	cd /tmp/amass && go get -d ./... && go build -o $(bin_dir)/amass cmd/amass/*
	cd $(curr_dir) 

massdns:
	@echo "[Installing MASSDNS]"
	git clone https://github.com/blechschmidt/massdns.git /tmp/massdns
	cd /tmp/massdns && $(CC) $(CFLAGS) -O3 -std=c11 -DHAVE_EPOLL -DHAVE_SYSINFO -Wall -fstack-protector-strong src/main.c -o $(bin_dir)/massdns
	cd $(curr_dir)

dnsgen:
	@echo "[Installing DNSGEN]"
	pip3 install --disable-pip-version-check --quiet dnsgen

dnsvalidator:
	@echo "[Installing DNSVALIDATOR]"
	git clone https://github.com/vortexau/dnsvalidator.git /tmp/dnsvalidator
	pip3 install setuptools wheel
	cd /tmp/dnsvalidator && sudo python3 setup.py --quiet install
	cd $(curr_dir)

pv:
	@echo "[Installing PV]"
	sudo apt install -y pv

jq:
	@echo "[Installing JQ]"
	sudo apt install -y jq

clean:
	rm -rf /tmp/zdns
	rm -rf /tmp/amass
	rm -rf /tmp/massdns
	sudo rm -rf /tmp/dnsvalidator