import Link from "next/link";

import { FadeInImage } from "@/components/FadeInImage";
import { exhibitPhoto } from "@/lib/exhibit-records";
import { getHomepageExhibits } from "@/lib/homepage-exhibits";
import type { Entry } from "@/lib/types";

export function HomepageExhibition({ entries }: { entries: Entry[] }) {
  const exhibits = getHomepageExhibits(entries);

  return (
    <section aria-labelledby="collection-title" className="home-exhibition bg-lacquer">
      <div className="gallery-shell exhibition-intro">
        <div className="exhibition-copy">
          <p className="exhibition-eyebrow">Collection 01 · Across Cambodia</p>
          <h1 id="collection-title" lang="km" className="homepage-khmer-title font-khmer">
            នំខ្មែរ
          </h1>
          <p className="homepage-english-title font-display">
            Khmer Traditional Cakes &amp; Snacks
          </p>
          <p className="exhibition-lede">
            A living archive of Cambodia’s traditional cakes, snacks, and the
            stories behind them.
          </p>
        </div>

        {exhibits.length > 0 ? (
          <div className="exhibition-cabinet">
            <span aria-hidden="true" className="kbach-frieze exhibition-crown" />
            {exhibits.map((entry, index) => (
              <Link
                key={entry.id}
                href={`/entries/${entry.id}`}
                className={`exhibit-object ${index === 1 ? "exhibit-object--companion" : ""}`}
              >
                <figure>
                  <div className="exhibit-photograph ornament-frame">
                    <FadeInImage
                      src={exhibitPhoto(entry)?.src ?? entry.photo_url}
                      alt={exhibitPhoto(entry)?.alt ?? `${entry.name_english} (${entry.name_khmer})`}
                      fill
                      sizes="(max-width: 639px) 43vw, (max-width: 1023px) 26vw, 340px"
                      className="object-contain p-2 sm:p-4"
                      loading="eager"
                    />
                  </div>
                  <figcaption className="exhibit-label">
                    <span lang="km" className="block font-khmer">{entry.name_khmer}</span>
                    <span className="exhibit-english-name">{entry.name_english.split(" — ")[0]}</span>
                  </figcaption>
                </figure>
              </Link>
            ))}
            <p className="exhibition-evidence">
              Every record shows its sources, its photo credit and what is
              still unverified.
            </p>
          </div>
        ) : null}
        <div className="exhibition-context">
          <a href="#collection" className="exhibition-enter">
            <span className="nav-dual">
              <span lang="km">ចូលទស្សនាបណ្ដុំ</span>
              <span className="nav-english">Explore the collection</span>
            </span>
            <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M5 19 19 5M5 5h14v14" stroke="currentColor" strokeWidth="1.5" />
            </svg>
          </a>
        </div>
      </div>
    </section>
  );
}
