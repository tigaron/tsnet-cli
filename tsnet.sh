#!/bin/env bash
version="1.2"
dependencies=("curl" "sed" "printf")

# Text colors
red="\033[1;31m"
green="\033[1;32m"
default="\033[0m"

print_green() { # Print green text
    printf "${green}%s${default}\n" "${*}"
}

print_red() { # Print red text to STDERR
    printf "${red}%s${default}\n" "${*}" >&2
}

show_help() {
    while IFS= read -r line
    do
        printf "%s\n" "${line}"
    done <<-EOF
	tsnet script v.${version}
	Usage: tsnet <command>
	Available commands:
	status  - check the currently logged in user
	logout  - log out the currently logged in user
	login   - log in with the given username and password
EOF
}

check_dependencies() {
	for dependency in "${dependencies[@]}"
    do
		if ! command -v "${dependency}" &> /dev/null
        then
			print_red "Missing dependency: '${dependency}'"
            exit_script=true
		fi
	done

	if [[ "${exit_script}" == "true" ]]
    then
		exit 1
	fi
}

check_dependencies
mapfile -t user_status < <(curl -so - "ts.net/status" | sed -rn -e "s/.*(user.)\!.*/\1/p" -e "s/.*connected:<\/td><td>(.*)<\/td>.*/\1/p")

case "${1}" in
    status)
    [[ ${#user_status[@]} != 2 ]] &&
    print_red "You're not logged in. Please log in and try again!" &&
    exit 1 ||
    print_green "You have been logged in as ${user_status[0]} for ${user_status[1]}!" &&
    exit 0
    ;;

    logout)
    [[ ${#user_status[@]} == 0 ]] &&
    print_red "You're not logged in yet!" &&
    exit 1 ||
    curl -so - "ts.net/logout" >/dev/null &&
    print_green "You have just logged out!" &&
    exit 0
    ;;

    login)
    [[ ${#user_status[@]} != 0 ]] &&
    print_red "You're currently already logged in as ${user_status[0]}!" &&
    exit 1 ||
    [[ -z "${2}" ]] &&
    print_red "Usage: tsnet login <username> <password>" &&
    exit 1 ||
    login_attempt="$(
        curl -so - -d "username=${2}&password=${3:-${2}}&submit=sendin" "ts.net/login" |
        sed -rn -e "s/.*(RADIUS\ server\ is\ not\ responding).*/\1/p" \
                -e "s/.*(invalid\ Calling-Station-Id).*/\1/p" \
                -e "s/.*(simultaneous\ session\ limit\ reached).*/\1/p" \
                -e "s/.*(already\ authorizing,\ retry\ later).*/\1/p" \
                -e "s/.*(invalid\ password).*/\1/p" \
                -e "s/.*(You\ are\ logged\ in).*/\1/p"
    )"
    [[ ! "${login_attempt}" =~ "You are logged in" ]] &&
    print_red "Login failed! Error: '${login_attempt}'" &&
    exit 1 ||
    print_green "You're now logged in as ${2}!" &&
    exit 0
    ;;
    
    *)
    show_help
    exit 1
    ;;
esac