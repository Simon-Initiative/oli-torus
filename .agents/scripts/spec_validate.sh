#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  .agents/scripts/spec_validate.sh --slug <feature_slug> [--check all|prd|fdd|plan|design] [--file <design_file>] [--check-external-links] [--timeout <seconds>]
  .agents/scripts/spec_validate.sh --feature-dir <path> [--check all|prd|fdd|plan|design] [--file <design_file>] [--check-external-links] [--timeout <seconds>]

Examples:
  .agents/scripts/spec_validate.sh --slug docs_import --check prd
  .agents/scripts/spec_validate.sh --slug docs_import --check all
  .agents/scripts/spec_validate.sh --feature-dir docs/features/docs_import --check design --file docs/features/docs_import/design/slice.md
EOF
}

slug=""
feature_dir=""
check="all"
design_file=""
check_external_links=false
timeout=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug)
      [[ $# -ge 2 ]] || { echo "ERROR: --slug requires a value" >&2; usage; exit 2; }
      slug="$2"
      shift 2
      ;;
    --feature-dir)
      [[ $# -ge 2 ]] || { echo "ERROR: --feature-dir requires a value" >&2; usage; exit 2; }
      feature_dir="$2"
      shift 2
      ;;
    --check)
      [[ $# -ge 2 ]] || { echo "ERROR: --check requires a value" >&2; usage; exit 2; }
      check="$2"
      shift 2
      ;;
    --file)
      [[ $# -ge 2 ]] || { echo "ERROR: --file requires a value" >&2; usage; exit 2; }
      design_file="$2"
      shift 2
      ;;
    --check-external-links)
      check_external_links=true
      shift
      ;;
    --timeout)
      [[ $# -ge 2 ]] || { echo "ERROR: --timeout requires a value" >&2; usage; exit 2; }
      timeout="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -n "$slug" && -n "$feature_dir" ]]; then
  echo "ERROR: provide only one of --slug or --feature-dir" >&2
  usage
  exit 2
fi

if [[ -z "$slug" && -z "$feature_dir" ]]; then
  echo "ERROR: one of --slug or --feature-dir is required" >&2
  usage
  exit 2
fi

if [[ -n "$slug" ]]; then
  feature_dir="docs/features/$slug"
fi

if [[ ! -d "$feature_dir" ]]; then
  echo "ERROR: feature directory not found: $feature_dir" >&2
  exit 2
fi

if [[ "$check" == "design" && -z "$design_file" ]]; then
  echo "ERROR: --file is required when --check design" >&2
  exit 2
fi

cmd=(
  python3
  .agents/skills/spec_validate/scripts/validate_spec_pack.py
  "$feature_dir"
  --check
  "$check"
)

if [[ -n "$design_file" ]]; then
  cmd+=(--file "$design_file")
fi

if [[ "$check_external_links" == true ]]; then
  cmd+=(--check-external-links)
fi

if [[ -n "$timeout" ]]; then
  cmd+=(--timeout "$timeout")
fi

echo "Running: ${cmd[*]}"
"${cmd[@]}"
