"use server";

import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { redirect } from "next/navigation";

import { authErrorKey, type AuthErrorKey } from "@/lib/auth-messages";
import { safeInternalPath } from "@/lib/safe-path";
import { createSupabaseServerClient } from "@/lib/supabase/server";

/**
 * Sign-up, log-in and log-out, as Server Actions.
 *
 * These are plain `<form action={...}>` handlers with no client component and
 * no React state anywhere — the same decision SearchBar makes, for the same
 * reasons: the whole flow works with JavaScript disabled, and there is no
 * second copy of the validation rules living in the browser.
 *
 * The cost of that choice is error reporting. Without `useActionState` there is
 * no in-memory place to put a message, so a failure redirects back to the form
 * with `?error=<key>`, and the page looks the key up in lib/auth-messages.ts.
 * Supabase's own wording never reaches the page; unexpected errors go to the
 * server log instead.
 *
 * Only a Server Action or a Route Handler may write cookies in the App Router,
 * which is precisely why sign-in lives here: `signInWithPassword` sets the
 * session cookies through the client built in lib/supabase/server.ts.
 */

/**
 * The message key for a Supabase Auth error. Errors a person can fix are
 * expected; anything else (an outage, a code this does not know) is logged
 * with what Supabase said, since the page will only say "try again".
 */
function refusal(step: string, error: { code?: string; status?: number; message: string }): AuthErrorKey {
  const key = authErrorKey(error);
  if (key === "unavailable") {
    console.error(`[auth] ${step} failed (${error.status ?? "no status"} ${error.code ?? "no code"}): ${error.message}`);
  }
  return key;
}

/** Bounce back to a form with the key of a message a person can act on. */
function backToForm(path: string, key: AuthErrorKey, next: string): never {
  const params = new URLSearchParams({ error: key });
  if (next !== "/") params.set("next", next);
  redirect(`${path}?${params.toString()}`);
}

export async function signIn(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const next = safeInternalPath(String(formData.get("next") ?? ""));

  if (!email || !password) {
    backToForm("/login", "missing_login", next);
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    /*
     * Supabase answers a bad email and a bad password with the same code,
     * `invalid_credentials`, and both get the same message. One that told the
     * two apart would tell an attacker which addresses have accounts here.
     */
    backToForm("/login", refusal("sign-in", error), next);
  }

  // The header renders the signed-in state, and it is on every route.
  revalidatePath("/", "layout");
  redirect(next);
}

export async function signUp(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const next = safeInternalPath(String(formData.get("next") ?? ""));

  if (!email || !password) {
    backToForm("/signup", "missing_signup", next);
  }

  /*
   * Checked here as well as in the `minlength` attribute on the input, because
   * the attribute is a convenience for the browser and disappears the moment
   * someone posts the form another way. Supabase's own floor is six; eight is
   * this project's.
   */
  if (password.length < 8) {
    backToForm("/signup", "short_password", next);
  }

  /*
   * Where the link in the confirmation email should land: /auth/confirm on the
   * same site the person signed up on, so a sign-up on the live site comes back
   * to the live site and one on localhost comes back to localhost. Without
   * this, Supabase uses the project's "Site URL" for every link.
   *
   * The Origin header is not taken on trust. Next.js refuses a Server Action
   * whose Origin does not match the Host it arrived on, and Supabase refuses
   * any redirect that is not the Site URL's host or on the project's Redirect
   * URLs allow-list — it falls back to the Site URL instead.
   */
  const origin = (await headers()).get("origin");
  const emailRedirectTo = origin
    ? `${origin}/auth/confirm?next=${encodeURIComponent(next)}`
    : undefined;

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { emailRedirectTo },
  });

  if (error) {
    /*
     * An address that already has an account ends where a new one does, on
     * "check your email", so this form cannot be used to find out who has an
     * account. Supabase does the same itself while email confirmation is on;
     * these codes are what it says when confirmation is off.
     */
    if (error.code === "user_already_exists" || error.code === "email_exists") {
      redirect("/login?pending=confirm");
    }
    backToForm("/signup", refusal("sign-up", error), next);
  }

  /*
   * A Supabase project with email confirmation switched on returns a user but
   * no session: the account exists and is not usable until the link in the
   * email is clicked. Saying so is better than redirecting to a page that
   * behaves as though nobody is logged in, which is what happens otherwise.
   */
  if (!data.session) {
    redirect("/login?pending=confirm");
  }

  revalidatePath("/", "layout");
  redirect(next);
}

export async function signOut() {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.signOut();

  // supabase-js clears this browser's session cookies even when the call to
  // revoke the session fails, so the person is signed out here either way.
  // What may not have happened is the server-side revocation: log it.
  if (error) console.error(`[auth] sign-out: session not revoked (${error.status ?? "no status"} ${error.code ?? "no code"}): ${error.message}`);

  revalidatePath("/", "layout");
  redirect("/");
}
