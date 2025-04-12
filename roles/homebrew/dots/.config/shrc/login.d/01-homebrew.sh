# Load homebrew env
if test -x /opt/homebrew/bin/brew; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif test -x /usr/local/bin/brew; then
  eval "$(/usr/local/bin/brew shellenv)"
elif test -x /home/linuxbrew/.linuxbrew/bin/brew; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
