/** Scoped to / so other pages keep their redirects and genuine 404 responses. */
export default function BrowseLoading() {
  return (
    <section className="gallery-shell py-12">
      <div className="threshold py-6">
        <p role="status" className="text-sm text-muted">Loading the collection…</p>
      </div>
    </section>
  );
}
