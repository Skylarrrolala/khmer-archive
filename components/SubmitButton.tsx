"use client";

import { useFormStatus } from "react-dom";

/**
 * A submit button that disables itself while its form's Server Action runs.
 *
 * This exists because of a real failure. Signing up takes a few seconds —
 * Supabase sends the confirmation email before it answers — and a plain button
 * gives no sign that anything is happening, so people click again. Every click
 * is queued and sent as its own sign-up, Supabase refuses the repeats with its
 * email rate limit, and the last refusal is what lands on screen: a sign-up
 * that worked reads as one that failed.
 *
 * `useFormStatus` reads the state of the <form> this button sits inside, which
 * is why it has to be its own component (01-app/02-guides/forms.md, "Pending
 * states"). The form around it stays a Server Component and still submits with
 * JavaScript disabled; without JavaScript the button simply never disables.
 *
 * A disabled submit button also blocks implicit submission, so pressing Enter
 * in a field while the request is in flight does not queue another one either.
 */
export function SubmitButton({
  label,
  pendingLabel,
  className,
}: {
  label: string;
  pendingLabel: string;
  className?: string;
}) {
  const { pending } = useFormStatus();

  return (
    <button type="submit" disabled={pending} className={className}>
      {pending ? pendingLabel : label}
    </button>
  );
}
