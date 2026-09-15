/**
 * Reading an entry out of a submitted form, and refusing it if it is not one.
 *
 * Submitting and editing validate identically, so they validate here. Two
 * copies of these rules would be two places for "told_by is required" to stop
 * being true, and the sourcing rule is the one this archive can least afford
 * to lose.
 *
 * The same constraints exist a second time as CHECK constraints in
 * supabase/migrations/0001_init.sql, and those are the ones that actually
 * hold: a row that somehow got past this function would still be refused by
 * Postgres. This exists so a contributor is told which field is missing,
 * rather than being shown a constraint violation.
 */

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

/** A form value as trimmed text, whatever the form actually sent. */
function text(formData: FormData, name: string): string {
  return String(formData.get(name) ?? "").trim();
}

export function readEntryFields(formData: FormData): EntryFieldsResult {
  const fields: EntryFields = {
    nameKhmer: text(formData, "name_khmer"),
    nameEnglish: text(formData, "name_english"),
    toldBy: text(formData, "told_by"),
    context: text(formData, "context"),
    description: text(formData, "description"),
  };

  if (!fields.nameEnglish) {
    return { ok: false, error: "Give the dessert a name in English." };
  }
  if (!fields.nameKhmer) {
    return { ok: false, error: "Give the dessert's name in Khmer script." };
  }
  if (!fields.context) {
    return {
      ok: false,
      error: "Say when the dessert is made — a festival, a daily snack.",
    };
  }
  if (!fields.description) {
    return { ok: false, error: "Add the story or description." };
  }

  /*
   * `told_by` is the archive's sourcing rule expressed as a form field: every
   * entry credits the person who shared it, by name, with their permission.
   * The column is `not null` for the same reason. This is the one field a
   * contributor cannot shrug off.
   */
  if (!fields.toldBy) {
    return {
      ok: false,
      error: "Credit the person who shared this dessert, by name.",
    };
  }

  return { ok: true, fields };
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
