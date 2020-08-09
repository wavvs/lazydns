import requests
import csv

PUBDNS_URL = 'https://public-dns.info/nameservers.csv'


def fetch_resolvers():
    r = requests.get(PUBDNS_URL).content.decode().split('\n')
    data = csv.DictReader(r)
    valid_resolvers = [i['ip_address'] for i in data if i['reliability'] == '1.00' and ':' not in i['ip_address']]
    for i in valid_resolvers:
        print(i)


if __name__ == '__main__':
    fetch_resolvers()
