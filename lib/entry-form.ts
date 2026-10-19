/**
 * Reading an entry out of a submitted form, and refusing it if it is not one.
 *
 * Submitting and editing validate identically, so they validate here. Two
 * copies of these rules would be two places for "told_by is required" to stop
 * being true, and the sourcing rule is the one this archive can least afford
 * to lose.
 *
 * The same rules exist a second time as CHECK constraints in migration 0002,
 * and those are the ones that actually hold: a row that somehow got past this
 * function would still be refused by Postgres. This exists so a contributor
 * is told which field to fix, rather than being shown a constraint violation.
 * EntryForm runs the same check in the browser as each field is typed in.
 */

/**
 * The five text fields, in form order: the label the form shows, the longest
 * value migration 0002 accepts, and what to say when the field is left blank.
 *
 * `told_by` is the archive's sourcing rule expressed as a form field: every
 * entry credits the person who shared it, by name, with their permission.
 * This is the one field a contributor cannot shrug off.
 */
export const ENTRY_FIELDS = {
  name_khmer: { label: "Name in Khmer", max: 120, blank: "Give the dessert's name in Khmer script." },
  name_english: { label: "Name in English", max: 150, blank: "Give the dessert a name in English." },
  told_by: { label: "Told by", max: 120, blank: "Credit the person who shared this dessert, by name." },
  context: { label: "When it is made", max: 300, blank: "Say when the dessert is made — a festival, a daily snack." },
  description: { label: "The story", max: 8000, blank: "Add the story or description." },
} as const;

export type EntryFieldName = keyof typeof ENTRY_FIELDS;

// Migration 0002's "visible" rule: one character that is neither whitespace
// nor an invisible mark. \s already covers the rest of the database's list.
const VISIBLE = /[^\s\u180e\u200b-\u200d\u2060]/;

/**
 * Why migration 0002 would refuse this (already trimmed) value, in words that
 * name the field, or null if it would accept it.
 *
 * Length is counted in code points, as Postgres's char_length counts it, not
 * in UTF-16 units as `.length` does: an emoji is one character, and every
 * Khmer letter, vowel sign and subscript mark is one each. There is no shape
 * rule, so a single word or a single letter is a whole name.
 */
export function fieldProblem(name: EntryFieldName, value: string): string | null {
  const { label, max, blank } = ENTRY_FIELDS[name];
  if (!VISIBLE.test(value)) return blank;

  const length = [...value].length;
  if (length > max) {
    return `"${label}" is too long: ${length.toLocaleString("en")} characters, and the limit is ${max.toLocaleString("en")}.`;
  }
  return null;
}

/** The five text columns a contributor fills in. */
export type EntryFields = {
  nameKhmer: string;
  nameEnglish: string;
  toldBy: string;
  context: string;
  description: string;
};

export type EntryFieldsResult =
  | { ok: true; fields: EntryFields }
  | { ok: false; error: string };

/**
 * A form value as trimmed text, whatever the form actually sent. Browsers send
 * a textarea's line breaks as CRLF, which would count twice against the limit
 * and store a stray \r, so they become plain \n first, as the browser counts.
 */
function text(formData: FormData, name: string): string {
  return String(formData.get(name) ?? "").replace(/\r\n?/g, "\n").trim();
}

export function readEntryFields(formData: FormData): EntryFieldsResult {
  const problem = (Object.keys(ENTRY_FIELDS) as EntryFieldName[])
    .map((name) => fieldProblem(name, text(formData, name)))
    .find((found) => found !== null);
  if (problem) return { ok: false, error: problem };

  return {
    ok: true,
    fields: {
      nameKhmer: text(formData, "name_khmer"),
      nameEnglish: text(formData, "name_english"),
      toldBy: text(formData, "told_by"),
      context: text(formData, "context"),
      description: text(formData, "description"),
    },
  };
}

/**
 * The uploaded photo, or null when the form carried no file.
 *
 * A file input that was left alone still posts — as an empty File — so "did
 * they choose a photo?" is a size check, not a presence check.
 */
export function readPhoto(formData: FormData): File | null {
  const photo = formData.get("photo");

  return photo instanceof File && photo.size > 0 ? photo : null;
}

/**
 * The five text fields exactly as typed, keyed by column name, so a failed
 * submission can put them back in the form. Not trimmed: what comes back is
 * what the contributor wrote.
 */
export type EntryValues = {
  name_khmer: string;
  name_english: string;
  told_by: string;
  context: string;
  description: string;
};

/**
 * What a submit or edit action hands back to the form when it does not
 * succeed. Success never comes back here: it redirects.
 *
 * `attempt` counts failed submissions. The form is keyed on it, so each
 * failure remounts the inputs with `values` as their starting text.
 */
export type EntryFormState = {
  error: string | null;
  values: EntryValues | null;
  attempt: number;
};

export const initialEntryFormState: EntryFormState = {
  error: null,
  values: null,
  attempt: 0,
};

export function entryValues(formData: FormData): EntryValues {
  const raw = (name: string) => String(formData.get(name) ?? "");
  return {
    name_khmer: raw("name_khmer"),
    name_english: raw("name_english"),
    told_by: raw("told_by"),
    context: raw("context"),
    description: raw("description"),
  };
}

/** A failed attempt: the message, and the text to put back. */
export function formFailure(
  previous: EntryFormState,
  error: string,
  values: EntryValues,
): EntryFormState {
  return { error, values, attempt: previous.attempt + 1 };
}
