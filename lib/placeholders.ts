/**
 * The archive stores what it does not know yet as a bracketed marker rather
 * than as an empty field, because `supabase/migrations/0001_init.sql` makes
 * name_khmer, context and told_by `not null`. A row that is missing its Khmer
 * spelling holds '[KHMER SCRIPT NOT CONFIRMED]', an unsourced row holds
 * '[SOURCE PENDING ...]', and so on.
 *
 * Those markers have to stay in the data: they are what the cleanup queries in
 * README.md and CLAUDE.md match on, and they are the honest record of a gap.
 * What must not happen is printing them to a visitor, who would read an
 * editing note as either a bug or, worse, as content.
 *
 * So the split is: the database keeps the marker, and the UI reads it through
 * this file and renders a badge. Both the browse card and the detail page
 * import from here so the two can never disagree about what counts as a gap.
 */

/**
 * True when a field holds an editing marker instead of a real value.
 *
 * The test is deliberately structural — a trimmed value wrapped in square
 * brackets — rather than a list of known marker texts. A new marker added to
 * the seed data is then handled without touching this file, and the failure
 * mode is safe in both directions: a real person's name, a real occasion and
 * a real Khmer spelling are never bracketed, so a genuine value cannot be
 * mistaken for a gap and hidden.
 *
 * Not for `description`, whose markers are appended to real prose rather than
 * replacing it — use the two functions below for that field.
 */
export function isPlaceholder(value: string): boolean {
  const trimmed = value.trim();
  return trimmed.startsWith("[") && trimmed.endsWith("]");
}

/** The generic Family credit is retained as written, but is not a named source. */
export function hasUnattributedSource(value: string): boolean {
  return isPlaceholder(value) || value.trim().toLowerCase() === "family";
}

/**
 * A description with its bracketed markers removed, leaving the real prose.
 *
 * Runs of spaces and tabs are collapsed so removing a marker does not leave a
 * gap mid-sentence, but newlines are preserved: the detail page renders the
 * description with `whitespace-pre-line` to keep the line breaks a contributor
 * typed, and collapsing them here would quietly undo that.
 *
 * Returns "" when the whole description was a placeholder, which is the case
 * for the [SAMPLE] rows.
 */
export function descriptionProse(description: string): string {
  return description
    .replace(/\[[^\]]*\]/g, "")
    .replace(/[ \t]+/g, " ")
    .replace(/[ \t]+$/gm, "")
    .trim();
}

/**
 * Human-readable labels for the markers found in a description.
 *
 * The marker text itself is never shown — it is written for whoever maintains
 * the archive ("Replace this with the story your grandparents actually tell"),
 * not for a visitor. Each marker is translated into a short statement of what
 * is missing, so the page stays honest about the gap without handing over the
 * editing note.
 */
export function descriptionNotes(description: string): string[] {
  const notes: string[] = [];

  if (/\[SAMPLE DATA/i.test(description)) {
    notes.push("Placeholder text — no story recorded yet");
  }
  if (/\[Internet reference/i.test(description)) {
    notes.push("Not yet verified with family");
  }
  if (/\[PHOTO CREDIT PENDING/i.test(description)) {
    notes.push("Photo credit pending");
  }

  return notes;
}
