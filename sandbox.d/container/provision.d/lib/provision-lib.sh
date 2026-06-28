_lib_setup_trap() {
	_lib_cleanup_handler() {
		local exit_code=$?
		if [[ $exit_code -ne 0 ]]; then
			echo "[ERR] unexpected script termination. dropping tracking tokens." >&2
			if [[ -n "${LOCK_FILE:-}" ]]; then
				rm -f "$LOCK_FILE"
			fi
		fi
		exit "$exit_code"
	}
	trap _lib_cleanup_handler EXIT
}

_lib_init_provision_state() {
	local profile="$1"
	shift

	local specs_rev="${MUTHR_SPECS_REV:-unknown-spec-rev}"

	LOCK_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/muthr"
	mkdir -p "$LOCK_DIR"
	LOCK_FILE="$LOCK_DIR/provision.lock"
	local IFS='|'
	ENV_FINGERPRINT="${profile}|${specs_rev}|${*}"

	_lib_setup_trap

	if [[ -f "$LOCK_FILE" ]] && [[ "$(cat "$LOCK_FILE" 2>/dev/null || true)" == "$ENV_FINGERPRINT" ]]; then
		echo "[INFO] environment match detected for '${profile}'. skipping provision run."
		exit 0
	fi

	echo "[PROC] initiating installation tracking context for '${profile}'..."
}

_lib_finalize_provision_state() {
	if [[ -z "${LOCK_FILE:-}" ]] || [[ -z "${ENV_FINGERPRINT:-}" ]]; then
		echo "[ERR] provision tracing primitives missing initialization." >&2
		exit 1
	fi

	printf '%s\n' "$ENV_FINGERPRINT" > "$LOCK_FILE"
	chmod 0600 "$LOCK_FILE"
}
