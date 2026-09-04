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
-- The first row now carries a real (internet-sourced) photograph instead of
-- the placeholder SVG. See the [PHOTO CREDIT PENDING ...] note in its
-- description — that image is not ours either.
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
    'make it, who taught them, and how it is prepared.] '
    '[PHOTO CREDIT PENDING — the photo on this entry is not ours. Replace '
    'it with a family photograph, or one that is licensed and credited, '
    'before this archive is shared.]',
    '/entries/num-ansom-chek.jpg',
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
-- The Khmer spellings and occasions were supplied by the project owner and
-- are filled in. What is still missing is the SOURCING: who told it, and
-- their permission to be credited.
--
-- The photos in public/entries/ are internet images, NOT family
-- photographs. Two of them still carry another photographer's camera in
-- their EXIF. Every row using one says so in its description, and they must
-- be replaced with family photographs — or with licensed, credited images —
-- before this archive is shared.
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
    'verified with family.] '
    '[PHOTO CREDIT PENDING — the photo on this entry is not ours. Replace '
    'it with a family photograph, or one that is licensed and credited, '
    'before this archive is shared.]',
    '/entries/num-ansom-chrouk.jpg',
    'published'
  ),
  (
    'នំផ្លែអាយ',
    'Num Plae Ai — palm sugar sticky rice balls rolled in coconut',
    '[SOURCE PENDING — internet reference, not yet verified with family]',
    'Daily life',
    'Balls of glutinous rice dough with a palm sugar centre, boiled and then '
    'rolled in fresh grated coconut. Mostly an everyday market snack or '
    'family dessert. The nickname "kill husband cake" comes from a Khmer '
    'folk legend; the dessert itself is perfectly safe to eat. The balls are '
    'also playfully associated with childbirth, because they pop up to the '
    'surface of the water as soon as they are cooked. '
    '[Internet reference — not yet verified with family.] '
    '[PHOTO CREDIT PENDING — the photo on this entry is not ours. Replace '
    'it with a family photograph, or one that is licensed and credited, '
    'before this archive is shared.]',
    '/entries/num-plae-ai.jpg',
    'published'
  ),
  (
    'នំកង',
    'Num Korng — crispy fried rice-flour donuts',
    '[SOURCE PENDING — internet reference, not yet verified with family]',
    'Daily life',
    'Rings of rice-flour batter deep-fried until crisp. Sold by street '
    'vendors, often in the morning near schools. [Internet reference — not '
    'yet verified with family.] '
    '[PHOTO CREDIT PENDING — the photo on this entry is not ours. Replace '
    'it with a family photograph, or one that is licensed and credited, '
    'before this archive is shared.]',
    '/entries/num-korng.jpg',
    'published'
  ),
  (
    'នំអាកោរ',
    'Num Akor — steamed palm sugar sponge cake topped with grated coconut',
    '[SOURCE PENDING — internet reference, not yet verified with family]',
    'Festival',
    'A fluffy, steamed palm-sugar sponge cake made from fermented rice '
    'flour, traditionally topped with freshly grated coconut. A staple for '
    'religious festivals, especially Pchum Ben and Khmer New Year, where it '
    'is offered to monks and ancestors. Also a standard morning market '
    'breakfast. [Internet reference — not yet verified with family.] '
    '[PHOTO CREDIT PENDING — the photo on this entry is not ours. Replace '
    'it with a family photograph, or one that is licensed and credited, '
    'before this archive is shared.]',
    '/entries/num-akor.jpg',
    'published'
  ),
  (
    'នំបត់',
    'Num Bot — mung bean glutinous rice dumpling in banana leaf',
    '[SOURCE PENDING — internet reference, not yet verified with family]',
    'Festival',
    'A glutinous rice dumpling filled with mung bean paste, wrapped in banana '
    'leaves and folded into a pyramid shape. Heavily tied to Pchum Ben, when '
    'they are made in large batches to take to the pagoda. '
    '[Internet reference — not yet verified with family.] '
    '[PHOTO CREDIT PENDING — the photo on this entry is not ours. Replace '
    'it with a family photograph, or one that is licensed and credited, '
    'before this archive is shared.]',
    '/entries/num-bot.jpg',
    'published'
  );
