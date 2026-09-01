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
  title: "The Khmer Living Archive — Desserts",
  description:
    "A community archive of traditional Khmer desserts (nom), remembered and " +
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
        <header className="border-b border-line bg-card">
          <div className="mx-auto flex max-w-3xl flex-col gap-1 px-4 py-6">
            <Link href="/" className="text-xl font-semibold text-ink">
              The Khmer Living Archive
            </Link>
            <p className="text-sm text-muted">
              Traditional desserts (នំ), remembered and recorded.
            </p>
          </div>
        </header>

        <main className="mx-auto max-w-3xl px-4 py-8">{children}</main>

        <footer className="mx-auto max-w-3xl px-4 pb-10 text-sm text-muted">
          Every entry is credited to the person who shared it, with their
          permission.
        </footer>
      </body>
    </html>
  );
}
