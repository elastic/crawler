#!/bin/bash

# Do not color output in environments that do not have the TERM set (no TTY in docker, etc)
if [ "${TERM:-dumb}" == "dumb" ]; then
  echo "Warning: No TERM defined, output coloring will be disabled!"
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  RESET=""
else
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  RESET=$(tput sgr0)
fi

function yellow_echo() {
  echo "${YELLOW}${*}${RESET}"
}

function yellow_echo_date() {
  yellow_echo "[$(date +"%Y-%m-%d %H:%M:%S")] ${*}"
}

function red_echo()    {
  echo "${RED}${*}${RESET}"
}

function red_echo_date() {
  red_echo "[$(date +"%Y-%m-%d %H:%M:%S")] ${*}"
}

function green_echo()  {
  echo "${GREEN}${*}${RESET}"
}

function green_echo_date() {
  green_echo "[$(date +"%Y-%m-%d %H:%M:%S")] ${*}"
}

function load_version_constraints() {
  if [[ -z "${PROJECT_ROOT}" ]]; then
    PROJECT_ROOT="$(dirname "${BASH_SOURCE[0]}")/.."
  fi

  export BUNDLER_VERSION="$(cat "$PROJECT_ROOT/.bundler-version")"
  export BUNDLER_CONSTRAINT="~> $BUNDLER_VERSION"

  export RUBY_VERSION="$(cat "$PROJECT_ROOT/.ruby-version")"
  export JAVA_VERSION="$(cat "$PROJECT_ROOT/.java-version")"

  yellow_echo "Checking version constraints..."
  green_echo "Required Ruby version: ${RUBY_VERSION}"
  green_echo "Required Java version: ${JAVA_VERSION}"
  echo

  if [ "$CRAWLER_MANAGE_ENV" = "true" ]; then
    rbenv_init
    ensure_jruby_installed "$RUBY_VERSION"
    jenv_init
    ensure_java_installed "$JAVA_VERSION"
  fi

  RUNNING_RUBY_VERSION=$(ruby --version)
  RUNNING_JAVA_VERSION=$(java --version)

  yellow_echo "Checking running versions..."
  echo "Running Ruby version: ${RUNNING_RUBY_VERSION}"
  echo "Running Java version: ${RUNNING_JAVA_VERSION}"
  green_echo "Done!"
  echo
}

function check_bundle() {
  yellow_echo "Checking for missing gems..."
  if ! bundle check > /dev/null; then
    try_then_error "Bundle is missing gems" "script/bundle"
  fi
  green_echo "Done!"
  echo
}

function rbenv_init() {
  yellow_echo "Checking if rbenv is installed..."
  if ! command -v rbenv; then
    echo "ERROR: rbenv is not installed! Please install it by running 'brew install rbenv' (or use your OS-specific install methods)."
    exit 2
  fi
  green_echo "rbenv: OK"
  echo

  yellow_echo "Enabling rbenv support..."
  eval "$(rbenv init -)"
  green_echo "Done!"
  echo
}

function jenv_init() {
  yellow_echo "Checking if jenv is installed..."
  if ! command -v jenv; then
    echo "ERROR: jenv is not installed! Please install it by running 'brew install jenv' (or use your OS-specific install methods)."
    exit 2
  fi
  green_echo "jenv: OK"
  echo

  yellow_echo "Enabling jenv support..."
  eval "$(jenv init -)"
  green_echo "Done!"
  echo
}

function ensure_java_installed() {
  JAVA_VERSION="$1"
  yellow_echo "Checking if JAVA $JAVA_VERSION is installed..."
  set +e
  if ! jenv prefix; then
    red_echo "ERROR: Java version $JAVA_VERSION is not installed! Please install it from homebrew or use your OS-specific install methods."
    echo
    yellow_echo "If you are on a mac, you may need to add homebrew-installed java to jenv: "
    echo
    echo "  jenv add /Library/Java/JavaVirtualMachines/<full-java-version-name>/Contents/Home && jenv rehash"
    echo
    exit 2
  fi
  set -e
  green_echo "Done!"
  echo
}

function ensure_jruby_installed() {
  RUBY_VERSION="$1"
  yellow_echo "Checking if Ruby $RUBY_VERSION is installed..."
  if [ -z "$(rbenv versions --bare | grep "^$RUBY_VERSION")" ]; then
    try_then_error "Ruby version $RUBY_VERSION is not installed" "script/setup-rubies"
  fi
  green_echo "Done!"
  echo
}

function try_then_error() {
  ISSUE="$1"
  COMMAND="$2"
  yellow_echo "$ISSUE. Running: '$COMMAND'"
  eval "$2"
  rt=$?
  if [[ $rt -ne 0 ]] ; then
    red_echo "ERROR: $ISSUE. Please run '$COMMAND' to fix."
    exit $rt
  fi
}

function __install_macosx_dev_deps() {
  local root_dir

  if [ -z "${__MACOSX_DEV_DEPS_CHECKED:-}" ] && [[ "$(uname -s)" == 'Darwin' ]]
  then
    if ! brew -v
    then
      >&2 echo "Homebrew doesn't appear to be installed, please install it from: https://brew.sh/"
      exit 1
    fi

    # Doesn't matter where the calling script is called from
    root_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/../"

    # Only run homebrew if dependencies have changed since last time
    if ! diff "${root_dir}/Brewfile" "${root_dir}/.Brewfile.cached"
    then
      echo "Running 'brew bundle' to install your local system dev dependencies..."
      echo
      echo "${RED}⚠️  Warning ⚠️"
      echo "You may need to run this after if Homebrew has installed/updated icu4c:${RESET}"
      echo "${BLUE}$ bundle pristine${RESET}"
      echo
      echo "${RED}If temurin11 (java) is being installed Homebrew may ask you for a password,"
      echo "this is fine as the temurin11 recipe needs to install files outside of /usr/local...${RESET}"
      echo

      sleep 2

      ( cd "${root_dir}" && brew bundle --verbose )

      cat "${root_dir}/Brewfile" > "${root_dir}/.Brewfile.cached"
    fi

    # We track this environment variable so we don't unnecessarily run homebrew if this file is sourced more than once
    __MACOSX_DEV_DEPS_CHECKED=1
    export __MACOSX_DEV_DEPS_CHECKED
  fi
}
__install_macosx_dev_deps
