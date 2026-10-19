import type { Metadata } from "next";

import { signUp } from "@/app/(auth)/actions";
import { AuthForm } from "@/components/AuthForm";
import { authErrorMessage } from "@/lib/auth-messages";
import { safeInternalPath } from "@/lib/safe-path";

export const metadata: Metadata = {
  title: "Create an account — The Khmer Living Archive",
};

/**
 * The sign-up page. Same shape as the log-in page — see the note there about
 * why `error` and `next` are treated as untrusted input.
 */
export default async function SignUpPage({
  searchParams,
}: {
  searchParams: Promise<{
    error?: string | string[];
    next?: string | string[];
  }>;
}) {
  const params = await searchParams;
  const first = (v: string | string[] | undefined) =>
    (Array.isArray(v) ? v[0] : v) ?? "";

  return (
    <AuthForm
      mode="signup"
      action={signUp}
      next={safeInternalPath(params.next)}
      error={authErrorMessage(first(params.error))}
    />
  );
}
