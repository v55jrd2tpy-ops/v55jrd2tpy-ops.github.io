#!/usr/bin/env bash
#
# publish.sh - commit and push changes to the lobbipop.ai GitHub Pages repo
#
# Usage:
#   ./publish.sh                          Commit with an auto-generated message
#   ./publish.sh -m "Add ROI post"        Commit with a custom message
#   ./publish.sh --dry-run                Show what would happen, change nothing
#   ./publish.sh -h | --help              Show this help text
#
set -euo pipefail

# --- defaults -----------------------------------------------------------
COMMIT_MSG=""
DRY_RUN=false

# --- helpers --------------------------------------------------------------
usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed '1d'
  exit 0
}

log()   { printf '==> %s\n' "$1"; }
error() { printf 'Error: %s\n' "$1" >&2; }

# --- parse args -------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message)
      if [[ -z "${2:-}" ]]; then
        error "-m requires a message argument"
        exit 1
      fi
      COMMIT_MSG="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      error "Unknown option: $1"
      usage
      ;;
  esac
done

# --- sanity checks ----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v git >/dev/null 2>&1; then
  error "git is not installed or not on PATH."
  exit 1
fi

if [[ ! -d .git ]]; then
  error "This doesn't look like a git repo: $SCRIPT_DIR"
  error "Expected to find a .git directory here."
  exit 1
fi

# Make sure we're tracking a remote before doing anything else
if ! git remote get-url origin >/dev/null 2>&1; then
  error "No 'origin' remote configured for this repo."
  exit 1
fi

# --- check for local changes -------------------------------------------------
if [[ -z "$(git status --porcelain)" ]]; then
  log "No changes to commit. Nothing to do."
  exit 0
fi

log "Changes detected:"
git status --short

# --- pull first, to avoid push conflicts -------------------------------------
log "Pulling latest changes from origin/main..."
if ! git pull --rebase origin main; then
  error "git pull failed. Resolve any conflicts manually, then re-run this script."
  exit 1
fi

# --- build commit message -----------------------------------------------------
if [[ -z "$COMMIT_MSG" ]]; then
  # Try to name the most recently added/modified post file, else fall back
  NEW_POST=$(git status --porcelain | grep '_posts/' | head -n 1 | awk '{print $NF}' || true)
  if [[ -n "$NEW_POST" ]]; then
    COMMIT_MSG="Add post: $(basename "$NEW_POST" .md)"
  else
    COMMIT_MSG="Update site content ($(date '+%Y-%m-%d %H:%M'))"
  fi
fi

log "Commit message: \"$COMMIT_MSG\""

if $DRY_RUN; then
  log "[dry run] Would run: git add -A"
  log "[dry run] Would run: git commit -m \"$COMMIT_MSG\""
  log "[dry run] Would run: git push origin main"
  log "Dry run complete. No changes were made."
  exit 0
fi

# --- commit and push -------------------------------------------------------
log "Staging changes..."
git add -A

log "Committing..."
if ! git commit -m "$COMMIT_MSG"; then
  error "git commit failed."
  exit 1
fi

log "Pushing to origin/main..."
if ! git push origin main; then
  error "git push failed. Your commit is saved locally but not published."
  error "Once you resolve the issue, just run: git push origin main"
  exit 1
fi

log "Done. GitHub Pages will rebuild automatically in a minute or two."
log "Check: https://lobbipop.ai/"
