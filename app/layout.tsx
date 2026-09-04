import type { Metadata } from "next";
import { Noto_Sans, Noto_Sans_Khmer } from "next/font/google";
import Link from "next/link";

import "./globals.css";

/*
 * next/font downloads these at build time and self-hosts them, so there is no
 * request to Google at runtime and no layout shift while a font loads.
 *
 * Noto Sans Khmer is here because Khmer script is the primary content of the
 * archive; without a font that covers the script, many machines fall back to
 * tofu boxes. Each font is exposed as a CSS variable that `globals.css` wires
 * into the `--font-sans` / `--font-khmer` tokens.
 */
const latin = Noto_Sans({
  variable: "--font-noto-latin",
  subsets: ["latin"],
  display: "swap",
});

const khmer = Noto_Sans_Khmer({
  variable: "--font-noto-khmer",
  subsets: ["khmer"],
  display: "swap",
});

/** Next.js turns this into <title> and <meta name="description"> automatically. */
export const metadata: Metadata = {
  /* Latin first in the <title>: browser tabs render with system fonts, not
     the Noto Sans Khmer that next/font loads for the page, and a machine
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
    <html lang="en" className={`${latin.variable} ${khmer.variable}`}>
      <body className="min-h-screen font-sans antialiased">
        {/* A terracotta-to-gold hairline across the top. Purely decorative,
            which is the only role `gold` is allowed in this palette — at
            2.6:1 on paper it is far too low-contrast to carry text. */}
        <div
          aria-hidden="true"
          className="h-1 bg-gradient-to-r from-accent via-gold to-accent"
        />

        <header className="border-b border-line bg-card">
          <div className="mx-auto max-w-6xl px-4 py-8">
            {/*
              The wordmark leads with the Khmer, the same order the entry cards
              use: នំ is the thing being archived, and "Num" is the gloss for a
              reader who cannot yet read the script.

              `items-baseline` rather than `items-center` so the two sit on a
              shared baseline despite the size difference, and the generous
              leading keeps the nikahit (ំ) above ន from being clipped.
            */}
            <Link href="/" className="inline-flex items-baseline gap-3">
              <span className="font-khmer text-4xl leading-[1.7] text-accent">
                នំ
              </span>
              <span className="text-2xl font-semibold tracking-tight text-ink">
                Num
              </span>
            </Link>
            <p className="mt-1 text-sm text-muted">
              The Khmer Living Archive — traditional desserts, remembered and
              recorded.
            </p>
          </div>
        </header>

        <main className="mx-auto max-w-6xl px-4 py-8">{children}</main>

        <footer className="mx-auto max-w-6xl border-t border-line px-4 py-6 text-sm text-muted">
          Every entry is credited to the person who shared it, with their
          permission.
        </footer>
      </body>
    </html>
  );
}
