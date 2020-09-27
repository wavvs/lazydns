import string
import random
import csv
import click
import requests
import json
import os
import time
import sys
import tempfile
import subprocess

from subprocess import Popen, PIPE
from os.path import join
from colorama import init, Fore

init(autoreset=True)


PUBDNS_URL = 'https://public-dns.info/nameservers.csv'
SONAR_URL = 'https://sonar.omnisint.io/subdomains/{0}?page={1}'
SCRIPT_PATH = os.path.dirname(os.path.realpath(__file__))
DATE = int(time.time())


class Cmd:
    @staticmethod
    def amass(bin, domain, log, mode, config):
        cmd = [
            bin,
            'enum',
            '-nolocaldb',
            '-d',
            domain,
            '-log',
            log
        ]
        if config is not None:
            cmd.extend(['-config', config])
        if mode == 'passive':
            cmd.extend(['-passive', '-exclude', '"Brute Forcing"'])
        else:
            cmd.extend(['-active', '-brute'])
        return cmd

    @staticmethod
    def zdns(bin, ns, input, threads, retries, procs, log):
        cmd = [
            bin,
            'A',
            '--name-servers=@' + ns,
            '-input-file',
            input,
            '-threads',
            threads,
            '-retries',
            retries,
            '-go-processes',
            procs,
            '-log-file',
            log
        ]
        return cmd

    @staticmethod
    def dm(bin, domain):
        cmd = [
            'python3',
            bin,
            '-k',
            domain,
            '-s',
            '2'
        ]
        return cmd

    @staticmethod
    def pv(count):
        cmd = ['pv', '-l', '-s', count]
        return cmd

    @staticmethod
    def jq(file):
        cmd = [
            'jq',
            '-r',
            '\'select(.status=="NOERROR") | .name\'',
            file
        ]
        return cmd

    @staticmethod
    def execute(cmd, shell=True, stdout=PIPE, stderr=PIPE, **kwargs):
        with Popen(cmd, shell=shell, stdout=stdout, stderr=stderr, **kwargs) as proc:
            return proc.communicate()


def switch_clr(opt):
    return Fore.GREEN if opt else Fore.RED


def switch(opt):
    return 'on' if opt else 'off'


@click.group()
@click.option('-d', 'domains', type=str, help="Comma-separated domain names.")
@click.option('-df', 'domains_file', type=click.Path(exists=True), help='Path to file containing domain names.')
@click.option('--dir', 'output_dir', type=click.Path(exists=False, resolve_path=True), help='Output directory.',
              default='.', show_default=True)
@click.option('--prefix', '-f', type=str, default='lazydns', help='Filename prefix to name all output files.',
              show_default=True)
@click.pass_context
def lazydns(ctx, domains, domains_file, output_dir, prefix):
    ctx.ensure_object(dict)
    if not os.path.exists(output_dir):
        os.mkdir(output_dir)

    log_dir = join(output_dir, 'logs')
    if not os.path.exists(log_dir):
        os.mkdir(log_dir)

    if domains is not None:
        ctx.obj['domains'] = domains.split(',')
    elif domains_file is not None:
        with open(domains_file, 'r') as f:
            ctx.obj['domains'] = f.read().splitlines()
    else:
        sys.exit(Fore.RED + '[!] Provide domain names via -d or -df!')

    bins = {
        'amass': join(SCRIPT_PATH, 'bin/amass'),
        'zdns': join(SCRIPT_PATH, 'bin/zdns'),
        'dm': join(SCRIPT_PATH, 'bin/dm.py')
    }
    files = {
        'amass_passive_log': join(log_dir, f'{prefix}-amass-passive-{DATE}.log'),
        'amass_active_log': join(log_dir, f'{prefix}-amass-active-{DATE}.log'),
        'brute_log': join(log_dir, f'{prefix}-brute-{DATE}.log'),
        'brute': join(output_dir, f'{prefix}-brute-{DATE}.txt'),
        'brute_json': join(output_dir, f'{prefix}-brute-{DATE}.json'),
        'amass_active': join(output_dir, f'{prefix}-amass-{DATE}.txt'),
        'passive': join(output_dir, f'{prefix}-passive-{DATE}.txt')
    }
    for i in bins:
        if i == 'dm':
            continue
        bins[i] = os.path.expanduser(bins[i])
        if not os.path.exists(bins[i]):
            sys.exit(Fore.RED + f'[!] Cannot find "{i}" binary at {bins[i]}')

    ctx.obj['files'] = files
    ctx.obj['bins'] = bins


@lazydns.command(help="Passive DNS enumeration.")
@click.option('--amass/--no-amass', default=True, help='Enable Amass passive enumeration.', show_default=True)
@click.option('--sonar/--no-sonar', default=True, help='SonarSearch enumeration.', show_default=True)
@click.option('--dm/--no-dm', default=False, hidden=True)
@click.option('--amass-config', '-ac', type=click.Path(exists=True), help='Amass configuration file.')
@click.pass_context
def passive(ctx, amass, sonar, dm, amass_config):
    print(Fore.BLUE + '[PASSIVE] Performing passive DNS enumeration.')
    print(switch_clr(amass) + '[!] Amass: {0}'.format(switch(amass)))
    print(switch_clr(sonar) + '[!] Sonar: {0}'.format(switch(sonar)))
    if dm:
        print(switch_clr(dm) + '[!] DM: {0}'.format(switch(dm)))

    domains = ctx.obj['domains']
    bins = ctx.obj['bins']
    files = ctx.obj['files']
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
        amass_cmd = Cmd.amass(bins['amass'], ','.join(domains),
                              files['amass_passive_log'], 'passive', amass_config)
        out, err = Cmd.execute(amass_cmd)
        if len(err) > 0 and len(out) == 0:
            sys.exit(Fore.RED + '[!] Amass: ' + err.decode())
        subdomains.update(out.decode().splitlines())

    if dm:
        if os.path.exists(bins['dm']):
            print(Fore.YELLOW + '[*] DM passive enumeration.')
            for domain in domains:
                dm_cmd = Cmd.dm(bins['dm'], domain)
                out, _ = Cmd.execute(dm_cmd)
                result = out.decode().splitlines()
                if result[0] != 'wasted':
                    subdomains.update(result)
                else:
                    print(Fore.RED + '[!] DM couldn\'t find subdomains or failed.')
        else:
            print(Fore.RED + '[!] Specify DM script path.')

    with open(files['passive'], 'w') as f:
        if len(subdomains) > 0:
            f.write('\n'.join(sorted(list(subdomains))) + '\n')
    print(Fore.BLUE + f'[+] Found {len(subdomains)} subdomains on passive DNS enumeration.')


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
@click.option('--processes', '-p', type=int, default=4, help='Number of processes passed to tool.', show_default=True)
@click.option('--known', '-kf', type=click.Path(exists=False), help='File with known subdomains (i.e., from "passive" subcommand)')
@click.option('--tool', type=click.Choice(['zdns']), default='zdns', help='Subdomains brute-forcing tool.', show_default=True)
@click.pass_context
def active(ctx, amass, brute, alts, amass_config, wordlist, resolvers, threads, retries, processes, known, tool):
    print(Fore.BLUE + '[ACTIVE] Performing active DNS enumeration.')
    print(switch_clr(amass) + '[!] Amass: {0}'.format(switch(amass)))
    print(switch_clr(brute) + '[!] Brute-force: {0}'.format(switch(brute)))
    print(switch_clr(alts) + '[!] Alterations: {0}'.format(switch(alts)))

    domains = ctx.obj['domains']
    bins = ctx.obj['bins']
    files = ctx.obj['files']

    if amass:
        print(Fore.YELLOW + '[AMASS] Amass active enumeration.')
        amass_cmd = Cmd.amass(bins['amass'], ','.join(domains), files['amass_active_log'], 'active', amass_config)
        if known is not None:
            amass_cmd.extend(['-nf', known])
        out, err = Cmd.execute(amass_cmd)
        if len(err) > 0 and len(out) == 0:
            sys.exit(Fore.RED + '[!] Amass: ' + err.decode())
        subdomains = sorted(out.decode().splitlines())
        with open(files['amass_active'], 'w') as f:
            f.write('\n'.join(subdomains) + '\n')
        print(Fore.BLUE + f'[AMASS] Amass found {len(subdomains)} subdomains on active enumeration.')

    if brute:
        print(Fore.YELLOW + f'[BRUTE] Subdomains brute-force using {tool.upper()}.'.format)
        _, tmp = tempfile.mkstemp()
        for domain in domains:
            Cmd.execute(f'sed "s/$/.{domain}/" {wordlist} >> {tmp}')
        out, _ = Cmd.execute(['wc', '-l', '<', tmp])
        total_subdomains = out.decode().strip()
        print(Fore.YELLOW + f'[BRUTE] Total {total_subdomains} subdomains to brute-force.')
        if tool == 'zdns':
            zdns_cmd = Cmd.zdns(bins[tool], resolvers, tmp, threads, retries, processes, files['brute_log'])
            zdns_cmd += ['|'] + Cmd.pv(total_subdomains) + ['>', files['brute_json']]
            Cmd.execute(zdns_cmd, stdout=None, stderr=None)
            Cmd.execute(Cmd.jq(files['brute_json']) + ['>', files['brute']])
            out, _ = Cmd.execute(['wc', '-l', '<', files['brute']])
            total_subdomains = out.decode().strip()
            print(Fore.BLUE + f'[BRUTE] {tool.upper()} found {total_subdomains} subdomains on active enumeration.')
            # TODO: If TIMEOUT is in raw output, print and remove faulty resolvers from the list and re-run subdomains resolve.
        os.remove(tmp)
    if alts:
        print('TODO')


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
