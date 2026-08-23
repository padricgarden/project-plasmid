# F##: Feature Name

> Copy this file to `F##_Feature-Name.md`, add the row to [README.md](README.md), and
> delete these instruction blocks as you fill each section in.

**Status:** planned | in progress | done | cut
**Spec sections:** §X.Y, §Z
**Depends on:** F## (or: nothing)

## Purpose

One paragraph: what this feature is and what it is for. If the design spec already
answers that, cite the section instead of paraphrasing it.

## Design constraints

The rules from the spec this feature must not violate, each with its section number.
Also note anything here that touches the invariants listed in CLAUDE.md.

## Approach

How we are building it — the shape of the code, where it lives under `src/`, the key
types and their responsibilities. This is the part the spec does not cover.

## Milestones

Each milestone is independently completable and verifiable. Keep IDs stable once
allocated; if one is abandoned, leave it in place marked `[cut]` rather than renumbering
the ones after it.

### F##-M01 — Short title

**Done when:** the observable condition that ends this milestone. Prefer something a
test or a run of the game can settle, not "implemented X".

Scope, notes, open questions.

### F##-M02 — Short title

**Done when:**

## Tunables

Any balance parameter this feature introduces or changes — costs, tick counts, slot
counts, yields, thresholds. **Register them in [docs/balance.md](../balance.md) and link
to it here; do not restate the values.** Delete the section if the feature introduces
none.

## Open questions

Things that need a decision before or during the work, and who decides. Delete the
section if empty.

## Changelog

Material decisions and their reasons, so the reasoning survives the commit that
implemented it.

- `YYYY-MM-DD` — Created.
