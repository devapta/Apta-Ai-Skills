#!/usr/bin/env bash
# Builds the Linux release archive in Docker. Run from the project root next to Dockerfile.linux.
# Needs: docker (with buildx) and jq. Output: build/ubuntu/<app-slug>-linux-x64.tar.gz

set -euo pipefail

app_name="<app-slug>"   # archive name prefix, e.g. my-app

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output_dir="$script_dir/build/ubuntu"

for tool in docker jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Error: %s must be installed to build the Ubuntu release.\n' "$tool" >&2
    exit 1
  fi
done

if ! flutter_version="$(jq -er '.flutter | select(type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' "$script_dir/.fvmrc")"; then
  printf 'Error: .fvmrc must specify an exact stable Flutter version.\n' >&2
  exit 1
fi

if [[ ! -f "$script_dir/.env" ]]; then
  printf 'Error: the .env application asset is missing from the project root.\n' >&2
  exit 1
fi

docker buildx version >/dev/null
docker info >/dev/null

printf 'Building Ubuntu 22.04 x64 release with Flutter %s...\n' "$flutter_version"
docker buildx build \
  --platform linux/amd64 \
  --file "$script_dir/Dockerfile.linux" \
  --build-arg "FLUTTER_VERSION=$flutter_version" \
  --build-arg "APP_NAME=$app_name" \
  --output "type=local,dest=$output_dir" \
  "$script_dir"

printf 'Ubuntu release archive: %s/%s-linux-x64.tar.gz\n' "$output_dir" "$app_name"
