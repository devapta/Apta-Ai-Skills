#!/usr/bin/env bash
# cleanup.sh — remove Docker containers the skill started. Run it when an
# Investigation ends.
#
#   cleanup.sh            remove leftover containers (normally there are none)
#   cleanup.sh --images   also remove the postgres and logcli images it pulled
#
# Exit: 0 ok

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$HERE/_lib.sh"

case "${1:-}" in -h|--help) sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit "${AI_EXIT_USAGE}" ;; esac

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "Docker not available: nothing to clean up."
  exit 0
fi
mapfile -t ids < <(docker ps -aq --filter "label=$AI_LABEL")
if (( ${#ids[@]} )); then
  docker rm -f "${ids[@]}" >/dev/null && echo "Removed ${#ids[@]} leftover container(s)."
else
  echo "No apta-investigate containers left."
fi
if [[ "${1:-}" == --images ]]; then
  for img in "$AI_PG_IMAGE" "$AI_LOGCLI_IMAGE"; do
    if docker image inspect "$img" >/dev/null 2>&1; then
      docker rmi "$img" >/dev/null 2>&1 && echo "Removed image $img." || echo "Kept image $img (in use elsewhere)."
    fi
  done
fi
exit 0
