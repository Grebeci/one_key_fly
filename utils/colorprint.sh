# Description: This file contains color print functions for the shell scripts.

# 判断是否通过外部ssh登陆，否则为1
# -t 1检测文件描述符1（即标准输出，STDOUT）是否关联到一个终端。
# 如果脚本在一个交互式终端中运行，那么这个条件为真，变量__INTERACTIVE将被设置为"1"。这意味着脚本可以使用诸如颜色化输出等终端特性，因为用户可以直接看到这些输出。
# 如果脚本不是在交互式终端中运行（比如被另一个脚本调用或通过SSH在远程执行），那么文件描述符1可能不会关联到一个终端，这个条件为假，__INTERACTIVE保持空。这种情况下，使用颜色化输出可能不合适，因为输出可能被重定向到文件或其他程序，这些情况下ANSI颜色代码可能会引起混乱。
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
__yellow() {
  if [[ "${__INTERACTIVE}" = "1" ]]; then
    printf '\033[1;33m%b\033[0m' "$1"
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

_problem() {
 printf -- "%s" "[$(date)] "
 if [ -z "$2" ]; then
   __yellow "$1"
 else
   __yellow "$1='$2'"
 fi
 printf "\n"
}

