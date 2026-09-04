/**
 * A small pill standing in for a field the archive does not have yet.
 *
 * Shared by the browse card and the detail page so a gap looks the same
 * wherever it appears, the same reason <NoPhotoPanel /> is shared.
 *
 * `accent` on `accent-soft` measures 5.09:1, above the 4.5:1 AA floor that
 * app/globals.css documents. `muted` on the same tint is 4.26:1 and would
 * fail, and `gold` is decorative-only per that file — neither is usable here.
 */
export function PendingBadge({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-block rounded-full bg-accent-soft px-2 py-0.5 text-xs font-medium text-accent">
      {children}
    </span>
  );
}
