#!/bin/bash
# Run with `source bootstrap.sh` OR `source <(wget -qO- <URL>/bootstrap.sh)`

# Constants
GITHUB_USER="simifalaye"
REPO_NAME="dotfiles-ansible"
CLONE_DIR="${HOME}/.dotfiles"
SSH_KEY="${HOME}/.ssh/id_ed25519"

#-
#  Main
#-

# Reset all variables that might be set
email="simifalaye1@gmail.com"

while :; do
  case $1 in
    -h|-\?|--help)
      echo "usage: $0 [-e]"
      echo "  -e,--email [email]  Email to use for ssh key"
      echo "  -h,--help           Display help"
      exit
      ;;
    -e|--email)
        if [ -n "$2" ]; then
          email=$2
          shift
        else
          printf 'ERROR: "--email" requires a non-empty option argument.\n' >&2
          exit 1
        fi
        ;;
    --)
      shift
      break
      ;;
    -?*)
      printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
      ;;
    *)
      break
  esac
  shift
done

echo "## Running Bootstrap"
echo "## Email: ${email}"

# Install dependencies
case "$(uname -s)" in
  Linux)
    if [ -f /etc/os-release ]; then
      if grep -q -E '(ubuntu)' /etc/os-release; then
        echo "## Detected Ubuntu machine, installing deps..."
        sudo apt update
        sudo apt install software-properties-common
        sudo add-apt-repository --yes --update ppa:ansible/ansible
        sudo apt install -y ansible git zsh xz-utils build-essential
      elif grep -q -E '(centos|rhel|fedora)' /etc/os-release; then
          echo "## Detected CentOS/RHEL/Fedora machine, installing deps..."
          if [ -f /etc/centos-release ]; then
            sudo dnf install -y epel-release
          fi
          sudo dnf install -y ansible git zsh
          sudo dnf groupinstall -y 'Development Tools'
      elif grep -q -E '(arch)' /etc/os-release; then
        echo "## Detected Arch machine, installing deps..."
        sudo pacman -S ansible git zsh base-devel
      elif grep -q -E '(opensuse)' /etc/os-release; then
        echo "## Detected SUSE machine, installing deps..."
        sudo zypper install ansible git zsh
        sudo zypper install -t pattern devel_basis
      else
        echo "ERROR: Unsupported Linux distribution" && exit 1
      fi
    else
      echo "ERROR: Missing linux os-release file" && exit 1
    fi
    ;;
  Darwin)
    echo "## Detected Darwin machine, installing deps..."
    if ! command -v brew >/dev/null; then
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    brew install ansible git
    ;;
  *)
    echo "ERROR: Unsupported operating system" && exit 1
    ;;
esac

# Install required modules
ansible-galaxy install -r requirements.yml

# Generate SSH key pair
if [ ! -f "${SSH_KEY}.pub" ]; then
  echo "## SSH key not detected, setting up key..."
  ssh-keygen -t ed25519 -C "${email}" -f "${SSH_KEY}"
  # Start the ssh-agent in the background
  eval "$(ssh-agent -s)"
  # Add SSH private key to the ssh-agent
  ssh-add "${SSH_KEY}"
fi

# Display the public key and prompt user to add it to GitHub
printf "## Please add the following SSH key to your GitHub account:\n"
cat "${SSH_KEY}.pub"
printf "## Visit https://github.com/settings/keys to add the key.\n"
printf "  Press [Enter] key after adding the key to GitHub..."
read -r dummy
[ -n "${dummy}" ] && echo ""

# Clone the repository using SSH
echo "## Cloning dotfiles repo..."
git clone git@github.com:"${GITHUB_USER}"/"${REPO_NAME}".git "${CLONE_DIR}"

# Switch to zsh
echo "## Setting zsh as default shell..."
chsh -s "$(which zsh)"

# Navigate to the cloned repository directory
cd "${CLONE_DIR}" || exit 1

# Restart shell
exec "$(which zsh)"
