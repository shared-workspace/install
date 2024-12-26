#!/bin/sh
# This script installs Google Chrome Stable using the OS's package manager
# Requires: coreutils, grep, sh, sudo/doas (except macOS)

set -eu

main() {
    ## Check if the browser can run on this system

    os="$(uname)"
    arch="$(uname -m)"

    case "$os" in
        Darwin) error "This script does not support macOS. Please download Google Chrome from https://www.google.com/chrome/";;
        *) glibc_ver="$(ldd --version 2>/dev/null|head -n1|grep -oE '[0-9]+\.[0-9]+$' || true)"
           supported glibc "$glibc_ver" "2.26";;
    esac

    case "$arch" in
        aarch64|arm64|x86_64) ;;
        *) error "Unsupported architecture $arch. Only 64-bit x86 or ARM machines are supported.";;
    esac

    ## Find and/or install the necessary tools

    if [ "$(id -u)" = 0 ]; then
        sudo=""
    elif available sudo; then
        sudo="sudo"
    elif available doas; then
        sudo="doas"
    else
        error "Please install sudo or doas to proceed."
    fi

    if available curl; then
        curl="curl -fsS"
    elif available wget; then
        curl="wget -qO-"
    elif available apt-get; then
        curl="curl -fsS"
        export DEBIAN_FRONTEND=noninteractive
        show $sudo apt-get update
        show $sudo apt-get install -y curl
    fi

    ## Install Google Chrome

    if available apt-get; then
        export DEBIAN_FRONTEND=noninteractive
        show $curl https://dl-ssl.google.com/linux/linux_signing_key.pub | show $sudo apt-key add -
        show $sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
        show $sudo apt-get update
        show $sudo apt-get install -y google-chrome-stable

    elif available dnf; then
        show $sudo dnf install -y 'dnf-command(config-manager)'
        show $sudo dnf config-manager --add-repo=https://dl.google.com/linux/chrome/rpm/stable/x86_64
        show $sudo dnf install -y google-chrome-stable

    elif available yum; then
        available yum-config-manager || show $sudo yum install yum-utils -y
        show $sudo yum-config-manager --add-repo=https://dl.google.com/linux/chrome/rpm/stable/x86_64
        show $sudo yum install -y google-chrome-stable

    elif available zypper; then
        show $sudo zypper --non-interactive addrepo --gpgcheck --repo https://dl.google.com/linux/chrome/rpm/stable/x86_64
        show $sudo zypper --non-interactive --gpg-auto-import-keys refresh
        show $sudo zypper --non-interactive install google-chrome-stable

    else
        error "Could not find a supported package manager. Only apt, dnf, yum and zypper are supported." "" \
            "If you'd like us to support your system better, please file an issue at" \
            "https://github.com/googlechrome/install.sh/issues and include the following information:" "" \
            "$(uname -srvmo)" "" \
            "$(cat /etc/os-release || true)"
    fi

    printf "Installation complete! Start Google Chrome by typing: google-chrome-stable\n"
}

# Helpers
available() { command -v "${1:?}" >/dev/null; }
error() { exec >&2; printf "Error: "; printf "%s\n" "${@:?}"; exit 1; }
newer() { [ "$(printf "%s\n%s" "$1" "$2"|sort -V|head -n1)" = "${2:?}" ]; }
show() { (set -x; "${@:?}"); }
supported() { newer "$2" "${3:?}" || error "Unsupported ${1:?} version ${2:-<empty>}. Only $1 versions >=$3 are supported."; }

main
