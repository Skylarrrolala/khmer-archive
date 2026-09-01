-- =============================================================================
-- DUMMY DEVELOPMENT DATA — DELETE BEFORE THE ARCHIVE IS TREATED AS FINAL.
--
-- These rows exist so the browse and search pages have something to render
-- before the real entries have been gathered. The dessert names are common
-- knowledge; the `told_by` and `description` fields are NOT real family
-- memories and are marked as placeholders so they can never be mistaken for
-- sourced material.
--
-- Every row is inserted with contributor_id = null (nobody owns sample data)
-- and status = 'published' so Sprint 1's public page has content.
--
-- To wipe them once real entries exist:
--   delete from public.entries where told_by like '[SAMPLE%';
-- =============================================================================

insert into public.entries
  (name_khmer, name_english, told_by, context, description, photo_url, status)
values
  (
    'នំអន្សមចេក',
    '[SAMPLE] Num Ansom Chek — banana sticky rice cake',
    '[SAMPLE DATA — replace with a real, credited source]',
    'Festival',
    '[SAMPLE DATA — placeholder text, not a real memory. Replace this with '
    'the story your grandparents actually tell about this dessert: when they '
    'make it, who taught them, and how it is prepared.]',
    '/sample-photo-placeholder.svg',
    'published'
  ),
  (
    'នំគម',
    '[SAMPLE] Num Kom — palm sugar filled rice dumpling',
    '[SAMPLE DATA — replace with a real, credited source]',
    'Special occasion',
    '[SAMPLE DATA — placeholder text, not a real memory. This row has no '
    'photo on purpose: it stands in for a dessert that is remembered but no '
    'longer made, which the archive supports.]',
    null,
    'published'
  ),
  (
    'បបរស្ករត្នោត',
    '[SAMPLE] Bobor Skor Tnaot — palm sugar rice pudding',
    '[SAMPLE DATA — replace with a real, credited source]',
    'Daily life',
    '[SAMPLE DATA — placeholder text, not a real memory. Replace before '
    'submitting or sharing this archive.]',
    null,
    'published'
  );
