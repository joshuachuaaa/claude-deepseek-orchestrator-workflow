---
name: engineering-orchestrator
disable-model-invocation: true
argument-hint: "[sol-codex | deepseek-opencode] <task>"
description: Plan, build, review and accept a substantial coding task with Opus 5.5 as the working session, Fable 5.2 as architect and final sign-off (subagents), and one of two interchangeable workers (sol-codex: GPT-6.2 Sol through the Codex CLI; deepseek-opencode: DeepSeek V4.1 Flash through OpenCode) for large machine-checkable implementation. Use for implementation work in a git repository that is a new feature, module or endpoint, a refactor across several files, or roughly 150+ lines of new code. Do not use for questions, explanations, reviews of existing code, config changes, or fixes whose cause is already known.
---

# Engineering orchestrator

## Roles

- **You (main session): Opus 5.5 at xhigh effort, the driver.** You explore, write
  the dossier and the acceptance tests, run the worker, review, verify, take over
  when the worker fails, and report. You never switch the main model during a task.
- **fable-architect (subagent, Fable 5.2, high effort).** Designs from your
  dossier. Writes plan.md, brief.md and holdback.md. Answers one consult when you
  are stuck.
- **fable-signoff (subagent, Fable 5.2, high effort).** Judges the finished,
  verified change against the plan.
- **Explore (built-in subagent, Haiku).** All repository searching.
- **test-runner (subagent, Haiku).** Runs `delegate verify` and returns a short
  result.
- **Worker: a model that `delegate` runs through its own CLI.** Types the code
  from a brief, in its own git worktree. You never talk to a worker: you write
  a file and run `delegate`. There are two, and they are interchangeable: the
  same brief, the same gate, the same commands.
  - `sol-codex`: GPT-6.2 Sol through the Codex CLI, at xhigh effort for every
    round. The default.
  - `deepseek-opencode`: DeepSeek V4.1 Flash through OpenCode, at max effort.

## Which worker

The user chooses the worker; you never do.

- If the request starts with `sol-codex` or `deepseek-opencode`, that word is
  the worker and the rest is the task. A worker named anywhere else in the
  request ("use deepseek-opencode for this") counts the same way.
- Otherwise the worker is the default: `sol-codex`, unless `ENG_ORCH_TYPIST`
  names the other.

Before triage, run `delegate check --typist <worker>` (plain `delegate check`
for the default). It prints the worker and stops if that worker's CLI, model
or sign-in is not ready. If it stops, tell the user what it said; do not switch
to the other worker yourself. Pass the same `--typist <worker>` to
`delegate start`. Later commands for the task (`fix`, `verify` and the rest)
take no such flag: the task remembers its worker.

Fable is never the main model and never the `/advisor`: both would make it read
the whole conversation. It only ever reads a dossier, a sign-off package or a
consult file, plus a few named files.

## The rule behind every step

The gate sets the quality, not the worker. A change is accepted only after it
passes checks at least as strong as the ones you would apply to your own work:
acceptance tests you wrote before any code existed, held-back checks the worker
never saw, your review of the real diff, and Fable's sign-off where the change
is risky. When the worker cannot get through the gate, you do the work yourself,
so the result is never worse than you working alone.

The worker can match you, not exceed you. Only the Fable steps can raise quality
above yours, so keep them for design and risk, and keep the worker for work a
machine can check.

## Step 0. Triage: four decisions

Make all four before doing anything else and state them in one line to the user,
for example: `Triage: design=fable, typist=worker (sol-codex), pieces=1, signoff=yes`.
Name the worker from "Which worker" above in that line.

**A. Is this a task for this skill at all?** No, do it directly without the skill,
if it is a question, explanation, review, config change, or a fix whose cause is
known, or if the change is under about 150 lines in one or two files with an
obvious design.

**B. Who designs?** Fable, if any one of these holds:
1. The request is ambiguous and the code cannot settle it.
2. It creates a new subsystem or changes boundaries between modules.
3. It touches a risky domain: auth or permissions, money, data migrations or
   schema changes, concurrency, security-sensitive code, public APIs.
4. You are not confident of the design after discovery.
Otherwise you design. If the repository root contains `.no-fable`, you design
regardless and say so.

**C. Who types?** The worker, if all of these hold:
1. Many similar edits across files, or enough new or changed code: roughly 200+
   lines for DeepSeek, roughly 100+ for Sol.
2. The design can be stated exactly. For DeepSeek that means names, signatures,
   contracts and the internal structure. For Sol the contracts must be exact
   (names, signatures, behaviour at the boundaries); the internals need not be
   designed in advance.
3. The result is machine-checkable: you can write acceptance tests for it before
   any code exists. For Sol those tests must run without the network: its
   sandbox has none.
4. The brief will be much shorter than the work it replaces. If specifying the
   change takes about as much as writing it, you type.
5. The repository is a git repository with at least one commit.
6. The repository root has no `.no-delegate`.
Otherwise you type.

**D. One piece or several?** (worker path only) If the work divides into pieces
that touch different files and do not need each other's results, make each piece
its own task, with its own name, brief and acceptance tests, and dispatch them
together. If two pieces would edit the same file, or one needs the other's
output, keep them as one task or as stages of one task.

**E (follows from B). Sign-off?** Yes if Fable designed, or if the change touches a
risky domain from B3. Otherwise no.

## Step 1. Discover

Use the Explore subagent for searching. Read yourself only the files you need to
understand the change: the modules it touches, their callers and interfaces, how
tests are written and run. Find the exact test command, and the lint and
type-check commands if the project has them. Run the tests once on HEAD (through
test-runner if the output is long) so you know the starting state.

If the request is ambiguous in a way the code cannot settle, ask the user now.

## Step 2. Prepare the task folder and dossier

    delegate prep <task-name>

Task names: lowercase letters, digits, dot, dash, underscore. The command prints
the task directory and creates `dossier.md` from the template. Fill in every
section. Point at files and line ranges instead of pasting code. Keep it under
about 3,000 words.

If you are designing (B = you), skip the dossier and go to Step 3b.

## Step 3a. Fable designs

Call the `fable-architect` subagent with this prompt and nothing else:

    Task directory: <absolute task dir>
    Read dossier.md there and follow your instructions.

Then:
- If it replies `QUESTIONS:`, ask the user those questions, add the answers to
  the dossier, and call it once more.
- Otherwise read plan.md, brief.md and holdback.md. Check that brief.md stands
  alone and matches plan.md. If something is wrong, tell the architect exactly
  what in one follow-up call; do not rewrite its design yourself.
- If plan.md sets the typist differently from your triage, follow plan.md and
  tell the user.

## Step 3b. You design

Write `brief.md` (same eight sections as the architect's brief: Goal, Behaviour,
Design, Conventions, Tests with exact command, numbered Acceptance criteria, Out of
scope, Stop conditions) and `holdback.md` (two to five checks the worker will not
see) in the task directory.

How much the Design section spells out depends on the worker. DeepSeek
implements the brief literally: give it the internal structure as well as the
contracts. Sol needs the contracts exact and the files to read first; leave the
internal structure to it and keep the brief short, because every line you write
for it costs more than the line it writes. For either worker, name every file
it needs to read. Discovery is your job, not the worker's.

## Step 3c. Write the acceptance tests first

Before any code is written, write the acceptance tests yourself: the cases the
plan lists when Fable designed, otherwise the brief's acceptance criteria turned
into tests. Each test must fail on the base commit and pass only when the
behaviour is right.

- **Worker types:** put the test files under `<task dir>/tests/`, each at its
  repository-relative path (for example `<task dir>/tests/backend/tests/test_x.py`).
  Name these paths in section 5 of brief.md and say there that they must pass
  unchanged. If the architect wrote the brief, check it names the same paths.
- **You type:** write them in the main checkout before the implementation.

The held-back checks stay in holdback.md. They are not acceptance tests and the
worker never sees them.

## Step 4. Implement

**Worker types:**

    delegate start <task> [--typist <worker>] --spec <dir>/brief.md --tests <dir>/tests --check '<acceptance test command>' [--plan <dir>/plan.md] [--signoff]

`--tests` commits the acceptance tests into the worktree before the worker
starts, and `delegate verify` refuses if they change afterwards. `--check` is
the self-check: one shell command that runs the acceptance tests (the command
from section 5 of the brief, limited to those test files so it is quick). When
the worker says it has finished, the script runs it in the worktree, and if it
fails or an acceptance test was changed, the script sends the output back into
the worker's own session once before the round ends. That is not a correction
round and costs you nothing; always pass it. Pass `--plan`
when Fable designed (this makes sign-off mandatory). Pass `--signoff` when you
designed but the change is risky. Run it with the Bash tool's
`run_in_background` and wait for it to finish; do not poll more than every few
minutes. The one exception: the script prints a line for following the round,
`resume  cd <worktree> && codex resume <id>` for Sol (at once) or
`resume  cd <worktree> && opencode -s <id>` for DeepSeek (once the session
starts, usually within a minute). Read the background output once, about a
minute after starting, and give that line to the user so they can follow the
round. The same line prints at the start of every `delegate fix` round. Both
windows attach to the running session, update live, and can stay open between
rounds. Tell the user to run the line exactly as printed (with a `-c` option,
Codex runs its own copy, which cannot follow the round), that typing there
reaches the worker, and that Esc stops the round. For Sol, `delegate watch
<task>` is a read-only alternative.

Sol's rounds run inside the Codex service, which is what makes the
`codex resume` line safe. If a round prints a `note` saying it runs as
`codex exec` (the service could not be reached), its line is
`watch  cd <worktree> && delegate watch <task>`: give that one, and do not
give `codex resume` for that task, because it would take the session over and
the next round would fail. Two stops mean nothing ran and the round was not
counted; run the same command again once the cause is gone:
- "the Codex session ... is open somewhere else": ask the user to close that
  window and wait a minute.
- "... is still working in session ...": a turn typed in a Codex window, or one
  left by a killed round, is still running. Wait for it, or ask the user to
  stop it with Esc.

Sol runs in Codex's sandbox: it can write only inside its worktree, its
commands have no network, and it cannot commit (the script commits what it
leaves). So the brief's test command must run offline: no package installs, no
calls to outside services.

For several pieces (decision D), start each as its own task in the background at
the same time, then take each through Steps 5 to 7 on its own.

For a staged plan, dispatch stage 1 only. Later stages go in as
`delegate fix <task> --feedback <that stage's brief> --stage`, each verified
before the next. `--stage` marks the round as new work, so it runs at the
worker's implementation effort, not its correction effort. Add
`--check '<command>'` when the stage has its own acceptance tests.

**You type:** implement in the main checkout following brief.md exactly, then
verify with the test command. If sign-off is required, write the package yourself
to `<dir>/signoff-package-1.md` with the same sections `delegate package` uses:
plan, held-back checks, what you ran and its result, the full `git diff`.

## Step 5. Review and verify (worker path)

Read the `self-check` line the round printed. `PASS` means the acceptance tests
pass on the committed work; it does not replace anything below. `STILL FAILING`
means the worker was already told once and could not fix it: do not run
`delegate verify`, read the self-check log and the diff, and go to Step 6.

1. Read the diff stat the round printed. Read in full the files the plan marks as
   risky and any file whose change you did not expect. For the rest, read enough
   to confirm names, signatures and contracts match the brief.
2. Read the tests the worker added. Do they assert behaviour? Was any existing
   test weakened, skipped or deleted?
3. Add the held-back checks: write them into the worktree, then
   `git -C <worktree> add -A && git -C <worktree> commit -m "held-back checks"`.
4. Verify through the `test-runner` subagent with this prompt:

       Directory: <repo root>
       Command: delegate verify <task> -- <gate command>

   The gate command runs the acceptance tests, the held-back tests, and the
   existing suite where practical so regressions show. Where the project has
   lint or type checks, chain them in: `sh -c '<lint> && <type-check> && <tests>'`.
5. Check each acceptance criterion: passed, failed, or could not check.

If `delegate verify` reports that the acceptance tests changed, the worker
altered them and the round failed. If an acceptance test was itself wrong and you
corrected it, re-run with `--allow-test-changes` and say so in the report.

The worker's report is a claim. Where it and the evidence disagree, the evidence
wins and the disagreement goes in your final report.

## Step 6. Correct, then take over

The worker gets one correction per stage. After that you do the work.

1. **One correction round.** Write feedback to `<dir>/feedback-<n>.md`: file and
   line, what is wrong, the failing command and its output, what correct looks
   like. Then:

       delegate fix <task> --feedback <dir>/feedback-<n>.md

   Review and verify again from Step 5. With Sol the script runs this round at
   xhigh effort by itself. The self-check's automatic retry inside a round does
   not use up this correction.
2. **Take over.** If the gate or your review still fails after that round, do not
   send a third. Record it and finish the task yourself:

       delegate takeover <task> --reason "<what the worker could not do>"

   Edit and commit in the task's worktree, then verify as in Step 5. The script
   refuses further worker rounds on this task, including later stages.
3. **Consult Fable once, if you are stuck.** If two attempts of your own still
   fail the gate, or the design itself looks wrong, write `<dir>/consult-1.md`:
   the problem, what was tried, the failing command and its output, the files
   involved (up to 5), and one question. Call `fable-architect` with this prompt
   and nothing else:

       Consult: <dir>/consult-1.md

   Act on its answer in `<dir>/consult-1-answer.md`. If the repository has
   `.no-fable`, skip this and go to the next point.
4. **Report the blocker.** If the task is still failing after the consult, stop
   and tell the user what blocks it, with the evidence.

You may make a purely mechanical touch-up yourself without taking over (a merge
conflict, a typo) and must say so in the report. The script stops at 6 worker
rounds as a backstop for staged plans.

## Step 7. Sign-off (when required)

After a passing verification on the current commit:

    delegate package <task>

Call `fable-signoff` with this prompt and nothing else:

    Package: <path printed by delegate package>
    Write your verdict to: <dir>/signoff-response-<n>.md

Then record it:

    delegate signoff <task> --verdict ACCEPT|CHANGES --file <dir>/signoff-response-<n>.md

- ACCEPT: go to Step 8.
- CHANGES: fix each blocker and should-fix finding (through the worker's one
  correction if it is unused, otherwise yourself, as in Step 6), verify, package
  and sign off again. After two CHANGES verdicts, stop and report to the user
  with both verdict files.
- Do not argue with a finding inside the same call. If you believe a finding is
  wrong, say why in your report to the user and let them decide.

## Step 8. Integrate

    delegate integrate <task>

It squash-merges into the main checkout as staged, uncommitted changes, and
refuses unless the latest verification passed on the exact commit and, where
required, the latest sign-off is ACCEPT for that commit. If it warns that the main
checkout moved, re-run the tests in the main checkout.

With several pieces, integrate them one after another, then run the whole gate
once in the main checkout, because each piece was verified without the others.

Commit only if the user asked for commits. Then `delegate cleanup <task>`.

## Step 9. Report

Lead with the decision: accepted, accepted with noted risks, or not accepted and
why. Then: triage line; what changed (from the diff); design decisions and allowed
deviations; commands run and real results, including failures along the way;
which worker typed it; whether a self-check failed and whether the worker
recovered; whether the first verification passed, the number of worker rounds,
and whether you took the task over and why; the sign-off verdict and its findings; remaining
risks and anything you could not verify.

`delegate stats` keeps these numbers across tasks: the share of tasks that passed
their first verification, the share you took over, how often sign-off returned
CHANGES, and the tokens each seat read and wrote. Its `by typist` lines give
the first-pass rate, takeovers, self-check recoveries, and the cost OpenCode
reports or the tokens Codex reports, for each worker. They show whether the worker is paying for itself.

After reporting, tell the user to run `/clear` before the next unrelated task.
The token count for a task starts at the session's start, so a fresh session per
task keeps the numbers clean.

## Stop conditions

- **Not a git repository:** do not run `git init` without asking. Type it yourself.
- **`.no-delegate`:** no worker. You type.
- **`.no-fable`:** no Fable subagents. You design, sign-off and the consult are
  skipped; say so.
- **Worker unreachable** (`delegate check` fails, provider down, model mismatch):
  stop and tell the user. Never substitute another worker model, and do not
  quietly implement the task yourself in its place. This is different from
  Step 6: a takeover follows a worker that ran and failed the gate, and is
  recorded.
- **Fable unavailable** (usage limit, error, or a model fallback reported): stop
  and ask the user whether to continue with you designing. Do not substitute
  silently.
- **Isolation breach reported by `delegate`:** stop everything, inspect the main
  checkout, tell the user.

## Cost rules

- Never change the main session's model or effort during a task.
- Fable calls per task: one architect call (plus one for answered questions or a
  correction), one sign-off per verification that needs it, and at most one
  consult. Nothing else.
- Searching goes through Explore; verification output through test-runner.
- Do not paste large files or diffs into your own messages; point at paths.
- Pass work between models as files in the task directory, never as conversation.

## Commands

    delegate check [--typist sol-codex|deepseek-opencode]   preflight: which worker, its CLI, model, sandbox or agent, sign-in
    delegate takeover <task> --reason "..."   you take the task over from the worker
    delegate watch <task>          follow a Sol round live, read-only (for the user's terminal)
    delegate status [<task>]       rounds, verification, sign-off, session
    delegate stats                 every task so far: rounds, first-pass rate, takeovers, CHANGES rate, tokens by seat
    delegate cleanup <task> --force    discard an unintegrated task (ask the user first)
