#!/bin/bash
#
# ARG_POSITIONAL_SINGLE([domain],[domain to enumerate],[])
# ARG_OPTIONAL_SINGLE([threads],[t],[zdns threads],[500])
# ARG_OPTIONAL_SINGLE([config],[c],[path to amass configuration file],[./amass_config.ini])
# ARG_OPTIONAL_SINGLE([wordlist],[w],[path to subdomains wordlist],[./normal.txt])
# ARG_OPTIONAL_SINGLE([resolvers],[r],[path to resolvers list],[./resolvers.txt])
# ARG_OPTIONAL_SINGLE([amass],[a],[path to amass binary],[/usr/bin/amass])
# ARG_OPTIONAL_SINGLE([zdns],[z],[path to zdns binary],[/bin/zdns])
# ARG_OPTIONAL_SINGLE([dm],[m],[private tool],[])
# ARG_HELP([lazydns usage])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([
die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}


begins_with_short_option()
{
	local first_option all_short_options='tcwrazmh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
# THE DEFAULTS INITIALIZATION - OPTIONALS
SCRIPT_PATH=$(dirname $(realpath -s $0))
_arg_threads="500"
_arg_config="$SCRIPT_PATH/amass_config.ini"
_arg_wordlist="$SCRIPT_PATH/normal.txt"
_arg_resolvers="$SCRIPT_PATH/resolvers.txt"
_arg_amass="/usr/bin/amass"
_arg_zdns="/bin/zdns"
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
    echo "|/x/|/o/|/x/|"
    echo "|\x\|\x\|\o\|"
    echo "|/o/|/o/|/o/|"
    echo ""
}

print_help()
{
    banner
	printf 'Usage: %s [-t|--threads <arg>] [-c|--config <arg>] [-w|--wordlist <arg>] [-r|--resolvers <arg>] [-a|--amass <arg>] [-z|--zdns <arg>] [-m|--dm <arg>] [-h|--help] <domain>\n' "$0"
	printf '\t%s\n' "<domain>: domain to enumerate"
	printf '\t%s\n' "-t, --threads: Zdns threads (default: '500')"
	printf '\t%s\n' "-c, --config: Path to amass configuration file (default: './amass_config.ini')"
	printf '\t%s\n' "-w, --wordlist: Path to subdomains wordlist (default: './normal.txt')"
	printf '\t%s\n' "-r, --resolvers: Path to resolvers list (default: './resolvers.txt')"
	printf '\t%s\n' "-a, --amass: Path to amass binary (default: '/usr/bin/amass')"
	printf '\t%s\n' "-z, --zdns: Path to zdns binary (default: '/bin/zdns')"
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
			-a|--amass)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_amass="$2"
				shift
				;;
			--amass=*)
				_arg_amass="${_key##--amass=}"
				;;
			-a*)
				_arg_amass="${_key##-a}"
				;;
			-z|--zdns)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_zdns="$2"
				shift
				;;
			--zdns=*)
				_arg_zdns="${_key##--zdns=}"
				;;
			-z*)
				_arg_zdns="${_key##-z}"
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

# OTHER STUFF GENERATED BY Argbash

### END OF CODE GENERATED BY Argbash (sortof) ### ])
# [ <-- needed because of Argbash



RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"


DOMAIN=$_arg_domain
AMASS=$_arg_amass
ZDNS=$_arg_zdns
DM=$_arg_dm
WORDLIST=$_arg_wordlist
AMASS_CONFIG=$_arg_config
RESOLVERS=$_arg_resolvers
ZDNS_RATE=$_arg_threads

resolve_amass()
{
    echo -e "${GREEN}[+] Running Amass subdomain enumeration.${RESET}"
    
    echo -e "${BLUE}[*] Running passive enumeration.${RESET}"
    $AMASS enum -nolocaldb -d $DOMAIN -passive -config $AMASS_CONFIG -o $DOMAIN.passive -log amass.log 1&>/dev/null
    echo -e "${YELLOW}[*] Found $(wc -l < $DOMAIN.passive) subdomains on passive enumeration.${RESET}"

    echo -e "${BLUE}[*] Running active enumeration.${RESET}"
    $AMASS enum -nolocaldb -d $DOMAIN -active -brute -config $AMASS_CONFIG -nf $DOMAIN.passive -o $DOMAIN.active -log amass.log 1&>/dev/null 
    echo -e "${YELLOW}[*] Found $(wc -l < $DOMAIN.active) subdomains on active enumeration.${RESET}"
    

    cat $DOMAIN.passive $DOMAIN.active | sort -u > $DOMAIN.combined
    echo -e "${YELLOW}[+] Found $(wc -l < $DOMAIN.combined) subdomains.${RESET}"
}

resolve_wordlist()
{
    # BEWARE OF WILDCARDS :)
    echo -e "${GREEN}[+] Generating subdomains from a wordlist of total ($(wc -l < $WORDLIST) subdomains).${RESET}"
    tmp=$(mktemp)
    sed "s/$/.$DOMAIN/" $WORDLIST >> $tmp
    # In order to view progress you can do "watch -n 0.1 wc -l zdns.json"
    $ZDNS alookup --name-servers=@$RESOLVERS -input-file $tmp -threads $ZDNS_RATE -output-file $DOMAIN.wordlist.json -log-file zdns.log
    jq -r 'select(.status=="NOERROR") | .name' $DOMAIN.wordlist.json > $tmp
    cat $tmp >> $DOMAIN.combined    
    sort -u $DOMAIN.combined -o $DOMAIN.combined
    echo -e "${YELLOW}[+] Found $(wc -l < $tmp) subdomains.${RESET}"
    rm $tmp
}

# Private tool
resolve_dm()
{
    echo -e "${GREEN}[+] DM passive subdomain enumeration.${RESET}"
    tmp=$(mktemp)
    python3 $DM -k $DOMAIN > $tmp
    cat $tmp >> $DOMAIN.combined
    sort -u $DOMAIN.combined -o $DOMAIN.combined
    echo -e "${YELLOW}[+] Found $(wc -l < $tmp) subdomains.${RESET}"
    rm $tmp
}

resolve_alt()
{
    echo -e "${GREEN}[+] Generating subdomain alterations.${RESET}"
    tmp=$(mktemp)
    cat $DOMAIN.combined | dnsgen - | sort -u > $tmp
    echo -e "${BLUE}[*] $(wc -l < $tmp) alterations generated. Starting DNS A records lookup.${RESET}"
    $ZDNS alookup --name-servers=@$SCRIPT_PATH/resolvers.txt -input-file $tmp -threads $ZDNS_RATE -output-file $DOMAIN.alt.json -log-file zdns.log
    jq -r 'select(.status=="NOERROR") | .name' $DOMAIN.alt.json > $tmp
    echo -e "${YELLOW}[+] Found $(wc -l < $tmp) subdomains.${RESET}"
    cat $tmp >> $DOMAIN.combined
    sort -u $DOMAIN.combined -o $DOMAIN.combined
}

resolve_final()
{
    echo -e "${GREEN}[+] Final resolve.${RESET}"
    $ZDNS alookup --name-servers=1.1.1.1 -input-file $DOMAIN.combined -threads 1 -output-file $DOMAIN.final.json -log-file zdns.log
    echo -e "${YELLOW}[+] Found total $(jq -r 'select(.status=="NOERROR") | .name' $DOMAIN.final.json | wc -l) active subdomains.${RESET}"
}


banner

if [ "$AMASS_DISABLE" != "true" ]; then
    resolve_amass
fi

if [ "$DM_DISABLE" != "true" ] && [ "$DM" ]; then
    resolve_dm
fi

if [ "$WORDLIST_DISABLE" != "true" ]; then
    resolve_wordlist
fi

if [ "$ALT_DISABLE" != "true" ]; then
    resolve_alt
fi

if [ "$FINAL_DISABLE" != "true" ]; then
    resolve_final
fi

# ] <-- needed because of Argbash