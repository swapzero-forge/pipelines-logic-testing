# plugins/lib/log.bash - logging helpers

: "${LOG_PREFIX:=noprefix}"

log() {
  local LEVEL=${1:-NOLEVEL}
  local CALLER=${2:-NOCALLER}
  shift 2

  if [[ "${LEVEL}" == "ERROR" ]]; then
    echo "[$LEVEL] [$LOG_PREFIX] [$CALLER] $*" >&2
  else
    echo "[$LEVEL] [$LOG_PREFIX] [$CALLER] $*"
  fi
}
