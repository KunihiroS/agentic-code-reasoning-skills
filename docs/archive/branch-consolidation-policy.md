# Branch consolidation policy for agentic-code-reasoning-skills

## Goal

Before changing Git state, define a safe branch cleanup and release policy for the repository. The working assumption is:

- `iter-46` is the current best `SKILL.md` and should become the release target.
- Existing auto-improve branches are mostly historical / non-functional work branches.
- The repository should be simplified so `main` again represents the stable released skill.

## Current observed branch state

Checked from `/Users/kunihiros/dev/agentic-code-reasoning-skills` after `git fetch --all --prune`.

Remote/default:

- `origin/HEAD -> origin/main`
- `origin/main`: `1c7d7f9c docs: publish benchmark-progression.md and update README with iter-5 results`

Active/historical branches:

- `origin/script/auto-improve`: `1de21a43 Add analysis and output for patch equivalence testing in Django`
- `origin/meta-agent/auto-improve`: `f1bd1135 docs: add branch summary (section 18) - meta-agent/auto-improve final retrospective`
- `origin/meta-agent-2/auto-improve`: `534c48aa final: iter-46 SKILL.md confirmed — Compare +10.0pp (5-run avg)`
- `origin/meta-agent-3/auto-improve`: `6504b92f chore: persist auto-improve iter-64-68 archive updates`

Lineage facts:

- All auto-improve branches descend from `origin/main`.
- `meta-agent-2/auto-improve` descends from `meta-agent/auto-improve`.
- `meta-agent-3/auto-improve` descends from `meta-agent-2/auto-improve`.
- `origin/meta-agent-3/auto-improve` is 28 commits ahead of `origin/meta-agent-2/auto-improve`, with no commits missing from meta-agent-2.
- `origin/meta-agent-2/auto-improve:SKILL.md` hash equals both:
  - `origin/meta-agent-2/auto-improve:benchmark/swebench/runs/iter-46/SKILL.md.snapshot`
  - `origin/meta-agent-3/auto-improve:benchmark/swebench/runs/iter-46/SKILL.md.snapshot`
- `origin/meta-agent-3/auto-improve:SKILL.md` differs from iter-46 and is not the best known release candidate.

## Recommended policy

### 1. Treat `meta-agent-2/auto-improve` as the release source of truth

Reason:

- It is explicitly finalized at `534c48aa` as iter-46.
- Its top-level `SKILL.md` is byte-identical to the iter-46 snapshot.
- It avoids later meta-agent-3 changes that did not improve over iter-46.

Release candidate:

- Commit: `534c48aa`
- Branch: `origin/meta-agent-2/auto-improve`
- Skill file: `SKILL.md`
- Benchmark interpretation: current best known, Compare +10.0pp / 5-run avg per commit subject and previous inspection.

### 2. Do not merge `meta-agent-3/auto-improve` into `main` as-is

Reason:

- It includes the iter-46 snapshot in history, but top-level `SKILL.md` has moved away from iter-46.
- The latest 20 iterations did not beat iter-46.
- Merging meta-agent-3 HEAD would publish a later, less-proven `SKILL.md` unless manually reverted or cherry-picked.

If any meta-agent-3 artifacts are worth keeping, they should be selectively cherry-picked or copied after review, not merged wholesale as release content.

Potentially keep from meta-agent-3:

- `docs/history/meta-agent-1.md`
- `docs/history/meta-agent-2.md`
- final archive/log evidence, if the repo intentionally stores full run evidence.

Potentially avoid from meta-agent-3:

- Top-level `SKILL.md` changes after iter-46.
- Any failed direction embedded in `failed-approaches.md` / `SKILL.md` that conflicts with the iter-46 release stance.
- Large run logs unless the repository policy is to retain them.

### 3. Consolidate `main` through a controlled release PR/merge

Recommended route:

1. Create a temporary release branch from `origin/main`, e.g. `release/iter-46-skill`.
2. Bring in the desired release contents from `origin/meta-agent-2/auto-improve`.
3. Keep history either by:
   - normal merge from `meta-agent-2/auto-improve`, if preserving all experimental history on main is acceptable; or
   - squash/cherry-pick curated files, if `main` should remain clean and readable.

Preferred for this repo:

- Use a curated merge/cherry-pick approach rather than merging all branch history blindly.
- Rationale: the branch contains many generated benchmark artifacts and auto-improve iterations. `main` should communicate the released skill and reproducibility evidence, not every failed worktree artifact.

Minimum files likely required for release:

- `SKILL.md` from iter-46 / `meta-agent-2` HEAD.
- `README.md` release summary updates, if accurate and not stale.
- `failed-approaches.md`, if it reflects lessons that protect future iterations.
- Benchmark scripts required to reproduce current claims, if stable.
- Compact benchmark evidence under docs, not necessarily all raw `benchmark/swebench/runs/*` logs.

Files requiring explicit decision:

- `benchmark/swebench/runs/archive.jsonl`
- `benchmark/swebench/runs/auto-improve-*.log`
- `benchmark/swebench/runs/iter-*` directories
- `SKILL.md.full`
- generated prompt / benchmark data artifacts

### 4. Tag before deleting or hiding branches

Before deleting remote branches, preserve recoverability with tags.

Suggested archival tags:

- `archive/script-auto-improve-final` -> `origin/script/auto-improve`
- `archive/meta-agent-1-final` -> `origin/meta-agent/auto-improve`
- `release/iter-46-skill` or `v1.1.0-iter46` -> `534c48aa`
- `archive/meta-agent-3-final` -> `6504b92f`

After tags exist and are pushed, remote branches can be deleted safely if desired.

Suggested delete candidates after release:

- `script/auto-improve`
- `meta-agent/auto-improve`
- `meta-agent-2/auto-improve`
- `meta-agent-3/auto-improve`

But do not delete `meta-agent-2/auto-improve` until `main` contains the iter-46 release and the release tag exists.

### 5. Define branch roles after cleanup

Recommended long-term branch model:

- `main`: stable released skill only.
- `experiment/<short-topic>`: short-lived branches for future auto-improve attempts.
- `archive/*` tags: immutable record of old experimental branch heads.
- Optional: `meta-agent/latest` only if there is an active long-running automation branch; otherwise avoid permanent auto-improve branches.

### 6. Update repository policy to prevent recurrence

Add a short branch / artifact policy to docs, e.g. `CONTRIBUTING.md` or `docs/release-policy.md`:

- `main` is stable release.
- Auto-improve runs must happen on experiment branches.
- Release candidate must be identified by commit and benchmark evidence.
- Failed / superseded branches get archived with tags then deleted.
- Large logs are not committed unless explicitly needed; archive summaries are preferred.
- `archive.jsonl` handling must be explicit: either committed as reproducibility evidence or exported separately.

## Concrete execution plan, when approved

No execution should happen until the user approves the policy.

### Phase A: safety snapshot

1. Ensure local and VM repos are clean.
2. Fetch/prune all remotes.
3. Create and push archive tags for current branch heads.
4. Confirm tags resolve to expected commits.

### Phase B: prepare release branch

1. Checkout `main`.
2. Create `release/iter-46-skill` from `origin/main`.
3. Apply curated content from `origin/meta-agent-2/auto-improve`.
4. Ensure top-level `SKILL.md` hash equals iter-46 snapshot hash: `563fb8cf1ab6177defa893d06c50f928d1750006c187d3d993e6d7a5f6783225`.
5. Update README/docs to state iter-46 is the released skill.
6. Avoid publishing top-level `SKILL.md` from meta-agent-3 HEAD.

### Phase C: validate release branch

Run at least:

- `python3 -m compileall -q scripts benchmark/swebench`
- `bash -n auto-improve.sh scripts/*.sh benchmark/swebench/*.sh`
- Benchmark selection sanity check: best parent should still identify iter-46 if archive is included.
- Optional: run the compare benchmark subset used to justify iter-46, if cost/time acceptable.

### Phase D: merge to main

1. Review final diff from `origin/main`.
2. Merge/squash PR into `main` or fast-forward local main then push, depending on repository convention.
3. Tag the release commit, e.g. `v1.1.0-iter46`.
4. Push `main` and tag.

### Phase E: branch cleanup

1. Confirm `main` includes iter-46 release.
2. Confirm archive tags exist on remote.
3. Delete remote experimental branches.
4. Delete local obsolete tracking branches with prune.
5. Update VM checkout to `main` or the new release branch, depending on future workflow.

## Risks and tradeoffs

### Normal merge from meta-agent-2

Pros:

- Preserves all experimental history.
- Simple to reason about lineage.
- No risk of accidentally omitting benchmark scripts used by the branch.

Cons:

- Pollutes `main` with a large number of generated artifacts and failed iterations.
- Makes stable release history harder to read.

### Curated cherry-pick / squash

Pros:

- Clean `main`.
- Easier future maintenance.
- Forces explicit decision about what evidence belongs in the release.

Cons:

- Requires careful file selection.
- Raw provenance remains only in archive tags/branches, not in main history.

Recommended tradeoff:

- Use curated release content on `main` plus archive tags for full provenance.

## Open questions

1. Should `main` include raw run artifacts, or only summarized benchmark evidence?
2. Should release version be `v1.1.0-iter46`, `v2.0.0`, or another naming scheme?
3. Should obsolete remote branches be deleted immediately after release, or kept for a short grace period after tagging?
4. Should future auto-improve runs commit `archive.jsonl` and logs, or export them outside the main repository?
