import type { Metadata } from "next";
import { Fraunces, Kantumruy_Pro, Noto_Serif_Khmer } from "next/font/google";
import Link from "next/link";
import { ViewTransition } from "react";

import { AccountNav } from "@/components/AccountNav";

import "./globals.css";

/*
 * next/font downloads these at build time and self-hosts them, so there is no
 * request to Google at runtime and no layout shift while a font loads.
 *
 * Three families, two jobs:
 *
 *   Kantumruy Pro  body copy and UI chrome. It ships both Latin and Khmer, so
 *                  a Khmer word inside an English sentence keeps the same
 *                  proportions instead of switching typeface mid-line. It is
 *                  also drawn for Khmer first rather than extended into it.
 *   Fraunces       Latin display: entry names in English, the wordmark.
 *   Noto Serif Khmer
 *                  Khmer display, so the Khmer name of a dessert is set in a
 *                  serif that answers Fraunces. The archive previously used
 *                  Noto *Sans* Khmer for these, which read as a different
 *                  voice from the headline beside it.
 *
 * A font that covers Khmer is not optional here: without one, a machine with
 * no Khmer coverage renders the names as tofu boxes. Each family is exposed as
 * a CSS variable that `globals.css` wires into the `--font-sans`,
 * `--font-display` and `--font-khmer` tokens.
 */
const body = Kantumruy_Pro({
  variable: "--font-kantumruy",
  subsets: ["latin", "khmer"],
  display: "swap",
});

const display = Fraunces({
  variable: "--font-fraunces",
  subsets: ["latin"],
  /* The italic is not decoration: the section numerals (01 / 02 / 03) are set
     in it, on the cards and on the detail page's fields. */
  style: ["normal", "italic"],
  display: "swap",
});

const khmerDisplay = Noto_Serif_Khmer({
  variable: "--font-noto-serif-khmer",
  subsets: ["khmer"],
  display: "swap",
});

/** Next.js turns this into <title> and <meta name="description"> automatically. */
export const metadata: Metadata = {
  /* Latin first in the <title>: browser tabs render with system fonts, not
     the Khmer faces that next/font loads for the page, and a machine
     without Khmer coverage would show the tab as tofu boxes. */
  title: "Num (នំ) — The Khmer Living Archive",
  description:
    "A community archive of traditional Khmer desserts (num), remembered and " +
    "recorded with the people who make them.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="en"
      className={`${body.variable} ${display.variable} ${khmerDisplay.variable}`}
    >
      <body className="min-h-screen font-sans antialiased">
        {/* A gold hairline across the top of the maroon. Purely decorative,
            which is the role `gold` is allowed in this palette — on cream it
            measures 4.6:1, too close to the floor to carry paragraphs. */}
        <div
          aria-hidden="true"
          className="h-1 bg-gradient-to-r from-accent via-gold to-accent"
        />

        {/* Cream, so it reads as the top of the same sheet the hero is printed
            on rather than as a separate strip above it. The archive's name is
            the eyebrow of the band directly below, so it is not repeated here —
            the right-hand side carries the account state instead. */}
        <header className="bg-card">
          <div className="mx-auto flex max-w-6xl flex-wrap items-baseline justify-between gap-x-6 gap-y-3 px-6 py-5">
            {/*
              The wordmark leads with the Khmer, the same order the entry cards
              use: នំ is the thing being archived, and "Num" is the gloss for a
              reader who cannot yet read the script.

              `items-baseline` rather than `items-center` so the two sit on a
              shared baseline despite the size difference, and the generous
              leading keeps the nikahit (ំ) above ន from being clipped.
            */}
            <Link href="/" className="inline-flex items-baseline gap-3">
              <span className="font-khmer text-2xl leading-[1.7] text-accent">
                នំ
              </span>
              <span className="font-display text-lg italic tracking-tight text-ink">
                Num
              </span>
            </Link>

            <AccountNav />
          </div>
        </header>

        {/* No container here. Each page draws its own full-bleed cream and
            maroon bands, and a max-width on <main> would trap them in a
            column. The pages centre their own content instead.

            The ViewTransition is what makes a page change animate rather than
            cut: every navigation is a React transition, so when the page
            inside <main> changes, the new one rises in (the `page-fade` rules
            in globals.css). It wraps <main> rather than sitting in each page
            because this layout persists across navigations — the boundary
            stays and its contents update. The header and footer are outside
            it and hold still, so there is always something fixed to read the
            movement against. */}
        <ViewTransition default="none" update="page-fade">
          <main>{children}</main>
        </ViewTransition>

        <footer className="border-t border-line">
          <div className="mx-auto max-w-6xl px-6 py-10 text-sm text-muted">
            Every entry is credited to the person who shared it, with their
            permission.
          </div>
        </footer>
      </body>
    </html>
  );
}
