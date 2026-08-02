# HANDOFF — Sections 5 (completion), 6 (insertion), 7 and 8

For a fresh drafting session. Read this before writing anything.

## 1. Roles

Simon orchestrates and decides. You draft the manuscript, manage the ledger and
the replication package, and write prompts for a separate coding agent that
executes on the Festus cluster. **No further compute is planned.** Everything
remaining is writing and bookkeeping. If you find yourself drafting a compute
task, stop and check with Simon first — the empirical work is finished, and four
consecutive rounds were spent on a question the paper turned out not to need.

## 2. Repository and how to edit it

`SimonBloethner/heterogeneity-rta-effects`, branch `main`.

- **`meta/canonical_facts.md` is the SOLE AUTHORITY** for every number. Where it
  disagrees with anything in `output/`, the ledger governs. Read it first; it is
  long, and the binding prose notes matter as much as the values.
- Every quantitative claim in the article carries a `% [ID]` comment naming its
  ledger ID. A number without one is a defect.
- `meta/SUPERSEDED.md` holds INV-010 to INV-026 and the CAV series;
  `meta/canonical_facts.md` holds INV-027 onward. Neither file is complete alone.

**Editing `article/main.tex`:** it is roughly 130,000 characters, and the GitHub
connector has no partial-edit operation — a push must carry the whole file, which
exceeds what you can emit. Do not attempt it. Instead give Simon exact
anchor-based instructions: a verbatim block to find and a verbatim block to
replace it with. Verify each anchor occurs exactly once in the current file
before handing it over, and check environment balance and dangling references on
your locally built version first. Smaller files — the ledger, registry, sidecars
— you push directly. For very large appends to the ledger, prefer giving Simon a
tested `cat >> ` command over retyping the file.

Always verify a push by re-reading from origin at the pushed SHA and diffing
against what you intended.

## 3. Where the paper stands

Sections 1 to 5 drafted and in `main.tex`. Appendix corrected. Section 6 drafted
but **not inserted**. Sections 7 and 8 unwritten.

Outstanding before submission:

1. **Section 5** — a literature comparison is marked `[NEEDED]` and never written.
2. **Section 6** — insert, with its close rewritten (see §5) and its
   identification-ledger table typeset.
3. **Section 7** — the policy reading. Section 6 hands it forward explicitly: the
   estimand is defined over self-selected matches, and that conditioning is the
   constraint any policy reading must respect.
4. **Section 8** — the coda. Pairs the equivalence theorem with the reliability
   paradox: the diagnostics that could be computed were confidently wrong, the
   quantities that mattered most are beyond computation under the model's own
   assumptions.
5. **Compile blockers** — `\ref{sec:conclusion}` and `\ref{sec:robustness}` are
   referenced and undefined; three `[X-REF:]` placeholders remain because
   `app:tables` is empty. Resolve or remove.

## 4. Numbers that were corrected. Do not reinstate the originals.

Each of these was wrong in the repository at some point and is now right. If you
see the old value anywhere, it is stale.

| Quantity | Correct | Stale, do not use |
|---|---|---|
| Higher-moment separation, identification z | 2.96 to 11.44 | 59 to 229 (Monte Carlo precision, INV-040) |
| Predicted reliability | 0.7539 vs 0.7463 observed | 0.81 vs 0.75 (Arm-0 plug-in) |
| Mean theta_D | 0.2473 (SE 0.0241) | 0.2138 (retired pack) |
| SD(theta_D) observed | 1.5614 | 0.5950 (retired pack) |
| Split-half r, treated | 0.9243 | 0.9720 |
| SD_true identified set | [0.74, 1.48] | [0.95, 1.48] |

Anything under `archive/` is uncitable, including
`archive/retired_pack/output/A5_proposition_verification.csv`, which some older
drafting specifications reference as an `[A5:row]` citation convention. That
convention names a retired file. The live proposition table is
`output/T25_prop_verification.csv`, cited as `% [T25: ID]`.

## 5. Section 6, and the one thing that must change in it

A full draft exists from the prior session (four subsections plus close, roughly
1,500 words, with a caption and row contents for a four-row identification-ledger
exhibit and a coda feed for Section 8). Simon has it. Ask for it rather than
redrafting from scratch.

**Its close is now wrong.** It ends: "the quantities that mattered most are
provably beyond computation." Two results since changed that.

- The equivalence of Proposition 3(b) is exact **under normality** and silent
  outside it. The appendix's old claim that the non-normal route was impassable
  has been retracted; see Remark~\ref{rem:moments}, now in `main.tex`.
- Normality is **rejected** in these data: 32.8 percent of pairs against a
  matched-control 5.0 percent, with net excess kurtosis near 1.05 — inside the
  simulated grid where separation runs 2.96 to 11.44 under cross-pair
  independence.

So the boundary is a **measured conditional**, not a wall: exactly unidentified
under normality; outside it, recoverable at this sample under cross-pair
independence and treatment-invariant shock shape; status without those two
conditions unestablished. Cross-pair dependence has never been estimated here.
Section 6 must say that, and it is a more interesting section for it. The
reported interval is unaffected either way, since it concerns the persistent
component Proposition 3(a) identifies.

## 6. Binding prose constraints from the ledger

These are not style preferences. Each records a way the paper could misstate its
own evidence.

- **The gradient is fall-then-floor, not monotone.** Q4 lies below Q5 and the
  difference is insignificant. Do not describe the largest pairs as
  statistically indistinguishable from zero (Q5 differs from zero at t = -2.11).
- **The (A2) departure is left-tailed.** The upper tail is *thinner* than the
  control at p0.95, p0.99 and p0.995. Never describe the log gaps as heavy-tailed
  on the right.
- **Decile 3 of the drift calibration is PARTIAL** (-0.1013 on 314 pairs). Never
  present the pooled 0.0188 without it. 0.10 log points is the resolution of the
  correction layer; no claim about size-profile structure finer than that is
  supported.
- **SD_true and the GE bracket are arm-indexed.** Always report both endpoints
  with their assumptions labelled. No arm preference is established (INV-023).
- **The reliability paradox is a within-run contrast**: treated 0.9243 against
  placebo 0.7463, computed identically. It does not rest on either figure alone.

## 7. Writing conventions

- The introduction argues why the problem matters, not what the paper does. No
  result numbers in the introduction.
- Contributions compressed to one paragraph above the roadmap.
- Austrian School and Talebian influences shape the architecture and are **never
  named** in the article. No "Taleb", "Austrian", "knowledge problem".
- American spelling throughout.
- Marginal comments: one line per paragraph, describing its job.
- Target: Journal of International Economics. Written for a broad audience.
- Fail-fast framing. Intellectually honest over narrative-driven. Where something
  is not identified, say so and say what would identify it.

## 8. Open items, all recorded, none blocking submission

- **INV-039** — `archive/retired_pack/` outside the registry; check (d) cannot
  forbid it. Task S38 addresses both the instance and the class.
- **INV-040** — T29's z column reports Monte Carlo precision, not identification
  z. Corrected `MOMPOW_IDENT_*` IDs are ledgered and are what the article cites.
  A regeneration so the artifact carries the right column is desirable, not
  required.
- **INV-041** — (A2) normality rejected; the location identity survives once the
  Proposition 2 drift wedge is accounted for. That reconciliation is marked
  **DERIVED, NOT GATED** and **must not be cited in the article** until
  reproduced in a gated script. Section 4's (A2) passage was written to avoid it.
- **CAV-005** — `code/S13b_matching_sensitivity.R` carries the pre-INV-038 status
  `SUPERSEDED`, which no check examines. Simon's decision, not yours.

## 9. How this project has gone wrong before

Worth reading once. Every item cost real time.

- **Wrong-object errors are the dominant failure mode**, nine instances so far.
  A number gets computed on the right data with the wrong definition, or on the
  wrong population, and reads as plausible. Before citing any value, check what
  population and definition it belongs to.
- **Verification instruments get trusted beyond their coverage.** `enforce.R`
  check (d) could not fire for months; the registry omitted an entire directory.
  When a check reports zero violations, ask what it actually examines.
- **Specifications can be wrong in ways the executor cannot see.** INV-040 came
  from a drafting prompt asking for the wrong standard error; the script computed
  exactly what was asked. When commissioning anything, state the *question*, not
  only the formula.
- **The executor satisfices under scope breadth.** It drops tasks silently,
  reports artifacts that never reached origin, and answers "NONE" to residual
  ambiguities when ambiguities exist. Verify from origin at the pushed SHA; a
  file not at origin does not exist.
- **Do not iterate on infrastructure.** Simon has low tolerance for discovering a
  new flaw each round. Investigate fully, then propose one fix.
