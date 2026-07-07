# Per-account EMA state for the status line

**Date:** 2026-07-07
**Status:** Approved, ready for implementation plan

## Problem

The status-line EMA forecast persists its state to a fixed path:

- `~/.claude/.statusline-ema-5h`
- `~/.claude/.statusline-ema-7d`

and every derived file (`.samples.tsv`, `.lock`, `.tmp.$$`) hangs off that same
base path. The path is hardcoded in `fmt_rate_limit`'s two call sites in
`private_dot_claude/statusline-command.sh` (currently lines 181–183).

Rate-limit windows are **per account**. When the user switches accounts, the new
account's `used_percentage` samples are written into the previous account's state
file. The EMA rate is computed from cross-account deltas, so the forecast is
garbage until the bad samples decay out of the half-life window. This is the
pollution the change eliminates.

## Approach

Key every EMA state path by the account's stable `accountUuid`, read from
`~/.claude.json` (`.oauthAccount.accountUuid`). Each account gets its own state
file, sample log, and lock; switching accounts can no longer cross-contaminate.

Extracting the UUID via `jq` from `~/.claude.json` measured ~4 ms — negligible
per render.

### Decisions

1. **Identity source: `accountUuid`.** Stable across email/display-name changes,
   opaque (no PII in `~/.claude/` filenames), globally unique per account.
   Rejected: `emailAddress` (leaks PII into filenames, changes if the account's
   email changes) and `organizationUuid` (wrong granularity — rate limits are
   per account, not per org).
2. **Existing unkeyed files: adopt for the current account.** On first render
   after the change, if the keyed file is absent but the legacy unkeyed file
   exists, rename the legacy file (and its `.samples.tsv`) to the keyed path.
   This preserves EMA warmup for whichever account is active at rollout; other
   accounts start fresh.
3. **Fallback when the UUID can't be read: shared `unknown` bucket.** Fall back
   to `account_key="unknown"` so the EMA keeps working (degraded to today's
   shared behavior) rather than dropping the forecast. Rare, and self-heals on
   the next render once the read succeeds.

## Implementation

All changes are in `private_dot_claude/statusline-command.sh`. The pure
`ema_project` function in `statusline-ema.sh` never sees paths and is untouched.
The advisory-lock helpers are untouched — they simply lock the keyed path now.

### 1. Resolve the account once (main body, before the two `fmt_rate_limit` calls)

```sh
account_key=$(jq -r '.oauthAccount.accountUuid // empty' "${HOME}/.claude.json" 2>/dev/null \
  | tr -cd 'A-Za-z0-9_-')
[ -z "$account_key" ] && account_key="unknown"
```

`tr -cd` is defensive path hygiene — a UUID is already filename-safe, but this
guarantees no surprise character reaches the path. Resolved once and passed into
both windows.

### 2. Pass the base path + `account_key` into `fmt_rate_limit`; derive the keyed path inside

`fmt_rate_limit` receives the unkeyed base path (as today) plus the new
`account_key` argument. Inside the function, after acquiring the lock and before
reading prior state:

```sh
local keyed="${state_file}-${account_key}"
# One-time adoption: inherit pre-keying warmup for the real active account.
if [ "$account_key" != "unknown" ] && [ ! -f "$keyed" ] && [ -f "$state_file" ]; then
  mv -f "$state_file" "$keyed"
  [ -f "${state_file}.samples.tsv" ] && mv -f "${state_file}.samples.tsv" "${keyed}.samples.tsv"
fi
state_file="$keyed"
```

- Runs **inside the existing lock**, so two concurrent sessions cannot
  double-adopt.
- Fires exactly once: afterward the keyed file exists and the unkeyed one is
  gone.
- The `!= "unknown"` guard prevents the degraded fallback bucket from stealing
  the legacy warmup that belongs to a real account.
- `.lock`, `.tmp.$$`, and `.samples.tsv` all follow automatically because they
  are derived from `state_file`, which is reassigned to the keyed path here.

### 3. Lock ordering note

The lock is acquired on the keyed path (`${state_file}.lock` after
reassignment), or the adoption must occur under a lock on the base path first.
Simplest correct ordering: compute `keyed`, acquire the lock on `keyed`, perform
adoption, then proceed. Because adoption only renames when `keyed` is absent and
is idempotent under the lock, locking on the keyed path is sufficient — the
race being prevented is two sessions of the **same** account, which share the
same keyed lock.

## Testing

Add cases to `tests/statusline-command.test.sh`, using a temp `HOME` per repo
convention (never render against the real `~/.claude`). Each case writes a fake
`~/.claude.json` under the temp HOME and drives one render with `STATUSLINE_NOW`
fixed.

1. **Keying:** `~/.claude.json` has an `accountUuid` → state is written to
   `…-5h-<uuid>` / `…-7d-<uuid>`; the unkeyed paths do not appear.
2. **Adoption:** pre-seed a legacy unkeyed state file (and `.samples.tsv`) →
   after the first render it is renamed to the keyed path; a second render leaves
   the keyed file in place and does not recreate the unkeyed one.
3. **Fallback:** `~/.claude.json` lacks `oauthAccount` → state is written to
   `…-5h-unknown`; any pre-existing legacy file is left untouched (no adoption
   into the `unknown` bucket).

## Non-goals

- No cleanup/garbage-collection of stale per-account files when an account is
  removed. Files are small; accumulation is negligible.
- No change to the EMA math, the lock protocol, or the sample-log pruning.
- No change to `.chezmoiignore` — only existing tracked files are edited; no new
  file classes are introduced.
