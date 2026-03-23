#!/usr/bin/env bash

set -euo pipefail

repo="SednaLabs/codex"
workflow="sedna-branch-build"
branch=""
run_id=""
install_dir="${CODEX_INSTALL_DIR:-$HOME/.local/bin}"
keep_tmp=0

usage() {
  cat <<'EOF'
Install the latest successful Sedna branch-build artifact into a local bin dir.

Usage:
  scripts/install-sedna-branch-artifact.sh [--branch <branch>] [--run-id <run-id>] [--repo <owner/repo>] [--install-dir <dir>] [--keep-tmp]

Examples:
  scripts/install-sedna-branch-artifact.sh --branch validation/compile-remote-build-20260324
  scripts/install-sedna-branch-artifact.sh --run-id 23451655671

Notes:
  - If --run-id is omitted, the script installs the latest successful `sedna-branch-build`
    run for the selected branch.
  - The installed binaries are `codex` and `codex-responses-api-proxy`.
  - Existing binaries are backed up with a timestamp suffix before replacement.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      branch="${2:?missing value for --branch}"
      shift 2
      ;;
    --run-id)
      run_id="${2:?missing value for --run-id}"
      shift 2
      ;;
    --repo)
      repo="${2:?missing value for --repo}"
      shift 2
      ;;
    --install-dir)
      install_dir="${2:?missing value for --install-dir}"
      shift 2
      ;;
    --keep-tmp)
      keep_tmp=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$branch" && -z "$run_id" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch="$(git rev-parse --abbrev-ref HEAD)"
  else
    echo "--branch is required outside a git worktree when --run-id is not provided" >&2
    exit 2
  fi
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [[ -z "$run_id" ]]; then
  run_id="$(gh run list \
    --repo "$repo" \
    --workflow "$workflow" \
    --branch "$branch" \
    --limit 20 \
    --json databaseId,conclusion \
    --jq 'map(select(.conclusion=="success"))[0].databaseId')"
  if [[ -z "$run_id" || "$run_id" == "null" ]]; then
    echo "no successful $workflow run found for branch $branch in $repo" >&2
    exit 1
  fi
fi

artifact_name="$(gh api "repos/$repo/actions/runs/$run_id/artifacts" \
  --jq '.artifacts[] | select(.expired == false) | .name' | head -n 1)"
if [[ -z "$artifact_name" ]]; then
  echo "no downloadable artifact found for run $run_id in $repo" >&2
  exit 1
fi

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/codex-branch-artifact.XXXXXX")"
cleanup() {
  if [[ "$keep_tmp" -eq 0 ]]; then
    rm -rf "$tmpdir"
  fi
}
trap cleanup EXIT

gh run download "$run_id" --repo "$repo" --name "$artifact_name" --dir "$tmpdir" >/dev/null

archive="$(find "$tmpdir" -type f -name '*.tar.gz' | head -n 1)"
if [[ -z "$archive" ]]; then
  echo "artifact $artifact_name from run $run_id did not contain a .tar.gz payload" >&2
  exit 1
fi

stage_dir="$tmpdir/extracted"
mkdir -p "$stage_dir"
tar -xzf "$archive" -C "$stage_dir"

backup_stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$install_dir"

if [[ -f "$install_dir/codex" ]]; then
  cp -p "$install_dir/codex" "$install_dir/codex.backup-$backup_stamp"
fi
if [[ -f "$install_dir/codex-responses-api-proxy" ]]; then
  cp -p "$install_dir/codex-responses-api-proxy" "$install_dir/codex-responses-api-proxy.backup-$backup_stamp"
fi

install -Dm 0755 "$stage_dir/codex" "$install_dir/codex"
if [[ -f "$stage_dir/codex-responses-api-proxy" ]]; then
  install -Dm 0755 "$stage_dir/codex-responses-api-proxy" "$install_dir/codex-responses-api-proxy"
fi

echo "Installed artifact:"
echo "  repo: $repo"
echo "  run: $run_id"
echo "  artifact: $artifact_name"
echo "  install_dir: $install_dir"
echo "  backup_stamp: $backup_stamp"
"$install_dir/codex" --version
