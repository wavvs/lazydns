import string
import random
import csv
import click
import requests
import json
import os
import time
import sys
import configparser
import tempfile
import subprocess

from subprocess import Popen
from colorama import init, Fore

init(autoreset=True)


PUBDNS_URL = 'https://public-dns.info/nameservers.csv'
SCRIPT_PATH = os.path.dirname(os.path.realpath(__file__))
SONAR_URL = 'https://sonar.omnisint.io/subdomains/{0}?page={1}'
AMASS_PASSIVE = '{bin} enum -silent -nolocaldb -passive -exclude "Brute Forcing" -d {domains} -o {output} -log {log}'
AMASS_ACTIVE = '{bin} enum -silent -nolocaldb -active -brute -d {domains} -o {output} -log {log}'
ZDNS_ACTIVE = '{bin} A --name-servers=@{ns} -input-file {input} -threads {threads} -retries {retries} -log-file {log}'

PROGRESS = 'pv -l -s {count}'


@click.group()
@click.option('--config', '-c', type=str, help='Lazydns configuration file.', default="")
@click.option('--domain', '-d', type=str, help="Comma-separated domain names.", required=True)
@click.option('--dir', type=click.Path(exists=False, resolve_path=True),
              help='Output directory.', default='.', show_default=True)
@click.option('--base-filename', '-f', type=str, default=time.strftime("%d-%m-%Y-%H-%M-%S"), help='Base filename prefix.')
@click.pass_context
def lazydns(ctx, config, domain, dir, base_filename):
    ctx.ensure_object(dict)
    if not os.path.exists(dir):
        os.mkdir(dir)

    bins = {
        'amass': os.path.join(SCRIPT_PATH, 'bin/amass'),
        'zdns': os.path.join(SCRIPT_PATH, 'bin/zdns'),
    }

    if os.path.exists(config):
        parser = configparser.ConfigParser()
        read_file = parser.read(config)
        if read_file[0] != config and 'tools' not in config:
            sys.exit("Invalid configuration file.")
        tools = parser.get('tools')
        bins['amass'] = tools.get('amass')
        bins['zdns'] = tools.get('zdns')
        bins['dm'] = tools.get('dm')
    for i in bins:
        if not os.path.exists(bins[i]):
            sys.exit('Cannot find "{}" binary at {}'.format(i, bins[i]))

    ctx.obj['domains'] = domain.split(',')
    ctx.obj['dir'] = dir
    ctx.obj['base_filename'] = base_filename
    ctx.obj['bins'] = bins


@lazydns.command(help="Passive DNS enumeration.")
@click.option('--amass/--no-amass', default=True, help='Enable Amass passive enumeration.', show_default=True)
@click.option('--sonar/--no-sonar', default=True, help='SonarSearch enumeration.', show_default=True)
@click.option('--dm/--no-dm', default=False, show_default=True)
@click.option('--amass-config', '-ac', type=click.Path(exists=True), help='Amass configuration file.')
@click.pass_context
def passive(ctx, amass, sonar, dm, amass_config):
    print(Fore.BLUE + '[*] Performing passive DNS enumeration.')
    print((Fore.GREEN if amass else Fore.RED) + '[!] Amass: {0}'.format('on' if amass else 'off'))
    print((Fore.GREEN if sonar else Fore.RED) + '[!] Sonar: {0}'.format('on' if sonar else 'off'))
    print((Fore.GREEN if dm else Fore.RED) + '[!] DM: {0}'.format('on' if dm else 'off'))

    domains = ctx.obj['domains']
    bins = ctx.obj['bins']
    subdomains = set()
    if sonar:
        sonar_result = fetch_from_sonar(domains)
        if sonar_result is None:
            print(Fore.RED + '[!] Sonar failed.')
        else:
            subdomains.update(sonar_result)

    if amass:
        _, tmp = tempfile.mkstemp()
        log_file = os.path.join(ctx.obj['dir'], 'amass-passive-' + ctx.obj['base_filename'] + '.log')
        cmd = AMASS_PASSIVE.format(bin=bins['amass'], domains=','.join(domains), output=tmp,
                                   log=log_file)
        if amass_config is not None:
            cmd += ' -config {0}'.format(amass_config)
        Popen(cmd, shell=True).wait()
        amass_subdomains = open(tmp, 'r').read().splitlines()
        os.remove(tmp)
        subdomains.update(amass_subdomains)

    subdomains = list(subdomains)
    subdomains.sort()
    fname = os.path.join(ctx.obj['dir'], ctx.obj['base_filename'] + '.passive')
    with open(fname, 'w') as f:
        f.write('\n'.join(subdomains))
    print(Fore.BLUE + "[+] Found {0} subdomains on passive DNS enumeration.".format(len(subdomains)))


@lazydns.command(help='Active DNS enumeration.')
@click.option('--amass/--no-amass', default=True, help='Enable Amass active enumeration.')
@click.option('--brute/--no-brute', default=True, help='Enable brute-forcing.')
@click.option('--alts/--no-alts', default=True, help='Enable alterations.')
@click.option('--amass-config', '-ac', type=click.Path(exists=True), help='Amass configuration file.')
@click.option('--wordlist', '-w', type=click.Path(exists=True), default=os.path.join(SCRIPT_PATH, 'wordlists/normal.txt'),
              help='Subdomains wordlist.', show_default=True)
@click.option('--resolvers', '-ns', type=click.Path(exists=True), default=os.path.join(SCRIPT_PATH, 'resolvers.txt'),
              help='List of name servers.', show_default=True, required=True)
@click.option('--threads', '-t', type=int, default=350, help='Number of threads passed to tool.', show_default=True)
@click.option('--retries', '-r', type=int, default=3, help='Number of retries passed to tool.', show_default=True)
@click.option('--known', '-k', type=click.Path(exists=False), help='File with known subdomains (i.e., from "passive" subcommand)')
@click.pass_context
def active(ctx, amass, brute, alts, amass_config, wordlist, resolvers, threads, retries, known):
    print(Fore.BLUE + '[*] Performing active DNS enumeration.')
    print((Fore.GREEN if amass else Fore.RED) + '[!] Amass: {0}'.format('on' if amass else 'off'))
    print((Fore.GREEN if brute else Fore.RED) + '[!] Brute-force: {0}'.format('on' if brute else 'off'))
    print((Fore.GREEN if alts else Fore.RED) + '[!] Alterations: {0}'.format('on' if alts else 'off'))

    domains = ctx.obj['domains']
    bins = ctx.obj['bins']

    if amass:
        print(Fore.YELLOW + '[*] Amass active enumeration.')
        log_file = os.path.join(ctx.obj['dir'], 'amass-active-' + ctx.obj['base_filename'] + '.log')
        amass_output = os.path.join(ctx.obj['dir'], ctx.obj['base_filename'] + '.amass')
        cmd = AMASS_ACTIVE.format(bin=bins['amass'], domains=','.join(domains), output=amass_output,
                                  log=log_file)
        if amass_config is not None:
            cmd += ' -config {0}'.format(amass_config)
        if known is not None:
            cmd += ' -nf {0}'.format(known)
        Popen(cmd, shell=True).wait()
        Popen('sort -u {0} -o {0}'.format(amass_output), shell=True)
        lines = Popen('wc -l < {0}'.format(amass_output), shell=True, stdout=subprocess.PIPE).stdout.read()
        print(Fore.BLUE + '[!] Amass found {0} subdomains on active enumeration.'.format(lines))


def fetch_from_sonar(domains):
    subdomains = []
    for domain in domains:
        try:
            page = 0
            while True:
                r = requests.get(SONAR_URL.format(domain, page), timeout=10)
                data = json.loads(r.content.decode())
                if data is None:
                    break
                subdomains.extend(data)
                page += 1
        except:
            return None
    return subdomains


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


if __name__ == '__main__':
    lazydns()
