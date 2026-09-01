import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";

import { supabaseEnv } from "@/lib/env";

/**
 * Creates a Supabase client for use inside Server Components, Route Handlers
 * and Server Actions.
 *
 * Why `@supabase/ssr` and not plain `createClient`: Supabase keeps the logged-in
 * user's session in cookies. This wrapper hands Supabase a read/write view of
 * the Next.js cookie store, so a request made on the server carries the same
 * identity as the browser that sent it. That is what makes `auth.uid()` inside
 * the RLS policies resolve to the real user instead of null.
 *
 * On Sprint 1 there is no login yet, so every request is anonymous and the
 * policies treat it as `anon` — which can read published entries and nothing
 * else. The plumbing is here already so Sprint 2 does not have to rewrite it.
 *
 * This is a function, not a shared singleton, because each request has its own
 * cookies. Reusing one client across requests would leak one user's session
 * into another user's response.
 */
export async function createSupabaseServerClient() {
  const { url, anonKey } = supabaseEnv();
  const cookieStore = await cookies();

  return createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options),
          );
        } catch {
          // Server Components are not allowed to write cookies — only Route
          // Handlers and Server Actions are. Swallowing the error here is the
          // pattern Supabase documents: a refreshed token simply is not
          // persisted on a read-only render, and gets written on the next
          // action instead.
        }
      },
    },
  });
}
