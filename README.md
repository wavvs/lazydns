# lazydns
*WORK IN PROGESS*

Script to automate some steps of initial domain reconnaissance.
## Tools
Lazydns utilizes following tools:
* Amass (https://github.com/OWASP/Amass)
* zdns (https://github.com/zmap/zdns)
* dnsgen (https://github.com/ProjectAnte/dnsgen)
* jq (https://github.com/stedolan/jq)
* Argbash (https://github.com/matejak/argbash)

## How to use
```bash
Usage: ./lazydns.sh [-t|--threads <arg>] [-c|--config <arg>] [-w|--wordlist <arg>] [-r|--resolvers <arg>] [-a|--amass <arg>] [-z|--zdns <arg>] [-m|--dm <arg>] [-h|--help] <domain>
	<domain>: domain to enumerate
	-t, --threads: Zdns threads (default: '500')
	-c, --config: Path to amass configuration file (default: './amass_config.ini')
	-w, --wordlist: Path to subdomains wordlist (default: './normal.txt')
	-r, --resolvers: Path to resolvers list (default: './resolvers.txt')
	-a, --amass: Path to amass binary (default: '/usr/bin/amass')
	-z, --zdns: Path to zdns binary (default: '/bin/zdns')
	-m, --dm: private tool (no default)
	-h, --help: Prints help
```
You can pass environment variables to disable unnecessary reconnaissance steps:
* AMASS_DISABLE
* WORDLIST_DISABLE
* ALT_DISABLE
* FINAL_DISABLE
```bash
$ WORDLIST_DISABLE=true ./lazydns domain.com
```

Generated files:
* domain.passive
* domain.active
* domain.combined
* domain.wordlist.json
* domain.alt.json
* domain.final.json

## TODO
* Fill in README
* Improve workflow