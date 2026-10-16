# Prompt Journal — Sprint 1

Golden rule from Chapter 3: share and reuse effective prompts.
Three entries, one per work session.

> **One thing left to do.** Each entry's part 1 is a single blank line marked
> `PROMPT:`. Open the session named above it, copy the prompt, paste it in.
> Everything else is written. The technique labels in part 2 are the standard
> names — if Chapter 3's checklist words them differently, swap the label; the
> line underneath describes what you actually did and shouldn't need changing.

---

## Entry 1 — Tuesday 1 September

*Session: "Khmer Living Archive Desserts". Shipped `f742cad`.*

**1. Prompt**

PROMPT:

*(The kick-off prompt — top of that session. It's the one that produced browse,
search, the detail page and `0001_init.sql` in a single pass.)*

**2. Technique** — Context-setting with explicit constraints

I wrote the project rules into `CLAUDE.md` before asking for any code: locked
stack, four numbered features, a hard "nothing outside this" rule, and the
security requirements. So the constraints arrived as context, not as
corrections afterwards.

**3. What came back**

All of Sprint 1 in one pass — browse, search, detail page, and a migration
whose RLS policies it actually exercised against a local Postgres rather than
just asserting they worked.

**4. What I changed or rejected**

It had written "nom" throughout and the correct transliteration is "num"; I
sent it back that evening to fix all four files, and it flagged that one of
them was the migration — which is the file that must not be edited in place
once deployed.

---

## Entry 2 — Friday 4 September (lab)

*Sessions: "Git 22425 changes", then "Design rework color and typography".
Shipped `dff1beb`, `2ea800e`, `c1c0e03`, `0c210e9`, `cd61dfc`, `fbda8ec`,
`0021689`, `b2bcd81`.*

**1. Prompt**

PROMPT:

*(The seed-data prompt — the one that added five desserts. If the design prompt
felt like the one that mattered more, use that instead and swap parts 3 and 4
for the design notes at the bottom of this entry.)*

**2. Technique** — Constraining uncertainty

I told it what to do when it *didn't* know something — flag the gap with a
bracketed marker, don't guess — instead of only telling it what to produce.

**3. What came back**

Five real desserts with every unknown left visible: `[KHMER SCRIPT NOT
CONFIRMED]` where I hadn't supplied a spelling, `[NOT RECORDED]` where I
hadn't given an occasion, and `[SOURCE PENDING]` on every `told_by`.

**4. What I changed or rejected**

Three things it couldn't have known — Num Akor has no filling (it's a steamed
palm sugar sponge with grated coconut), the Khmer spellings for three
desserts, and dropping the Bobor row — and one thing it got structurally
wrong: the markers were printing raw on the live page, so a visitor read "Told
by [SOURCE PENDING - internet reference…]". I kept the markers in the database
and had only the rendering changed, to a "Source pending verification" badge.

> *Design half of the same session, if you'd rather use that prompt:* I gave it
> a reference layout to work from (reference-driven prompting). What came back
> was the maroon-and-cream palette with contrast ratios measured rather than
> eyeballed — but the composition took four more passes to land: the photos
> were cropped in half by a fixed 4:3 frame, the watermark was smudged across
> the headline at narrow widths and clipped off the edge at wide ones, and the
> search field truncated to "Search by na…" at 320px. The palette prompt
> worked first time; the layout prompt didn't.

---

## Entry 3 — Sunday 6 September (weekend)

*Same design session, continued. Shipped `9999625`, `4278461`, `16629d1`.*

**1. Prompt**

PROMPT:

*(Whatever you sent along with the source document holding the seven desserts.
This is the prompt that surfaced the problem in part 4.)*

**2. Technique** — Grounding in supplied source material

Rather than letting it research the desserts itself, I gave it a source
document and asked it to work from that.

**3. What came back**

The seven entries with ingredients, preparation, region and notes folded into
`description` instead of new columns, so the data model stayed minimal — plus
a fix I hadn't asked for, since `now()` is constant inside a transaction and
every seeded row had been getting an identical `created_at`.

**4. What I changed or rejected**

I rejected the testimony: the source document carried first-person passages
attributed to a named relative — "Grandmother recalls sitting under the stilt
house…" — that were composed, not transcribed, so I had the voice stripped and
the facts kept, left every `told_by` as a `[SOURCE PENDING]` marker, and wrote
the rule into `CLAUDE.md` the same session so it can't come back.

---

*Continues through Sprints 2 and 3.*
