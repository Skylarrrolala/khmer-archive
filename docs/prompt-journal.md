# Prompt Journal — Sprint 1

Golden rule from Chapter 3: share and reuse effective prompts. Three entries,
one per work session.

> **How to finish this file.** Parts 3 and 4 below are reconstructed from the
> commit record of each session — read them and correct anything that doesn't
> match what you remember, then put them in your own words. Parts 1 and 2 are
> blank on purpose: part 1 is the prompt itself, which only exists in your
> Claude history, and part 2 is the technique name, which has to come from
> Chapter 3's checklist wording, not from a guess. Each entry says which
> session to open to find the prompt.

---

## Entry 1 — Tuesday 1 September

*Session: "Khmer Living Archive Desserts" (the desktop-app session, opened
13:53). Landed as commit `f742cad`, the whole Sprint 1 scaffold.*

**1. The prompt that mattered most**

> _Paste it here, exactly as sent. This is the kick-off prompt — the one that
> produced browse, search, the detail page and `0001_init.sql` in one pass.
> Open that session and scroll to the top._

**2. Technique**

> _Name it from the checklist. In practice: you handed it a written spec up
> front — a locked stack, four numbered features, a hard "nothing outside
> this" rule, and the security requirements — rather than describing the app
> and letting it choose._

**3. What came back**

All of Sprint 1 in a single pass: a public browse-and-search page, an entry
detail page, and a migration whose RLS policies were actually exercised
against a local Postgres — cross-user edit, delete and read all refused,
logged-out clients seeing no pending rows. Search shipped as a plain GET form,
so results are shareable URLs and work without JavaScript. Seed data was three
rows with every field prefixed `[SAMPLE]`.

**4. What you changed or rejected**

Caught the transliteration: it had written "nom" throughout, and the correct
romanisation is "num". Sent it back in a follow-up session the same evening to
fix all four files, and it flagged that one of them was
`supabase/migrations/0001_init.sql` — which is the file that must not be
edited in place once deployed. That fix rode along with Friday's push
(`70bede9`).

---

## Entry 2 — Friday 4 September (lab)

*Sessions: "Git 22425 changes" (13:56) and "Design rework color and
typography" (15:00 onward). Landed as `dff1beb`, `2ea800e`, `c1c0e03`,
`0c210e9`, `cd61dfc`, `fbda8ec`, `0021689`, `b2bcd81`.*

**1. The prompt that mattered most**

> _Paste it here. Two candidates from this session — pick the one that
> actually mattered:_
> - _the seed-data prompt, which produced five researched dessert rows with
>   every unknown flagged rather than guessed;_
> - _the design prompt, which took the archive from cream-and-terracotta to
>   the maroon-and-cream direction._

**2. Technique**

> _Name it from the checklist. In practice: you told it what to do when it
> didn't know something — flag the gap, don't fill it — instead of only
> telling it what to produce._

**3. What came back**

Five real desserts researched and added, with the gaps left visible: three
rows carrying `[KHMER SCRIPT NOT CONFIRMED]` because the spelling wasn't
supplied, three carrying `[NOT RECORDED]` for the occasion, and every
`told_by` marked `[SOURCE PENDING]`. Its reasoning was that in a preservation
archive a wrong spelling is worse than a visible gap. The design half
rebuilt the palette and typography around maroon and cream, with contrast
ratios measured rather than eyeballed.

**4. What you changed or rejected**

Three corrections, all things the model could not have known:

- **Num Akor was wrong.** It had described a filling. Num Akor has none — it
  is a steamed palm sugar sponge topped with grated coconut, which is also
  what the photograph shows. Both `name_english` and `description` were fixed.
- **Supplied the Khmer spellings** it had left bracketed — នំផ្លែអាយ, នំកង,
  នំបត់ — and the occasions for three desserts.
- **Dropped the Bobor Skor Tnaot row** entirely.

Also rejected how the markers were being displayed: a visitor was reading
"Told by [SOURCE PENDING - internet reference, not yet verified with family]"
on the live page. The markers stay in the database, because they are the
honest record of a gap and the cleanup queries match on them — but the page
now renders them as a "Source pending verification" badge (`c1c0e03`).

---

## Entry 3 — Sunday 6 September (weekend)

*Same design session, continued. Landed as `9999625`, `4278461`, `16629d1`.*

**1. The prompt that mattered most**

> _Paste it here. The strongest candidate is whatever you sent along with the
> source document containing the seven desserts — that's the prompt that
> produced the problem described below._

**2. Technique**

> _Name it from the checklist. Note the honest angle: the interesting thing
> here isn't that the prompt worked, it's what it surfaced._

**3. What came back**

The seven researched entries, with ingredients, preparation, region and notes
folded into `description` rather than becoming new columns — so the data model
stayed at its four-feature minimum. It also fixed a bug nobody asked about:
`now()` is constant inside a transaction, so every seeded row had an identical
`created_at` and the browse order was arbitrary.

**4. What you changed or rejected**

**Rejected the testimony.** The source document carried first-person passages
attributed to a named relative — "Grandmother recalls sitting under the stilt
house…" — composed, not transcribed. Writing those in would have put invented
words in a real person's mouth in a public archive. The voice was stripped and
the facts kept; every `told_by` stays a `[SOURCE PENDING]` marker, so the page
states the gap instead of claiming a source. The rule went into `CLAUDE.md`
the same session (`16629d1`) so it can't come back: researched facts are fine,
composed quotes attributed to a real person are not.

---

*Continues through Sprints 2 and 3.*
