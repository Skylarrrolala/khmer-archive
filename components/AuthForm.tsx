import Link from "next/link";

import { SubmitButton } from "@/components/SubmitButton";

/**
 * The sign-up / log-in form.
 *
 * One component for both, because the two differ in four strings and a server
 * action — duplicating them would mean two places to change the moment the
 * password rule or the field styling moves.
 *
 * No `"use client"`, no React state, no `useActionState`. It is a plain
 * `<form action={serverAction}>`, so it submits and validates with JavaScript
 * disabled, exactly like SearchBar. The consequence is that a failed attempt
 * comes back as a redirect carrying `?error=<key>`; the page turns the key
 * into the message that `error` renders.
 *
 * `autoComplete` is set deliberately: password managers key off these values,
 * and `new-password` on sign-up is what prompts one to offer a generated
 * password instead of reusing an existing one.
 */
export function AuthForm({
  mode,
  action,
  next,
  error,
  notice,
}: {
  mode: "login" | "signup";
  action: (formData: FormData) => void | Promise<void>;
  next: string;
  error?: string;
  notice?: string;
}) {
  const isLogin = mode === "login";

  return (
    <section className="mx-auto max-w-6xl px-6 py-16 lg:py-24">
      <div className="mx-auto max-w-md border border-line bg-card p-8 sm:p-10">
        <p className="text-xs uppercase tracking-[0.22em] text-muted">
          {isLogin ? "Contributor sign in" : "New contributor"}
        </p>

        <h1 className="mt-5 text-3xl uppercase leading-[1.1] tracking-[0.01em] text-accent">
          {isLogin ? "Welcome back." : "Join the archive."}
        </h1>

        <p className="mt-4 text-sm leading-relaxed text-muted">
          {isLogin
            ? "Sign in to submit a dessert and to see the entries you have already sent."
            : "An account lets you add a dessert to the public archive, and edit or delete the entries you add."}
        </p>

        {/* Rendered before the fields so a screen reader meets the problem on
            the way to the inputs rather than after them. `role="alert"` is not
            used: the message is present on first paint after the redirect, and
            an alert region announces changes, not initial content. */}
        {error ? (
          <p className="mt-6 border border-accent bg-accent-soft px-4 py-3 text-sm text-accent">
            {error}
          </p>
        ) : null}

        {notice ? (
          <p className="mt-6 border border-line bg-accent-soft px-4 py-3 text-sm text-ink">
            {notice}
          </p>
        ) : null}

        <form action={action} className="mt-8 space-y-5">
          {/* Where to go after authenticating. Carried through the form so it
              survives a failed attempt; the action re-checks that it is a
              same-site path before trusting it. */}
          <input type="hidden" name="next" value={next} />

          <div className="space-y-2">
            <label
              htmlFor="email"
              className="block text-xs uppercase tracking-[0.18em] text-muted"
            >
              Email address
            </label>
            <input
              id="email"
              name="email"
              type="email"
              required
              autoComplete="email"
              className="w-full border border-line bg-accent-soft px-4 py-3 text-ink transition-colors placeholder:text-muted focus:border-accent focus:outline-none"
            />
          </div>

          <div className="space-y-2">
            <label
              htmlFor="password"
              className="block text-xs uppercase tracking-[0.18em] text-muted"
            >
              Password
            </label>
            <input
              id="password"
              name="password"
              type="password"
              required
              minLength={isLogin ? undefined : 8}
              autoComplete={isLogin ? "current-password" : "new-password"}
              className="w-full border border-line bg-accent-soft px-4 py-3 text-ink transition-colors placeholder:text-muted focus:border-accent focus:outline-none"
            />
            {!isLogin ? (
              <p className="text-xs text-muted">At least 8 characters.</p>
            ) : null}
          </div>

          {/* The one client component on this page — see SubmitButton for
              why a repeat click here used to turn a successful sign-up into
              an error message. */}
          <SubmitButton
            label={isLogin ? "Sign in" : "Create account"}
            pendingLabel={isLogin ? "Signing in…" : "Creating account…"}
            className="w-full bg-accent px-6 py-3 text-xs uppercase tracking-[0.18em] text-on-accent transition-opacity hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:cursor-wait disabled:opacity-60"
          />
        </form>

        <p className="mt-8 border-t border-line pt-6 text-sm text-muted">
          {isLogin ? "No account yet? " : "Already have an account? "}
          <Link
            href={
              isLogin
                ? `/signup${next !== "/" ? `?next=${encodeURIComponent(next)}` : ""}`
                : `/login${next !== "/" ? `?next=${encodeURIComponent(next)}` : ""}`
            }
            className="text-accent hover:underline"
          >
            {isLogin ? "Create one" : "Sign in"}
          </Link>
        </p>
      </div>
    </section>
  );
}
