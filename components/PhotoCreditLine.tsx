import { photoCreditParts, type PhotoCredit } from "@/lib/exhibit-records";

/** A verified credit in the licence's required form, or the stated gap. */
export function PhotoCreditLine({ credit }: { credit?: PhotoCredit }) {
  if (!credit) {
    return (
      <span className="photo-credit-text">
        Photographer and reuse rights not yet established.
      </span>
    );
  }

  return (
    <span className="photo-credit-text">
      {photoCreditParts(credit).map((part, index) =>
        part.href ? <a key={index} href={part.href}>{part.text}</a> : part.text,
      )}
    </span>
  );
}
