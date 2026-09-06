import type { Metadata } from "next";

import { signIn } from "@/app/(auth)/actions";
import { AuthForm } from "@/components/AuthForm";

export const metadata: Metadata = {
  title: "Sign in — The Khmer Living Archive",
};

/**
 * The log-in page.
 *
 * `searchParams` is a Promise in the App Router and is awaited. Three values
 * arrive here, all of them from the URL and therefore untrusted:
 *
 *   error    a message from a failed attempt, put there by the server action
 *   pending  set to "confirm" after a sign-up that needs an email confirmed
 *   next     where to go once signed in
 *
 * `error` is rendered as text inside JSX, so React escapes it — a crafted
 * `?error=<script>` is displayed, not executed. `next` is never trusted here
 * either: it is passed back into the form and re-checked by `safeNext` in the
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

  const next = first(params.next) || "/";
  const error = first(params.error) || undefined;
  const notice =
    first(params.pending) === "confirm"
      ? "Account created. Check your email for a confirmation link, then sign in."
      : undefined;

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
