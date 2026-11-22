import Link from "next/link";

import { signOut } from "@/app/(auth)/actions";
import { getCurrentUser, isCurrentUserReviewer } from "@/lib/auth";
import { isSupabaseConfigured } from "@/lib/env";

/**
 * The signed-in state in the masthead.
 *
 * An async Server Component, so the header can await the current user without
 * the page becoming a client component. `getCurrentUser` is memoised with
 * React's `cache`, so this rendering on every route costs one auth round trip
 * per request no matter how many other things also ask who is logged in.
 *
 * Sign-out is a `<form>` and not a link, because it changes server state.
 * A GET link would let a prefetch, a crawler or an <img src> in someone else's
 * page log a visitor out; a POST to a Server Action cannot be triggered that
 * way, and Next's action handling carries its own origin check.
 *
 * Nothing here is a security boundary. It shows and hides links. What actually
 * stops someone touching an entry they do not own is the RLS policy in
 * supabase/migrations/0001_init.sql.
 */
export async function AccountNav() {
  // A clone with no Supabase env vars renders the setup notice on the browse
  // page; the header should not throw out from under it.
  if (!isSupabaseConfigured()) return null;

  const user = await getCurrentUser();

  if (!user) {
    return (
      <Link
        href="/login"
        className="text-sm text-muted transition-colors hover:text-accent"
      >
        Sign in
      </Link>
    );
  }

  // A review lookup failure must not take unrelated pages out of service.
  const reviewer = await isCurrentUserReviewer().catch(() => false);

  return (
    <div className="flex min-w-0 max-w-full flex-wrap items-center gap-x-5 gap-y-1">
      <Link
        href="/submit"
        className="text-sm text-accent transition-opacity hover:opacity-70"
      >
        Submit
      </Link>

      <Link
        href="/my-entries"
        className="text-sm text-muted transition-colors hover:text-accent"
      >
        Your entries
      </Link>

      {reviewer ? (
        <Link
          href="/review"
          className="text-sm text-muted transition-colors hover:text-accent"
        >
          Review entries
        </Link>
      ) : null}

      {/* The email is the only identifier a contributor has until profiles
          exist, so it is what the archive greets them with. `break-all` because
          a long address must not push the masthead wider than the page. */}
      <span className="max-w-full text-xs text-muted [overflow-wrap:anywhere]">
        {user.email}
      </span>

      <form action={signOut}>
        <button
          type="submit"
          className="text-sm text-accent transition-opacity hover:opacity-70"
        >
          Sign out
        </button>
      </form>
    </div>
  );
}
