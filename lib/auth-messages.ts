/**
 * What the sign-in and sign-up forms say when something goes wrong.
 *
 * The actions put a key from this table in the URL (`?error=credentials`),
 * never a sentence, and the page looks it up. So neither Supabase's own
 * wording nor text someone typed into a link can appear on the form. Kept
 * free of imports so `node --test` can load it.
 *
 * None of these may say whether an account exists. A wrong password and an
 * unknown address get the same message, and a sign-up for an address that
 * already has an account ends on the same notice as a new one (see signUp).
 */
export const AUTH_ERRORS = {
  missing_login: "Enter your email address and password.",
  missing_signup: "Enter an email address and a password.",
  short_password: "Use a password of at least 8 characters.",
  credentials: "That email address and password don't match. Check them and try again.",
  // Supabase reports this only once the password has been accepted, so it
  // tells nothing to someone guessing.
  unconfirmed: "Confirm your email address first: open the link we emailed you when you signed up.",
  weak_password:
    "Choose a stronger password: at least 8 characters, and not one that is common or has appeared in a data breach.",
  invalid_email: "That email address can't be used. Check it for typos, or use another address.",
  rate_limited: "Too many attempts in a short time. Wait a few minutes, then try again.",
  unavailable: "Something went wrong on our side. Please try again in a moment.",
} as const;

export type AuthErrorKey = keyof typeof AUTH_ERRORS;

/** The message for a key from the URL, or undefined for anything else. */
export function authErrorMessage(key: string): string | undefined {
  // hasOwn, because the key comes from the URL: "constructor" must not match.
  return Object.hasOwn(AUTH_ERRORS, key) ? AUTH_ERRORS[key as AuthErrorKey] : undefined;
}

/**
 * Which message fits an error from Supabase Auth: `code` is its error code
 * (supabase.com/docs/guides/auth/debugging/error-codes), `status` the HTTP
 * status. A server error or a network failure has no code.
 */
export function authErrorKey(error: { code?: string; status?: number }): AuthErrorKey {
  switch (error.code) {
    case "invalid_credentials":
      return "credentials";
    case "email_not_confirmed":
      return "unconfirmed";
    case "weak_password":
      return "weak_password";
    case "email_address_invalid":
    case "validation_failed":
      return "invalid_email";
    case "over_request_rate_limit":
    case "over_email_send_rate_limit":
      return "rate_limited";
  }
  return error.status === 429 ? "rate_limited" : "unavailable";
}
