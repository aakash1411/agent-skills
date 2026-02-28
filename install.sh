#!/usr/bin/env bash
set -euo pipefail

REPO="aakash1411/agent-skills"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

SKILL_NAME=""
MODE="global"
CUSTOM_DIR=""

AVAILABLE_SKILLS=(
  memory-manager git-explain root-cause-analyzer test-first-workflow
  completion-guard worktree-manager system-design-advisor resilience-patterns
  pytest-architect perf-profiler ts-service-scaffolder ci-pipeline-generator
  container-optimizer progressive-delivery credential-vault
)

usage() {
  echo "Install individual skills from github.com/${REPO}"
  echo ""
  echo "Usage:"
  echo "  bash install.sh <skill-name> [options]"
  echo "  bash install.sh --all [options]"
  echo ""
  echo "Options:"
  echo "  --global       Install to ~/.windsurf/skills/ (default)"
  echo "  --workspace    Install to ./.windsurf/skills/ in current directory"
  echo "  --dir <path>   Install to a custom directory"
  echo "  --all          Install all skills"
  echo "  --list         List available skills"
  echo ""
  echo "Examples:"
  echo "  bash install.sh memory-manager"
  echo "  bash install.sh root-cause-analyzer --workspace"
  echo "  bash install.sh --all --dir ~/.cursor/skills"
  echo ""
  echo "One-liner (curl):"
  echo "  curl -sL ${BASE_URL}/install.sh | bash -s -- <skill-name>"
  echo "  curl -sL ${BASE_URL}/install.sh | bash -s -- --all"
}

list_skills() {
  echo "Available skills:"
  for s in "${AVAILABLE_SKILLS[@]}"; do
    echo "  $s"
  done
}

install_skill() {
  local skill="$1"
  local target_dir="$2"

  local skill_url="${BASE_URL}/${skill}/SKILL.md"
  local dest="${target_dir}/${skill}"

  mkdir -p "$dest"

  if command -v curl &>/dev/null; then
    local http_code
    http_code=$(curl -sL -w "%{http_code}" -o "${dest}/SKILL.md" "$skill_url")
    if [[ "$http_code" != "200" ]]; then
      rm -f "${dest}/SKILL.md"
      echo "  ✗ ${skill} (not found)"
      return 1
    fi
  elif command -v wget &>/dev/null; then
    if ! wget -q -O "${dest}/SKILL.md" "$skill_url" 2>/dev/null; then
      rm -f "${dest}/SKILL.md"
      echo "  ✗ ${skill} (not found)"
      return 1
    fi
  else
    echo "Error: curl or wget is required"
    exit 1
  fi

  echo "  ✓ ${skill} -> ${dest}/SKILL.md"
}

# Parse arguments
INSTALL_ALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)    MODE="global"; shift ;;
    --workspace) MODE="workspace"; shift ;;
    --dir)       MODE="custom"; CUSTOM_DIR="$2"; shift 2 ;;
    --all)       INSTALL_ALL=true; shift ;;
    --list)      list_skills; exit 0 ;;
    --help|-h)   usage; exit 0 ;;
    -*)          echo "Unknown option: $1"; usage; exit 1 ;;
    *)           SKILL_NAME="$1"; shift ;;
  esac
done

if [[ "$INSTALL_ALL" == false && -z "$SKILL_NAME" ]]; then
  usage
  exit 1
fi

# Resolve target directory
case "$MODE" in
  global)    TARGET_DIR="${HOME}/.windsurf/skills" ;;
  workspace) TARGET_DIR=".windsurf/skills" ;;
  custom)    TARGET_DIR="$CUSTOM_DIR" ;;
esac

echo "Installing to: ${TARGET_DIR}"
echo ""

if [[ "$INSTALL_ALL" == true ]]; then
  for skill in "${AVAILABLE_SKILLS[@]}"; do
    install_skill "$skill" "$TARGET_DIR"
  done
else
  install_skill "$SKILL_NAME" "$TARGET_DIR"
fi

echo ""
echo "Done. Skills are ready to use."
