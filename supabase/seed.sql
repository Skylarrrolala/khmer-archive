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


-- =============================================================================
-- INTERNET-SOURCED ROWS — SOURCING NOT YET VERIFIED WITH FAMILY.
--
-- Five desserts added from general/internet knowledge so the archive has more
-- to show than the dummy rows above. Unlike those rows, the dessert names and
-- descriptions here are real; what is missing is the SOURCING. Every `told_by`
-- is marked '[SOURCE PENDING ...]' and must be replaced with a real person,
-- credited by name and with their permission, before the archive is final.
--
-- Three rows carry '[KHMER SCRIPT NOT CONFIRMED]' in name_khmer. The spelling
-- was not supplied and is deliberately NOT guessed: in a preservation archive
-- a wrong spelling is worse than a visible gap. That text renders as the card
-- headline until it is filled in. Same reasoning for '[NOT RECORDED]' in
-- context, on the rows where no occasion was given.
--
-- To find every row still awaiting sourcing:
--   select * from public.entries where told_by like '[SOURCE PENDING%';
-- =============================================================================

insert into public.entries
  (name_khmer, name_english, told_by, context, description, photo_url, status)
values
  (
    'នំអន្សមជ្រូក',
    'Num Ansom Chrouk — savoury pork and mung bean sticky rice cake',
    '[SOURCE PENDING — internet reference, not yet verified with family]',
    'Festival',
    'The savoury version of num ansom. Instead of banana, the sticky rice is '
    'filled with pork belly and mung bean, then wrapped and steamed. Made for '
    'Pchum Ben, Khmer New Year and weddings. [Internet reference — not yet '
    'verified with family.]',
    null,
    'published'
  ),
  (
    '[KHMER SCRIPT NOT CONFIRMED]',
    'Num Plae Ai — palm sugar sticky rice balls rolled in coconut',
    '[SOURCE PENDING — internet reference, not yet verified with family]',
    '[NOT RECORDED]',
    'Balls of glutinous rice dough with a palm sugar centre, boiled and then '
    'rolled in fresh grated coconut. The nickname "kill husband cake" comes '
    'from a Khmer folk legend; the dessert itself is perfectly safe to eat. '
    '[Internet reference — not yet verified with family. Khmer spelling still '
    'to be confirmed.]',
    null,
    'published'
  ),
  (
    '[KHMER SCRIPT NOT CONFIRMED]',
    'Num Korng — crispy fried rice-flour donuts',
    '[SOURCE PENDING — internet reference, not yet verified with family]',
    'Daily life',
    'Rings of rice-flour batter deep-fried until crisp. Sold by street '
    'vendors, often in the morning near schools. [Internet reference — not '
    'yet verified with family. Khmer spelling still to be confirmed.]',
    null,
    'published'
  ),
  (
    'នំអាកោរ',
    'Num Akor — steamed fermented rice cake with coconut cream filling',
    '[SOURCE PENDING — internet reference, not yet verified with family]',
    '[NOT RECORDED]',
    'A steamed cake made from fermented rice batter, with a coconut cream '
    'filling. [Internet reference — not yet verified with family.]',
    null,
    'published'
  ),
  (
    '[KHMER SCRIPT NOT CONFIRMED]',
    'Num Bot — mung bean glutinous rice dumpling in banana leaf',
    '[SOURCE PENDING — internet reference, not yet verified with family]',
    '[NOT RECORDED]',
    'A glutinous rice dumpling filled with mung bean paste, wrapped in banana '
    'leaves and folded into a pyramid shape. [Internet reference — not yet '
    'verified with family. Khmer spelling still to be confirmed.]',
    null,
    'published'
  );
