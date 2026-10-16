import type { Metadata } from "next";

import { signIn } from "@/app/(auth)/actions";
import { AuthForm } from "@/components/AuthForm";
import { safeInternalPath } from "@/lib/auth";

export const metadata: Metadata = {
  title: "Sign in — The Khmer Living Archive",
};

/**
 * What to tell someone partway through confirming their email.
 *
 *   confirm    just signed up (from the sign-up action)
 *   confirmed  opened the email link in a browser that cannot finish signing
 *              them in (from /auth/confirm)
 *   expired    opened a link Supabase would not accept (from /auth/confirm)
 */
const NOTICES: Record<string, string> = {
  confirm:
    "Account created. Open the confirmation link we emailed you to finish signing up.",
  confirmed: "Your email is confirmed. Sign in to continue.",
  expired:
    "That confirmation link has expired or was already used. If you have confirmed your email, sign in; if not, sign up again for a new link.",
};

/**
 * The log-in page.
 *
 * `searchParams` is a Promise in the App Router and is awaited. Three values
 * arrive here, all of them from the URL and therefore untrusted:
 *
 *   error    a message from a failed attempt, put there by the server action
 *   pending  where an email confirmation stands — one of the NOTICES keys
 *   next     where to go once signed in
 *
 * `error` is rendered as text inside JSX, so React escapes it — a crafted
 * `?error=<script>` is displayed, not executed. `next` is never trusted here
 * either: it is passed back into the form and re-checked by `safeInternalPath` in the
 * action before any redirect uses it.
 */
export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{
    error?: string | string[];
    pending?: string | string[];
    next?: string | string[];
  }>;
}) {
  const params = await searchParams;
  const first = (v: string | string[] | undefined) =>
    (Array.isArray(v) ? v[0] : v) ?? "";

  const next = safeInternalPath(params.next);
  const error = first(params.error) || undefined;

  /*
   * `Object.hasOwn` rather than a bare lookup, because `pending` comes from the
   * URL: `?pending=constructor` would otherwise find Object's constructor on
   * the prototype and try to render a function.
   */
  const pending = first(params.pending);
  const notice = Object.hasOwn(NOTICES, pending) ? NOTICES[pending] : undefined;

  return (
    <AuthForm
      mode="login"
      action={signIn}
      next={next}
      error={error}
      notice={notice}
    />
  );
}
