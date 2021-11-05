#!/bin/sh
CUR_DIR=$(cd "$(dirname "$0")";pwd)
[ -f "${CUR_DIR}/.profile" ] && . ${CUR_DIR}/.profile

_get_input_value() {
	echo "$1" | grep -Eo "<input.*name=\"$2\".*" | head -n1 | grep -Eo 'value="[^"]*"' | awk '{gsub(/(^value="|"$)/,"",$0); print $0}'
}

_get_coockie() {
	echo "$1" | grep -Eio "^Set-Cookie:\s*$2=.*" | tr -d ' ' | awk -F'[:;]' '{print $2}' | sed -E "s/^$2=//" | tr -d '\r\n'
}

_get_location() {
	echo "$1" | grep -Eio "^Location:.*" | sed -E "s/^Location:\s*//i" | tr -d '\r\n'
}

_get_code() {
	echo "$1" | grep -Eo '"code"\s*:\s*[0-9]+' | tr -d ' ' | awk -F':' '{print $2}'
}

_curl() {
	[ -z "$1" ] && return 1
	__CURL_URL__=$(echo "$1" | tr -d '\r\n ')
	__CURL_UA__="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.54 Safari/537.36"
	__CURL_METHOD__=""
	__CURL_OPTION__="-sk -H 'user-agent: ${__CURL_UA__}' -H 'sec-ch-ua-platform: \"Windows\"'"
	__CURL_COOKIE__=""
	__CURL_POST_DATA__=""
	__CURL_REFERER=""
	__CURL_JSON__=""
	shift
	while true
	do
		[ "$#" = "0" ] && break
		__OPTION__=$(echo "$1" | awk -F'=' '{
			if ($1=="--post") {
				print "__CURL_METHOD__=\"POST\""
			} else if ($1=="--cookie" && $2!="") {
				gsub(/^--cookie=/,"",$0)
				print "__CURL_COOKIE__=\"${__CURL_COOKIE__}"$0";\""
			} else if ($1=="--referer" || $1=="--ref") {
				gsub(/^--ref(erer)?=/,"",$0)
				print "__CURL_REFERER=\""$0"\""
			} else if ($1=="--data" && $2!="") {
				gsub(/^--data=/,"",$0)
				print "__CURL_POST_DATA__=\"${__CURL_POST_DATA__} --data-raw \\\""$0"\\\"\""
			} else if ($1=="--head") {
				print "__CURL_OPTION__=\"${__CURL_OPTION__} -i\""
			} else if ($1=="--head-only") {
				print "__CURL_OPTION__=\"${__CURL_OPTION__} -I\""
			} else if ($1=="--retry") {
				gsub(/^--data=/,"",$0)
				print "__CURL_OPTION__=\"${__CURL_OPTION__} --retry "($0==""?1:$0)" --retry-delay 3\""
			} else if ($1=="--json") {
				print "__CURL_JSON__=\"1\""
			}
		}')
		[ -z "$__OPTION__" ] || eval "$__OPTION__"
		shift
	done
	__CURL_CMD__=$(cat <<-EOF | tr -d '\n'
	curl '${__CURL_URL__}' 
	$([ -z "$__CURL_METHOD__" ] || echo "-X $__CURL_METHOD__ ")
	${__CURL_OPTION__} 
	$([ -z "$__CURL_REFERER" ] || echo "-H 'referer: $__CURL_REFERER' ")
	$([ -z "$__CURL_COOKIE__" ] || echo "-H 'cookie: ${__CURL_COOKIE__}' ")
	$([ -z "$__CURL_POST_DATA__" ] || echo " ${__CURL_POST_DATA__}")
	$([ "$__CURL_JSON__" = "1" ] && echo " | jq '.'")
	EOF
	)
	eval "$__CURL_CMD__"
	return $?
}

_load_cookie() {
	[ -f "$COOKIE_FILE" ] || return 1
	cat "$COOKIE_FILE" | grep -E "^${1}=" | sed -E "s/^${1}=//"
}

_set_cookie() {
	[ -f "$COOKIE_FILE" ] || touch "$COOKIE_FILE" || return 1
	if grep -Eq "^${1}=" "$COOKIE_FILE"; then
		sed -Ei "s/^${1}=.*/${1}=${2}/" "$COOKIE_FILE" && return 0
	else
		echo "${1}=${2}" >> "$COOKIE_FILE" && return 0
	fi
	return 1
}

_random() {
	__DIFF__=$(($2-$1+1))
	__RANDOM__=$$
	for i in $(seq 1)
	do
		__R__=$(($((__RANDOM__%$__DIFF__))+$1))
		echo $__R__
	done
}

_delay() {
	[ "$MAX_DELAY_TIME" -gt 0 ] || return 1
	__DELAY__=$(_random 1 $MAX_DELAY_TIME)
	echo "Delay Time: ${__DELAY__}s"
	sleep $__DELAY__
}

_oshwhub_login() {
	__RES__=$(_curl 'https://passport.szlcsc.com/login?service=https%3A%2F%2Foshwhub.com%2Flogin%3Ff%3Doshwhub' --head)
	__DATA_LT__=$(_get_input_value "$__RES__" "lt")
	__DATA_EXECUTION__=$(_get_input_value "$__RES__" "execution")
	__DATA_EVENTID__=$(_get_input_value "$__RES__" "_eventId")
	__DATA_LOGINURL__="https%3A%2F%2Fpassport.szlcsc.com%2Flogin%3Fservice%3Dhttps%253A%252F%252Foshwhub.com%252Flogin%253Ff%253Doshwhub"
	__DATA_USERNAME__="${OSHWHUB_USERNAME}"
	__DATA_PASSWORD__="${OSHWHUB_PASSOWRD}"
	__DATA__="lt=${__DATA_LT__}&execution=${__DATA_EXECUTION__}&_eventId=${__DATA_EVENTID__}&loginUrl=${__DATA_LOGINURL__}&afsId=&sig=&token=&scene=login&loginFromType=shop&showCheckCodeVal=false&pwdSource=&username=${__DATA_USERNAME__}&password=${__DATA_PASSWORD__}&rememberPwd=yes"
	__COOKIE_ACW_TC__=$(_get_coockie "$__RES__" "acw_tc")
	__COOKIE_SESSION__=$(_get_coockie "$__RES__" "SESSION")
	__COOKIE__="acw_tc=${__COOKIE_ACW_TC__}; SESSION=${__COOKIE_SESSION__}"

	# echo "Cookie:"
	# echo "$__COOKIE__"
	# echo "Data:"
	# echo "$__DATA__"
	__RES__=$(_curl 'https://passport.szlcsc.com/login' --cookie="${__COOKIE__}" --data="${__DATA__}" --referer="https://passport.szlcsc.com/login?service=https%3A%2F%2Foshwhub.com%2Flogin%3Ff%3Doshwhub" --head)
	__LOCATION__=$(_get_location "$__RES__")
	[ -z "$__LOCATION__" ] && {
		echo "$__RES__"
		return 1
	}
	echo "[302] $__LOCATION__"
	__RES__=$(_curl "$__LOCATION__" --referer="https://passport.szlcsc.com/login" --head-only)
	__COOKIE_ACW_TC__=$(_get_coockie "$__RES__" "acw_tc")
	__COOKIE_CASAUTH__=$(_get_coockie "$__RES__" "CASAuth")
	[ -z "$__COOKIE_CASAUTH__" ] && return 0
	_set_cookie "acw_tc" "${__COOKIE_ACW_TC__}"
	_set_cookie "CASAuth" "${__COOKIE_CASAUTH__}"

	__COOKIE__="acw_tc=${__COOKIE_ACW_TC__}; CASAuth=${__COOKIE_CASAUTH__}"
	# echo "Cookie:"
	# echo "$__COOKIE__"
	__RES__=$(_curl 'https://oshwhub.com/login?f=oshwhub' --cookie="${__COOKIE__}" --referer="https://passport.szlcsc.com/" --head-only)
	__COOKIE_OSHWHUB_SESSION__=$(_get_coockie "$__RES__" "oshwhub_session")
	__COOKIE_OSHWHUBREFERER__=$(_get_coockie "$__RES__" "oshwhubReferer")
	_set_cookie "oshwhub_session" "${__COOKIE_OSHWHUB_SESSION__}"
	_set_cookie "oshwhubReferer" "${__COOKIE_OSHWHUBREFERER__}"
	_oshwhub_check_login
}

_oshwhub_refresh_session() {
	__COOKIE_ACW_TC__=$(_load_cookie "acw_tc")
	__COOKIE_CASAUTH__=$(_load_cookie "CASAuth")
	[ -z "$__COOKIE_CASAUTH__" ] && return 1
	__COOKIE__="acw_tc=${__COOKIE_ACW_TC__}; CASAuth=${__COOKIE_CASAUTH__}"
	# echo "Cookie:"
	# echo "$__COOKIE__"
	__RES__=$(_curl 'https://oshwhub.com/login?f=oshwhub' --cookie="${__COOKIE__}" --referer="https://passport.szlcsc.com/" --head-only)
	__COOKIE_OSHWHUB_SESSION__=$(_get_coockie "$__RES__" "oshwhub_session")
	__COOKIE_OSHWHUBREFERER__=$(_get_coockie "$__RES__" "oshwhubReferer")
	_set_cookie "oshwhub_session" "${__COOKIE_OSHWHUB_SESSION__}"
	_set_cookie "oshwhubReferer" "${__COOKIE_OSHWHUBREFERER__}"
	[ -z "$__COOKIE_OSHWHUB_SESSION__" ] && echo "[ERR] Failed to refresh session." && return 1
	return 0
}

_oshwhub_check_login() {
	__COOKIE_OSHWHUB_SESSION__=$(_load_cookie "oshwhub_session")
	[ -z "$__COOKIE_OSHWHUB_SESSION__" ] && return 1
	__RES__=$(_curl 'https://oshwhub.com/api/unreadNotifications' --cookie="oshwhub_session=${__COOKIE_OSHWHUB_SESSION__}" --referer="https://oshwhub.com/")
	__CODE__=$(_get_code "$__RES__")
	[ "$__CODE__" = "0" ] && echo "[OK] You have already logined." && return 0
	echo "[ERR] Faied to check logined (CODE: $__CODE__)"
	return 1
}

_oshwhub_checkin() {
	__RES__=$(_curl 'https://oshwhub.com/api/user/sign_in' --cookie="oshwhub_session=${__COOKIE_OSHWHUB_SESSION__}" --referer="https://oshwhub.com/sign_in" --post)
	__CODE__=$(_get_code "$__RES__")
	[ "$__CODE__" = "0" ] && echo "[OK] Success to checkin!" && return 0
	[ "$__CODE__" = "422" ] && echo "[WAR] Already checkined today." && return 0
	echo "[ERR] Failed to checkin." && echo "$__RES__" && return 1
}

checkin_oshwhub() {
	COOKIE_FILE="$CUR_DIR/.oshwhub_cookie"
	_oshwhub_check_login || _oshwhub_refresh_session || _oshwhub_login || exit 0
	# _delay
	_oshwhub_checkin
}

checkin() {
	case "$1" in
		"oshwhub"|"oshwhub.com")
			checkin_oshwhub
			;;
	esac
	return 0
}

case "$1" in
	"checkin")
		shift
		checkin "$@"
		;;
esac



