import { ViewTransition, type ReactNode } from "react";

/**
 * Marks a dessert's photo frame as one object across pages, so opening an
 * entry carries its photo from the card in the grid to the large frame on the
 * detail page — and back again — instead of one vanishing and another
 * appearing somewhere else.
 *
 * The browser does the animation. Two elements on consecutive pages that share
 * a view-transition name are treated as the same thing, and it tweens the
 * frame's size and position between them (the `.morph` rules in
 * app/globals.css). Both ends of the pair render this component, so the name
 * and the props below cannot drift apart. That matters more than it looks: the
 * pair silently stops animating if one side loses `share`.
 *
 * `default="none"` keeps each photo out of every other transition on the page.
 * Without it, every named frame on the grid would run its own crossfade
 * whenever anything at all changed.
 *
 * The frame is named rather than the <img>, so a dessert with no photo —
 * NoPhotoPanel inside the same frame — travels the same way.
 */
export function EntryPhotoTransition({
  entryId,
  children,
}: {
  entryId: string;
  children: ReactNode;
}) {
  return (
    <ViewTransition
      name={`entry-photo-${entryId}`}
      share="morph"
      default="none"
    >
      {children}
    </ViewTransition>
  );
}
