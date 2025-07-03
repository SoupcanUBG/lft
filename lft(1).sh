#!/bin/bash
CONFIG_DIR="$HOME/.lft"
USER_FILE="$CONFIG_DIR/project.user"
PASS_FILE="$CONFIG_DIR/project.password"
HOST_FILE="$CONFIG_DIR/project.host"
ROOT_FILE="$CONFIG_DIR/project.root"

mkdir -p "$CONFIG_DIR"

read_config() {
  USER=$(<"$USER_FILE")
  PASS=$(<"$PASS_FILE")
  HOST=$(<"$HOST_FILE")
  ROOT=$(<"$ROOT_FILE")
}

signup() {
  echo "LFT Signup:"
  read -p "BunnyCDN username: " USER
  read -s -p "BunnyCDN password (FTP API key): " PASS; echo
  read -p "BunnyCDN FTP host (e.g. ftp://uk.storage.bunnycdn.com): " HOST
  read -p "Remote base path (e.g. /soupcan or /project): " ROOT

  echo "$USER" > "$USER_FILE"
  echo "$PASS" > "$PASS_FILE"
  echo "$HOST" > "$HOST_FILE"
  echo "$ROOT" > "$ROOT_FILE"
  echo "Saved config in $CONFIG_DIR"
}

uninstall() {
  echo "This will remove the lft CLI and all its config files (~/.lft)"
  read -p "Are you sure? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    sudo rm -f /usr/local/bin/lft
    rm -rf "$CONFIG_DIR"
    echo "LFT uninstalled."
  else
    echo "Cancelled."
  fi
  exit 0
}

expand_local_path() {
  [[ "$1" == ~* ]] && echo "${1/#\~/$HOME}" || echo "$1"
}

expand_remote_path() {
  path="${1#/}"
  echo "${ROOT%/}/${path}"
}

show_help() {
  echo ""
  echo "lft - BunnyCDN CLI Wrapper"
  echo "Setup: lft signup"
  echo ""
  echo "Upload:"
  echo "  lft -uF  LOCAL_FILE REMOTE_DIR     Upload single file"
  echo "  lft -uD  LOCAL_DIR  REMOTE_DIR     Upload folder (preserve structure)"
  echo "  lft -uDF LOCAL_DIR  REMOTE_DIR     Upload contents only (flatten)"
  echo ""
  echo "Download:"
  echo "  lft -dF  REMOTE_FILE LOCAL_FILE    Download single file"
  echo "  lft -dD  REMOTE_DIR  LOCAL_DIR     Download folder"
  echo ""
  echo "Other:"
  echo "  lft mkdir REMOTE_DIR               Create remote directory"
  echo "  lft rm    REMOTE_PATH              Delete file or directory"
  echo "  lft -Tr                            Tree view of remote structure"
  echo "  lft uninstall                     Uninstall the tool"
  echo ""
}

case "$1" in
  signup)
    signup
    exit 0
    ;;
  uninstall)
    uninstall
    ;;
  help|"")
    read_config
    show_help
    [[ "$1" == "help" ]] && exit 0
    echo "Opening LFTP shell..."
    lftp -u "$USER","$PASS" "$HOST"
    exit 0
    ;;
esac

read_config

case "$1" in
  -uF)
    local_file=$(expand_local_path "$2")
    remote_dir=$(expand_remote_path "$3")
    [ ! -f "$local_file" ] && echo "File not found: $local_file" && exit 1
    lftp -u "$USER","$PASS" "$HOST" -e "cd $remote_dir; put -c "$local_file"; bye"
    ;;
  -uD)
    local_dir=$(expand_local_path "$2")
    remote_dir=$(expand_remote_path "$3")
    folder_name=$(basename "$local_dir")
    parent_dir=$(dirname "$local_dir")
    lftp -u "$USER","$PASS" "$HOST" <<EOF
cd $remote_dir
lcd $parent_dir
mirror --reverse --parallel=8 --only-newer "$folder_name" "$folder_name"
bye
EOF
    ;;
  -uDF)
    local_dir=$(expand_local_path "$2")
    remote_dir=$(expand_remote_path "$3")
    lftp -u "$USER","$PASS" "$HOST" <<EOF
cd $remote_dir
lcd $local_dir
mirror --reverse --no-empty-dirs --no-perms --no-symlinks --parallel=8 . .
bye
EOF
    ;;
  -dF)
    remote_file=$(expand_remote_path "$2")
    local_file=$(expand_local_path "$3")
    lftp -u "$USER","$PASS" "$HOST" -e "get "$remote_file" -o "$local_file"; bye"
    ;;
  -dD)
    remote_dir=$(expand_remote_path "$2")
    local_dir=$(expand_local_path "$3")
    lftp -u "$USER","$PASS" "$HOST" <<EOF
mirror --parallel=8 "$remote_dir" "$local_dir"
bye
EOF
    ;;
  mkdir)
    remote_dir=$(expand_remote_path "$2")
    lftp -u "$USER","$PASS" "$HOST" -e "mkdir -p $remote_dir; bye"
    ;;
  rm)
    remote_target=$(expand_remote_path "$2")
    lftp -u "$USER","$PASS" "$HOST" -e "rm -r "$remote_target"; bye"
    ;;
  -Tr)
    MAX_DEPTH=10
    echo "Remote directory tree ($ROOT, depth ≤ $MAX_DEPTH)"
    lftp -u "$USER","$PASS" "$HOST" <<EOF | awk -F/ -v maxdepth="$MAX_DEPTH" '
      /^\// { print \$0; next }
      {
        if (\$0 ~ /^\s*\$/ || \$0 ~ /^\./) next
        last = \$NF
        depth = NF - 1
        if (depth <= maxdepth) {
          indent = depth
          printf "%*s- %s\n", indent * 2, "", last
        }
      }
'
cd $ROOT
find
bye
EOF
    ;;
  *)
    echo "Unknown command: $1. Use: lft help"
    exit 1
    ;;
esac
