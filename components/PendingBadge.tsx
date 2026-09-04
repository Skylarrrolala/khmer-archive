/**
 * A small pill standing in for a field the archive does not have yet.
 *
 * Shared by the browse card and the detail page so a gap looks the same
 * wherever it appears, the same reason <NoPhotoPanel /> is shared.
 *
 * The tint sets the cream surface context, so `accent` here is the deep
 * lacquer red rather than the gold used on the maroon ground: 6.52:1 on the
 * tint, above the 4.5:1 AA floor that app/globals.css documents. `muted` on
 * the same tint is 4.83:1 and `gold` is 4.11:1 — neither is used here.
 */
export function PendingBadge({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-block rounded-full bg-accent-soft px-2 py-0.5 text-xs font-medium text-accent">
      {children}
    </span>
  );
}
