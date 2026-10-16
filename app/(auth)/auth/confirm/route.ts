import { redirect } from "next/navigation";
import type { NextRequest } from "next/server";

import { safeInternalPath } from "@/lib/safe-path";
import { createSupabaseServerClient } from "@/lib/supabase/server";

/**
 * Where the link in a confirmation email lands.
 *
 * Clicking that link takes the visitor to Supabase first, which marks the
 * email as confirmed and then sends them here with a one-time `code`. This
 * handler trades the code for a session, so a new contributor arrives signed
 * in rather than on a page that behaves as though nobody is.
 *
 * The trade needs a second half: when sign-up ran, @supabase/ssr stored a
 * secret "code verifier" in a cookie in the sign-up browser, and Supabase only
 * accepts the code together with it (PKCE). A link opened in a different
 * browser — the email app on a phone, say — has no such cookie, so the trade
 * fails there. By then the email is already confirmed, though, so the right
 * answer is "sign in", not an error.
 *
 * `sb_flow_id` is how newer Supabase clients say which stored verifier belongs
 * to this link. It is passed on when present; without it the client falls
 * back to the most recent one.
 */
export async function GET(request: NextRequest) {
  const params = request.nextUrl.searchParams;
  const code = params.get("code");
  const flowId = params.get("sb_flow_id") ?? undefined;

  // Re-checked here, not trusted from the link: anyone can craft one.
  const next = safeInternalPath(params.get("next") ?? "");

  /*
   * No code means Supabase could not use the link — most often it expired, or
   * it was already clicked once. Supabase describes the problem in the URL,
   * but that text is not shown: it would let anyone who crafts a link put
   * words of their choosing on this site's login page.
   */
  if (!code) redirect("/login?pending=expired");

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code, {
    flowId,
  });

  if (error) redirect("/login?pending=confirmed");

  redirect(next);
}
