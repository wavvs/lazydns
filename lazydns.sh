#!/bin/bash
#
# ARG_POSITIONAL_SINGLE([domain],[Domain to enumerate],[])
# ARG_OPTIONAL_BOOLEAN([update],[u],[Update list of resolvers],[off])
# ARG_OPTIONAL_BOOLEAN([on-amass],[],[Enable Amass subdomain enumeration],[on])
# ARG_OPTIONAL_BOOLEAN([on-wordlist],[],[Enable subdomains bruteforce],[on])
# ARG_OPTIONAL_BOOLEAN([on-alt],[],[Enable alterations bruteforce],[on])
# ARG_OPTIONAL_SINGLE([config],[c],[Amass configuration file],[])
# ARG_OPTIONAL_SINGLE([wordlist],[w],[Subdomains wordlist],[normal.txt])
# ARG_OPTIONAL_SINGLE([resolvers],[r],[List of resolvers],[resolvers.txt])
# ARG_OPTIONAL_SINGLE([threads],[t],[Subdomain bruteforce rate],[500])
# ARG_OPTIONAL_SINGLE([retries],[s],[Subdomain bruteforce retries],[3])
# ARG_OPTIONAL_SINGLE([dm],[m],[private tool],[])
# ARG_HELP([Lazydns usage])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([

RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"


die()
{
	local _ret="${2:-1}"
	test "${_PRINT_HELP:-no}" = yes && print_help >&2
	echo "$1" >&2
	exit "${_ret}"
}


begins_with_short_option()
{
	local first_option all_short_options='ucwrmh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
# THE DEFAULTS INITIALIZATION - OPTIONALS
script_path=$(dirname $(realpath -s $0))
_arg_update="off"
_arg_on_amass="on"
_arg_on_wordlist="on"
_arg_on_alt="on"
_arg_wildcard="off"
_arg_config=
_arg_wordlist=$script_path/wordlists/normal.txt
_arg_resolvers=$script_path/resolvers.txt
_arg_threads="500"
_arg_retries="3"
_arg_dm=

banner() 
{
    echo "                                                                                 ";
    echo "    _/          _/_/    _/_/_/_/_/  _/      _/  _/_/_/    _/      _/    _/_/_/   ";
    echo "   _/        _/    _/        _/      _/  _/    _/    _/  _/_/    _/  _/          ";
    echo "  _/        _/_/_/_/      _/          _/      _/    _/  _/  _/  _/    _/_/       ";
    echo " _/        _/    _/    _/            _/      _/    _/  _/    _/_/        _/      ";
    echo "_/_/_/_/  _/    _/  _/_/_/_/_/      _/      _/_/_/    _/      _/  _/_/_/         ";
    echo "                                                                                 ";
    echo "                                                                                 ";
}

print_help()
{
	banner
	printf '%s\n' "Lazydns usage"
	printf 'Usage: %s [-u|--(no-)update] [--(no-)on-amass] [--(no-)on-wordlist] [--(no-)on-alt] [--(no-)wildcard] [-c|--config <arg>] [-w|--wordlist <arg>] [-r|--resolvers <arg>] [-t|--threads <arg>] [-s|--retries <arg>] [-m|--dm <arg>] [-h|--help] <domain>\n' "$0"
	printf '\t%s\n' "<domain>: Domain to enumerate"
	printf '\t%s\n' "-u, --update, --no-update: Update list of resolvers (off by default)"
	printf '\t%s\n' "--on-amass, --no-on-amass: Enable Amass subdomain enumeration (on by default)"
	printf '\t%s\n' "--on-wordlist, --no-on-wordlist: Enable subdomains bruteforce (on by default)"
	printf '\t%s\n' "--on-alt, --no-on-alt: Enable alterations bruteforce (on by default)"
	printf '\t%s\n' "--wildcard, --no-wildcard: Remove wildcard responses using shuffledns (off by default)"
	printf '\t%s\n' "-c, --config: Amass configuration file (no default)"
	printf '\t%s\n' "-w, --wordlist: Subdomains wordlist (default: 'normal.txt')"
	printf '\t%s\n' "-r, --resolvers: List of resolvers (default: 'resolvers.txt')"
	printf '\t%s\n' "-t, --threads: Subdomain bruteforce rate (default: '500')"
	printf '\t%s\n' "-s, --retries: Subdomain bruteforce retries (default: '3')"
	printf '\t%s\n' "-m, --dm: private tool (no default)"
	printf '\t%s\n' "-h, --help: Prints help"
}


parse_commandline()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-u|--no-update|--update)
				_arg_update="on"
				test "${1:0:5}" = "--no-" && _arg_update="off"
				;;
			-u*)
				_arg_update="on"
				_next="${_key##-u}"
				if test -n "$_next" -a "$_next" != "$_key"
				then
					{ begins_with_short_option "$_next" && shift && set -- "-u" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
				fi
				;;
			--no-on-amass|--on-amass)
				_arg_on_amass="on"
				test "${1:0:5}" = "--no-" && _arg_on_amass="off"
				;;
			--no-on-wordlist|--on-wordlist)
				_arg_on_wordlist="on"
				test "${1:0:5}" = "--no-" && _arg_on_wordlist="off"
				;;
			--no-on-alt|--on-alt)
				_arg_on_alt="on"
				test "${1:0:5}" = "--no-" && _arg_on_alt="off"
				;;
			--no-wildcard|--wildcard)
				_arg_wildcard="on"
				test "${1:0:5}" = "--no-" && _arg_wildcard="off"
				;;
			-c|--config)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_config="$2"
				shift
				;;
			--config=*)
				_arg_config="${_key##--config=}"
				;;
			-c*)
				_arg_config="${_key##-c}"
				;;
			-w|--wordlist)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_wordlist="$2"
				shift
				;;
			--wordlist=*)
				_arg_wordlist="${_key##--wordlist=}"
				;;
			-w*)
				_arg_wordlist="${_key##-w}"
				;;
			-r|--resolvers)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_resolvers="$2"
				shift
				;;
			--resolvers=*)
				_arg_resolvers="${_key##--resolvers=}"
				;;
			-r*)
				_arg_resolvers="${_key##-r}"
				;;
			-t|--threads)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_threads="$2"
				shift
				;;
			--threads=*)
				_arg_threads="${_key##--threads=}"
				;;
			-t*)
				_arg_threads="${_key##-t}"
				;;
			-s|--retries)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_retries="$2"
				shift
				;;
			--retries=*)
				_arg_retries="${_key##--retries=}"
				;;
			-s*)
				_arg_retries="${_key##-s}"
				;;
			-m|--dm)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_dm="$2"
				shift
				;;
			--dm=*)
				_arg_dm="${_key##--dm=}"
				;;
			-m*)
				_arg_dm="${_key##-m}"
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_last_positional="$1"
				_positionals+=("$_last_positional")
				_positionals_count=$((_positionals_count + 1))
				;;
		esac
		shift
	done
}


handle_passed_args_count()
{
	local _required_args_string="'domain'"
	test "${_positionals_count}" -ge 1 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 1 (namely: $_required_args_string), but got only ${_positionals_count}." 1
	test "${_positionals_count}" -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 1 (namely: $_required_args_string), but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}


assign_positional_args()
{
	local _positional_name _shift_for=$1
	_positional_names="_arg_domain "

	shift "$_shift_for"
	for _positional_name in ${_positional_names}
	do
		test $# -gt 0 || break
		eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an Argbash bug." 1
		shift
	done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"
# [ <-- needed because of Argbash

# CHANGE HERE IF NEEDED
amass=$script_path/bin/amass
massdns=$script_path/bin/massdns
zdns=$script_path/bin/zdns
shuffledns=$script_path/bin/shuffledns

update_resolvers()
{
	echo -e "${GREEN}[+] Updating resolvers.${RESET}"
	tmp=$(mktemp)
	python3 $script_path/publicdns.py > $tmp
	dnsvalidator -tL $tmp -threads 20 --silent -o $script_path/resolvers.txt &> /dev/null
	rm $tmp
	echo -e "${YELLOW}[+] Found $(wc -l < $script_path/resolvers.txt) valid resolvers.${RESET}"
}

resolve_amass()
{
    echo -e "${GREEN}[+] Running Amass subdomain enumeration.${RESET}"
    echo -e "${BLUE}[*] Running passive enumeration.${RESET}"
	$amass enum -nolocaldb -d $_arg_domain -passive -config $_arg_config -o $_arg_domain.passive -log amass.log &> /dev/null
	echo -e "${YELLOW}[*] Found $(wc -l < $_arg_domain.passive) subdomains on passive enumeration.${RESET}"
    echo -e "${BLUE}[*] Running active enumeration.${RESET}"
	$amass enum -nolocaldb -d $_arg_domain -active -brute -config $_arg_config -nf $_arg_domain.passive -o $_arg_domain.active -log amass.log &> /dev/null 
	echo -e "${YELLOW}[*] Found $(wc -l < $_arg_domain.active) subdomains on active enumeration.${RESET}"
	cat "$_arg_domain.passive" "$_arg_domain.active" | sort -u >> "$_arg_domain.combined"
	echo -e "${YELLOW}[+] Found $(wc -l < $_arg_domain.combined) subdomains.${RESET}"
}

resolve_wordlist()
{
    tmp=$(mktemp)
	wordlist=$(mktemp)
    sed "s/$/.$_arg_domain/" $_arg_wordlist > $tmp
    echo -e "${GREEN}[+] Subdomains bruteforce. Total $(wc -l < $tmp) subdomains.${RESET}"
	echo -e "${BLUE}[*] Performing A lookup. Raw wordlist json file: $wordlist.${RESET}"
    $zdns alookup --name-servers=@$_arg_resolvers -input-file $tmp -threads $_arg_threads -retries $_arg_retries -log-file zdns.log | pv -l -s $(wc -l < $tmp) > $wordlist
	if [ "$_arg_wildcard" == "on" ]; then
		echo -e "${BLUE}[*] Removing wildcards if any present.${RESET}"
		jq -r 'select(.status=="NOERROR") | .name' $wordlist > $tmp
		$shuffledns -d $_arg_domain -list $tmp -r $_arg_resolvers -massdns $massdns -retries $_arg_retries -silent -t $_arg_threads -wt 50 | pv -l -s $(wc -l < $tmp) > $_arg_domain.wordlist
	else
		jq -r 'select(.status=="NOERROR") | .name' $wordlist > "$_arg_domain.wordlist"
	fi
	cat "$_arg_domain.wordlist" >> "$_arg_domain.combined"
    sort -u "$_arg_domain.combined" -o "$_arg_domain.combined"
    echo -e "${YELLOW}[+] Found $(wc -l < $_arg_domain.wordlist) subdomains.${RESET}"
    rm $tmp
}

# Private tool
resolve_dm()
{
    echo -e "${GREEN}[+] DM passive subdomain enumeration.${RESET}"
    tmp=$(mktemp)
    python3 $_arg_dm -k $_arg_domain > $tmp
    cat $tmp >> "$_arg_domain.combined"
    sort -u "$_arg_domain.combined" -o "$_arg_domain.combined"
    echo -e "${YELLOW}[+] Found $(wc -l < $tmp) subdomains.${RESET}"
    rm $tmp
}

resolve_alt()
{
    tmp=$(mktemp)
	alts=$(mktemp)
    cat "$_arg_domain.combined" | dnsgen -l 2 - | sort -u > $tmp
    echo -e "${GREEN}[+] Alterations bruteforce. Total $(wc -l < $tmp) alterations.${RESET}"
    echo -e "${BLUE}[*] Performing A lookup. Raw wordlist json file: $alts.${RESET}"
    $zdns alookup --name-servers=@$_arg_resolvers -input-file $tmp -threads $_arg_threads -retries $_arg_retries -log-file zdns.log | pv -l -s $(wc -l < $tmp) > $alts
	if [ "$_arg_wildcard" == "on" ]; then
		echo -e "${BLUE}[*] Removing wildcards if any present.${RESET}"
		jq -r 'select(.status=="NOERROR") | .name' $alts > $tmp
		$shuffledns -d $_arg_domain -list $tmp -r $_arg_resolvers -massdns $massdns -retries $_arg_retries -silent -t $_arg_threads -wt 50 | pv -l -s $(wc -l < $tmp) > $_arg_domain.alt
	else
		jq -r 'select(.status=="NOERROR") | .name' $alts > "$_arg_domain.alt"
	fi
	
    echo -e "${YELLOW}[+] Found $(wc -l < $_arg_domain.alt) subdomains.${RESET}"
    cat "$_arg_domain.alt" >> "$_arg_domain.combined"
    sort -u "$_arg_domain.combined" -o "$_arg_domain.combined"
	rm $tmp
}

banner

if [ "$_arg_update" == "on" ]; then
	update_resolvers
fi

if [ "$_arg_on_amass" == "on" ]; then
    resolve_amass
fi

if [ "$_arg_dm" ]; then
    resolve_dm
fi

if [ "$_arg_on_wordlist" == "on" ]; then
    resolve_wordlist
fi

if [ "$_arg_on_alt" == "on" ]; then
    resolve_alt
fi

# ] <-- needed because of Argbash