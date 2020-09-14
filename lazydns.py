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

from subprocess import Popen, PIPE
from colorama import init, Fore

init(autoreset=True)


PUBDNS_URL = 'https://public-dns.info/nameservers.csv'
SCRIPT_PATH = os.path.dirname(os.path.realpath(__file__))
SONAR_URL = 'https://sonar.omnisint.io/subdomains/{0}?page={1}'
FILEDATE = time.strftime("%d-%m-%Y-%H-%M-%S")
# Commands for passive DNS enumeration
AMASS_PASSIVE = '{bin} enum -nolocaldb -passive -exclude "Brute Forcing" -d {domains} -log {log}'
DM_PASSIVE = 'python3 {bin} -k {domain} -s 2'
# Commands for active DNS enumeration
AMASS_ACTIVE = '{bin} enum -nolocaldb -active -brute -d {domains} -log {log}'
ZDNS_ACTIVE = '{bin} A --name-servers=@{ns} -input-file {input} -threads {threads} -retries {retries} -log-file {log}'
PROGRESS = 'pv -l -s {count}'


def switch_clr(opt):
    return Fore.GREEN if opt else Fore.RED


def switch(opt):
    return 'on' if opt else 'off'


@click.group()
@click.option('--config', '-c', type=str, help='Lazydns configuration file.', default="")
@click.option('--domain', '-d', type=str, help="Comma-separated domain names.", required=True)
@click.option('--dir', type=click.Path(exists=False, resolve_path=True),
              help='Output directory.', default='.', show_default=True)
@click.option('--base-filename', '-f', type=str, help='Base filename prefix.')
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
            sys.exit(Fore.RED + "[!] Invalid configuration file.")
        tools = parser['tools']
        if 'amass' in tools:
            bins['amass'] = tools.get('amass')
        if 'zdns' in tools:
            bins['zdns'] = tools.get('zdns')
        if 'dm' in tools:
            bins['dm'] = tools['dm']
    for i in bins:
        bins[i] = os.path.expanduser(bins[i])
        if not os.path.exists(bins[i]):
            sys.exit(Fore.RED + '[!] Cannot find "{}" binary at {}'.format(i, bins[i]))

    if base_filename is None or len(base_filename) == 0:
        base_filename = 'lazydns'
    ctx.obj['domains'] = domain.split(',')
    ctx.obj['dir'] = dir
    ctx.obj['base_filename'] = base_filename
    ctx.obj['bins'] = bins


@lazydns.command(help="Passive DNS enumeration.")
@click.option('--amass/--no-amass', default=True, help='Enable Amass passive enumeration.', show_default=True)
@click.option('--sonar/--no-sonar', default=True, help='SonarSearch enumeration.', show_default=True)
@click.option('--dm/--no-dm', default=False, help='private', show_default=True)
@click.option('--amass-config', '-ac', type=click.Path(exists=True), help='Amass configuration file.')
@click.pass_context
def passive(ctx, amass, sonar, dm, amass_config):
    print(Fore.BLUE + '[*] Performing passive DNS enumeration.')
    print(switch_clr(amass) + '[!] Amass: {0}'.format(switch(amass)))
    print(switch_clr(sonar) + '[!] Sonar: {0}'.format(switch(sonar)))
    if dm:
        print(switch_clr(dm) + '[!] DM: {0}'.format(switch(dm)))

    domains = ctx.obj['domains']
    bins = ctx.obj['bins']
    base_filename = ctx.obj['base_filename']
    dir = ctx.obj['dir']
    subdomains = set()
    if sonar:
        print(Fore.YELLOW + '[*] Sonar passive enumeration.')
        sonar_result = fetch_from_sonar(domains)
        if sonar_result is None:
            print(Fore.RED + '[!] Sonar failed.')
        else:
            subdomains.update(sonar_result)

    if amass:
        print(Fore.YELLOW + '[*] Amass passive enumeration.')
        log_file = os.path.join(dir, '{0}-amass-passive-{1}.log'.format(base_filename, FILEDATE))
        cmd = AMASS_PASSIVE.format(bin=bins['amass'], domains=','.join(domains), log=log_file)
        if amass_config is not None:
            cmd += ' -config {0}'.format(amass_config)
        out, err = execute_cmd(cmd)
        if len(err) > 0 and len(out) == 0:
            sys.exit(Fore.RED + '[!] Amass: ' + err.decode())
        subdomains.update(out.decode().splitlines())

    if dm:
        if 'dm' in bins:
            print(Fore.YELLOW + '[*] DM passive enumeration.')
            for domain in domains:
                cmd = DM_PASSIVE.format(bin=bins['dm'], domain=domain)
                out, _ = execute_cmd(cmd)
                result = out.decode().splitlines()
                if result[0] != 'wasted':
                    subdomains.update(result)
                else:
                    print(Fore.RED + '[!] DM couldn\'t find subdomains or failed.')
        else:
            print(Fore.RED + '[!] Specify DM script path.')

    passive_file = os.path.join(dir, '{0}-{1}.passive'.format(base_filename, FILEDATE))
    with open(passive_file, 'a') as fd:
        if len(subdomains) > 0:
            subdomains = list(subdomains)
            subdomains.sort()
            fd.write('\n'.join(subdomains) + '\n')
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
    print(switch_clr(amass) + '[!] Amass: {0}'.format(switch(amass)))
    print(switch_clr(brute) + '[!] Brute-force: {0}'.format(switch(brute)))
    print(switch_clr(alts) + '[!] Alterations: {0}'.format(switch(alts)))
    domains = ctx.obj['domains']
    bins = ctx.obj['bins']
    base_filename = ctx.obj['base_filename']
    dir = ctx.obj['dir']

    if amass:
        print(Fore.YELLOW + '[*] Amass active enumeration.')
        log_file = os.path.join(dir, '{0}-amass-active-{1}.log'.format(base_filename, FILEDATE))
        amass_output = os.path.join(dir, '{0}-{1}.amass'.format(base_filename, FILEDATE))
        amass_cmd = AMASS_ACTIVE.format(bin=bins['amass'], domains=','.join(domains), log=log_file)
        if amass_config is not None:
            amass_cmd += ' -config {0}'.format(amass_config)
        if known is not None:
            amass_cmd += ' -nf {0}'.format(known)
        out, err = execute_cmd(amass_cmd)
        if len(err) > 0 and len(out) == 0:
            sys.exit(Fore.RED + '[!] Amass: ' + err.decode())
        subdomains = out.decode().splitlines()
        subdomains.sort()
        with open(amass_output, 'w') as fd:
            fd.write('\n'.join(subdomains) + '\n')
        print(Fore.BLUE + '[!] Amass found {0} subdomains on active enumeration.'.format(len(subdomains)))

    if brute:
        print(Fore.YELLOW + '[*] Subdomains brute-forcing using ZDNS.')
        log_file = os.path.join(dir, '{0}-brute-{1}.log'.format(base_filename, FILEDATE))
        brute_output = os.path.join(dir, '{0}-{1}.brute'.format(base_filename, FILEDATE))
        brute_output_raw = brute_output + '.raw'
        _, tmp = tempfile.mkstemp()
        sed_cmd = 'sed "s/$/.{0}/" {1} >> {2}'
        for domain in domains:
            execute_cmd(sed_cmd.format(domain, wordlist, tmp))
        out, _ = execute_cmd('wc -l < {0}'.format(tmp))
        print(Fore.YELLOW + '[!] Total {0} subdomains to brute-force.'.format(out.decode()))
        os.remove(tmp)
        print('TODO')

    if alts:
        print('TODO')


def execute_cmd(cmd):
    with Popen(cmd, shell=True, stdout=PIPE, stderr=PIPE) as proc:
        return proc.communicate()


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
