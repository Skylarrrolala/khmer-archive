/**
 * Editorial records for published exhibits: the written references behind a
 * record, verified photo credits, and what is still unverified.
 *
 * The database has no fields for any of this (CLAUDE.md, data model), so it
 * lives here, reviewed in Git. The evidence for every line — claim-to-source
 * registers, quotes, licence pages — is in docs/v2/content/.
 *
 * Safety properties:
 * - The database is the only source of displayed text, so the page, search
 *   and every occasion always agree. A record never replaces stored words.
 * - Each record names the exact content it was checked against (`checked`) and
 *   attaches only while the row still says exactly that. An edit by a
 *   contributor, a re-created row or an unapplied content update matches
 *   nothing, and the page falls back to its honest disclosures; references are
 *   never presented as supporting text they were not checked against.
 * - A record only decorates a row the published-only query already returned,
 *   so it can never make anything public.
 * - Credits are keyed by image path, so a credit can never drift onto another
 *   image. A replacement `photo` applies only to ownerless researched rows.
 * - The `told_by` source marker stays in the database. Written references are
 *   shown as written research, never as oral testimony.
 *
 * The reviewed text reaches the database through
 * docs/v2/content/proposed-content-update.sql, which must match `checked`.
 * Regenerate it with `node scripts/generate-content-update.ts`;
 * tests/exhibit-records.test.ts fails if the two differ.
 */
import { hasUnattributedSource, isPlaceholder } from "./placeholders.ts";
import type { Entry } from "./types";

export type Reference = {
  title: string;
  /** Person or organisation responsible, when the source names one. */
  author?: string;
  publisher: string;
  /** As printed by the source; omitted when the source shows no date. */
  published?: string;
  url: string;
  /** Language of the source, for the `lang` attribute on its title. */
  lang: "en" | "km" | "fr";
  /** Plain-English summary of what this reference documents for the record. */
  supports: string;
};

export type PhotoCredit = {
  creator: string;
  title?: string;
  /** Page where the image and its licence are published. */
  sourceUrl: string;
  sourceName: string;
  licence: string;
  licenceUrl: string;
  /** What the archive changed, as the licence requires; e.g. "Resized". */
  modifications?: string;
};

export type Photograph = { width: number; height: number; credit?: PhotoCredit; alt?: string; caption?: string };

/**
 * A credit in the order Creative Commons asks for — title (when supplied),
 * creator, source, licence, and any modification — as text and link parts,
 * so the detail page can link them and the card can show the same words.
 */
export function photoCreditParts(credit: PhotoCredit): { text: string; href?: string }[] {
  return [
    { text: "Photo: " },
    ...(credit.title ? [{ text: `“${credit.title}” by ` }] : []),
    { text: credit.creator },
    { text: " / " },
    { text: credit.sourceName, href: credit.sourceUrl },
    { text: " — " },
    { text: credit.licence, href: credit.licenceUrl },
    { text: "." },
    ...(credit.modifications ? [{ text: ` ${credit.modifications}.` }] : []),
  ];
}

export type CheckedContent = Pick<Entry, "name_khmer" | "name_english" | "context" | "description">;

export type ExhibitRecord = {
  /** The row content these references were checked against, exactly. */
  checked: CheckedContent;
  references: Reference[];
  /** Short public statements of what remains unverified. */
  unresolved: string[];
  /** A rights-cleared replacement image from PHOTOGRAPHS. */
  photo?: string;
};

/** Natural size of every known image, and its credit once one is verified. */
export const PHOTOGRAPHS: Record<string, Photograph> = {
  "/entries/num-akor.jpg": {
    "width": 603,
    "height": 489,
    "credit": {
      "creator": "MoonsMoon",
      "title": "Khmer Cambodia cuisine dessert nom akor tnout.jpg",
      "sourceUrl": "https://commons.wikimedia.org/wiki/File:Khmer_Cambodia_cuisine_dessert_nom_akor_tnout.jpg",
      "sourceName": "Wikimedia Commons",
      "licence": "CC BY 4.0",
      "licenceUrl": "https://creativecommons.org/licenses/by/4.0/",
      "modifications": "Resized where needed and re-encoded; not cropped"
    }
  },
  "/entries/num-korng.jpg": {
    "width": 1280,
    "height": 960,
    "credit": {
      "creator": "Turaids",
      "title": "Num Krouch, Num Krong, and Num Pong Ansorng.jpg",
      "sourceUrl": "https://commons.wikimedia.org/wiki/File:Num_Krouch,_Num_Krong,_and_Num_Pong_Ansorng.jpg",
      "sourceName": "Wikimedia Commons",
      "licence": "CC BY-SA 4.0",
      "licenceUrl": "https://creativecommons.org/licenses/by-sa/4.0/",
      "modifications": "Resized where needed and re-encoded; not cropped"
    },
    "alt": "Market tray with num kong ring cakes, sesame balls and other snacks",
    "caption": "Mixed market-snack photograph: num kong ring cakes are among the foods pictured; this is not an exclusive photograph of num kong."
  },
  "/entries/num-plae-ai.jpg": {
    "width": 641,
    "height": 641,
    "credit": {
      "creator": "Hyzuko",
      "title": "Num Plae Ai.jpg",
      "sourceUrl": "https://commons.wikimedia.org/wiki/File:Num_Plae_Ai.jpg",
      "sourceName": "Wikimedia Commons",
      "licence": "CC BY-SA 4.0",
      "licenceUrl": "https://creativecommons.org/licenses/by-sa/4.0/",
      "modifications": "Resized where needed and re-encoded; not cropped"
    }
  },
  "/entries/num-ansom-chek.jpg": {
    "width": 1280,
    "height": 1271,
    "credit": {
      "creator": "MoonsMoon",
      "title": "Num ansom chek Khmer Cambodian dessert rice cake.jpg",
      "sourceUrl": "https://commons.wikimedia.org/wiki/File:Num_ansom_chek_Khmer_Cambodian_dessert_rice_cake.jpg",
      "sourceName": "Wikimedia Commons",
      "licence": "CC BY 4.0",
      "licenceUrl": "https://creativecommons.org/licenses/by/4.0/",
      "modifications": "Cropped to the wrapped cakes to exclude the printed sign; re-encoded"
    }
  },
  "/entries/num-ansom-chrouk.jpg": {
    "width": 562,
    "height": 387,
    "credit": {
      "creator": "វ៉ង់ វណ្ណលីដា",
      "title": "Num ansom chrouk.jpg",
      "sourceUrl": "https://commons.wikimedia.org/wiki/File:Num_ansom_chrouk.jpg",
      "sourceName": "Wikimedia Commons",
      "licence": "CC BY-SA 3.0",
      "licenceUrl": "https://creativecommons.org/licenses/by-sa/3.0/",
      "modifications": "Resized where needed and re-encoded; not cropped"
    }
  },
  "/entries/num-bot.jpg": {
    "width": 1280,
    "height": 960,
    "credit": {
      "creator": "Engsamnang",
      "title": "Num bot filling.jpg",
      "sourceUrl": "https://commons.wikimedia.org/wiki/File:Num_bot_filling.jpg",
      "sourceName": "Wikimedia Commons",
      "licence": "CC BY-SA 3.0",
      "licenceUrl": "https://creativecommons.org/licenses/by-sa/3.0/",
      "modifications": "Resized where needed and re-encoded; not cropped"
    },
    "alt": "Num bot filling made from coconut, palm sugar and roasted sesame seeds; not a finished cake",
    "caption": "Filling, not the finished cake. The Commons description lists coconut, palm sugar and roasted sesame seeds; it does not show the mung-bean filling described in this record."
  },
  "/entries/num-korm.jpg": {
    "width": 1280,
    "height": 1556,
    "credit": {
      "creator": "MoonsMoon",
      "title": "Num kom sticky rice cake Khmer Cambodian dessert.jpg",
      "sourceUrl": "https://commons.wikimedia.org/wiki/File:Num_kom_sticky_rice_cake_Khmer_Cambodian_dessert.jpg",
      "sourceName": "Wikimedia Commons",
      "licence": "CC BY 4.0",
      "licenceUrl": "https://creativecommons.org/licenses/by/4.0/",
      "modifications": "Resized where needed and re-encoded; not cropped"
    }
  }
};

// Shared sources. SEAlang's dictionary pages are served over plain HTTP.
const SEALANG = "http://sealang.net/khmer/search.pl?dict=khmer&orth=";
const PPP_2023: Reference = {
  title: "Traditional cakes capture capital hearts",
  author: "Kim Sarom",
  publisher: "The Phnom Penh Post, via Asia News Network",
  published: "2 August 2023",
  url: "https://asianews.network/traditional-cakes-capture-capital-hearts/",
  lang: "en",
  supports: "Num ansorm, num korm and num bort as banana-leaf-wrapped cakes served at prayer ceremonies and weddings, and still made commercially in Phnom Penh.",
};
const THMEY_THMEY_25: Reference = {
  title: "នំខ្មែរ ២៥មុខ ដែលពលរដ្ឋខ្មែរស្គាល់ និងពេញនិយមបរិភោគ",
  author: "Po Sophea",
  publisher: "Thmey Thmey 25",
  published: "12 August 2021",
  url: "https://thmeythmey25.com/detail/90698",
  lang: "km",
  supports: "A survey of 25 popular Khmer cakes: num kom's coconut and palm-sugar filling, and num bot's flat, steamed parcels sold in Phnom Penh markets.",
};
const AMS_NUM_ANSOM: Reference = {
  title: "នំអន្សម",
  publisher: "AMS Khmer Civilization",
  url: "https://khmercivilization.ams.com.kh/detail/36136",
  lang: "km",
  supports: "Num ansom set on the wedding offering tray with num kom or num bot, and the researchers' reading of the pair; notes the meaning cannot yet be explained precisely.",
};
const CAMBODGE_MAG_2026: Reference = {
  title: "Num Ansorm and Num Kom: Cambodia’s Sacred Rice Cakes of Body, Belief, and Tradition",
  publisher: "Cambodge Mag",
  published: "13 January 2026",
  url: "https://www.cambodgemag.com/en/post/num-ansorm-and-num-kom-cambodia-s-sacred-rice-cakes-of-body-belief-and-tradition",
  lang: "en",
  supports: "Offerings at Khmer New Year and Pchum Ben, use at weddings, and historian Sambo Manara’s reading of the two cakes as male and female.",
};
const KAMPUCHEA_THMEY_2021: Reference = {
  title: "ប្រវត្តិនៃការវេចនំអន្សម ជាប្រពៃណីដូនតាខ្មែរចោលមិនបាន ក្នុងពិធីបុណ្យភ្ជុំបិណ្ឌ",
  author: "Sang Sreyleak",
  publisher: "Kampuchea Thmey",
  published: "16 September 2021",
  url: "https://www.kampucheathmey.com/belief/199931",
  lang: "km",
  supports: "Num ansom, num kom and num bot wrapped and offered to monks around Pchum Ben.",
};

const CHUON_NATH_ANSOM: Reference = {
  title: "វចនានុក្រមខ្មែរ, entry អន្សម",
  author: "Chuon Nath",
  publisher: "Buddhist Institute, via SEAlang Library",
  published: "1967",
  url: `${SEALANG}%E1%9E%A2%E1%9E%93%E1%9F%92%E1%9E%9F%E1%9E%98`,
  lang: "km",
  supports: "Ansom as glutinous rice in fresh leaves, usually banana, cylindrical and cooked by boiling or grilling; ansom chek with a whole ripe nam va banana, ansom chrouk with pork.",
};
const CAMBODIANESS_2026: Reference = {
  title: "Who Will Teach the Next Generation to Make Num Ansom?",
  author: "Chea Socheata",
  publisher: "Cambodianess",
  published: "11 October 2026",
  url: "https://cambodianess.com/article/who-will-teach-the-next-generation-to-make-num-ansom",
  lang: "en",
  supports: "Families wrapping the cakes on the first days of Pchum Ben as offerings for monks; sweet or savoury fillings; a Ministry of Culture official on the Shiva link; a maker’s observation that country families are more likely to make them.",
};
const PPP_2017: Reference = {
  title: "Num Ansorm: the salacious street snack",
  publisher: "The Phnom Penh Post",
  published: "2017",
  url: "https://phnompenhpost.com/national/num-ansorm-salacious-street-snack/",
  lang: "en",
  supports: "Historian Sambo Manara on num ansom and num kom as male and female and as mother and father; temple offerings at Khmer New Year and Pchum Ben; the cakes grilled, fried or steamed.",
};
const VICE_2016: Reference = {
  title: "Cambodian Ghosts Love Sticky Rice Cakes",
  author: "Nathan A. Thompson",
  publisher: "Vice",
  published: "25 April 2016",
  url: "https://www.vice.com/en/article/cambodian-ghosts-love-sticky-rice-cakes/",
  lang: "en",
  supports: "A village making pork and mung bean cakes for Pchum Ben: the logs boiled for hours in a large pot, and offerings passing to the dead through the monks.",
};

export const RECORDS: Record<string, ExhibitRecord> = {
  // Num Ansom Chek. Evidence: docs/v2/content/research-num-ansom.md
  "0164e482-97a6-405b-bdc1-28635971b617": {
    checked: {
      name_khmer: "នំអន្សមចេក",
      name_english: "Num Ansorm Chek — banana sticky rice cake",
      context: "Pchum Ben · Khmer New Year · Weddings",
      description:
        "Num ansom chek is a cylinder of glutinous rice wrapped in banana leaf around a whole ripe chek nam va, the Thai banana. The Khmer dictionary of Chuon Nath defines ansom as a cake of glutinous rice wrapped in fresh leaves, usually banana, round and even at both ends, and cooked by boiling or grilling; the banana version is the first of the kinds it lists.\n\n" +
        "The tightly bound logs cook for several hours in a large pot of boiling water, the leaf keeping the water out so that the rice cooks in its own steam. The work takes time and many hands, and the same dictionary records the saying “ten people, and the ansom burns” for a crowd that still cannot get a job done.\n\n" +
        "Num ansom is closely tied to Pchum Ben. On the first days of the festival, families gather to wrap the cakes as offerings for Buddhist monks, made on behalf of departed relatives, and to share with household and friends. It is also made for Khmer New Year and for weddings. Voices quoted in the Cambodian press, among them a Ministry of Culture official, link the cylindrical ansom and its pyramid-shaped partner num kom to the Hindu god Shiva and his consort; the historian Sambo Manara describes the pair as representing mother and father.\n\n" +
        "A maker quoted in 2026 observed that families in the countryside are more likely than city families to make the cakes at home.",
    },
    references: [
      CHUON_NATH_ANSOM,
      {
        title: "វចនានុក្រមខ្មែរ, entry ដប់",
        author: "Chuon Nath",
        publisher: "Buddhist Institute, via SEAlang Library",
        published: "1967",
        url: `${SEALANG}%E1%9E%8A%E1%9E%94%E1%9F%8B`,
        lang: "km",
        supports: "The proverb “ten people, and the ansom burns”, for many hands that get nothing done.",
      },
      CAMBODIANESS_2026,
      {
        title: "The Hindu Influence on Cambodian Cakes during Pchum Ben",
        author: "Ky Soklim",
        publisher: "Cambodianess",
        published: "7 October 2023",
        url: "https://cambodianess.com/article/the-hindu-influence-on-cambodian-cakes-during-pchum-ben",
        lang: "en",
        supports: "Researcher Heang Rith on the Hindu symbolism of the cakes; num ansom at weddings, engagements and Khmer New Year.",
      },
      PPP_2017,
      VICE_2016,
      {
        title: "Caring for the Dead Ritually in Cambodia",
        author: "John Clifford Holt",
        publisher: "Southeast Asian Studies 1 (1), Kyoto University",
        published: "2012",
        url: "https://englishkyoto-seas.org/wp-content/uploads/010101.pdf",
        lang: "en",
        supports: "Context for Pchum Ben: food offered to monks on behalf of departed kin. It does not discuss num ansom itself.",
      },
      {
        title: "Thai banana",
        publisher: "Wikipedia",
        url: "https://en.wikipedia.org/wiki/Thai_banana",
        lang: "en",
        supports: "Chek nam va as the Thai banana favoured in Cambodia (a general reference).",
      },
    ],
    unresolved: [
      "How long the cakes are boiled: reports range from about three hours to tending the fire through a day or night.",
      "Whether the rice in this version is seasoned with coconut milk and sugar.",
      "The male and female, and mother and father, readings come from interviews in the press; no academic source has been consulted for them.",
      "Whether the photograph shows a banana-filled ansom: its filling has not been confirmed.",
    ],
  },

  // Num Ansom Chrouk. Evidence: docs/v2/content/research-num-ansom.md
  "c730fdea-fc93-44a2-ba82-4bf926ba61de": {
    checked: {
      name_khmer: "នំអន្សមជ្រូក",
      name_english: "Num Ansorm Chrouk — savoury pork and mung bean sticky rice cake",
      context: "Pchum Ben · A savoury num",
      description:
        "Num ansom chrouk is the savoury form of num ansom: glutinous rice and mung beans wrapped in banana leaf around a core of pork and bound into a cylinder. The Khmer dictionary of Chuon Nath lists it among the kinds of ansom, defining it simply as ansom with pork at its centre, beside the banana-filled ansom chek.\n\n" +
        "It belongs in a collection of Khmer cakes and snacks by Khmer usage rather than taste. Num, the word that begins its name, is the dictionary’s term for cakes made from rice or flour, moist or dry, counted among snacks and sweets of every kind; Cambodian reporting describes num ansom as made with either savoury or sweet fillings.\n\n" +
        "Like the banana version, the logs cook for several hours in a pot of boiling water. Pork and mung bean ansom are wrapped for Pchum Ben, when cakes are offered to monks on behalf of the dead, and slices are sometimes fried.\n\n" +
        "In 2021, officials in Stung Treng described their recipe as a hallmark of the province and considered registering it as a local speciality; the same report notes that the cake is also available in other provinces.",
    },
    references: [
      CHUON_NATH_ANSOM,
      {
        title: "វចនានុក្រមខ្មែរ, entry នំ",
        author: "Chuon Nath",
        publisher: "Buddhist Institute, via SEAlang Library",
        published: "1967",
        url: `${SEALANG}%E1%9E%93%E1%9F%86`,
        lang: "km",
        supports: "Num as food made from rice or flour, moist or dry, counted among snacks and sweets of every kind.",
      },
      CAMBODIANESS_2026,
      VICE_2016,
      PPP_2017,
      {
        title: "S Treng eyes sticky rice cake status",
        publisher: "The Phnom Penh Post",
        published: "21 October 2021",
        url: "https://phnompenhpost.com/national/stung-treng-eyes-sticky-rice-cake-status/",
        lang: "en",
        supports: "Stung Treng officials calling their ansom chrouk recipe a hallmark of the province; the cake available in other provinces.",
      },
    ],
    unresolved: [
      "How the pork and mung beans are seasoned: no well-sourced recipe was consulted.",
      "Whether Stung Treng’s registration as a local speciality was completed.",
      "Whether the photograph shows pork and mung bean ansom: its filling has not been confirmed.",
    ],
  },

  // Num Plae Ai. Evidence: docs/v2/content/research-num-plae-ai-num-kroch.md
  "31d7fcb7-5d07-4cff-aeee-e40444e2653b": {
    checked: {
      name_khmer: "នំផ្លែអាយ",
      name_english: "Num Plae Ai — palm sugar sticky rice balls with fresh coconut",
      context: "Everyday snack",
      description:
        "Num plae ai (នំផ្លែអាយ) is a small sweet of glutinous rice dough wrapped around a lump of palm sugar. The Khmer dictionary of Chuon Nath describes the sugar as hidden from sight inside the dough, and gives the sweet three names: num bompuon skor, “the cake that hides the sugar”, which it calls the original and most literal; num plae ai; and, less often, num kaet kdei.\n\n" +
        "The dictionary also records explanations handed down by elders. Num plae ai, roughly “fruit of this side”, is said to go back to the reign of King Ang Duong in the nineteenth century, when the cakes were fixed in rows on branches set into a length of banana trunk, so that they looked like a fruiting tree close at hand rather than fruit picked from a tree over there.\n\n" +
        "Num kaet kdei, “the lawsuit cake”, comes from a tale of two men eating the sweets face to face. One bit a cake in half, the syrup squirted into the other’s eye, and the quarrel that followed ended before a judge. The dictionary adds that no one knows when this happened.\n\n" +
        "In recipes published today, the filled balls are boiled, cooled and rolled in grated coconut. Recipe writers describe num plae ai as an everyday snack, and one notes roadside vendors selling it in Phnom Penh.",
    },
    references: [
      {
        title: "វចនានុក្រមខ្មែរ, entry ផ្លែអាយ",
        author: "Chuon Nath",
        publisher: "Buddhist Institute, via SEAlang Library",
        published: "1967",
        url: `${SEALANG}%E1%9E%95%E1%9F%92%E1%9E%9B%E1%9F%82%E1%9E%A2%E1%9E%B6%E1%9E%99`,
        lang: "km",
        supports: "The name num plae ai and the elders’ account of cakes fixed on branches in the reign of King Ang Duong; num bompuon skor as the original name.",
      },
      {
        title: "វចនានុក្រមខ្មែរ, entry កើតក្តី",
        author: "Chuon Nath",
        publisher: "Buddhist Institute, via SEAlang Library",
        published: "1967",
        url: `${SEALANG}%E1%9E%80%E1%9E%BE%E1%9E%8F%E1%9E%80%E1%9F%92%E1%9E%8F%E1%9E%B8`,
        lang: "km",
        supports: "The name num kaet kdei and the tale of the squirting syrup and the judge, told by elders and undated.",
      },
      {
        title: "Modern Cambodian-English Dictionary, entry នំផ្លែអាយ",
        author: "Robert K. Headley, Rath Chim and Ok Soeum",
        publisher: "Dunwoody Press, via SEAlang Library",
        published: "1997",
        url: `${SEALANG}%E1%9E%93%E1%9F%86%E1%9E%95%E1%9F%92%E1%9E%9B%E1%9F%82%E1%9E%A2%E1%9E%B6%E1%9E%99`,
        lang: "en",
        supports: "A piece of sugar wrapped in a layer of sticky rice flour; ai as “here, on this side”.",
      },
      {
        title: "Num plae ai",
        publisher: "Wikipedia",
        url: "https://en.wikipedia.org/wiki/Num_plae_ai",
        lang: "en",
        supports: "The balls boiled, cooled and garnished with grated coconut, citing published Cambodian cookbooks (a general reference).",
      },
      {
        title: "Ang Duong",
        publisher: "Wikipedia",
        url: "https://en.wikipedia.org/wiki/Ang_Duong",
        lang: "en",
        supports: "Identifies the throne title named in the dictionary as King Ang Duong’s (a general reference).",
      },
      {
        title: "Cambodia: Nom Plae Ai",
        author: "Nisha Ramesh",
        publisher: "196 Flavors",
        published: "25 June 2018",
        url: "https://www.196flavors.com/cambodia-nom-plae-ai/",
        lang: "en",
        supports: "Roadside vendors in Phnom Penh; also the earliest source found for the “husband-killing” nickname, which it calls speculation.",
      },
    ],
    unresolved: [
      "Any festival or ceremonial use: none is documented in the sources consulted.",
      "The nickname “husband-killing cake” (num samlap pdei), repeated in English-language blogs since 2018, has not been found in any Khmer source.",
      "The custom in King Ang Duong’s reign is recorded as what elders relate; no independent historical source was found.",
      "Any regional association.",
    ],
  },

  // Num Kroch: a contributor's own entry, so its text is theirs. References only.
  // Evidence: docs/v2/content/research-num-plae-ai-num-kroch.md
  "7a6a74d7-4c12-4857-a1a7-ccda1d39c165": {
    checked: {
      name_khmer: "នំក្រូច",
      name_english: "Num Kroch",
      context: "Everyday snack",
      description: "a traditional Cambodian fried sesame ball dessert that are sweet and heart warming",
    },
    references: [
      {
        title: "Modern Cambodian-English Dictionary, entry នំក្រូច",
        author: "Robert K. Headley, Rath Chim and Ok Soeum",
        publisher: "Dunwoody Press, via SEAlang Library",
        published: "1997",
        url: `${SEALANG}%E1%9E%93%E1%9F%86%E1%9E%80%E1%9F%92%E1%9E%9A%E1%9E%BC%E1%9E%85`,
        lang: "en",
        supports: "A fried cake stuffed with sweet mung beans and covered with sesame seed; kroch as citrus, orange.",
      },
      {
        title: "Picture of the Day: Num Kroch, Cambodia’s Golden Sesame Treats",
        author: "Wonders of Cambodia; photograph by Pascal Médeville",
        publisher: "Cambodianess",
        published: "23 October 2026",
        url: "https://cambodianess.com/article/picture-of-the-day-num-kroch-cambodias-golden-sesame-treats",
        lang: "en",
        supports: "The Khmer name, the sesame coating, and a culinary connection with Chinese jian dui.",
      },
    ],
    unresolved: [
      "Whether the name refers to the sweet’s orange-like shape: only one recipe blog says so.",
      "How num kroch came to Cambodia: a connection with Chinese jian dui is noted, but its history is undocumented.",
    ],
  },

  // Num Kong. Evidence: docs/v2/content/research-num-kong-num-akor.md
  "19242196-86ef-44df-bb46-b16c7e6431e4": {
    checked: {
      name_khmer: "នំកង",
      name_english: "Num Kong — crispy fried rice-flour donuts with palm sugar glaze",
      context: "Everyday street and market sweet",
      description:
        "Num kong is a Cambodian fried ring cake. A dough of glutinous rice flour, sometimes with a little ordinary rice flour and, in the recipes consulted, bound with coconut milk, is rolled into ropes, looped into rings and deep-fried until golden. The rings are then coated in palm sugar cooked down to a dark caramel and scattered with sesame seeds, which gives them their glossy, honey-coloured finish.\n\n" +
        "In Khmer, kang is the everyday word for a ring or bracelet, and the cakes are ring-shaped, although no published source examined explains the name directly. In English the cake is also written num kang, noum kong and nom korng.\n\n" +
        "Published accounts describe num kong as an everyday street dessert, sold from stalls and by vendors in Phnom Penh; the sources consulted do not mention its use at festivals or ceremonies. One recent account notes the cake’s Chinese roots.",
    },
    references: [
      {
        title: "Picture of the Day: Num Kang, Cambodia’s Sweet Sesame Rice Cakes",
        author: "Wonders of Cambodia; photograph by Pascal Médeville",
        publisher: "Cambodianess",
        published: "20 October 2026",
        url: "https://cambodianess.com/article/picture-of-the-day-num-kang-cambodias-sweet-sesame-rice-cakes",
        lang: "en",
        supports: "The Khmer name នំកង, the ring shape and glossy sesame finish, its place in everyday life, and its Chinese roots.",
      },
      {
        title: "Traditional Cambodian Donuts Recipe",
        publisher: "Royal Embassy of Cambodia in London, recipe credited to Neal Khmer Cakes",
        published: "11 February 2022",
        url: "https://www.cambodiaembassyuk.org/?p=6393",
        lang: "en",
        supports: "Glutinous and rice flour bound with coconut milk, shaped into rings, deep-fried and coated in caramelised sugar and sesame; a street dessert.",
      },
      {
        title: "Recipe: Noum Kong, Cambodian doughnut",
        author: "Coin gourmand",
        publisher: "Cambodge Mag",
        published: "25 August 2025",
        url: "https://www.cambodgemag.com/en/post/recipe-noum-kong-cambodian-doughnut",
        lang: "en",
        supports: "Sold at street stalls and by vendors in Phnom Penh; toasted sesame; the spelling noum kong.",
      },
      {
        title: "Cambodian-English Dictionary and វចនានុក្រមខ្មែរ, entry កង",
        author: "Robert K. Headley et al.; Chuon Nath",
        publisher: "Dunwoody Press; Buddhist Institute; via SEAlang Library",
        published: "1997; 1967",
        url: `${SEALANG}%E1%9E%80%E1%9E%84`,
        lang: "en",
        supports: "Kang as a ring, bracelet or anklet: the meaning of the word, not an explanation of the cake’s name.",
      },
    ],
    unresolved: [
      "Any regional association beyond its sale in Phnom Penh.",
      "Whether the name means ring (កង) or wheel (កង់), as one writer’s “bicycle wheel cake” suggests.",
      "Its Chinese roots rest on a single short source.",
      "Any festival or ceremonial use.",
    ],
  },

  // Recorded as Num Kor; documented as Num Akor Thnot. Evidence: docs/v2/content/research-num-kong-num-akor.md
  "10793f27-f7b5-4db0-937d-7438c573634a": {
    checked: {
      name_khmer: "នំអាកោត្នោត",
      name_english: "Num Akor Thnot — steamed palm-fruit rice cake",
      context: "Palm-fruit season, reported May to October · Market and street sweet",
      description:
        "Num akor thnot (នំអាកោត្នោត) is the palm-fruit form of num akor, a small steamed cake. The Khmer dictionary of Chuon Nath defines akor as a cake leavened and steamed in cups so that it rises light, and akor thnot as the version made by mixing the flesh of ripe sugar-palm fruit with flour and sugar.\n\n" +
        "The sugar palm, Borassus flabellifer, was named Cambodia’s national tree by royal decree in 2005. For this cake the fruit is left until its skin turns dark brown and orange, and the fibrous pulp is worked into a batter of rice flour, coconut cream and yeast. The light-orange batter is spooned into small cups folded from banana leaf and steamed, swelling as it cooks, and is finished with coconut cream or grated coconut.\n\n" +
        "Because it depends on ripe fruit, the cake follows the fruit season, reported as May to October, rather than the dry-season tapping of palm sap for sugar, which runs from about December to May.\n\n" +
        "Akor thnot is sold by street vendors and in markets, including at Oudong in Kampong Speu province. A 2021 report from Prey Veng describes steamed palm cakes sold at Neak Loeung market and ordered in quantity for weddings and ceremonies.",
    },
    references: [
      {
        title: "វចនានុក្រមខ្មែរ, entry អាកោ",
        author: "Chuon Nath",
        publisher: "Buddhist Institute, via SEAlang Library",
        published: "1967",
        url: `${SEALANG}%E1%9E%A2%E1%9E%B6%E1%9E%80%E1%9F%84`,
        lang: "km",
        supports: "Akor as a leavened cake steamed in cups; akor thnot made with the flesh of ripe sugar-palm fruit, flour and sugar.",
      },
      {
        title: "Modern Cambodian-English Dictionary, entry នំអាកោ",
        author: "Robert K. Headley, Rath Chim and Ok Soeum",
        publisher: "Dunwoody Press, via SEAlang Library",
        published: "1997",
        url: `${SEALANG}%E1%9E%93%E1%9F%86%E1%9E%A2%E1%9E%B6%E1%9E%80%E1%9F%84`,
        lang: "en",
        supports: "A steamed cake of rice flour, yeast, sugar and coconut, steamed in small cups.",
      },
      {
        title: "Akao tnaot : gâteau cambodgien à la pulpe du fruit du borasse",
        author: "Pascal Médeville",
        publisher: "Le Petit Journal Cambodge",
        published: "3 June 2022",
        url: "https://lepetitjournal.com/cambodge/comprendre-cambodge/akao-tnaot-gateau-cambodgien-pulpe-fruit-borasse-339396",
        lang: "fr",
        supports: "The ripe fruit, the batter of rice flour, coconut cream and yeast, the banana-leaf cups, the orange colour, and sale at Oudong market.",
      },
      {
        title: "Royal Decree NS/RKT/0305/149 on the Designation of Animals and Plants as National Symbols (unofficial translation)",
        publisher: "Forestry Administration, Cambodia, via the Internet Archive",
        published: "2005",
        url: "https://web.archive.org/web/20070630215053/http://www.forestry.gov.kh/Documents/ROYAL-DECREE-ENG.pdf",
        lang: "en",
        supports: "The sugar palm, Borassus flabellifer, as Cambodia’s national tree.",
      },
      {
        title: "Application for the registration of the Protected Geographical Indication “Skor Thnot Kampong Speu”",
        author: "Kampong Speu Palm Sugar Promotion Association",
        publisher: "GOV.UK",
        published: "2017",
        url: "https://assets.publishing.service.gov.uk/media/66584f5016cf36f4d63ebc01/Kampong_Speu_Palm_Suga.pdf",
        lang: "en",
        supports: "Palm-sugar production from the sap of Borassus flabellifer between December and May.",
      },
      {
        title: "Resilient Grandma Supports Whole Family by Selling Steamed Palm Cakes",
        author: "Phat Dane",
        publisher: "Cambodianess",
        published: "26 July 2021",
        url: "https://cambodianess.com/article/resilient-grandma-supports-whole-family-by-selling-steamed-palm-cakes",
        lang: "en",
        supports: "Palm fruit ripening from May to October; steamed palm cakes sold at Neak Loeung market in Prey Veng and ordered for weddings and ceremonies.",
      },
    ],
    unresolved: [
      "Whether the sugar is palm sugar: the dictionaries say only sugar.",
      "Whether the steamed palm cakes reported from Prey Veng are akor thnot: the report gives no Khmer name.",
      "Any regional association beyond the markets named here.",
    ],
  },

  // Num Korm. Evidence: docs/v2/content/research-num-korm-num-bot.md
  "cd99961d-c893-4f65-ad10-4d86ad245983": {
    checked: {
      name_khmer: "នំគម",
      name_english: "Num Korm — palm sugar and coconut filled rice dumpling",
      context: "Pchum Ben and Khmer New Year offerings · Weddings, beside num ansom · Market sweet",
      description:
        "Num kom (នំគម, also written num korm) is a steamed cake of glutinous rice flour dough wrapped around a filling of grated coconut cooked with palm sugar; some recipes add sesame seeds. Each cake is enclosed in banana leaf and folded into a pyramid before steaming. Cambodian–English dictionaries record it as a pyramidal cake, often filled with sweetened coconut.\n\n" +
        "The name is descriptive. In the Khmer dictionary of the Supreme Patriarch Chuon Nath, kom means hunched, and the cake is defined as one shaped like a hunched back. The same entry allows a sweetened bean filling in place of coconut.\n\n" +
        "Num kom belongs to ritual as well as to the market. It is among the leaf-wrapped cakes offered to monks for Pchum Ben and Khmer New Year, and it appears at weddings beside num ansom, the cylindrical rice cake. A Cambodian historian and several Khmer writers read the pair as female and male; the reading is widely repeated, but it is an interpretation rather than a documented origin.\n\n" +
        "It is sold in Phnom Penh’s markets and by makers who supply hotels and restaurants.",
    },
    references: [
      {
        title: "Cambodian-English Dictionary, entry នំគម",
        author: "Robert K. Headley et al.",
        publisher: "Catholic University of America Press, via SEAlang Library",
        published: "1977",
        url: `${SEALANG}%E1%9E%93%E1%9F%86%E1%9E%82%E1%9E%98`,
        lang: "en",
        supports: "The name and its pronunciation; a pyramidal cake often filled with sweetened coconut.",
      },
      {
        title: "វចនានុក្រមខ្មែរ, entry គម",
        author: "Chuon Nath",
        publisher: "Buddhist Institute, via SEAlang Library",
        published: "1967",
        url: `${SEALANG}%E1%9E%82%E1%9E%98`,
        lang: "km",
        supports: "Kom as “hunched”; the cake shaped like a hunched back, of glutinous flour with a coconut or sweetened bean filling, leaf-wrapped and steamed.",
      },
      THMEY_THMEY_25,
      KAMPUCHEA_THMEY_2021,
      CAMBODGE_MAG_2026,
      PPP_2023,
      AMS_NUM_ANSOM,
    ],
    unresolved: [
      "Any regional association: no source found links num kom to a particular province.",
      "Whether sesame is a traditional ingredient or a later addition to some recipes.",
      "The male and female reading of num kom and num ansom is an interpretation; its origin is undocumented.",
    ],
  },

  // Num Bot. Evidence: docs/v2/content/research-num-korm-num-bot.md
  "0edd4f19-cf3e-417d-a2c7-4aba6e9fd6b9": {
    checked: {
      name_khmer: "នំបត់",
      name_english: "Num Bot — folded mung bean glutinous rice dumpling",
      context: "Pchum Ben offerings to monks · Weddings, beside num ansom · Market cake in Phnom Penh",
      description:
        "Num bot (នំបត់, also romanised num bort) is a steamed cake of glutinous rice flour enclosing a mung bean filling, wrapped in banana leaf. The Modern Cambodian–English Dictionary describes the filling as salted mung beans, and a Khmer-language survey of popular cakes describes the parcels as flat. In Khmer, bot means to fold or bend, and Chuon Nath’s dictionary gives “to fold a leaf” as an example; no source consulted explains how the cake came by its name.\n\n" +
        "Num bot is closely related to num kom. The two are listed side by side among the cakes wrapped and offered to monks around Pchum Ben, and at weddings either may be set beside num ansom on the offering tray. Some popular writing treats the two names as one cake; the dictionaries list them separately.\n\n" +
        "Sources do not describe num bot as rare. In 2021 it was reported as mostly sold in markets and served at ceremonies in Phnom Penh, and in 2023 a Phnom Penh maker listed it among his wrapped cakes.",
    },
    references: [
      {
        title: "Modern Cambodian-English Dictionary, entry នំបត់",
        author: "Robert K. Headley, Rath Chim and Ok Soeum",
        publisher: "Dunwoody Press, via SEAlang Library",
        published: "1997",
        url: `${SEALANG}%E1%9E%93%E1%9F%86%E1%9E%94%E1%9E%8F%E1%9F%8B`,
        lang: "en",
        supports: "Num bot as a cake of sticky rice flour filled with salted mung beans and wrapped in banana leaves.",
      },
      {
        title: "វចនានុក្រមខ្មែរ, entry បត់",
        author: "Chuon Nath",
        publisher: "Buddhist Institute, via SEAlang Library",
        published: "1967",
        url: `${SEALANG}%E1%9E%94%E1%9E%8F%E1%9F%8B`,
        lang: "km",
        supports: "Bot as “to fold”, with “to fold a leaf” among its examples.",
      },
      THMEY_THMEY_25,
      KAMPUCHEA_THMEY_2021,
      AMS_NUM_ANSOM,
      PPP_2023,
    ],
    unresolved: [
      "Whether num bot is usually sweet or salted: the dictionary records salted mung beans.",
      "The photograph may not show num bot: several parcels are pyramid-shaped, the form dictionaries give for num kom.",
      "How the cake came by its name, and any regional association.",
    ],
  },
};

/** The record for this row, only while the row says exactly what was checked. */
export function getExhibitRecord(entry: Entry): ExhibitRecord | undefined {
  const record = Object.hasOwn(RECORDS, entry.id) ? RECORDS[entry.id] : undefined;
  if (!record) return undefined;
  const { checked } = record;
  const unchanged =
    entry.name_khmer === checked.name_khmer &&
    entry.name_english === checked.name_english &&
    entry.context === checked.context &&
    entry.description === checked.description;
  return unchanged ? record : undefined;
}

/** An ownerless researched row, which no one can edit through the app. */
export const isResearchedRow = (entry: Entry) => entry.contributor_id === null;

/**
 * One line on where a record's knowledge comes from, or null when there is no
 * gap to state. Oral source and written research are separate questions: a
 * named person is a recorded source whether or not references were checked,
 * and references never stand in for a person who has not been named.
 */
export function provenanceSummary(entry: Entry): string | null {
  const count = getExhibitRecord(entry)?.references.length ?? 0;
  const noun = count === 1 ? "reference" : "references";
  const written = count
    ? `${isResearchedRow(entry) ? "Researched from" : "Checked against"} ${count} published ${noun}`
    : null;
  const oral = isPlaceholder(entry.told_by)
    ? written ? "no oral source recorded yet" : "Source pending verification"
    : hasUnattributedSource(entry.told_by)
      ? written ? "source not yet named" : "Source not yet named"
      : null;
  return [written, oral].filter(Boolean).join(" · ") || null;
}

/** The image to show for an entry, with its size and credit when known. */
/** Withhold only this existing contributor photo until reuse permission is confirmed. */
export function isPhotoWithheld(entry: Entry): boolean {
  return entry.id === "7a6a74d7-4c12-4857-a1a7-ccda1d39c165" &&
    Boolean(entry.photo_url?.endsWith("/61fe1754-18f6-46ff-b3ef-6b7dd1ac79a2/b5834c0d-8f2b-4aa7-bece-7449401bce9c.jpg"));
}

export function exhibitPhoto(entry: Entry): ({ src: string } & Partial<Photograph>) | null {
  if (isPhotoWithheld(entry)) return null;
  const replacement = getExhibitRecord(entry)?.photo;
  const src = replacement && isResearchedRow(entry) ? replacement : entry.photo_url;
  if (!src) return null;
  return { src, ...(Object.hasOwn(PHOTOGRAPHS, src) ? PHOTOGRAPHS[src] : {}) };
}
