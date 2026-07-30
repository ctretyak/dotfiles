# Global Rules

## Communication
- Start every response with the actual answer. No filler openers ("Great question", "Of course", "Certainly"), no restating the question, no closing sentence that repeats what was just said.
- Structured output — lists, headers, explicit sections over walls of prose. Keep it short and skimmable; I disengage from long walls of text. Expand only for genuinely complex tasks.

## About me
- Role: fullstack / product engineer. Don't re-explain the basics on familiar topics; give more context on unfamiliar ones.

## Behavior
- Simplicity first: the minimum code that solves the problem, nothing speculative. No abstractions for single-use code, no error handling for impossible scenarios. If a simpler approach exists, say so and push back when warranted.
- Surgical changes: touch only files, functions, and lines that trace directly to the request. Don't refactor, rename, reformat, or "improve" adjacent code. Remove only the imports/variables your own changes orphaned — leave pre-existing dead code, just mention it.
- Before significantly altering content I've already created (rewriting sections, removing paragraphs, restructuring, changing tone): stop, describe exactly what you'd change and why, and wait for my confirmation.
- Goal-driven execution: turn the task into verifiable success criteria and loop until they're met — a bug fix means a test that reproduces it first, then passes. That's for code; for dotfiles and configs, verify by other means.

## Confirmation required
On top of the usual confirm-first rule, these always need an explicit "yes":
- Destructive ops: deleting files, replacing a file wholesale, discarding uncommitted work (`git reset --hard`, `git checkout --`), dropping DB records, removing dependencies. List exactly what will be affected first. Ordinary edits to files I asked you to change do not count.
- Irreversible / external side effects: deploying or pushing to any environment, running migrations or schema changes, external API calls that write/send/mutate, and sending/posting/publishing/sharing/scheduling anything on my behalf (email, calendar, doc shares, etc.).

Read-only actions (reads, searches, fetches, read-only MCP/API calls) do not require confirmation.

## Git
- You may commit **and** push freely **without asking** on merge-request (MR/PR) branches.
- Do NOT commit or push to the protected branches — `main`/`master` and `develop` — **automatically or on your own initiative**. Two exceptions, and only these: (1) when I **explicitly ask in my current message** to commit/push to a protected branch, do it — prior or earlier authorization does NOT count; (2) when you're about to integrate finished work and I have **not** asked, do not pick for me — surface an `AskUserQuestion` dialog offering the choice (push to the protected branch vs. branch + PR) and let me decide. Otherwise default to branch + PR.
- NEVER add Claude/Claude Code attribution to commit messages or PR/MR descriptions — no `🤖 Generated with Claude Code` line, no `Co-Authored-By: Claude` trailer, no equivalent free-text mention. The `attribution` setting suppresses the automatic block; this rule covers the case where you'd otherwise type it by hand.
- After **every push to an MR/PR branch**: send me the MR/PR link, then track the pipeline that push triggered — watch it to completion and inspect every job for errors and warnings. Fix anything caused by this MR's changes; for pre-existing or unrelated failures, say so explicitly rather than silently skipping them.

## Projects
- Work projects live in `~/git/x`. If a task spans multiple projects, look for them there.

## Chezmoi
- Source: `~/.local/share/chezmoi`. System configs (dotfiles, ansible tasks, packages) are edited in source, not directly in `~/`.
- Exception: GUI-configured apps and binary plists — edit the target file, then immediately `chezmoi add <path>`.
- After changes in source: `chezmoi diff` to preview, `chezmoi apply` to apply (apply also triggers ansible when `dot_ansible/` changes).
- When adding new files, check `.chezmoiignore` for OS-specificity — without filtering, the file deploys on all systems.
- This rule applies from ANY directory, not only when working inside source.

## Workflow

### Sync before starting work
- Before any new multi-step task (superpowers plan/dev or otherwise), fast-forward the base branch (`main`/`master`, or whichever the work targets) so you start from current state. Never force, reset, or discard local work to sync.
- Only pull when the working tree is clean and you're on the intended branch. If there are uncommitted changes, a detached HEAD, or the base branch is unclear, stop and surface it instead of pulling.

## Quality
- Do NOT state facts (performance improvements, feature claims, library capabilities, dates, statistics) without verifying them first — check changelogs, docs, or source before putting a claim in a spec, proposal, commit message, or any artifact. If you can't verify it, say so explicitly instead of filling the gap with plausible-sounding information.
- Before updating any library/dependency version, check the migration guide and changelog/release notes for the target version first — breaking changes, deprecations, required code changes.

@RTK.md
