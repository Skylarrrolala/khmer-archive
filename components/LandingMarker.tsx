"use client";

import { useEffect } from "react";

/**
 * How long the landing sequence takes, from first paint to the last piece at
 * rest, with some margin. The latest piece to start is the sixth card, at
 * twelve staggers: 12 × 140ms + a 1200ms rise ≈ 2.9s (the `land*` rules at the
 * end of app/globals.css, and `--motion-stagger` / `--motion-land`). Stamping
 * any earlier would cut an animation off mid-flight, because the rules stop
 * matching. If those timings change, this has to follow.
 */
const LANDING_MS = 3400;

/**
 * Marks the landing as over, so it only ever plays on a first load.
 *
 * The landing animations are plain CSS, which is why they run with JavaScript
 * off. But CSS cannot tell a first load from a client-side navigation: both
 * put fresh elements on the page, and both would play the sequence. So every
 * landing rule is scoped to `html:not([data-landed])`, and this stamps
 * `data-landed` once the sequence has finished. From then on, moving around
 * the archive gets the quieter page transition instead.
 *
 * It lives in the root layout, which mounts once per document load and
 * survives navigations, so the timer runs exactly once. It renders nothing.
 */
export function LandingMarker() {
  useEffect(() => {
    const timer = setTimeout(() => {
      document.documentElement.dataset.landed = "";
    }, LANDING_MS);

    return () => clearTimeout(timer);
  }, []);

  return null;
}
