import { cache } from "react";
import { notFound, redirect } from "next/navigation";
import type { User } from "@supabase/supabase-js";

import { createSupabaseServerClient } from "@/lib/supabase/server";

/**
 * Who is logged in, and what a page is allowed to assume about them.
 *
 * This is the auth half of the data access layer — the same idea as
 * lib/entries.ts, which keeps every public read in one auditable place. Next's
 * authentication guide argues for exactly this shape: put the check "as close
 * as possible to your data source" rather than in a layout, because a layout
 * does not control whether the routes inside it render
 * (01-app/02-guides/authentication.md).
 *
 * Note what this file is *not* doing. It is not the thing that stops one
 * contributor editing another's entry — that is the RLS policy
 * `auth.uid() = contributor_id` in supabase/migrations/0001_init.sql, enforced
 * by Postgres on every statement. If every function here were deleted, the
 * database would still refuse. What these give is a decent experience: a
 * redirect to the login page instead of an empty list or a failed write.
 *
 * The `?next=` redirect guard used to live here too. It is now
 * lib/safe-path.ts, which has no imports, so it can be unit-tested on its own.
 */

/**
 * The logged-in user, or null.
 *
 * `getUser()` rather than `getSession()`, and the difference matters. A session
 * is just the cookie, decoded and trusted. `getUser()` sends the token to
 * Supabase's auth server to be verified, so a tampered or expired cookie comes
 * back as null instead of as a user. Anything that gates on identity has to
 * use this one.
 *
 * Wrapped in React's `cache` so that a page calling it, plus a header calling
 * it, plus a server action calling it, all share one network round trip per
 * render instead of three.
 */
export const getCurrentUser = cache(async (): Promise<User | null> => {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return user ?? null;
});

/**
 * The logged-in user, or a redirect to the login page.
 *
 * For pages that make no sense signed out — the submission form, "my entries".
 * `redirect()` throws, so control never returns to the caller when there is no
 * user, which is what lets the return type be a plain `User`.
 *
 * `next` carries where the visitor was trying to get to, so logging in can send
 * them onward instead of dumping them on the archive's front page.
 */
export async function requireUser(next?: string): Promise<User> {
  const user = await getCurrentUser();

  if (!user) {
    const target = next ? `/login?next=${encodeURIComponent(next)}` : "/login";
    redirect(target);
  }

  return user;
}

export const isCurrentUserReviewer = cache(async (): Promise<boolean> => {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("is_reviewer");
  if (error) {
    console.error(`[review] access check failed (${error.code}): ${error.message}`);
    throw new Error("Could not check reviewer access.");
  }
  return data === true;
});

// Used by both the page and every decision; the database checks again inside review_entry().
export async function requireReviewer(): Promise<User> {
  const user = await requireUser("/review");
  if (!(await isCurrentUserReviewer())) notFound();
  return user;
}
