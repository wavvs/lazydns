import requests
import csv

PUBDNS_URL = 'https://public-dns.info/nameservers.csv'


def fetch_resolvers():
    r = requests.get(PUBDNS_URL).content.decode().split('\n')
    data = csv.DictReader(r)
    for i in data:
        if i['reliability'] == '1.00' and i['dnssec'] == 'true': 
            print(i['ip_address'])


if __name__ == '__main__':
    fetch_resolvers()
