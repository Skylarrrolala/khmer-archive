/** An evidence gap, separate from a contributor's submission/review status. */
export function PendingBadge({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-block border-l-2 border-accent bg-accent-soft px-3 py-1.5 text-sm leading-relaxed text-accent">
      {children}
    </span>
  );
}
