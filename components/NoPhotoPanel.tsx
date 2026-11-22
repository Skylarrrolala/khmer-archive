/**
 * The empty state for a dessert that is remembered but no longer made.
 *
 * `photo_url` is nullable by design — the archive is as much about the
 * desserts a source remembers as those they still make. So this
 * is not a "missing image" fallback to apologise for: it is a record of an
 * absence, and it gets the same visual weight as a photograph would.
 *
 * Shared by the browse card and the detail page so the two never drift apart.
 */
export function NoPhotoPanel({ size = "sm", withheld = false }: { size?: "sm" | "lg"; withheld?: boolean }) {
  const icon = size === "lg" ? 72 : 44;

  return (
    <div className="flex h-full flex-col items-center justify-center gap-2 bg-accent-soft px-6 text-center">
      <svg
        width={icon}
        height={icon}
        viewBox="0 0 48 48"
        fill="none"
        aria-hidden="true"
      >
        {/* Three rising dots where steam would be: the dessert is remembered,
            not cooking. Gold is decorative-only in this palette, which is
            exactly what an icon stroke is. */}
        <g stroke="var(--decor-gold)" strokeWidth="2.5" strokeLinecap="round" opacity="0.75">
          <path d="M17 13v-3" />
          <path d="M24 11v-4" />
          <path d="M31 13v-3" />
        </g>
        {/* The same bowl-and-mound mark as the photo placeholder, so the two
            empty states read as one family. */}
        <g
          stroke="var(--brand)"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M14 28q10-10 20 0" />
          <path d="M10 28h28" />
          <path d="M12.5 28q11.5 12 23 0" />
        </g>
      </svg>

      <p className="text-sm font-medium text-accent">
        {withheld ? "Photograph withheld" : "Remembered, not made today"}
      </p>
      <p className="text-xs text-muted">{withheld ? "Reuse permission pending confirmation" : "No photograph recorded"}</p>
    </div>
  );
}
