#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Lista de submódulos asociados a cada ETL
SUBMODULES=(
    "https://github.com/ceicol/af_zprn_to_ladm.git ms_to_ladm_zprn main"
)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
AIRFLOW_DIR="airflow"
SUBMODULES_DIR="$AIRFLOW_DIR/submodules"
CONFIGURE_MODE="${CONFIGURE_MODE:-link}"
SUBMODULE_UPDATE_REMOTE="${SUBMODULE_UPDATE_REMOTE:-1}"

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
abort() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

cd "$REPO_ROOT"

has_tracked_changes() {
    local abs_path="$1"

    if ! git -C "$abs_path" diff --quiet; then
        return 0
    fi

    if ! git -C "$abs_path" diff --cached --quiet; then
        return 0
    fi

    return 1
}

is_git_worktree() {
    local abs_path="$1"

    git -C "$abs_path" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

ensure_gitmodules_entry() {
    local repo_url="$1"
    local local_path="$2"
    local branch="$3"
    local current_url

    if current_url="$(git config --file .gitmodules --get "submodule.$local_path.url" 2>/dev/null)"; then
        if [[ "$current_url" != "$repo_url" ]]; then
            log "Updating URL for $local_path"
            git config --file .gitmodules "submodule.$local_path.url" "$repo_url"
        fi

        if [[ -n "$branch" ]]; then
            git config --file .gitmodules "submodule.$local_path.branch" "$branch"
        fi
        return
    fi

    log "Registering submodule $local_path"
    if [[ -n "$branch" ]]; then
        git submodule add --force -b "$branch" "$repo_url" "$local_path"
    else
        git submodule add --force "$repo_url" "$local_path"
    fi
}

ensure_working_branch() {
    local abs_path="$1"
    local branch="$2"
    local current_branch

    [[ -n "$branch" ]] || return

    current_branch="$(git -C "$abs_path" symbolic-ref --short -q HEAD || true)"
    if [[ "$current_branch" == "$branch" ]]; then
        return
    fi

    if [[ -n "$current_branch" ]]; then
        log "Submodule is on branch '$current_branch'; leaving it as-is."
        return
    fi

    if has_tracked_changes "$abs_path"; then
        warn "Submodule has tracked local changes while HEAD is detached. Skipping branch checkout for $abs_path."
        return
    fi

    if git -C "$abs_path" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$abs_path" checkout "$branch"
    elif git -C "$abs_path" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        git -C "$abs_path" checkout -b "$branch" --track "origin/$branch"
    else
        warn "Branch '$branch' was not found for $abs_path. Leaving current checkout."
    fi
}

update_submodule_remote() {
    local abs_path="$1"
    local branch="$2"

    [[ "$SUBMODULE_UPDATE_REMOTE" == "1" ]] || return
    [[ -n "$branch" ]] || return

    if has_tracked_changes "$abs_path"; then
        warn "Submodule has tracked local changes. Skipping remote update for $abs_path."
        return
    fi

    git -C "$abs_path" fetch origin "$branch"
    ensure_working_branch "$abs_path" "$branch"

    if [[ "$(git -C "$abs_path" symbolic-ref --short -q HEAD || true)" == "$branch" ]]; then
        git -C "$abs_path" pull --ff-only origin "$branch"
    fi
}

init_or_update_submodule() {
    local local_path="$1"
    local abs_path="$2"

    if is_git_worktree "$abs_path" && has_tracked_changes "$abs_path"; then
        warn "Submodule has tracked local changes. Skipping git submodule update for $abs_path."
        return
    fi

    git submodule update --init --recursive "$local_path"
}

run_configure_script() {
    local abs_path="$1"
    local configure_script="$abs_path/configure.sh"

    if [[ ! -f "$configure_script" ]]; then
        warn "No configure.sh found in $abs_path. Skipping configuration."
        return
    fi

    log "Running configure.sh in $CONFIGURE_MODE mode"
    (
        cd "$abs_path"
        AIRFLOW_ROOT="$REPO_ROOT/$AIRFLOW_DIR" CONFIGURE_MODE="$CONFIGURE_MODE" bash configure.sh
    )
}

log "Repository root: $REPO_ROOT"
log "Submodules directory: $SUBMODULES_DIR"
log "Configure mode: $CONFIGURE_MODE"

for submodule in "${SUBMODULES[@]}"; do
    read -r REPO_URL FOLDER_NAME BRANCH <<< "$submodule"
    BRANCH="${BRANCH:-main}"
    LOCAL_PATH="$SUBMODULES_DIR/$FOLDER_NAME"
    ABS_PATH="$REPO_ROOT/$LOCAL_PATH"

    log "Processing $LOCAL_PATH"
    log "Repository: $REPO_URL"
    log "Branch: $BRANCH"

    ensure_gitmodules_entry "$REPO_URL" "$LOCAL_PATH" "$BRANCH"

    git submodule sync -- "$LOCAL_PATH"
    init_or_update_submodule "$LOCAL_PATH" "$ABS_PATH"

    update_submodule_remote "$ABS_PATH" "$BRANCH"
    ensure_working_branch "$ABS_PATH" "$BRANCH"
    run_configure_script "$ABS_PATH"

    log "Submodule ready: $LOCAL_PATH"
    log "--------------------------------------------"
done

log "Submodule update process finished."
