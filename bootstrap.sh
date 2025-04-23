#!/usr/bin/env bash
# Run with `source bootstrap.sh` OR `source <(wget -qO- <URL>/bootstrap.sh)`

# Constants
REPO_NAME="simifalaye/dotfiles-ansible"
CLONE_DIR="${HOME}/.dotfiles"
GIT_CONFIG_DIR="${HOME}/.config/git"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

#
# Helper Functions
#

usage() {
  echo "usage: $0 -g <email> -s <email> [keyname] [-s <email> [keyname] ...]"
  echo "  -g,--git-email <email> => Override the git email in the config"
  echo "  -s,--ssh-key <email> => Generate an ssh key"
  echo "  -h,--help => Display help"
  abort ""
}

step() { echo -e "${BLUE}==> $*${NC}"; }
sub_step() { echo -e "${BLUE}=> $*${NC}"; }
success() { echo -e "${GREEN}✔ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
error() { echo -e "${RED}✖ $*${NC}" >&2; }
abort() {
  error "$@"
  return 1
}

#
# Main
#

set -euo pipefail

# Reset all variables that might be set
SSH_KEYS=()
GIT_EMAIL=""

while [[ $# -gt 0 ]]; do
  case $1 in
  -g | --git-email)
    if [ -n "$2" ]; then
      GIT_EMAIL=$2
      shift
    else
      abort "-g|--git-email needs <email>"
    fi
    ;;
  -s | --ssh-key)
    if [[ $# -lt 2 ]]; then
      abort "-s|--ssh-key needs <email> [keyname]"
    fi
    email="$2"
    keyname=""
    [ $# -eq 3 ] && keyname="$3"
    SSH_KEYS+=("$email:$keyname")
    shift 3
    ;;
  -h | --help)
    usage
    ;;
  -?*)
    printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
    ;;
  *)
    break
    ;;
  esac
done

step "Installing homebrew"
if ! command -v brew >/dev/null; then
  sub_step "Installing Homebrew package manager"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if test -r /opt/homebrew/bin/brew; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif test -r /usr/local/bin/brew; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif test -r /home/linuxbrew/.linuxbrew/bin/brew; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  else
    abort "Homebrew install not found"
  fi
  success "Homebrew installed"
fi

step "Installing core dependencies"
case "$(uname -s)" in
Linux)
  if [ -f /etc/os-release ]; then
    if grep -q -E '(ubuntu)' /etc/os-release; then
      sub_step "Detected Ubuntu machine, installing core deps"
      sudo apt update
      sudo apt install software-properties-common
      sudo add-apt-repository --yes --update ppa:ansible/ansible
      sudo apt install -y ansible git zsh xz-utils build-essential
      success "Installed core deps"
    elif grep -q -E '(centos|rhel|fedora)' /etc/os-release; then
      sub_step "Detected CentOS/RHEL/Fedora machine, installing core deps"
      if [ -f /etc/centos-release ]; then
        sudo dnf install -y epel-release
      fi
      sudo dnf install -y ansible git zsh
      sudo dnf groupinstall -y 'Development Tools'
      success "Installed core deps"
    elif grep -q -E '(arch)' /etc/os-release; then
      sub_step "Detected Arch machine, installing core deps"
      sudo pacman -S ansible git zsh base-devel
      success "Installed core deps"
    elif grep -q -E '(opensuse)' /etc/os-release; then
      sub_step "Detected SUSE machine, installing core deps"
      sudo zypper install ansible git zsh
      sudo zypper install -t pattern devel_basis
      success "Installed core deps"
    else
      abort "Unsupported Linux distribution"
    fi
  else
    abort "Missing linux os-release file"
  fi
  ;;
Darwin)
  sub_step "Detected Darwin machine, installing core deps"
  brew install ansible git
  success "Installed core deps"
  ;;
*)
  abort "Unsupported operating system"
  ;;
esac
success "Installed core dependencies"

step "Installing ansible dependencies"
ansible-galaxy install -r requirements.yml
success "Installed ansible dependencies"

# Override git email
if [ -n "$GIT_EMAIL" ]; then
  step "Overriding default git email"
  mkdir -p "${GIT_CONFIG_DIR}"
  git_override_file="${GIT_CONFIG_DIR}/config.local"
  touch "${git_override_file}"
  cat <<EOF >> "${git_override_file}"

  [user]
  email = "$GIT_EMAIL"
EOF
fi

# Generate SSH key pairs
if [[ ${#SSH_KEYS[@]} -ne 0 ]]; then
  step "Generating ssh keys"
  # Start ssh-agent
  eval "$(ssh-agent -s)"

  # Create ssh dir if it doesn't exist
  ssh_dir="$HOME/.ssh"
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  # Generate keys
  keypath="${ssh_dir}/id_ed25519"
  for entry in "${SSH_KEYS[@]}"; do
    email="${entry%%:*}"
    keyname="${entry##*:}"
    if [ -n "$keyname" ]; then
      keypath="${ssh_dir}/${keyname}"
    fi

    sub_step "Generating SSH key $keypath (email: $email)"
    ssh-keygen -t ed25519 -C "$email" -f "$keypath" -N ""
    ssh-add "$keypath"

    echo
    echo "=== SSH Key: $keypath ==="
    echo "Public Key:"
    echo
    cat "${keypath}.pub"
    echo
    echo "If needed, copy this key to GitHub (https://github.com/settings/keys)"
    echo "Press any key when you're done"
    read -r -n 1
    echo
  done
  success "SSH keys created, added to agent, and config updated.\n\
    To clone with alt identities, use: git@github-alt1:username/repo.git"
fi

# Clone the repository using SSH
step "Cloning dotfiles repo"
git clone git@github.com:"${REPO_NAME}".git "${CLONE_DIR}"
cd "${CLONE_DIR}" || return 1
step "Cloned dotfiles repo"
