# If ~/.bashrc is already a symlink resolving outside $HOME (e.g. a
# dotfiles repo checked out under $HOME), replace it with a real file
# that sources the original target before the exports below get
# appended. Every append/sed step further down writes straight through
# symlinks, so a live symlink here would silently edit tracked files in
# a developer's dotfiles repo instead of this workspace's local shell
# config -- that happened once already.
if [ -L "/home/coder/.bashrc" ]; then
  _bashrc_target=$(readlink -f "/home/coder/.bashrc" 2>/dev/null || true)
  case "$_bashrc_target" in
    /home/coder/*) ;; # resolves inside $HOME, safe to write through
    *)
      echo "~/.bashrc is a symlink to $_bashrc_target (outside \$HOME); replacing with a local file that sources it"
      rm -f "/home/coder/.bashrc"
      if [ -n "$_bashrc_target" ]; then
        echo "[ -r \"$_bashrc_target\" ] && source \"$_bashrc_target\"" > "/home/coder/.bashrc"
      fi
      ;;
  esac
fi
