import requests
import csv
import random
import string

PUBDNS_URL = 'https://public-dns.info/nameservers.csv'


def fetch_resolvers():
    r = requests.get(PUBDNS_URL).content.decode().split('\n')
    data = csv.DictReader(r)
    for i in data:
        if i['reliability'] == '1.00' and i['dnssec'] == 'true':
            print(i['ip_address'])


def gen_nxdomain(num, domain):
    for _ in range(num):
        subdomain = ''.join(random.choice(string.ascii_lowercase) for i in range(16))
        print(subdomain + '.' + domain)
