#!/bin/bash
# Saves what GitHub's agent on this machine logged about a job that was
# cancelled. GitHub has cancelled Mac test jobs by itself, with nothing in
# the job's log but "The operation was canceled." The agent (GitHub's
# runner program, which takes the job from GitHub's service, runs its
# steps and renews its hold on the job every minute) keeps its own log in
# its _diag folder. That log says which of two things happened:
#
#   - GitHub's service cancelled the job: the hold was renewed right up to
#     "Job cancellation request ... received".
#   - The agent lost its hold on the job: "Catch exception during renew",
#     "Retrying lock renewal" and "Lock renewal has run out of retry" come
#     before the cancel, with no cancellation request.
#
# The line that names the job's end ("finish job request ... with result")
# is written after the job's last step, so a step running this sees the
# lines above but not that one.
#
# Usage: scripts/github-agent-log.sh [results folder]
#
# Writes <results folder>/github-agent-log.txt (build/TestResults when no
# folder is given) and prints it. The workflow runs it only when a job was
# cancelled (.github/workflows/tests.yml). It only reads, and it always
# ends with status 0: it must never change how a job ended. If the file
# cannot be written, the record is still printed.
#
# The results are a public download, so only the lines below are copied,
# never a whole log; anything shaped like a token, key or signature in
# them is replaced with [removed]; and no process's arguments are read.
#
# It runs just before the job's test results are uploaded, on a Mac that
# may be very busy (`ps` has taken minutes there: docs/DECISIONS.md,
# "Tests", 2026-11-04). So it stops after GITHUB_AGENT_LOG_SECONDS
# (90 by default), keeping what it wrote, and gives `ps` a third of that.
#
# The agent's folder is the first of these that holds a _diag folder:
# /Users/runner/actions-runner/cached and /Users/runner/actions-runner (or
# the folders GITHUB_AGENT_KNOWN_FOLDERS lists, separated by colons), then
# the folder above bin/ of a running Runner.Worker or Runner.Listener.
# Setting GITHUB_AGENT_FOLDER reads that folder alone. The tests set both
# (scripts/test-runner.py, GitHubAgentLogTests).
set +e

results="${1:-build/TestResults}"
out="$results/github-agent-log.txt"
limit="${GITHUB_AGENT_LOG_SECONDS:-90}"
case "$limit" in '' | *[!0-9]*) limit=90 ;; esac
runner_lines='renew|cancel|abandon|finish job request|worker finished|exception|timed out|timeout|shut(ting)? ?down|deprovision|job request .* received'
worker_lines='cancel|abandon|shut(ting)? ?down'
trouble_lines='exception during renew|retrying lock renewal|run out of retry|no longer valid'
# Tokens (JSON web tokens, GitHub's), and the values of credentials and
# signed addresses.
redact='s/eyJ[A-Za-z0-9_-]{10,}(\.[A-Za-z0-9_-]*)*/[removed]/g
s/gh[opsur]_[A-Za-z0-9]{20,}/[removed]/g
s/([Bb]earer|[Bb]asic) [^[:space:]"'"'"',;]+/\1 [removed]/g
s/([Aa]uthorization[":= ]+)[^[:space:]"'"'"',;]+/\1[removed]/g
s/([Ss]ig|[Ss]ignature|[Tt]oken|[Aa]ccess_token|[Kk]ey|[Ss]ecret|[Pp]assword|[Jj]itconfig)=[^&[:space:]"'"'"',;]+/\1=[removed]/g'

# Writes to the job's log and, when it can be written, to the file, as it
# goes: a step cut short still keeps what it had.
writable=no
if mkdir -p "$results" 2>/dev/null && : > "$out" 2>/dev/null; then
    writable=yes
fi
emit() {
    if [ "$writable" = yes ]; then
        sed -E "$redact" | tee -a "$out"
    else
        sed -E "$redact"
    fi
}

# Each line indented, or "none" for no lines.
indented() {
    awk '{ print "  " $0 } END { if (NR == 0) print "  none" }'
}

# The first line, or "none".
first_or_none() {
    awk 'NR == 1 { print; found = 1 } END { if (!found) print "none" }'
}

# Ends the script, keeping what it wrote, once its time is up.
in_time() {
    if [ "$SECONDS" -ge "$limit" ]; then
        printf '\nStopped after %s s, so the upload after this step still runs: the rest is not here.\n' \
            "$SECONDS" | emit
        exit 0
    fi
}

load() {
    sysctl -n vm.loadavg 2>/dev/null || cat /proc/loadavg 2>/dev/null || echo "not readable"
}

processors() {
    sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo "not readable"
}

# Every process's number, running time and program, never its arguments,
# from a `ps` stopped after a third of the time this script has.
processes() {
    ps -axo pid=,etime=,comm= 2>/dev/null &
    local reader=$!
    (sleep $((limit / 3)); kill -9 "$reader") >/dev/null 2>&1 &
    local timer=$!
    wait "$reader"
    kill "$timer" 2>/dev/null
}

{
    echo "What GitHub's agent on this machine logged (scripts/github-agent-log.sh)"
    echo "Written: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "Job: ${GITHUB_JOB:-unknown}; run ${GITHUB_RUN_ID:-unknown}, attempt ${GITHUB_RUN_ATTEMPT:-unknown}; workflow: ${GITHUB_WORKFLOW:-unknown}"
    echo "Machine: ${RUNNER_NAME:-unknown}; image: ${ImageOS:-unknown}${ImageVersion:+ $ImageVersion}"
    echo "Load (1, 5 and 15 minutes): $(load)"
    echo "Processors: $(processors)"
    [ "$writable" = yes ] || echo "The results folder could not be written ($out), so this is only in the job's log."
} | emit

agent=""
tried=""
listing=""
listed=no
try() {
    [ -n "$1" ] || return 1
    tried="$tried$1
"
    [ -d "$1/_diag" ] && agent="$1"
}
if [ -n "${GITHUB_AGENT_FOLDER:-}" ]; then
    try "$GITHUB_AGENT_FOLDER"
else
    known="${GITHUB_AGENT_KNOWN_FOLDERS-/Users/runner/actions-runner/cached:/Users/runner/actions-runner}"
    while IFS= read -r folder; do
        try "$folder" && break
    done <<EOF
$(printf '%s\n' "$known" | tr ':' '\n')
EOF
    [ -n "$agent" ] || {
        in_time
        listing="$(processes)"
        listed=yes
        while IFS= read -r folder; do
            try "$folder" && break
        done <<EOF
$(printf '%s\n' "$listing" | awk '{ for (i = 3; i <= NF; i++) if ($i ~ /\/bin\/Runner\.(Worker|Listener)$/) {
        folder = $i; sub(/\/bin\/Runner\.(Worker|Listener)$/, "", folder)
        if (!(folder in seen)) { seen[folder] = 1; print folder } } }')
EOF
    }
fi

if [ -z "$agent" ]; then
    if [ "$listed" = no ]; then
        in_time
        listing="$(processes)"
    fi
    {
        echo
        echo "No folder of GitHub's agent with a _diag folder was found. Looked in:"
        printf '%s' "$tried" | while IFS= read -r folder; do
            if [ -d "$folder" ]; then
                echo "  $folder (no _diag folder; it holds: $(ls -A "$folder" 2>/dev/null | head -n 20 | tr '\n' ' '))"
            else
                echo "  $folder (not there)"
            fi
        done
        echo "Folders beside them whose name holds \"runner\":"
        printf '%s' "$tried" | while IFS= read -r folder; do dirname "$folder"; done | sort -u |
            while IFS= read -r parent; do
                ls -d "$parent"/*[Rr]unner* 2>/dev/null
            done | sort -u | indented
        # By the program's own name, not its folder's: every path under
        # GitHub's home folder (/Users/runner) holds "runner".
        echo "Running programs whose name holds \"runner\" (number, running time, program):"
        printf '%s\n' "$listing" | awk 'NF >= 3 { name = $3; sub(/.*\//, "", name)
                                         if (tolower(name) ~ /runner/) print }' | indented
    } | emit
    exit 0
fi

{
    echo "Agent folder: $agent"
    ls "$agent"/_diag/Runner_*.log >/dev/null 2>&1 || echo "Its _diag folder holds no Runner_*.log."
} | emit
for log in "$agent"/_diag/Runner_*.log; do
    [ -f "$log" ] || continue
    in_time
    name="${log##*/}"
    {
        echo
        echo "== $name =="
        echo "Last successful renewal: $(grep -i 'successfully renew' "$log" | tail -n 1 | first_or_none)"
        echo "First trouble renewing: $(grep -i -E "$trouble_lines" "$log" | first_or_none)"
        echo "Cancellation request: $(grep -i 'cancellation request' "$log" | first_or_none)"
        echo
        echo "-- $name: lines about the job, its hold, its cancelling and its end (last 300) --"
        grep -i -E "$runner_lines" "$log" | tail -n 300
        echo
        echo "-- $name: its last 40 lines --"
        tail -n 40 "$log"
    } | emit
done
for log in "$agent"/_diag/Worker_*.log; do
    [ -f "$log" ] || continue
    in_time
    name="${log##*/}"
    {
        echo
        echo "-- $name: lines about cancelling and shutting down (last 100) --"
        grep -i -E "$worker_lines" "$log" | tail -n 100
    } | emit
done
exit 0
