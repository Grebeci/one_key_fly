# 判断是否通过外部ssh登陆，否则为1
__INTERACTIVE=""
if [[ -t 1 ]]; then
 __INTERACTIVE="1"
fi

__green() {
 if [[ "${__INTERACTIVE}" = "1" ]]; then
   printf '\033[1;32m%b\033[0m' "$1"
   return
 fi
 printf -- "%b" "$1"
}

__red() {
 if [[ "${__INTERACTIVE}" = "1" ]]; then
   printf '\033[1;31m%b\033[0m' "$1"
   return
 fi
 printf -- "%b" "$1"
}

_err() {
 printf -- "%s" "[$(date)] " >&2
 if [ -z "$2" ]; then
   __red "$1" >&2
 else
   __red "$1='$2'" >&2
 fi
 printf "\n" >&2
}

_info() {
 printf -- "%s" "[$(date)] "
 if [ -z "$2" ]; then
   __green "$1"
 else
   __green "$1='$2'"
 fi
 printf "\n"
}