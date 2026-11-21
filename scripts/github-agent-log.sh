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
# cancelled, just before the results are uploaded
# (.github/workflows/tests.yml). It only reads, and it always ends with
# status 0: it must never change how a job ended. If the file cannot be
# written, the record is still printed.
#
# After a cancel GitHub gives the job's last steps five minutes, and on a
# busy Mac starting one program can take seconds (a first version of this
# script, starting about forty, kept the upload after it from finishing in
# two jobs of five: docs/log/2026-11-21-github-agent-log.md). So where the
# agent's folder is where GitHub keeps it, this starts two programs,
# sysctl and one awk that reads every log; `ps` runs only when the folder
# is elsewhere, for at most GITHUB_AGENT_PS_SECONDS (30 by default).
#
# The results are a public download, so only the lines below are copied,
# never a whole log; anything shaped like a token, key or signature in
# them is replaced with [removed]; and no program's arguments are read.
#
# The agent's folder is the first of these that holds a _diag folder:
# /Users/runner/actions-runner/cached and /Users/runner/actions-runner (or
# the folders GITHUB_AGENT_KNOWN_FOLDERS lists, separated by colons), then
# the folder above bin/ of a running Runner.Worker or Runner.Listener.
# Setting GITHUB_AGENT_FOLDER reads that folder alone. The tests set both
# (scripts/test-runner.py, GitHubAgentLogTests).
set +e
shopt -s nullglob

results="${1:-build/TestResults}"
out="$results/github-agent-log.txt"
ps_limit="${GITHUB_AGENT_PS_SECONDS:-30}"
case "$ps_limit" in '' | *[!0-9]*) ps_limit=30 ;; esac

writable=no
[ -d "$results" ] || mkdir -p "$results" 2>/dev/null
if : > "$out" 2>/dev/null; then
    writable=yes
fi

# One line to the job's log and, when it can be written, to the file.
say() {
    printf '%s\n' "$1"
    [ "$writable" = no ] || printf '%s\n' "$1" >> "$out"
}

# The load and the processors from one sysctl, or from Linux's files.
facts="$(sysctl -n vm.loadavg hw.ncpu 2>/dev/null)"
if [ -n "$facts" ]; then
    load="${facts%%$'\n'*}"
    processors="${facts##*$'\n'}"
else
    load="not readable"
    [ -r /proc/loadavg ] && read -r load < /proc/loadavg
    processors="$(getconf _NPROCESSORS_ONLN 2>/dev/null)"
fi

say "What GitHub's agent on this machine logged (scripts/github-agent-log.sh)"
say "Job: ${GITHUB_JOB:-unknown}; run ${GITHUB_RUN_ID:-unknown}, attempt ${GITHUB_RUN_ATTEMPT:-unknown}; workflow: ${GITHUB_WORKFLOW:-unknown}"
say "Machine: ${RUNNER_NAME:-unknown}; image: ${ImageOS:-unknown}${ImageVersion:+ $ImageVersion}"
say "Load (1, 5 and 15 minutes): ${load:-not readable}"
say "Processors: ${processors:-not readable}"
[ "$writable" = yes ] || say "The results folder could not be written ($out), so this is only in the job's log."

# Every program's number, running time and path, never its arguments, from
# a `ps` stopped after ps_limit seconds.
processes() {
    ps -axo pid=,etime=,comm= 2>/dev/null &
    local reader=$!
    (sleep "$ps_limit"; kill -9 "$reader") >/dev/null 2>&1 &
    local timer=$!
    wait "$reader"
    kill "$timer" 2>/dev/null
}

agent=""
tried=()
listing=""
listed=no
try() {
    [ -n "$1" ] || return 1
    tried+=("$1")
    [ -d "$1/_diag" ] && agent="$1"
}
if [ -n "${GITHUB_AGENT_FOLDER:-}" ]; then
    try "$GITHUB_AGENT_FOLDER"
else
    IFS=: read -r -a known <<< "${GITHUB_AGENT_KNOWN_FOLDERS-/Users/runner/actions-runner/cached:/Users/runner/actions-runner}"
    for folder in "${known[@]}"; do
        try "$folder" && break
    done
    if [ -z "$agent" ]; then
        listing="$(processes)"
        listed=yes
        while read -r _ _ program; do
            case "$program" in
                */bin/Runner.Worker | */bin/Runner.Listener) try "${program%/bin/Runner.*}" && break ;;
            esac
        done <<< "$listing"
    fi
fi

if [ -z "$agent" ]; then
    [ "$listed" = yes ] || listing="$(processes)"
    say "Written: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    say ""
    say "No folder of GitHub's agent with a _diag folder was found. Looked in:"
    for folder in "${tried[@]}"; do
        if [ -d "$folder" ]; then
            names=""
            count=0
            for entry in "$folder"/* "$folder"/.[!.]*; do
                [ "$count" -lt 20 ] || break
                names="$names ${entry##*/}"
                count=$((count + 1))
            done
            say "  $folder (no _diag folder; it holds:${names:- nothing})"
        else
            say "  $folder (not there)"
        fi
    done
    say "Folders beside them whose name holds \"runner\":"
    found=no
    for folder in "${tried[@]}"; do
        for beside in "${folder%/*}"/*[Rr]unner*; do
            say "  $beside"
            found=yes
        done
    done
    [ "$found" = yes ] || say "  none"
    # By the program's own name, not its folder's: every path under
    # GitHub's home folder (/Users/runner) holds "runner".
    say "Running programs whose name holds \"runner\" (number, running time, program):"
    found=no
    while read -r pid elapsed program; do
        name="${program##*/}"
        case "$name" in
            *[Rr][Uu][Nn][Nn][Ee][Rr]*) say "  $pid $elapsed $program"; found=yes ;;
        esac
    done <<< "$listing"
    [ "$found" = yes ] || say "  none"
    exit 0
fi

say "Agent folder: $agent"
logs=("$agent"/_diag/Runner_*.log "$agent"/_diag/Worker_*.log)
if [ "${#logs[@]}" -eq 0 ]; then
    say "Its _diag folder holds no Runner_*.log or Worker_*.log."
    exit 0
fi
[ "$writable" = yes ] || out=""

# One awk reads every log. For each Runner_ log: three lines that answer
# the question, then its lines about the job, its hold, its cancelling and
# its end (the last 300), then its last 40 lines. For each Worker_ log:
# its lines about cancelling and shutting down (the last 100). Only the
# agent's own timestamped lines are matched: the Worker log also holds the
# job's whole description, pull request text included.
read -r -d '' program <<'AWK'
function scrub(s, pattern, prefix,    done, start, length_, text, keep) {
    done = ""
    while (match(tolower(s), pattern)) {
        start = RSTART; length_ = RLENGTH
        text = substr(s, start, length_)
        keep = 0
        if (prefix != "" && match(tolower(text), prefix)) keep = RSTART + RLENGTH - 1
        done = done substr(s, 1, start - 1) substr(text, 1, keep) "[removed]"
        s = substr(s, start + length_)
    }
    return done s
}
# Tokens (JSON web tokens, GitHub's), and the values of credentials and
# signed addresses.
function redact(s) {
    s = scrub(s, "eyj[a-z0-9_-]+(\\.[a-z0-9_-]*)*", "")
    s = scrub(s, "gh[opsur]_[a-z0-9]+", "")
    s = scrub(s, "(bearer|basic) [^ \t\"',;]+", "^(bearer|basic) ")
    s = scrub(s, "authorization[\":= ]+[^ \t\"',;]+", "^authorization[\":= ]+")
    s = scrub(s, "(sig|signature|token|access_token|key|secret|password|jitconfig)=[^& \t\"',;]+", "^[a-z_]+=")
    return s
}
function say(line) {
    line = redact(line)
    print line
    if (out != "") print line >> out
}
function or_none(line) { return line == "" ? "none" : line }
# Seconds since 1970 as a UTC date and time.
function utc(t,    days, z, era, doe, yoe, y, doy, mp, d, m, s) {
    days = int(t / 86400); s = t - days * 86400
    z = days + 719468; era = int(z / 146097); doe = z - era * 146097
    yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
    y = yoe + era * 400; doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
    mp = int((5 * doy + 2) / 153); d = doy - int((153 * mp + 2) / 5) + 1
    m = mp < 10 ? mp + 3 : mp - 9
    if (m <= 2) y++
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", y, m, d, int(s / 3600), int(s % 3600 / 60), s % 60)
}
function finish(    i, first) {
    if (name == "") return
    if (kind == "runner") {
        say(""); say("== " name " ==")
        say("Last successful renewal: " or_none(renewed))
        say("First trouble renewing: " or_none(trouble))
        say("Cancellation request: " or_none(request))
        say(""); say("-- " name ": lines about the job, its hold, its cancelling and its end (last 300) --")
        for (i = (kept > 300 ? kept - 300 : 0); i < kept; i++) say(matched[i % 300])
        say(""); say("-- " name ": its last 40 lines --")
        for (i = (lines > 40 ? lines - 39 : 1); i <= lines; i++) say(last[i % 40])
    } else {
        say(""); say("-- " name ": lines about cancelling and shutting down (last 100) --")
        for (i = (kept > 100 ? kept - 100 : 0); i < kept; i++) say(matched[i % 100])
    }
    fflush()
}
BEGIN {
    srand(); now = srand()
    say("Written: " utc(now))
}
FNR == 1 {
    finish()
    name = FILENAME; sub(/.*\//, "", name)
    kind = name ~ /^Worker_/ ? "worker" : "runner"
    kept = 0; lines = 0; renewed = ""; trouble = ""; request = ""
}
{
    lines = FNR
    if (kind == "runner") last[FNR % 40] = $0
    if ($0 !~ /^\[[0-9]/) next
    low = tolower($0)
    if (low ~ /force kill process on cancellation/) next
    if (kind == "worker") {
        if (low ~ /cancel|abandon|shut(ting)? ?down/) matched[kept++ % 100] = $0
        next
    }
    if (low ~ /successfully renew/) renewed = $0
    if (trouble == "" && low ~ /exception during renew|retrying lock renewal|run out of retry|no longer valid/) trouble = $0
    if (request == "" && low ~ /cancellation request/) request = $0
    if (low ~ /renew|cancel|abandon|finish job request|worker finished|exception|timed out|timeout|shut(ting)? ?down|deprovision|job request .* received/)
        matched[kept++ % 300] = $0
}
END { finish() }
AWK
awk -v out="$out" "$program" "${logs[@]}"
exit 0
