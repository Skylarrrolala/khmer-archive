/**
 * What a contributor is told when one of their limits stops them. Review
 * finding M3; the limits themselves are in supabase/migrations/0006.
 *
 * The database refuses with its own error codes, one per limit, and this maps
 * each to a sentence. Anything else is not a limit and gets null, so the
 * caller falls back to its usual message. Kept free of imports so `node --test`
 * can load it.
 */

export const LIMIT_MESSAGES = {
  KA001:
    "You have 5 entries waiting for review. You can submit another once a reviewer has looked at one of them.",
  KA002: "You've uploaded 20 photos in the last 24 hours. Please try again tomorrow.",
  KA003:
    "You have 10 uploaded photos that aren't attached to any entry, so new uploads are paused. This usually means earlier uploads couldn't be cleaned up.",
} as const;

/** The sentence for a limit's error code, or null when the code is not a limit. */
export function limitMessage(code: string | undefined): string | null {
  return code !== undefined && Object.hasOwn(LIMIT_MESSAGES, code)
    ? LIMIT_MESSAGES[code as keyof typeof LIMIT_MESSAGES]
    : null;
}
