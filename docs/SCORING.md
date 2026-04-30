# Scoring & Evaluation Reference

This document describes the full scoring domain of Safari Manager: how photographs (slides) are evaluated by jurors, how subjects and coefficients affect scores, and how final rankings are determined. It is intended as a domain reference for anyone working on the competition logic.

> **Context**: Scoring is the final phase of the competition lifecycle. It follows slide selection and jury voting, and produces the official rankings. See [ARCHITECTURE.md](ARCHITECTURE.md) for the broader system overview.

---

## The Slide Lifecycle

A slide passes through one of three statuses during its lifetime in a competition:

- **`discarded`** — the default state. The slide was uploaded but not chosen for competition submission. It contributes no score and is not visible to jurors.
- **`submitted_jury`** — the slide has been selected and will be evaluated by jurors. A subject must be assigned before it can be scored.
- **`submitted_fixed`** — the slide has been selected but bypasses jury evaluation. It receives automatic fixed points instead. A subject must still be assigned.

### The Penalty Flag

Independently of status, a `submitted_jury` slide may carry a **penalty** flag. A penalised slide does not receive a normal jury score — it instead receives a flat negative `penalty_amount` defined in the competition settings (default: −100 points). The penalty flag is set automatically when more than half of the votes cast on that slide are of a penalty type (see Evaluations below). It is cleared automatically if the balance shifts back.

The penalty flag has no effect on `submitted_fixed` slides.

---

## Subjects and the Static Coefficient

A **subject** is an entry in the global species catalogue — a fish species, macro organism, or ambient marine element. Every submitted slide must reference exactly one subject.

Subjects carry the following domain-relevant attributes:

| Attribute | Role |
|-----------|------|
| **Common name** | Human-readable label used throughout the interface |
| **Scientific name** | Latin binomial for species accuracy |
| **Numeric ID** | Integer used for ordering slides in the jury queue (same species are grouped together) |
| **Type** | Classification: `fish`, `macro`, `fish_macro`, or `ambient` |
| **Coefficient** | Non-negative integer on the global catalog row. Used as the default when adding a species to a competition and as the **effective** static multiplier in **legacy** competitions (see below). |

### Per-competition subject list and coefficients

Each competition can define **`competition_subjects`**: a join of catalog `subjects` to that competition with a **competition-specific** non-negative integer coefficient.

- If a competition has **no** such rows, scoring uses **legacy** behaviour: every catalog subject can be assigned to slides, and the **global** `subjects.coefficient` is the static multiplier.
- If a competition has **at least one** row, only those subjects are intended for slide assignment (enforced in the UI and on slide updates when a subject is changed), and the **static** multiplier for scoring is taken from the join row (with fallback to the global coefficient if a row is missing for a subject).

Dynamic coefficient bonuses (rarity intervals) still apply on top of this **effective** static coefficient, according to `coefficient_mode` / `dynamic_coefficient_mode` as before.

---

## Evaluations

An **evaluation** is a vote option that a juror can assign to a slide. Evaluations are defined globally and then configured per competition.

### Evaluation Attributes

| Attribute | Role |
|-----------|------|
| **Name** | A short label (e.g. "8", "6", "penalty"). Also doubles as the keyboard shortcut for jurors in the desktop voting interface. |
| **Type** | `numeric` or `boolean`. Both types ultimately have a numeric value used in score calculation. |
| **Value** | The decimal score this vote contributes (e.g. 8.0, 6.0, 0.0, −5.0). |
| **Is penalty** | Marks this vote option as a penalty-type vote. When the count of penalty-type votes on a slide exceeds half of the expected total votes, the slide's penalty flag is automatically set. |
| **Description** | Optional free-text note. |

### Per-Competition Configuration

Evaluations are linked to competitions through a **CompetitionEvaluation** join, which also stores the display order (`position`) of each option. This means different competitions can use entirely different vote scales — one competition might use a 6/8/10/penalty scale, another might use a simpler pass/fail/penalty scheme.

---

## The Jury Vote (SlideEvaluation)

A **SlideEvaluation** records one juror's vote on one slide. Key constraints:

- **One vote per juror per slide** — each juror can cast at most one evaluation per slide. Attempting to vote again replaces the previous vote.
- The record links a slide, a juror (user), and the evaluation option they chose.
- The collection of all SlideEvaluations on a given slide determines both the slide's score (sum of values) and whether the penalty flag should be set.

### Evaluation Quorum

A slide is considered fully evaluated when the number of votes cast reaches the expected total (`number_of_jurors × evaluations_per_juror`). The jury interface tracks this in real time to show which slides still need votes.

---

## Slide Score Calculation

Each slide produces one score. The calculation follows three mutually exclusive cases, checked in priority order:

### 1. Penalty Slide

If the slide's penalty flag is set, its score is the flat `penalty_amount` from competition settings (default: −100). The selected coefficient is tracked for tiebreaker purposes but is **not** multiplied into the penalty amount.

### 2. Jury Slide

If the slide status is `submitted_jury` and no penalty flag is set:

> **Score = sum of all vote values × selected coefficient**

For example: three jurors voting "8" on a subject with coefficient 3 yields `(8 + 8 + 8) × 3 = 72`.

### 3. Fixed-Points Slide

If the slide status is `submitted_fixed`:

> **Score = fixed_points_multiplier × selected coefficient**

The `fixed_points_multiplier` is a competition setting (default: 5.0). A fixed-point slide on a coefficient-3 subject scores `5.0 × 3 = 15`.

---

## Coefficient Selection

Which coefficient is applied to a given slide depends on the competition's coefficient configuration settings. Two independent mode settings govern this:

- **`coefficient_mode`** — controls when the static subject coefficient is applied. Options: `disabled` (always use 1), `all` (apply to all submitted slides), `submitted_jury` (only jury slides), `submitted_fixed` (only fixed-point slides).
- **`dynamic_coefficient_mode`** — same set of options, but for the dynamic bonus coefficient (described below).

The final coefficient for a slide is resolved as (where **static** means the effective per-competition or legacy global value described above):

1. If the dynamic coefficient mode applies to this slide's status → `static_coefficient + dynamic_bonus`
2. Else if the static coefficient mode applies → `static_coefficient`
3. Otherwise → `1` (neutral)

---

## Dynamic Coefficients

The dynamic coefficient is a bonus multiplier that rewards photographing subjects that were less commonly submitted in this competition — introducing a popularity-based rarity factor on top of the inherent difficulty.

### Distribution

For each subject, the system computes a **distribution**: the fraction of participating photographers who submitted at least one slide of that species. A distribution of 0.2 means 20% of participants photographed this subject.

### Interval Rules

The competition settings store a list of **DynamicCoefficient intervals**, each with a decimal range (`from`, `to`) and a bonus `value`. When scoring, the system finds which interval the subject's distribution falls into (strictly greater than `from`, less than or equal to `to`) and uses that interval's value as the dynamic bonus.

The default configuration ships three intervals (all defaulting to value 1):

| Interval name | Distribution range | Typical intent |
|---------------|-------------------|----------------|
| High rarity | 0% – 33% | Few participants photographed it → higher bonus |
| Medium rarity | 33% – 66% | Moderately common |
| Low rarity | 66% – 100% | Very common → lower bonus |

Competition administrators can tune the bonus values to meaningfully reward rare subjects. For example, setting the high-rarity bonus to 3 and the low-rarity bonus to 0 would significantly increase the importance of species diversity.

### Combined Coefficient

When the dynamic coefficient is active, it is added to the static coefficient rather than replacing it:

> **Final coefficient = effective_static_coefficient + dynamic_bonus**

This means the dynamic bonus always augments the base difficulty — a naturally hard subject (high static coefficient) that is also rarely photographed earns both rewards.

---

## Participant and Team Totals

A participant's total score is the **sum of all their individual slide scores** across all submitted (non-discarded) slides, plus an optional **species bonus** when configured.

### Species bonus (per slide)

If `submission_bonus_per_slide` (competition setting, default `0`) is greater than zero, each participant receives an extra:

> **submission_bonus_per_slide × N**

where **N** is the number of submitted slides (`submitted_jury` + `submitted_fixed`) for that participant. If **any** of those slides has the **penalty** flag set, the **entire** species bonus for that participant is **zero** (penalty slide scores still apply as usual).

In team competitions, the team's slide-point total is still the **sum of all members' slide scores**. The species bonus is computed **once per team** as:

> **submission_bonus_per_slide × M**

where **M** is the total number of submitted slides across **all** team members (not the sum of per-member bonuses). If any slide in that combined set is penalised, the **team** species bonus is **zero**.

The same ranking and tiebreaker logic applies to teams.

---

## Ranking and Tiebreakers

Participants (or teams) are ranked using a multi-level descending sort. Ties are resolved step by step:

### Primary: Total Score

Participants are sorted by total score, highest first. This is the primary ranking criterion.

### First Tiebreaker: Number of Submitted Slides

When two participants have equal total scores, the one with more submitted slides ranks higher. Submitting more valid slides demonstrates greater effort and breadth. (When a positive species bonus is enabled, slide count is also reflected in the primary score, so this tiebreaker often matters only when totals tie for other reasons.)

### Second Tiebreaker: Coefficient Distribution

If total score and slide count are both equal, the system compares how many slides each participant submitted at each coefficient value, starting from the highest coefficient present in the competition and working downward. A participant with more slides at a high coefficient beats one who achieved the same total with lower-coefficient subjects.

This tiebreaker produces a sequence of sort keys — one per distinct coefficient value — ensuring that ties can be resolved with a high degree of specificity.

### Shared Rank

When participants are truly equal across all tiebreakers, they share the same rank. The next distinct result skips the appropriate positions (standard competition ranking, not dense ranking).

---

## Competition Settings Reference

The following competition settings directly control scoring behaviour:

| Setting | What it controls |
|---------|-----------------|
| `coefficient_mode` | Whether and when the static subject coefficient is applied (`disabled`, `all`, `submitted_jury`, `submitted_fixed`) |
| `dynamic_coefficient_mode` | Whether and when the dynamic rarity bonus is applied (same options) |
| `fixed_points_multiplier` | Base score for fixed-point slides before coefficient (default: 5.0) |
| `submission_bonus_per_slide` | Species bonus: points added per submitted slide (jury + fixed); forfeited if any penalised slide exists (default: 0) |
| `penalty_amount` | Flat score assigned to penalised slides (default: −100) |
| `number_of_jurors` | Expected number of jurors per slide; used for quorum calculation |
| `evaluations_per_juror` | Expected number of votes each juror casts per slide |
| `max_slides` | Maximum total slides a participant may submit |
| `max_jury_slides` | Maximum slides a participant may send to jury evaluation |
| `dynamic_coefficient_intervals` | List of distribution-range → bonus-value rules for the dynamic coefficient |
