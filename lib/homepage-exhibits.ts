import { isPlaceholder } from "./placeholders.ts";
import { isPhotoWithheld } from "./exhibit-records.ts";
import type { Entry } from "./types";

export type HomepageExhibit = Entry & { photo_url: string };

/** Select from the published browse result; never fetch a second, unfiltered set. */
export function getHomepageExhibits(entries: Entry[]): HomepageExhibit[] {
  const photographed = entries.filter(
    (entry): entry is HomepageExhibit =>
      entry.status === "published" && Boolean(entry.photo_url) && !isPlaceholder(entry.name_khmer) && !isPhotoWithheld(entry),
  );
  const preferred = ["/entries/num-plae-ai.jpg", "/entries/num-korng.jpg"]
    .map((photo) => photographed.find((entry) => entry.photo_url === photo))
    .filter((entry): entry is HomepageExhibit => entry !== undefined);

  return [...preferred, ...photographed.filter((entry) => !preferred.includes(entry))].slice(0, 2);
}
