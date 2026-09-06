-- =============================================================================
-- THE SEVEN DESSERTS — RESEARCHED CONTENT, SOURCING STILL OUTSTANDING.
--
-- What is real here: the dessert names, the Khmer spellings, the ingredients,
-- the preparation methods, the occasions and the regions. These are written up
-- from research and general knowledge, and they are safe to show.
--
-- What is NOT here, on purpose: family testimony. An earlier draft of this
-- content carried first-person passages ("Grandmother recalls sitting under
-- the stilt house...") attributed to a named relative. Those are composed
-- rather than transcribed, so they are not in this file. Writing them in would
-- have put words in a real person's mouth in a public archive, which is the
-- one thing the sourcing rule in CLAUDE.md exists to prevent.
--
-- Every `told_by` therefore holds '[SOURCE PENDING ...]'. The UI reads that
-- marker through lib/placeholders.ts and renders it as a "Source pending
-- verification" badge, so a visitor sees a stated gap rather than a false
-- claim. Replace each one with a real person, credited by name and with their
-- permission, after you have actually sat down with them — at which point the
-- memory they tell you belongs in the description too.
--
-- Photographs: provenance is not established for all of these. Before the
-- archive is treated as final, confirm each image is either a family
-- photograph or licensed and credited.
--
-- `created_at` is set explicitly rather than left to default. now() is
-- constant within a transaction, so every row inserted by one statement would
-- otherwise share a timestamp and the browse order (created_at desc) would be
-- arbitrary. The offsets below make the grid read 01..07 in the order of the
-- source document.
--
-- To find rows still awaiting a source:
--   select name_english from public.entries where told_by like '[SOURCE PENDING%';
-- =============================================================================

-- Clear the previously seeded rows before re-inserting, so running this file
-- twice does not leave two copies of every dessert in the archive.
--
-- `contributor_id is null` is precisely "rows nobody submitted" — seed data.
-- A real contributor's entry always carries their auth user id (Sprint 2), so
-- this cannot touch anything a person actually wrote. It is still a delete:
-- read it before you run it.
delete from public.entries where contributor_id is null;

insert into public.entries
  (name_khmer, name_english, told_by, context, description, photo_url, status, created_at)
values
  (
    'នំអន្សមចេក',
    'Num Ansorm Chek — banana sticky rice cake',
    '[SOURCE PENDING — researched, not yet confirmed with family]',
    'Festival (Pchum Ben, Khmer New Year) / Religious ceremony',
    'A steamed cake of glutinous rice, sweet baby banana and rich coconut milk '
    'wrapped tightly in banana leaves. It is one of the most culturally '
    'significant items in Cambodian culinary heritage, woven into major '
    'ancestral and religious observances.' || chr(10) || chr(10) ||
    'The outer layer of glutinous rice is soft, chewy and rich from coconut '
    'cream, balanced by the fragrant sweetness of ripe chek nam wa (baby '
    'bananas) at the core, which turn a deep reddish-purple during the long '
    'steaming.' || chr(10) || chr(10) ||
    'INGREDIENTS' || chr(10) ||
    'Glutinous rice, ripe baby bananas (chek nam wa), fresh coconut milk, '
    'sugar, salt, fresh banana leaves, split bamboo string or raffia.' || chr(10) || chr(10) ||
    'PREPARATION' || chr(10) ||
    'Glutinous rice is soaked, washed and seasoned with coconut milk, salt and '
    'sugar. Bananas are peeled and placed in the centre of rice laid flat on '
    'wilted banana leaves. The leaf is rolled tightly into a dense cylinder, '
    'tucked at both ends and bound firmly with bamboo string. The logs are '
    'boiled continuously for six to eight hours.' || chr(10) || chr(10) ||
    'REGION' || chr(10) ||
    'Nationwide — Battambang, Siem Reap and the rural agrarian heartlands.' || chr(10) || chr(10) ||
    'NOTE' || chr(10) ||
    'The cylindrical shape is a traditional symbol of unity, strength and '
    'agricultural abundance, offered to monks and ancestors.',
    '/entries/num-ansom-chek.jpg',
    'published',
    now() - interval '1 minute'
  ),
  (
    'នំគម',
    'Num Korm — palm sugar and coconut filled rice dumpling',
    '[SOURCE PENDING — researched, not yet confirmed with family]',
    'Special occasion / Weddings / Religious ceremony',
    'A delicate, pyramid-shaped steamed dumpling of glutinous rice flour dough '
    'enclosing a sweet, aromatic filling of fresh grated coconut cooked with '
    'dark palm sugar.' || chr(10) || chr(10) ||
    'The outer rice flour skin is soft and pliable against the rich, chewy '
    'interior. Toasted sesame seeds in the filling lend a warm, nutty aroma '
    'that defines traditional Khmer confectionery technique.' || chr(10) || chr(10) ||
    'INGREDIENTS' || chr(10) ||
    'Glutinous rice flour, water, Kampong Speu palm sugar (skor tnot), freshly '
    'grated coconut, toasted white sesame seeds, banana leaves cut into '
    'triangles, coconut oil or lard for brushing.' || chr(10) || chr(10) ||
    'PREPARATION' || chr(10) ||
    'Glutinous rice flour is kneaded with water into a smooth dough. The '
    'filling is cooked down by caramelising palm sugar with fresh coconut and '
    'sesame seeds. Portioned dough balls are flattened, stuffed, wrapped into '
    'precise pyramidal parcels using oiled banana leaves, and steamed for '
    '20 to 25 minutes.' || chr(10) || chr(10) ||
    'REGION' || chr(10) ||
    'Kandal, Kampong Cham, and nationwide.' || chr(10) || chr(10) ||
    'NOTE' || chr(10) ||
    'The pyramid structure echoes the sacred stupas and architectural '
    'geometries found across ancient Khmer stone temples.',
    '/entries/num-korm.jpg',
    'published',
    now() - interval '2 minutes'
  ),
  (
    'នំអន្សមជ្រូក',
    'Num Ansorm Chrouk — savoury pork and mung bean sticky rice cake',
    '[SOURCE PENDING — researched, not yet confirmed with family]',
    'Festival (Pchum Ben, Khmer New Year) / Special occasion',
    'The savoury counterpart to Num Ansorm Chek: glutinous rice layered with '
    'seasoned split yellow mung beans and a central strip of black-pepper-'
    'marinated pork belly, steamed in banana leaf cylinders.' || chr(10) || chr(10) ||
    'Fat from the pork belly melts into the mung beans and rice during the long '
    'boil, giving a rich, savoury dumpling with a pungency from crushed Kampot '
    'black pepper.' || chr(10) || chr(10) ||
    'INGREDIENTS' || chr(10) ||
    'Glutinous rice, split yellow mung beans (soaked and hulled), pork belly in '
    'thick strips, black pepper, garlic, sea salt, fresh banana leaves, bamboo '
    'string.' || chr(10) || chr(10) ||
    'PREPARATION' || chr(10) ||
    'Rice is seasoned and layered over banana leaves, followed by steamed mung '
    'beans and pork belly strips marinated in pepper and salt. Wrapped into '
    'heavy cylindrical logs, bound tightly, and boiled for six to eight hours. '
    'Leftovers are sliced into thick wheels and pan-fried until golden and '
    'crisp.' || chr(10) || chr(10) ||
    'REGION' || chr(10) ||
    'Kampong Speu, Battambang, and nationwide.' || chr(10) || chr(10) ||
    'NOTE' || chr(10) ||
    'Illustrates the historic technique of preserving high-value meat cuts '
    'within a fat and rice medium for extended festival celebrations.',
    '/entries/num-ansom-chrouk.jpg',
    'published',
    now() - interval '3 minutes'
  ),
  (
    'នំផ្លែអាយ',
    'Num Plae Ai — palm sugar sticky rice balls with fresh coconut',
    '[SOURCE PENDING — researched, not yet confirmed with family]',
    'Daily life / Special occasion / Snack',
    'Small, bouncy glutinous rice dumplings stuffed with a solid cube of hard '
    'palm sugar, boiled until cooked, then rolled in freshly shaved coconut.' || chr(10) || chr(10) ||
    'The texture is springy and soft. Biting into a warm dumpling bursts the '
    'melted palm sugar inside, against the cool, savoury grated coconut '
    'outside.' || chr(10) || chr(10) ||
    'INGREDIENTS' || chr(10) ||
    'Glutinous rice flour, warm water, hard palm sugar cubes, freshly grated '
    'coconut, a pinch of sea salt.' || chr(10) || chr(10) ||
    'PREPARATION' || chr(10) ||
    'The dough is divided into small balls, hollowed with a thumb, stuffed with '
    'a palm sugar cube and sealed tightly. The balls are dropped into boiling '
    'water; once they float they are moved straight into cold water, then '
    'rolled in grated coconut mixed with sea salt.' || chr(10) || chr(10) ||
    'REGION' || chr(10) ||
    'Takeo, Phnom Penh, and nationwide.' || chr(10) || chr(10) ||
    'NOTE' || chr(10) ||
    'Folklore names this one num samlap pdei, the husband-killing cake — a '
    'warning never to eat one in a single warm bite, in case the hot liquid '
    'palm sugar squirts out. A street snack beloved for its short ingredient '
    'list and its play on temperature and texture.',
    '/entries/num-plae-ai.jpg',
    'published',
    now() - interval '4 minutes'
  ),
  (
    'នំកង',
    'Num Kong — crispy fried rice-flour donuts with palm sugar glaze',
    '[SOURCE PENDING — researched, not yet confirmed with family]',
    'Daily life / Afternoon tea / Market snack',
    'Traditional fried donuts made from rice flour and glutinous rice flour, '
    'shaped into rings, deep-fried until golden and coated with caramelised '
    'palm sugar and toasted sesame seeds.' || chr(10) || chr(10) ||
    'A crunchy golden shell over a tender, chewy interior. The dark palm sugar '
    'glaze adds a deep caramel flavour lifted by the nutty aroma of white '
    'sesame.' || chr(10) || chr(10) ||
    'INGREDIENTS' || chr(10) ||
    'Rice flour, glutinous rice flour, warm water, palm sugar syrup, white '
    'sesame seeds, oil for deep frying.' || chr(10) || chr(10) ||
    'PREPARATION' || chr(10) ||
    'The flours are mixed with warm water into a pliable dough, rolled into '
    'small ropes and looped into rings. They are fried until puffed and crisp. '
    'Palm sugar is caramelised separately into a thick glaze, drizzled over the '
    'donuts and finished with toasted sesame seeds.' || chr(10) || chr(10) ||
    'REGION' || chr(10) ||
    'Siem Reap, Kampong Chhnang, and market towns.' || chr(10) || chr(10) ||
    'NOTE' || chr(10) ||
    'Reflects everyday Cambodian market culture and a deep-frying tradition '
    'built on rice rather than wheat. Sold in the late afternoon by street '
    'vendors, wrapped in fresh lotus leaf.',
    '/entries/num-korng.jpg',
    'published',
    now() - interval '5 minutes'
  ),
  (
    'នំកោ',
    'Num Kor — steamed palm sugar cake topped with coconut',
    '[SOURCE PENDING — researched, not yet confirmed with family]',
    'Special occasion / Seasonal harvest / Daily life',
    'A light, airy steamed cake of rice flour, fragrant palm fruit pulp (tnot) '
    'and palm sugar, a vibrant orange-yellow crowned with fresh salted '
    'shredded coconut.' || chr(10) || chr(10) ||
    'Spongy, soft and moist, with a sweet, floral aroma that comes straight '
    'from mature palmyra palm fruit and unrefined palm sugar.' || chr(10) || chr(10) ||
    'INGREDIENTS' || chr(10) ||
    'Rice flour, mature toddy palm fruit pulp (tnot), unrefined palm sugar, '
    'coconut cream, a fermented rice starter or yeast, freshly shredded '
    'coconut, a pinch of salt.' || chr(10) || chr(10) ||
    'PREPARATION' || chr(10) ||
    'Rice flour is mixed with extracted palm fruit pulp, palm sugar and coconut '
    'cream, then left to ferment slightly for airiness. The batter is poured '
    'into small leaf cups or metal ramekins, steamed over high heat until risen '
    'and spongy, and sprinkled with salted grated coconut.' || chr(10) || chr(10) ||
    'REGION' || chr(10) ||
    'Kampong Speu and Takeo — the palm sugar producing heartlands.' || chr(10) || chr(10) ||
    'NOTE' || chr(10) ||
    'Shows the culinary use of Borassus flabellifer, the palmyra palm and '
    'Cambodia''s national tree, drawing on both the fruit pulp and the tree '
    'sap. Made in the dry season, when fresh toddy palm syrup comes in from '
    'the fields.',
    '/entries/num-akor.jpg',
    'published',
    now() - interval '6 minutes'
  ),
  (
    'នំបត់',
    'Num Bot — folded mung bean glutinous rice dumpling',
    '[SOURCE PENDING — researched, not yet confirmed with family]',
    'Special occasion / Religious ceremony offerings',
    'A folded dumpling of sweet mung bean paste enclosed in glutinous rice '
    'dough, wrapped into neat, flat rectangular banana leaf packets rather '
    'than rolled or tied.' || chr(10) || chr(10) ||
    'The texture is delicate and smooth: a rich, sweet mung bean interior '
    'infused with coconut inside soft rice dough.' || chr(10) || chr(10) ||
    'INGREDIENTS' || chr(10) ||
    'Glutinous rice flour, hulled split yellow mung beans, coconut cream, white '
    'sugar, salt, softened banana leaves.' || chr(10) || chr(10) ||
    'PREPARATION' || chr(10) ||
    'Mung beans are steamed, mashed and cooked down with coconut cream and '
    'sugar until thick. Small balls of bean paste are enveloped in glutinous '
    'rice dough, placed onto flat banana leaf sheets, folded into neat flat '
    'rectangles — bot means to fold — and steamed until glossy.' || chr(10) || chr(10) ||
    'REGION' || chr(10) ||
    'Battambang and Prey Veng.' || chr(10) || chr(10) ||
    'NOTE' || chr(10) ||
    'Rare today. Where Num Korm remains widely available, Num Bot with its flat '
    'fold geometry has largely gone from urban markets and survives in select '
    'rural communities. It demonstrates a specialised banana-leaf wrapping art '
    'that depends on folding rather than string-tying.',
    '/entries/num-bot.jpg',
    'published',
    now() - interval '7 minutes'
  );
