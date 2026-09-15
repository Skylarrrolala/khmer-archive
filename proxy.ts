import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { isSupabaseConfigured, supabaseEnv } from "@/lib/env";

/**
 * Keeps the logged-in user's Supabase session alive.
 *
 * This file is called `proxy.ts`, not `middleware.ts`. The `middleware` file
 * convention is deprecated in Next.js 16 and renamed to `proxy` — same
 * behaviour, different file and export name. See
 * node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/proxy.md.
 *
 * What it does and, more importantly, what it does NOT do:
 *
 * Supabase access tokens are short-lived. The refresh token lives in a cookie,
 * and calling `getUser()` here exchanges it for a fresh access token and writes
 * the new cookies onto the response. Without this, a contributor's session
 * would quietly expire mid-visit and their own entries would stop loading.
 *
 * It is NOT the authorisation boundary. Next's own guidance is that a proxy
 * runs before the route and should be treated as an optimistic check only —
 * "it should not be your only line of defense in protecting your data"
 * (01-app/02-guides/authentication.md). This project has two real boundaries
 * behind it: the Row Level Security policies in
 * supabase/migrations/0001_init.sql, which are enforced by Postgres and cannot
 * be skipped by any client, and `requireUser()` in lib/auth.ts, which every
 * page needing a session calls for itself. So there is deliberately no
 * redirect logic in this file. Deleting it would log people out sooner than
 * they expect; it would not expose a single row.
 *
 * The response object is rebuilt inside `setAll` rather than mutated. That is
 * the pattern Supabase documents: the refreshed cookies have to be attached to
 * the response that is actually returned, and to the request that the route
 * about to render will read, or the two disagree for one navigation.
 */
export async function proxy(request: NextRequest) {
  // A deploy with no Supabase env vars should still serve the setup notice
  // rather than crash on every single request, including static assets.
  if (!isSupabaseConfigured()) return NextResponse.next({ request });

  const { url, publishableKey } = supabaseEnv();
  let response = NextResponse.next({ request });

  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value),
        );
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options),
        );
      },
    },
  });

  /*
   * `getUser()`, not `getSession()`. getSession() only decodes whatever is in
   * the cookie and trusts it; getUser() revalidates the token against
   * Supabase's auth server. On a refresh path that difference is the whole
   * point — a forged or stale cookie must not be renewed into a live session.
   */
  await supabase.auth.getUser();

  return response;
}

export const config = {
  /*
   * Everything except Next's own asset routes and image files. The auth guide
   * recommends running on all routes rather than a narrow allowlist, because a
   * session that only refreshes on some pages expires unpredictably on the
   * others.
   */
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
