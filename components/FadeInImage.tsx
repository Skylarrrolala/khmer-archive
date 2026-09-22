"use client";

import Image, { type ImageProps } from "next/image";
import { useCallback, useState } from "react";

/**
 * A next/image that fades in once its photo has arrived, instead of popping
 * onto an empty tile.
 *
 * The photo is only ever hidden by JavaScript, and only after JavaScript has
 * seen that it is not loaded yet. The server-rendered HTML shows it at full
 * opacity, so:
 *
 *   - with JavaScript off, photos appear exactly as they always did;
 *   - a photo that finished loading before the page hydrated is left alone,
 *     rather than hidden and faded in a second time;
 *   - the fade lands where the pop was worst — photos still arriving on a slow
 *     connection, and every photo after a client-side navigation, which mounts
 *     the next page's photos fresh.
 *
 * Hiding by default in CSS would have been shorter and worse: with JavaScript
 * off no photo would ever appear, and with it on every photo would wait for
 * hydration before it could be seen at all.
 *
 * A photo that fails to load is revealed too, so the browser can show its alt
 * text in place of the picture, as it did before.
 *
 * The fade's curve comes from the theme in app/globals.css, and visitors who
 * ask their system for reduced motion get no fade.
 */
export function FadeInImage({
  alt,
  className,
  onLoad,
  onError,
  ...props
}: ImageProps) {
  const [waiting, setWaiting] = useState(false);

  // A block body, not an arrow expression: React 19 treats a value returned
  // from a ref callback as its cleanup function.
  const checkLoaded = useCallback((img: HTMLImageElement | null) => {
    if (img && !img.complete) setWaiting(true);
  }, []);

  return (
    <Image
      {...props}
      // Named rather than left in the spread, so the accessibility lint can
      // see every photo still carries alt text.
      alt={alt}
      ref={checkLoaded}
      onLoad={(event) => {
        setWaiting(false);
        onLoad?.(event);
      }}
      onError={(event) => {
        setWaiting(false);
        onError?.(event);
      }}
      className={[
        className,
        "transition-opacity duration-(--motion-photo)",
        waiting && "opacity-0",
      ]
        .filter(Boolean)
        .join(" ")}
    />
  );
}
