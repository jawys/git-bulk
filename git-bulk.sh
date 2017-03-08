#!/bin/sh
invers=`tput rev`
reset=`tput sgr0`
txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) #  red
shopt -s extglob

#
# print usage message
#
usage() {
  echo 1>&2 "usage: git bulk [-g] <git command>"
  echo 1>&2 "       git bulk --addworkspace <ws-name> <ws-root-directory>"
  echo 1>&2 "       git bulk --removeworkspace <ws-name> <ws-root-directory>"
  echo 1>&2 "       git bulk --addcurrent <ws-name>"
  echo 1>&2 "       git bulk --purge"
  echo 1>&2 "       git bulk --listall"
}

# add another workspace to global git config
function addWSDir () {
  git config --global bulkworkspaces.$wsname "$wsdir"
}

# add current directory
function addCurrWSDir () {
  git config --global bulkworkspaces.$wsname "$PWD"
}

# remove workspace from global git config
function remWSDir () {
  git config --global --unset bulkworkspaces.$wsname
}

# remove workspace from global git config
function purgeWS () {
  git config --global --remove-section bulkworkspaces
}

# list all current workspace locations defined
function listWSDir () {
  git config --global --get-regexp bulkworkspaces
}

# atomic execution of a git command in one specific repository
function guardedExecution () {
  if [[ $guarded ]]; then
    echo -n "${invers}git $gitcommand${reset} -> execute here (y/n)? "
    read -n 1 -r </dev/tty; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      atomicExecution
    fi
  else
     atomicExecution
  fi
}

# execute a git command with log
function atomicExecution () {
  echo "${bldred}->${reset} executing ${invers}git $gitcommand${reset}"
  git $gitcommand
}

function checkGitCommand () {
  if git help -a | cat | grep -o "$corecommand"; then
    echo "Core command $corecommand accepted."
  else
    usage
    echo "error: unknown GIT command: $corecommand"
    exit 1
  fi
}

# execute the bul operation
function executBulkOp () {
  clear
  listWSDir | while read workspacespec; do
    wslocation=$(echo $workspacespec | cut -f2 -d' ')
    eval cd "$wslocation"
    actual=$(pwd)
    echo "Executing bulk operation in workspace ${invers}$actual${reset}"
    eval find . -name ".git" | while read line; do
      gitrepodir=${line::${#line}-5} # cut the .git part of find results to have the root git directory of that repository
      eval cd "$gitrepodir" # into git repo location
      curdir=$(pwd)
      echo "Current repository: ${curdir%/*}/${bldred}${curdir##*/}${reset}"
      guardedExecution
      eval cd "$wslocation" # back to origin location of last find command
    done 
  done 
}

initialcount="${#}"
initialarguments="${@}"
# parse command parameters
while [ "${#}" -ge 1 ] ; do

  case "$1" in
    --listall)
      butilcommand="listWSDir"
      break
      ;;
    --purge)
      butilcommand="purgeWS"
      break
      ;;
    --removeworkspace)
      shift
      wsname="$1"
      butilcommand="remWSDir"
      break
      ;;
    --addcurrent)
      shift
      wsname="$1"
      butilcommand="addCurrWSDir"
      break
      ;;
    --addworkspace)
      shift
      wsname="$1"
      shift
      wsdir="$1"
      butilcommand="addWSDir"
      break
      ;;
    -g)
      guarded=true
      ;;
    -*)
	  usage
      echo 1>&2 "error: unknown argument $1"
      exit 1
      ;;
    --*)
	  usage
      echo 1>&2 "error: unknown argument $1"
      exit 1
      ;;
    *)
      butilcommand="executBulkOp"
      corecommand="$1"
      gitcommand="$@"
      checkGitCommand
      butilcommand="executBulkOp"
      break
      ;;
  esac

  shift
done

# check right number of arguments
case $butilcommand in
    @(listWSDir|purgeWS) )
       if [[ $initialcount -ne 1 ]]; then
       	 usage
       	 echo 1>&2 "error: wrong number of arguments"
         exit 1
       fi 
    ;;
    @(addCurrWSDir|remWSDir))
       if [[ $initialcount -ne 2 ]]; then
       	 usage
       	 echo 1>&2 "error: wrong number of arguments"
         exit 1
       fi 
    ;;
	addWSDir)
       if [[ $initialcount -ne 3 ]]; then
       	 usage
       	 echo 1>&2 "error: wrong number of arguments"
         exit 1
       fi 
    ;;
esac

$butilcommand # run user command