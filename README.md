# lazydns
Script to automate initial domain reconnaissance and subdomain enumeration.

## Features
* **Passive** and **Active** modes
	* Sonar DNS [database](https://sonar.omnisint.io/) (Project Crobat)
	* [Amass](https://github.com/OWASP/Amass)
	* [zdns](https://github.com/zmap/zdns)
	* [dnsgen](https://github.com/ProjectAnte/dnsgen)
	* compiled [wordlists](https://github.com/wavvs/lazydns/tree/master/wordlists) from several sources 
* Auto-updated list of [resolvers](https://github.com/wavvs/lazydns/blob/master/resolvers.txt) (updates every day)
	* https://public-dns.info
	* [dnsvalidator](https://github.com/vortexau/dnsvalidator)
	* custom validation using [massdns](https://github.com/blechschmidt/massdns.git)
## Info
```bash
Usage: lazydns.py [OPTIONS] COMMAND [ARGS]...

Options:
  -c, --config PATH  Lazydns configuration file.
  -d TEXT            Comma-separated domain names.
  -df PATH           Path to file containing domain names.
  --dir PATH         Output directory.  [default: .]
  -f, --prefix TEXT  Filename prefix to name all output files.  [default:
                     lazydns]

  --help             Show this message and exit.

Commands:
  active   Active DNS enumeration.
  passive  Passive DNS enumeration.
```
### Passive mode
Passive mode includes:
* Querying Sonar database from https://sonar.omnisint.io/
* [Amass](https://github.com/OWASP/Amass) passive enumeration (specify API keys in configuration file)
```bash
Usage: lazydns.py passive [OPTIONS]

  Passive DNS enumeration.

Options:
  --amass / --no-amass      Enable Amass passive enumeration.  [default: True]
  --sonar / --no-sonar      SonarSearch enumeration.  [default: True]
  -ac, --amass-config PATH  Amass configuration file.
  --help                    Show this message and exit.
```
In passive mode script can generate following files:
* `{dir}/{base-filename}-amass-passive-{generated date}.log`
* `{dir}/{base-filename}-{generated date}.passive`
### Active mode
Active mode includes:
* Brute-forcing subdomains using [zdns](https://github.com/zmap/zdns) and [Amass](https://github.com/OWASP/Amass)
* Alterations generation using [dnsgen](https://github.com/ProjectAnte/dnsgen)
```bash
Usage: lazydns.py active [OPTIONS]

  Active DNS enumeration.

Options:
  --amass / --no-amass      Enable Amass active enumeration.
  --brute / --no-brute      Enable brute-forcing.
  --alts / --no-alts        Enable alterations.
  -ac, --amass-config PATH  Amass configuration file.
  -w, --wordlist PATH       Subdomains wordlist.  [default:
                            wordlists/normal.txt]

  -ns, --resolvers PATH     List of name servers.  [default:
                            resolvers.txt; required]

  -t, --threads INTEGER     Number of threads passed to tool.  [default: 350]
  -r, --retries INTEGER     Number of retries passed to tool.  [default: 3]
  -p, --processes INTEGER   Number of processes passed to tool.  [default: 4]
  -kf, --known PATH         File with known subdomains (i.e., from "passive"
                            subcommand)

  --tool [zdns]             Subdomains brute-forcing tool.  [default: zdns]
  --help                    Show this message and exit.
```