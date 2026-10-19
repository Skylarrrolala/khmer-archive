import assert from "node:assert/strict";
import { test } from "node:test";

import { AUTH_ERRORS, authErrorKey, authErrorMessage } from "../lib/auth-messages.ts";

test("Supabase's error codes map to messages a person can act on", () => {
  assert.equal(authErrorKey({ code: "invalid_credentials", status: 400 }), "credentials");
  assert.equal(authErrorKey({ code: "email_not_confirmed", status: 400 }), "unconfirmed");
  assert.equal(authErrorKey({ code: "weak_password", status: 422 }), "weak_password");
  assert.equal(authErrorKey({ code: "email_address_invalid", status: 400 }), "invalid_email");
  assert.equal(authErrorKey({ code: "over_request_rate_limit", status: 429 }), "rate_limited");
  assert.equal(authErrorKey({ code: "over_email_send_rate_limit", status: 429 }), "rate_limited");
  assert.equal(authErrorKey({ status: 429 }), "rate_limited", "a 429 without a code");
});

test("an outage, a network failure or an unknown code is 'try again', never Supabase's wording", () => {
  assert.equal(authErrorKey({ status: 503 }), "unavailable");
  assert.equal(authErrorKey({ status: 0 }), "unavailable");
  assert.equal(authErrorKey({ code: "something_new", status: 400 }), "unavailable");
});

test("only known keys show anything, so a crafted ?error= link shows nothing", () => {
  assert.equal(authErrorMessage("credentials"), AUTH_ERRORS.credentials);
  for (const crafted of ["Your account is locked. Call 555-0100.", "constructor", "__proto__", "toString", ""]) {
    assert.equal(authErrorMessage(crafted), undefined, crafted);
  }
});

test("no message says whether an account exists", () => {
  for (const message of Object.values(AUTH_ERRORS)) {
    assert.doesNotMatch(message, /no account|not registered|already (registered|exists|have an account)|does not exist|unknown (email|address|user)/i, message);
  }
});
