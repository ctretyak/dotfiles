# Per-account EMA state Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Key the status-line EMA state files by `accountUuid` so switching Claude accounts can no longer pollute another account's rate-limit forecast.

**Architecture:** Resolve the active account from `~/.claude.json` (`.oauthAccount.accountUuid`) once per render and thread it into `fmt_rate_limit`, which appends it to the state-file path. A one-time adoption step renames the pre-keying unkeyed files into the current account's keyed path so existing EMA warmup survives. An `unknown` fallback keeps the forecast rendering when the UUID can't be read.

**Tech Stack:** Bash, `jq`, `awk`; POSIX-ish shell in `private_dot_claude/statusline-command.sh`; test harness `tests/statusline-command.test.sh` (temp `HOME`, injected clock).

## Global Constraints

- Only `private_dot_claude/statusline-command.sh` and `tests/statusline-command.test.sh` are edited. `statusline-ema.sh` (pure `ema_project`) and the lock helpers are NOT touched.
- Account identity is `.oauthAccount.accountUuid` from `${HOME}/.claude.json`. No PII (email) in filenames.
- Fallback key when the UUID can't be read: the literal string `unknown`.
- Adoption of legacy unkeyed files runs only when `account_key != "unknown"`, only when the keyed file is absent and the legacy file exists, and inside the existing advisory lock.
- All state files live under `${HOME}/.claude/`. `~/.claude.json` is at `${HOME}/.claude.json` (HOME root, NOT inside `.claude/`).
- Tests never render against the real `~/.claude`; each uses `mktemp -d` as HOME and a fixed `STATUSLINE_NOW`.

---

### Task 1: Key EMA state paths by account, with `unknown` fallback

**Files:**
- Modify: `private_dot_claude/statusline-command.sh` (add account resolution in main body ~before the two `fmt_rate_limit` calls; add `account_key` param + keyed-path derivation in `fmt_rate_limit`)
- Test: `tests/statusline-command.test.sh` (update the two EMA cases to seed keyed paths + fake `~/.claude.json`; add keying + fallback cases)

**Interfaces:**
- Consumes: existing `fmt_rate_limit used_pct resets_at window_sec label state_file halflife min_elapsed` (7 args).
- Produces: `fmt_rate_limit` gains an 8th arg `account_key`. Inside, the effective state path becomes `${state_file}-${account_key}`; all derived paths (`.samples.tsv`, `.lock`, `.tmp.$$`) follow from it. Main body defines `account_key` (a `[A-Za-z0-9_-]`-only string, or `unknown`).

- [ ] **Step 1: Write the failing tests**

Add two new cases at the end of `tests/statusline-command.test.sh`, before `exit "$fail"`:

```bash
# --- State file is keyed by accountUuid; unkeyed path is not written ---
tmp4=$(mktemp -d); mkdir -p "${tmp4}/.claude"
printf '{"oauthAccount":{"accountUuid":"acctA"}}\n' > "${tmp4}/.claude.json"
NOW4=1000000000; RST4=$((NOW4+9000))
JSON4='{"model":{"display_name":"Test"},"context_window":{"used_percentage":40},"workspace":{"current_dir":"'"${tmp4}"'"},"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":'"$RST4"'}}}'
STATUSLINE_NOW=$NOW4 HOME="$tmp4" bash "$SCRIPT" <<<"$JSON4" >/dev/null
if [ -f "${tmp4}/.claude/.statusline-ema-5h-acctA" ] && [ ! -f "${tmp4}/.claude/.statusline-ema-5h" ]; then
  echo "PASS state-keyed-by-account"
else
  echo "FAIL state-keyed-by-account"; ls "${tmp4}/.claude/"; fail=1
fi
rm -rf "$tmp4"

# --- No oauthAccount -> shared 'unknown' bucket, legacy file left untouched ---
tmp5=$(mktemp -d); mkdir -p "${tmp5}/.claude"
printf '{}\n' > "${tmp5}/.claude.json"
NOW5=1000000000; RST5b=$((NOW5+9000))
printf 'legacy\n' > "${tmp5}/.claude/.statusline-ema-5h"   # sentinel legacy file
JSON5='{"model":{"display_name":"Test"},"context_window":{"used_percentage":40},"workspace":{"current_dir":"'"${tmp5}"'"},"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":'"$RST5b"'}}}'
STATUSLINE_NOW=$NOW5 HOME="$tmp5" bash "$SCRIPT" <<<"$JSON5" >/dev/null
if [ -f "${tmp5}/.claude/.statusline-ema-5h-unknown" ] \
   && [ "$(cat "${tmp5}/.claude/.statusline-ema-5h")" = "legacy" ]; then
  echo "PASS fallback-unknown-bucket"
else
  echo "FAIL fallback-unknown-bucket"; ls "${tmp5}/.claude/"; fail=1
fi
rm -rf "$tmp5"
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `bash tests/statusline-command.test.sh`
Expected: `FAIL state-keyed-by-account` (current code writes the unkeyed `.statusline-ema-5h`), and `FAIL fallback-unknown-bucket` (no `-unknown` file is produced). The pre-existing PASS lines still pass.

- [ ] **Step 3: Add account resolution in the main body**

In `private_dot_claude/statusline-command.sh`, after the four rate-limit `jq` extractions (the block ending with `rl_7d_reset=$(...)`) and before the `rl_5h_fmt=$(fmt_rate_limit ...)` call, insert:

```sh
# Resolve the active account so each account keeps its own EMA state; switching
# accounts can't pollute another's forecast. Fall back to a shared bucket if the
# UUID can't be read (logged out / partial write) so the forecast still renders.
account_key=$(jq -r '.oauthAccount.accountUuid // empty' "${HOME}/.claude.json" 2>/dev/null \
  | tr -cd 'A-Za-z0-9_-')
[ -z "$account_key" ] && account_key="unknown"
```

- [ ] **Step 4: Pass `account_key` into both `fmt_rate_limit` calls**

Change the two calls to append `"$account_key"` as the 8th argument:

```sh
rl_5h_fmt=$(fmt_rate_limit "$rl_5h" "$rl_5h_reset" 18000 "5h" \
  "${HOME}/.claude/.statusline-ema-5h" "$EMA_HL_5H" "$EMA_MINEL_5H" "$account_key")
rl_7d_fmt=$(fmt_rate_limit "$rl_7d" "$rl_7d_reset" 604800 "7d" \
  "${HOME}/.claude/.statusline-ema-7d" "$EMA_HL_7D" "$EMA_MINEL_7D" "$account_key")
```

- [ ] **Step 5: Accept the param and derive the keyed path in `fmt_rate_limit`**

Extend the local-args line:

```sh
  local state_file="$5" halflife="$6" min_elapsed="$7" account_key="$8"
```

Then, immediately before the existing lock block (`local lock="${state_file}.lock" locked=0`), insert the keying (no adoption yet — that is Task 2):

```sh
  # Key the EMA state by account so switching accounts can't cross-contaminate.
  # All derived paths (.samples.tsv/.lock/.tmp) follow because they hang off
  # state_file, which we reassign to the keyed path here.
  state_file="${state_file}-${account_key}"
```

- [ ] **Step 6: Run the full suite to verify green**

Run: `bash tests/statusline-command.test.sh`
Expected: `PASS state-keyed-by-account`, `PASS fallback-unknown-bucket`, and — after Step 7 — the two updated legacy cases pass. (Before Step 7 the `render-5h-token`, `no-double-percent-fallback`, and `samples-prune-old` cases FAIL, because they still seed the unkeyed path with no `~/.claude.json`.)

- [ ] **Step 7: Update the two existing EMA cases to seed keyed paths**

The render case (first block, `tmp`): after `mkdir -p "${tmp}/.claude"` add a fake account file, and change the seed path to the keyed name:

```bash
printf '{"oauthAccount":{"accountUuid":"acctA"}}\n' > "${tmp}/.claude.json"
```
and change
```bash
printf '%s %s %s %s\n' "$((NOW-100))" 10 0.02 "$RST5" > "${tmp}/.claude/.statusline-ema-5h"
```
to
```bash
printf '%s %s %s %s\n' "$((NOW-100))" 10 0.02 "$RST5" > "${tmp}/.claude/.statusline-ema-5h-acctA"
```

The pruning case (`tmp2`): after `mkdir -p "${tmp2}/.claude"` add:
```bash
printf '{"oauthAccount":{"accountUuid":"acctA"}}\n' > "${tmp2}/.claude.json"
```
and change both the seed and log paths from `.statusline-ema-5h` to `.statusline-ema-5h-acctA`:
```bash
printf '%s %s %s %s\n' "$((NOW2-100))" 10 0.001 "$RST2" > "${tmp2}/.claude/.statusline-ema-5h-acctA"
log2="${tmp2}/.claude/.statusline-ema-5h-acctA.samples.tsv"
```

- [ ] **Step 8: Run the full suite to verify all green**

Run: `bash tests/statusline-command.test.sh`
Expected: all cases PASS (`render-5h-token`, `no-double-percent-fallback`, `samples-prune-old`, `effort-from-stdin-xhigh`, `state-keyed-by-account`, `fallback-unknown-bucket`). Exit code 0.

- [ ] **Step 9: Commit**

```bash
git add private_dot_claude/statusline-command.sh tests/statusline-command.test.sh
git commit -m "feat(statusline): key EMA state by accountUuid"
```

---

### Task 2: Adopt pre-keying unkeyed state for the active account

**Files:**
- Modify: `private_dot_claude/statusline-command.sh` (add adoption block inside `fmt_rate_limit`, under the lock)
- Test: `tests/statusline-command.test.sh` (add adoption case)

**Interfaces:**
- Consumes: `account_key`, keyed `state_file` from Task 1.
- Produces: on first render where the keyed file is absent but the legacy unkeyed file exists (and `account_key != "unknown"`), the legacy state file and its `.samples.tsv` are renamed to the keyed path. Idempotent; runs under the lock.

- [ ] **Step 1: Write the failing test**

Add at the end of `tests/statusline-command.test.sh`, before `exit "$fail"`:

```bash
# --- Legacy unkeyed state is adopted once into the current account's keyed path ---
tmp6=$(mktemp -d); mkdir -p "${tmp6}/.claude"
printf '{"oauthAccount":{"accountUuid":"acctA"}}\n' > "${tmp6}/.claude.json"
NOW6=1000000000; RST6=$((NOW6+9000))
# Seed ONLY the legacy unkeyed files (state + samples); no keyed file yet.
printf '%s %s %s %s\n' "$((NOW6-100))" 10 0.02 "$RST6" > "${tmp6}/.claude/.statusline-ema-5h"
printf '%s\t10\t%s\t0\t18\t18\tFLAT\t0\n' "$((NOW6-100))" "$RST6" > "${tmp6}/.claude/.statusline-ema-5h.samples.tsv"
JSON6='{"model":{"display_name":"Test"},"context_window":{"used_percentage":40},"workspace":{"current_dir":"'"${tmp6}"'"},"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":'"$RST6"'}}}'
out6=$(STATUSLINE_NOW=$NOW6 HOME="$tmp6" bash "$SCRIPT" <<<"$JSON6")
plain6=$(printf '%s' "$out6" | sed 's/\x1b\[[0-9;]*m//g')
# Adopted warmup must yield the same EMA token as a directly-seeded keyed file.
if [ -f "${tmp6}/.claude/.statusline-ema-5h-acctA" ] \
   && [ ! -f "${tmp6}/.claude/.statusline-ema-5h" ] \
   && [ -f "${tmp6}/.claude/.statusline-ema-5h-acctA.samples.tsv" ] \
   && printf '%s' "$plain6" | grep -q '12%→24↗192'; then
  echo "PASS adopts-legacy-unkeyed"
else
  echo "FAIL adopts-legacy-unkeyed"; echo "  plain: $plain6"; ls "${tmp6}/.claude/"; fail=1
fi
rm -rf "$tmp6"
```

- [ ] **Step 2: Run the new test to verify it fails**

Run: `bash tests/statusline-command.test.sh`
Expected: `FAIL adopts-legacy-unkeyed`. With Task 1 only, the legacy file is ignored (cold start → no `12%→24↗192` token) and the unkeyed file is left in place (`[ ! -f …-5h ]` fails).

- [ ] **Step 3: Add the adoption block under the lock**

In `fmt_rate_limit`, the keying line from Task 1 currently reads:

```sh
  state_file="${state_file}-${account_key}"
```

Replace it with a legacy-capturing version, and add the adoption block immediately after `acquire_lock "$lock" "$now" && locked=1`:

Change the keying line to:
```sh
  # Key the EMA state by account so switching accounts can't cross-contaminate.
  local legacy="$state_file"
  state_file="${state_file}-${account_key}"
```

Then, right after the `acquire_lock ... && locked=1` line, insert:
```sh
  # One-time adoption: inherit pre-keying warmup for the real active account.
  # Guarded so the degraded 'unknown' bucket never steals a real account's state.
  if [ "$account_key" != "unknown" ] && [ ! -f "$state_file" ] && [ -f "$legacy" ]; then
    mv -f "$legacy" "$state_file"
    [ -f "${legacy}.samples.tsv" ] && mv -f "${legacy}.samples.tsv" "${state_file}.samples.tsv"
  fi
```

- [ ] **Step 4: Run the full suite to verify green**

Run: `bash tests/statusline-command.test.sh`
Expected: all cases PASS, including `adopts-legacy-unkeyed` and the still-green `fallback-unknown-bucket` (its legacy sentinel stays untouched because `account_key == "unknown"`). Exit code 0.

- [ ] **Step 5: Commit**

```bash
git add private_dot_claude/statusline-command.sh tests/statusline-command.test.sh
git commit -m "feat(statusline): adopt pre-keying EMA state for active account"
```

---

### Task 3: Deploy via chezmoi

**Files:** none (applies the committed source to `~`).

- [ ] **Step 1: Preview the diff**

Run: `chezmoi diff`
Expected: shows the changes to `~/.claude/statusline-command.sh` matching the committed source.

- [ ] **Step 2: Apply**

Run: `chezmoi apply`
Expected: no errors; `~/.claude/statusline-command.sh` now contains the account-keying logic.

- [ ] **Step 3: Smoke-test the live status line**

Verify the current account adopts its existing state (the live unkeyed `~/.claude/.statusline-ema-5h` should get renamed to the keyed path on the next render). Run:
```bash
jq -r '.oauthAccount.accountUuid' ~/.claude.json
ls -la ~/.claude/.statusline-ema-*
```
Expected: after the status line renders at least once (open/refresh a Claude Code session, or pipe a sample payload through `~/.claude/statusline-command.sh`), files named `.statusline-ema-5h-<uuid>` and `.statusline-ema-7d-<uuid>` exist, and the old unkeyed `.statusline-ema-5h` / `-7d` are gone (adopted).

---

## Self-Review

**Spec coverage:**
- Identity = accountUuid → Task 1 Step 3. ✓
- Keyed state paths (all derived files follow) → Task 1 Steps 5. ✓
- `unknown` fallback → Task 1 Step 3 + `fallback-unknown-bucket` test. ✓
- Adoption for current account, guarded, under lock → Task 2. ✓
- Tests: keying, adoption, fallback (temp HOME) → Tasks 1–2. ✓
- Untouched `ema_project` / lock helpers → respected (only `fmt_rate_limit` body + main body edited). ✓
- Non-goal (no GC of stale files) → not implemented, correct. ✓

**Placeholder scan:** none — every code and test block is complete.

**Type/name consistency:** `account_key` (main body → 8th arg → `fmt_rate_limit` local), `state_file` reassigned to keyed path, `legacy` captured before reassignment, test UUID `acctA` used consistently across seed paths and assertions.
