#!/bin/bash

# check Git repositoryt
gitStatus=`git status 2>&1 | grep "Not a git repository" | wc -l`
if [[ $gitStatus -gt 0 ]]; then 
  echo `git status 2>&1`
  exit 1
fi

# configurations
debugMode=0

while getopts ":d" opt; do
  case "$opt" in
    d)
      debugMode=1
      ;;
    :)
      error "Option -$OPTARG requires an argument."
      exit 1
      ;;
  esac
done
shift $(($OPTIND - 1))

actionFirst=$1
if [ -z $actionFirst ]; then
  actionFirst='help'
fi


# helper

function trim {
  var=$1
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  var="${var/  / }"
  var="${var/  / }"
  var="${var/  / }"
  echo "$var"
}


# gitM part

CONFIG_FILE="gitm-config"

function gitRemoteList {
  debug "Remote list"
  remoteExistList=()
  remoteNum=1
  remoteList=`git remote -v`
  IFS=$'\n' read -rd '' -a remoteListArray <<<"$remoteList"
  for remoteElement in "${remoteListArray[@]}"; do
    remoteElementA=($remoteElement)
    if [[ ! ("${remoteExistList[*]}" =~ ${remoteElementA[0]}) ]]; then
      remoteExistList+=${remoteElementA[0]}
      log "$remoteNum: ${remoteElementA[0]} (${remoteElementA[1]})"
      let "remoteNum+=1"
    fi
  done
}

function getConfigFile {
  path=`git rev-parse --show-toplevel`
  echo "$path/.git/$CONFIG_FILE"
}

function getRemote {
  configFile=$(getConfigFile)
  echo `cat $configFile`
}

function gitSetRemoteDefault {
  debug "Set remote default option"
  name=$2
  if [[ -z $name ]]; then
    error "ussage: $0 $1 <remote_name>"
    gitRemoteList
    exit 1
  fi

  remoteList=($(git remote))
  if [[ ! ("${remoteList[*]}" =~ $name) ]]; then
    error "remote \"$name\" not exist"
    gitRemoteList
    exit 1
  fi 

  configFile=$(getConfigFile)
  echo "$name" > $configFile
  remoteDefaultName=`cat $configFile`
  ok "remote \"$remoteDefaultName\" was set how default remote"
}

function gitRemoteAddUrl {
  debug "Add new remote url"
  name=$2
  url=$3
  if [[ -z $name ]] || [[ -z $url ]]; then
    error "ussage: $0 $1 <remote_name> <remote_url>"
    exit 1
  fi
  gitCommand "remote add $name $url"
  gitRemoteList
}

function gitRemoteChangeUrl {
  debug "Change remote url"
  remote=$(getRemoteForCommand $*)
  
  url="$*"
  url="${url/$1/}"
  url="${url/$remote/}"
  url=$(trim "$url")
  
  if [[ -z $url ]]; then
    error "ussage: $0 $1 [<remote_name>] <new_remote_url>"
    exit 1
  fi

  gitCommand "remote set-url $remote $url"
  ok "Remote $remote was changed"
  gitRemoteList
}

function gitPushAll {
  debug "Push into all remotes"
  remoteList=($(git remote))
  for remoteElement in "${remoteList[@]}"; do
    info "Push into $remoteElement remote"
    gitPush "push" $remoteElement $2
  done
}

function getRemoteForCommand {
  remote=""
  remoteList=($(git remote))
  for inputElement in "$@"; do
    if [[ ("${remoteList[*]}" =~ $inputElement) ]]; then
      remote=$inputElement
    fi
  done

  if [[ -z $remote ]]; then
    remote=$(getRemote)
  fi

  echo $remote
}


# git part

function gitCommand {
  command="git $*"
  debug "Run command => $command"
  $command
}

function gitRemote {
  debug "git remote"
  action=$2
  if [[ $action == 'show' ]];then
    gitCommand ""
  else
    gitCommand $*
  fi
}

function gitFetch {
  debug "git fetch"
  remote=$(getRemoteForCommand $*)

  lastPart="$*"
  lastPart="${lastPart/$1/}"
  lastPart="${lastPart/$remote/}"
  lastPart=$(trim "$lastPart")

  gitCommand "fetch $remote $lastPart"
}

function gitPush {
  debug "git push"
  remote=$(getRemoteForCommand $*)
  
  lastPart="$*"
  lastPart="${lastPart/$1/}"
  lastPart="${lastPart/$remote/}"
  lastPart=$(trim "$lastPart")

  gitCommand "push $remote $lastPart"
}


# logger part

function info {
  log "\033[36m$1\033[0m"
}

function header {
  log "\033[33m$1\033[0m"
}

function error {
  log "\033[31m$1\033[0m"
}

function ok {
  log "\033[32m$1\033[0m"
}

function debug {
  if [[ debugMode -eq 1 ]]; then
    log "[debug]: \033[35m$1\033[0m"
  fi
}

function testit {
  log "[test output]: \033[36m$1\033[0m"
}

function log {
  echo -e "$1"
}

# controle part

case $actionFirst in
  remote-list)
    gitRemoteList $*
    ;;
  remote-default)
    gitSetRemoteDefault $*
    ;;
  remote-add)
    gitRemoteAddUrl $*
    ;;
  remote-change)
    gitRemoteChangeUrl $*
    ;;
  remote)
    gitRemote $*
    ;;
  fetch)
    gitFetch $*
    ;;
  push)
    gitPush $*
    ;;
  push-all)
    gitPushAll $*
    ;;
  help)
    header "\nGitM v1.0.0"
    ok "\nActions:"
    log "remote-list - Display all exist remotes with urls"
    log "remote-default - Set default remote"
    log "remote-add - Add new remote"
    log "remote-change - Change url for remote"
    log "push-all - Push into all remotes"

    ok "\nOptions"
    log "-d - Debug mode"
    
    gitVersion=`git version`
    header "\n$gitVersion"
    git
    
    log ""
    ;;
  *)
    gitCommand $*
    ;;
esac
