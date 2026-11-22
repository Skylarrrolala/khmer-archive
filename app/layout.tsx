import type { Metadata } from "next";
import { Fraunces, Kantumruy_Pro, Noto_Serif_Khmer } from "next/font/google";
import Link from "next/link";
import { ViewTransition } from "react";

import { AccountNav } from "@/components/AccountNav";
import { LandingMarker } from "@/components/LandingMarker";

import "./globals.css";

const body = Kantumruy_Pro({
  variable: "--font-kantumruy",
  subsets: ["latin", "khmer"],
  display: "swap",
});

const display = Fraunces({
  variable: "--font-fraunces",
  subsets: ["latin"],
  style: ["normal", "italic"],
  display: "swap",
});

const khmerDisplay = Noto_Serif_Khmer({
  variable: "--font-noto-serif-khmer",
  subsets: ["khmer"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Khmer Living Archive — Khmer Traditional Cakes & Snacks",
  description:
    "A living archive of Cambodia's traditional cakes, snacks, and the stories behind them.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="en"
      className={`${body.variable} ${display.variable} ${khmerDisplay.variable}`}
    >
      <body className="min-h-screen font-sans antialiased">
        <a href="#main-content" className="skip-link bg-card px-4 py-3 text-accent">
          Skip to content
        </a>
        <LandingMarker />

        <header className="archive-masthead bg-lacquer border-b border-line">
          <div className="gallery-shell archive-masthead-inner flex flex-wrap items-center justify-between gap-y-2 py-3 sm:py-5">
            <Link
              href="/"
              className="archive-brand min-w-0 py-1 font-display text-ink"
            >
              Khmer Living Archive
            </Link>
            <nav
              aria-label="Main navigation"
              className="museum-nav flex min-w-0 max-w-full flex-wrap items-center gap-x-6 gap-y-1 text-sm"
            >
              <Link href="/#collection" className="nav-dual text-muted hover:text-ink">
                <span lang="km">បណ្ដុំ</span>
                <span className="nav-english">Collection</span>
              </Link>
              <AccountNav />
            </nav>
          </div>
          <div aria-hidden="true" className="land-line h-px bg-gold" />
        </header>

        <ViewTransition default="none" update="page-fade">
          <main id="main-content" tabIndex={-1}>{children}</main>
        </ViewTransition>

        <footer className="bg-lacquer mt-8 border-t border-line">
          <div className="gallery-shell grid gap-4 py-10 text-sm sm:grid-cols-[1fr_2fr] sm:gap-12">
            <p className="font-display text-lg text-ink">
              <span lang="km" className="block font-khmer text-base leading-loose text-muted">បណ្ណសាររស់ខ្មែរ</span>
              Khmer Living Archive
            </p>
            <p className="max-w-prose leading-relaxed text-muted">
              A growing collection of Cambodia’s traditional cakes and snacks from across the country,
              begun with one family’s connection to Prey Veng. Each record
              states its sources, its photo credit and what is still unverified.
            </p>
          </div>
        </footer>
      </body>
    </html>
  );
}
