#!/bin/bash
# Script for subdomain enumeration.
# Required tools:
# - amass (https://github.com/OWASP/Amass)
# - zdns (https://github.com/zmap/zdns)
# - dnsgen (https://github.com/ProjectAnte/dnsgen)
# - jq (https://github.com/stedolan/jq)


SCRIPT_PATH=$(dirname $(realpath -s $0))
RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"


DOMAIN=$1

# EDIT HERE
AMASS=/usr/bin/amass
ZDNS=/bin/zdns
ALTDNS=~/.local/bin/altdns
DM=$DM

WORDLIST=$SCRIPT_PATH/normal.txt
AMASS_CONFIG=$SCRIPT_PATH/amass_config.ini
RESOLVERS=$SCRIPT_PATH/resolvers.txt
ZDNS_RATE=500

resolve_amass()
{
    echo -e "${GREEN}[+] Running Amass subdomain enumeration.${RESET}"
    $AMASS enum -d $DOMAIN -passive -config $AMASS_CONFIG -o $DOMAIN.passive -log amass.log 1&>/dev/null
    $AMASS enum -d $DOMAIN -active -brute -config $AMASS_CONFIG -nf $DOMAIN.passive -o $DOMAIN.active -log amass.log 1&>/dev/null 
    cat $DOMAIN.passive $DOMAIN.active | sort -u > $DOMAIN.combined
    echo -e "${YELLOW}[+] Found $(wc -l < $DOMAIN.combined) subdomains on Amass scan.${RESET}"
}

resolve_wordlist()
{
    echo -e "${GREEN}[+] Generating subdomains from a wordlist of ($(wc -l < $WORDLIST) subdomains).${RESET}"
    tmp=$(mktemp)
    sed "s/$/.$DOMAIN/" $WORDLIST >> $tmp
    # In order to view progress you can do "watch -n 0.1 wc -l zdns.json"
    $ZDNS alookup --name-servers=@$SCRIPT_PATH/resolvers.txt -input-file $tmp -threads $ZDNS_RATE -output-file $DOMAIN.wordlist.json -log-file zdns.log
    jq -r 'select(.status=="NOERROR") | .name' $DOMAIN.wordlist.json > $tmp
    cat $tmp >> $DOMAIN.combined    
    sort -u $DOMAIN.combined -o $DOMAIN.combined
    echo -e "${YELLOW}[+] Found $(wc -l < $tmp) subdomains.${RESET}"
    rm $tmp
}

# Private tool
resolve_dm()
{
    echo -e "${GREEN}[+] DM passive subdomain enumeration.${RESET}"
    tmp=$(mktemp)
    python3 $DM -k $DOMAIN > $tmp
    cat $tmp >> $DOMAIN.combined
    sort -u $DOMAIN.combined -o $DOMAIN.combined
    echo -e "${YELLOW}[+] Found $(wc -l < $tmp) subdomains.${RESET}"
    rm $tmp
}

resolve_alt()
{
    echo -e "${GREEN}[+] Generating subdomain alterations.${RESET}"
    tmp=$(mktemp)
    cat $DOMAIN.combined | dnsgen - > $tmp
    sort -u $tmp -o $tmp
    echo -e "${YELLOW}[+] $(wc -l < $tmp) alterations generated.${RESET}"
    $ZDNS alookup --name-servers=@$SCRIPT_PATH/resolvers.txt -input-file $tmp -threads $ZDNS_RATE -output-file $DOMAIN.alt.json -log-file zdns.log
    jq -r 'select(.status=="NOERROR") | .name' $DOMAIN.alt.json > $tmp
    echo -e "${YELLOW}[+] Found $(wc -l < $tmp) subdomains.${RESET}"
    cat $tmp >> $DOMAIN.combined
    sort -u $DOMAIN.combined -o $DOMAIN.combined
}

resolve_final()
{
    echo -e "${GREEN}[+] Final resolve.${RESET}"
    $ZDNS alookup --name-servers=@$SCRIPT_PATH/resolvers.txt -input-file $DOMAIN.combined -threads 5 -output-file $DOMAIN.final.json -log-file zdns.log
    echo -e "${YELLOW}[+] Found total $(jq -r 'select(.status=="NOERROR") | .name' $DOMAIN.final.json | wc -l) active subdomains.${RESET}"
}


resolve_amass

if [ "$DM" ]; then
    resolve_dm
fi

resolve_wordlist
resolve_alt
resolve_final
