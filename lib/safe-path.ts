/**
 * Reduces a `?next=` value to a path inside this app, or to "/".
 *
 * Both the auth pages and the auth actions call this, so there is one rule
 * rather than two that can drift apart. The action is the one that matters —
 * it runs immediately before `redirect()`, so nothing can navigate anywhere
 * this function has not approved. The pages call it as well so a hostile value
 * is never echoed into the form's hidden input or its footer link in the first
 * place.
 *
 * The value is resolved the way a browser will resolve it, and only kept if
 * it is still on this site afterwards. Checking the raw string for a leading
 * "//" is not enough, because a browser cleans a URL up before reading it: it
 * drops tabs and newlines and turns "\" into "/". So "/<tab>/evil.example"
 * passes a string check and still lands on evil.example. Letting the URL
 * parser do the resolving means the check sees what the browser will see.
 *
 * What is rejected, and why:
 *   "https://evil.example"   absolute URL — the classic open redirect, used to
 *                            borrow this domain's credibility for phishing
 *   "//evil.example"         protocol-relative; a browser reads it as a host
 *   "/\evil.example"         the backslash becomes a slash: "//evil.example"
 *   "/<tab>/evil.example"    the tab is dropped: "//evil.example" (also \n, \r)
 *   "/..//evil.example"      the ".." is resolved away: "//evil.example"
 *   anything not starting with "/"
 *
 * Kept free of imports so `node --test` can load it without Next.js.
 */

// A placeholder origin to resolve against. `.invalid` is reserved by RFC 2606,
// so it can never be a real site that a value might legitimately point at.
const PLACEHOLDER_ORIGIN = "http://safe-path.invalid";

export function safeInternalPath(raw: string | string[] | undefined): string {
  const value = (Array.isArray(raw) ? raw[0] : raw) ?? "";

  if (!value.startsWith("/")) return "/";

  let resolved: URL;
  try {
    resolved = new URL(value, PLACEHOLDER_ORIGIN);
  } catch {
    return "/";
  }

  if (resolved.origin !== PLACEHOLDER_ORIGIN) return "/";

  // Rebuilt from the parsed parts rather than returning `value`, so what gets
  // redirected to is the cleaned-up form, with no stray control characters.
  const path = `${resolved.pathname}${resolved.search}${resolved.hash}`;

  // Cleaning up can itself produce a leading "//": "/..//evil.example" stays
  // on this origin while it is being resolved, but its path comes out as
  // "//evil.example", which is a host the moment it is used as a redirect.
  // So the result is checked the same way as the input before it is trusted.
  if (path.startsWith("//")) return "/";
  if (new URL(path, PLACEHOLDER_ORIGIN).origin !== PLACEHOLDER_ORIGIN) return "/";

  return path;
}
