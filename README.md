# lazydns
Script to automate initial domain reconnaissance.
## Tools
Lazydns utilizes following tools:
* [amass](https://github.com/OWASP/Amass)
* [zdns](https://github.com/zmap/zdns)
* [massdns](https://github.com/blechschmidt/massdns)
* [shuffledns](https://github.com/projectdiscovery/shuffledns)
* [dnsgen](https://github.com/ProjectAnte/dnsgen)
* [dnsvalidator](https://github.com/vortexau/dnsvalidator)
* [jq](https://github.com/stedolan/jq)
* [argbash](https://github.com/matejak/argbash)

## How to use
```bash
Usage: ./lazydns.sh [-u|--(no-)update] [--(no-)on-amass] [--(no-)on-wordlist] [--(no-)on-alt] [--(no-)wildcard] [-c|--config <arg>] [-w|--wordlist <arg>] [-r|--resolvers <arg>] [-t|--threads <arg>] [-s|--retries <arg>] [-m|--dm <arg>] [-h|--help] <domain>
	<domain>: Domain to enumerate
	-u, --update, --no-update: Update list of resolvers (off by default)
	--on-amass, --no-on-amass: Enable Amass subdomain enumeration (on by default)
	--on-wordlist, --no-on-wordlist: Enable subdomains bruteforce (on by default)
	--on-alt, --no-on-alt: Enable alterations bruteforce (on by default)
	--wildcard, --no-wildcard: Remove wildcard responses using shuffledns (off by default)
	-c, --config: Amass configuration file (no default)
	-w, --wordlist: Subdomains wordlist (default: 'normal.txt')
	-r, --resolvers: List of resolvers (default: 'resolvers.txt')
	-t, --threads: Subdomain bruteforce rate (default: '500')
	-s, --retries: Subdomain bruteforce retries (default: '3')
	-m, --dm: private tool (no default)
	-h, --help: Prints help
```