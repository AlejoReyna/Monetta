import { fingerprintOf } from '../crawl/fingerprint.js';
import {
  SOURCE_IDS,
  type CatalogProductRecord,
  type ExtractedProduct,
  type SourceId,
} from '../domain/types.js';

/** Minimum number of presentable products the API keeps for each US source. */
export const MINIMUM_PRODUCTS_PER_SOURCE = 10;

/** Sources that currently have a reviewed, dated fallback set. */
export const CURATED_SOURCE_IDS: readonly SourceId[] = [
  'coach_us',
  'michael_kors_us',
  'guess_us',
  'steve_madden_us',
];

/**
 * These records were checked against the brands' public US product pages on
 * 2026-08-12. They are a display fallback, not an inventory feed: prices are
 * USD snapshots and availability is deliberately unknown until a live US
 * crawl replaces the record.
 */
export const CURATED_US_CATALOG_OBSERVED_AT = new Date('2026-08-12T00:00:00.000Z');

export type CatalogDataOrigin = 'live_crawl' | 'curated_us_snapshot';

export interface PresentedCatalogProduct extends CatalogProductRecord {
  readonly dataOrigin: CatalogDataOrigin;
}

interface CuratedListing {
  readonly sourceId: SourceId;
  readonly item: ExtractedProduct;
}

const COACH_IMAGE_BASE = 'https://coach.scene7.com/is/image/Coach';
const MICHAEL_KORS_IMAGE_BASE = 'https://michaelkors.scene7.com/is/image/MichaelKors';
const GUESS_IMAGE_BASE =
  'https://img.guess.com/image/upload/f_auto,q_auto,fl_strip_profile,w_640,ar_2:3,c_fill/v1/NA/Style/ECOMM';

const LISTINGS: readonly CuratedListing[] = [
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CU068',
      canonicalUrl: 'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068.html',
      title: 'Brooklyn Shoulder Bag 28',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: `${COACH_IMAGE_BASE}/cu068_b4bk_a0`,
      priceUsd: 295,
      availability: 'unknown',
      variants: [
        {
          variantId: 'CU068:B4MPL',
          sku: 'CU068 B4MPL',
          colorName: 'Brass/Maple',
          colorCode: 'B4MPL',
          imageUrl: `${COACH_IMAGE_BASE}/cu068_b4mpl_a0`,
          priceUsd: 295,
          availability: 'inStock',
          detailUrl:
            'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068-B4MPL.html',
        },
        {
          variantId: 'CU068:B4BK',
          sku: 'CU068 B4/BK',
          colorName: 'Brass/Black',
          colorCode: 'B4BK',
          imageUrl: `${COACH_IMAGE_BASE}/cu068_b4bk_a0`,
          priceUsd: 295,
          availability: 'inStock',
          detailUrl:
            'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068-B4%2FBK.html',
        },
        {
          variantId: 'CU068:B4TF',
          sku: 'CU068 B4/TF',
          colorName: 'Brass/Toffee',
          colorCode: 'B4TF',
          imageUrl: `${COACH_IMAGE_BASE}/cu068_b4tf_a0`,
          priceUsd: 206.5,
          availability: 'inStock',
          detailUrl:
            'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068%20B4%2FTF.html',
        },
      ],
    },
  },
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CCU00',
      canonicalUrl: 'https://www.coach.com/products/brooklyn-shoulder-bag-34/CCU00.html',
      title: 'Brooklyn Shoulder Bag 34',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: `${COACH_IMAGE_BASE}/ccu00_b4bk_a0`,
      priceUsd: 395,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CDZ42',
      canonicalUrl: 'https://www.coach.com/products/brooklyn-shoulder-bag-28/CDZ42.html',
      title: 'Brooklyn Shoulder Bag 28 In Woven Leather',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      priceUsd: 237,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CDZ40',
      canonicalUrl: 'https://www.coach.com/products/brooklyn-shoulder-bag-34/CDZ40.html',
      title: 'Brooklyn Shoulder Bag 34 In Woven Straw',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      priceUsd: 245,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CEZ99',
      canonicalUrl:
        'https://www.coach.com/products/brooklyn-shoulder-bag-28-with-charms/CEZ99.html',
      title: 'Brooklyn Shoulder Bag 28 With Charms',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      priceUsd: 695,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CAM16',
      canonicalUrl: 'https://www.coach.com/products/jet-shoulder-bag/CAM16.html',
      title: 'Jet Shoulder Bag',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: `${COACH_IMAGE_BASE}/cam16_b4ha_a0`,
      priceUsd: 295,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CCE48',
      canonicalUrl: 'https://www.coach.com/products/ella-shoulder-bag/CCE48.html',
      title: 'Ella Shoulder Bag',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: `${COACH_IMAGE_BASE}/cce48_imse1_a0`,
      priceUsd: 179,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CY200',
      canonicalUrl:
        'https://www.coach.com/products/tabby-shoulder-bag-20-in-signature-canvas/CY200.html',
      title: 'Tabby Shoulder Bag 20 In Signature Canvas',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: `${COACH_IMAGE_BASE}/cy200_b4ydt_a0`,
      priceUsd: 350,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CR508',
      canonicalUrl: 'https://www.coach.com/products/jonie-bag/CR508.html',
      title: 'Jonie Bag',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: `${COACH_IMAGE_BASE}/cr508_b4pub_a0`,
      priceUsd: 250,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'coach_us',
    item: {
      externalId: 'CAQ86',
      canonicalUrl: 'https://www.coach.com/products/erin-shoulder-bag/CAQ86.html',
      title: 'Erin Shoulder Bag',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: `${COACH_IMAGE_BASE}/caq86_imblk_a0`,
      priceUsd: 279,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: '30F5GNXT0B',
      canonicalUrl:
        'https://www.michaelkors.com/hamilton-moderne-small-signature-logo-satchel/30F5GNXT0B.html',
      title: 'Hamilton Moderne Small Signature Logo Satchel',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: `${MICHAEL_KORS_IMAGE_BASE}/30F5GNXT0B-1335_1?$large$`,
      priceUsd: 279.5,
      availability: 'unknown',
      variants: [
        {
          variantId: '30F5GNXT0B:1546',
          sku: '30F5GNXT0B-1546',
          colorName: 'Vanilla/Acorn',
          colorCode: '1546',
          imageUrl: `${MICHAEL_KORS_IMAGE_BASE}/30F5GNXT0B-1546_1?$large$`,
          priceUsd: 279.5,
          availability: 'inStock',
          detailUrl:
            'https://www.michaelkors.com/hamilton-moderne-small-signature-logo-satchel/30F5GNXT0B.html?dwvar_30F5GNXT0B_color=1546',
        },
        {
          variantId: '30F5GNXT0B:1335',
          sku: '30F5GNXT0B-1335',
          colorName: 'Brown/Acorn',
          colorCode: '1335',
          imageUrl: `${MICHAEL_KORS_IMAGE_BASE}/30F5GNXT0B-1335_1?$large$`,
          priceUsd: 279.5,
          availability: 'inStock',
          detailUrl:
            'https://www.michaelkors.com/hamilton-moderne-small-signature-logo-satchel/30F5GNXT0B.html?dwvar_30F5GNXT0B_color=1335',
        },
      ],
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: '30F5GNXT0L',
      canonicalUrl:
        'https://www.michaelkors.com/hamilton-moderne-small-leather-satchel/30F5GNXT0L.html',
      title: 'Hamilton Moderne Small Leather Satchel',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: `${MICHAEL_KORS_IMAGE_BASE}/30F5GNXT0L-0001_1?$large$`,
      priceUsd: 279.5,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: '32R6GY5W6L',
      canonicalUrl:
        'https://www.michaelkors.com/nolita-medium-nubuck-chain-pochette/32R6GY5W6L.html',
      title: 'Nolita Medium Nubuck Chain Pochette',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: `${MICHAEL_KORS_IMAGE_BASE}/32R6GY5W6L-0001_1?$large$`,
      priceUsd: 199.5,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: '30F5GY5M6L',
      canonicalUrl:
        'https://www.michaelkors.com/nolita-medium-pebbled-leather-shoulder-bag/30F5GY5M6L.html',
      title: 'Nolita Medium Pebbled Leather Shoulder Bag',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: `${MICHAEL_KORS_IMAGE_BASE}/30F5GY5M6L-0001_1?$large$`,
      priceUsd: 299.5,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: '32S5SZCU1L',
      canonicalUrl:
        'https://www.michaelkors.com/zoe-small-pebbled-leather-pochette/32S5SZCU1L.html',
      title: 'Zoe Small Pebbled Leather Pochette',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: `${MICHAEL_KORS_IMAGE_BASE}/32S5SZCU1L-0001_1?$large$`,
      priceUsd: 99.5,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: '30T6A9IT0S',
      canonicalUrl:
        'https://www.michaelkors.com/laila-small-suede-shoulder-bag/30T6A9IT0S.html',
      title: 'Laila Small Suede Shoulder Bag',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: null,
      priceUsd: 199.5,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: '32S5S8QU1L',
      canonicalUrl:
        'https://www.michaelkors.com/kyla-small-leather-pochette/32S5S8QU1L.html',
      title: 'Kyla Small Leather Pochette',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: null,
      priceUsd: 83.4,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: '30T6G51T3S',
      canonicalUrl:
        'https://www.michaelkors.com/henly-large-leather-and-suede-tote-bag/30T6G51T3S.html',
      title: 'Henly Large Leather And Suede Tote Bag',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: null,
      priceUsd: 259.5,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: '32S6GQ1C0L',
      canonicalUrl:
        'https://www.michaelkors.com/jana-extra-small-leather-convertible-crossbody-bag/32S6GQ1C0L.html',
      title: 'Jana Extra-Small Leather Convertible Crossbody Bag',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: null,
      priceUsd: 89.4,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'michael_kors_us',
    item: {
      externalId: '30T6AUEM5L',
      canonicalUrl:
        'https://www.michaelkors.com/nolita-small-pebbled-leather-bucket-tote-bag/30T6AUEM5L.html',
      title: 'Nolita Small Pebbled Leather Bucket Tote Bag',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: `${MICHAEL_KORS_IMAGE_BASE}/30T6AUEM5L-0001_1?$large$`,
      priceUsd: 259.5,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'guess_us',
    item: {
      externalId: 'BS967218-LLU',
      canonicalUrl: 'https://www.guess.com/en-us/noelle-shoulder-bag-brown/BS967218-LLU.html',
      title: 'Noelle Shoulder Bag',
      brand: 'GUESS',
      category: 'Handbags',
      imageUrl: `${GUESS_IMAGE_BASE}/BS967218-LLU`,
      priceUsd: 68.6,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'guess_us',
    item: {
      externalId: 'QG973320-BLA',
      canonicalUrl:
        'https://www.guess.com/en-us/guess/women/bags/handbags/maxine-shoulder-bag-black/QG973320-BLA.html',
      title: 'Maxine Shoulder Bag',
      brand: 'GUESS',
      category: 'Handbags',
      imageUrl: `${GUESS_IMAGE_BASE}/QG973320-BLA`,
      priceUsd: 70.4,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'guess_us',
    item: {
      externalId: 'JG975521-BLO',
      canonicalUrl:
        'https://www.guess.com/en-us/guess/women/bags/handbags/audrey-logo-bag-black/JG975521-BLO.html',
      title: 'Audrey Logo Bag',
      brand: 'GUESS',
      category: 'Handbags',
      imageUrl: `${GUESS_IMAGE_BASE}/JG975521-BLO`,
      priceUsd: 70.4,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'guess_us',
    item: {
      externalId: 'SG974921-BNN',
      canonicalUrl:
        'https://www.guess.com/en-us/guess/women/bags/handbags/lindsey-crossbody-bag-off-white/SG974921-BNN.html',
      title: 'Lindsey Crossbody Bag',
      brand: 'GUESS',
      category: 'Handbags',
      imageUrl: `${GUESS_IMAGE_BASE}/SG974921-BNN`,
      priceUsd: 75.3,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'guess_us',
    item: {
      externalId: 'QG973306-BLA',
      canonicalUrl:
        'https://www.guess.com/en-us/guess/women/bags/handbags/maxine-satchel-bag-black/QG973306-BLA.html',
      title: 'Maxine Satchel Bag',
      brand: 'GUESS',
      category: 'Handbags',
      imageUrl: `${GUESS_IMAGE_BASE}/QG973306-BLA`,
      priceUsd: 82.4,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'guess_us',
    item: {
      externalId: 'GG974121-BLA',
      canonicalUrl:
        'https://www.guess.com/en-us/guess/promona/stacey-crossbody-bag-black/GG974121-BLA.html',
      title: 'Stacey Crossbody Bag',
      brand: 'GUESS',
      category: 'Handbags',
      imageUrl: `${GUESS_IMAGE_BASE}/GG974121-BLA`,
      priceUsd: 89.3,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'guess_us',
    item: {
      externalId: 'PD974606-BLO',
      canonicalUrl:
        'https://www.guess.com/en-us/guess/women/bags/handbags/ella-logo-satchel-bag-black/PD974606-BLO.html',
      title: 'Ella Logo Satchel Bag',
      brand: 'GUESS',
      category: 'Handbags',
      imageUrl: `${GUESS_IMAGE_BASE}/PD974606-BLO`,
      priceUsd: 82.4,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'guess_us',
    item: {
      externalId: 'ZG974701-LTR',
      canonicalUrl:
        'https://www.guess.com/en-us/guess/women/bags/handbags/gilda-hobo-bag-pink/ZG974701-LTR.html',
      title: 'Gilda Hobo Bag',
      brand: 'GUESS',
      category: 'Handbags',
      imageUrl: `${GUESS_IMAGE_BASE}/ZG974701-LTR`,
      priceUsd: 58.4,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'guess_us',
    item: {
      externalId: 'GG974172-OFF',
      canonicalUrl:
        'https://www.guess.com/en-us/guess/promona/stacey-shoulder-bag-off-white/GG974172-OFF.html',
      title: 'Stacey Shoulder Bag',
      brand: 'GUESS',
      category: 'Handbags',
      imageUrl: `${GUESS_IMAGE_BASE}/GG974172-OFF`,
      priceUsd: 68.3,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'guess_us',
    item: {
      externalId: 'GM992818-MUO',
      canonicalUrl:
        'https://www.guess.com/en-us/guess/women/bags/shoulder-bags/emelie-logo-shoulder--bag-multiplecolors/GM992818-MUO.html',
      title: 'Emelie Logo Shoulder Bag',
      brand: 'GUESS',
      category: 'Handbags',
      imageUrl: `${GUESS_IMAGE_BASE}/GM992818-MUO`,
      priceUsd: 58.4,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'steve_madden_us',
    item: {
      externalId: 'DT618175-BLACK',
      canonicalUrl: 'https://www.stevemadden.com/products/dt618175-black',
      title: 'Evelyn Bag Black',
      brand: 'Steve Madden',
      category: 'Handbags',
      imageUrl:
        'https://cdn.shopify.com/s/files/1/2170/8465/files/STEVEMADDEN_HANDBAGS_DT618175_BLACK_01.jpg?v=1692634204',
      priceUsd: 88,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'steve_madden_us',
    item: {
      externalId: 'BMAKIA-BLACK',
      canonicalUrl: 'https://www.stevemadden.com/products/bmakia-black',
      title: 'Makia Bag Black',
      brand: 'Steve Madden',
      category: 'Handbags',
      imageUrl:
        'https://cdn.shopify.com/s/files/1/2170/8465/files/STEVEMADDEN_HANDBAGS_BMAKIA_BLACK.jpg?v=1730145848',
      priceUsd: 49.99,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'steve_madden_us',
    item: {
      externalId: 'BRIGGS-BANANA-LEATHER',
      canonicalUrl: 'https://www.stevemadden.com/products/briggs-banana-leather',
      title: 'Riggs Bag Banana',
      brand: 'Steve Madden',
      category: 'Handbags',
      imageUrl:
        'https://cdn.shopify.com/s/files/1/2170/8465/files/STEVEMADDEN_HANDBAGS_BRIGGS_BANANA_01_0d534b39-1c46-4255-8fe7-3fa945de8ec9.jpg?v=1728573660',
      priceUsd: 99,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'steve_madden_us',
    item: {
      externalId: 'BTIKI-NATURAL',
      canonicalUrl: 'https://www.stevemadden.com/products/btiki-natural',
      title: 'Tiki Bag Natural',
      brand: 'Steve Madden',
      category: 'Handbags',
      imageUrl:
        'https://cdn.shopify.com/s/files/1/2170/8465/files/STEVEMADDEN_HANDBAGS_BTIKI_NATURAL-1.jpg?v=1728573484',
      priceUsd: 44.99,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'steve_madden_us',
    item: {
      externalId: 'BJULIANA-BLACK-PATENT',
      canonicalUrl: 'https://www.stevemadden.com/products/bjuliana-black-patent',
      title: 'Juliana Bag Black Patent',
      brand: 'Steve Madden',
      category: 'Handbags',
      imageUrl:
        'https://cdn.shopify.com/s/files/1/2170/8465/files/STEVEMADDEN_HANDBAGS_BJULIANA_BLACK-PATENT.jpg?v=1736176253',
      priceUsd: 39.99,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'steve_madden_us',
    item: {
      externalId: 'BANISE-RED-CROCODILE',
      canonicalUrl: 'https://www.stevemadden.com/products/banise-red-crocodile',
      title: 'Anise Bag Red Crocodile',
      brand: 'Steve Madden',
      category: 'Handbags',
      imageUrl:
        'https://cdn.shopify.com/s/files/1/2170/8465/files/STEVEMADDEN_HANDBAGS_BANISE_RED-CROCO-PATENT_01_6741895c-a21e-4178-8b8a-8b6bc8de8d84.jpg?v=1738074644',
      priceUsd: 99,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'steve_madden_us',
    item: {
      externalId: 'BLEILANI-BLACK',
      canonicalUrl: 'https://www.stevemadden.com/products/bleilani-black',
      title: 'Leilani Bag Black',
      brand: 'Steve Madden',
      category: 'Handbags',
      imageUrl:
        'https://cdn.shopify.com/s/files/1/2170/8465/files/STEVEMADDEN_HANDBAGS_BLEILANI_BLACK.jpg?v=1746477493',
      priceUsd: 139,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'steve_madden_us',
    item: {
      externalId: 'BJELLY-YELLOW',
      canonicalUrl: 'https://www.stevemadden.com/products/bjelly-yellow',
      title: 'Jelly Bag Yellow',
      brand: 'Steve Madden',
      category: 'Handbags',
      imageUrl:
        'https://cdn.shopify.com/s/files/1/2170/8465/files/STEVEMADDEN_HANDBAGS_BJELLY_YELLOW_01.jpg?v=1749141776',
      priceUsd: 39.99,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'steve_madden_us',
    item: {
      externalId: 'BLOHAN-BLACK',
      canonicalUrl: 'https://www.stevemadden.com/products/blohan-black',
      title: 'Lohan Bag Black',
      brand: 'Steve Madden',
      category: 'Handbags',
      imageUrl:
        'https://cdn.shopify.com/s/files/1/2170/8465/files/STEVEMADDEN_HANDBAGS_BLOHAN_BLACK_01.jpg?v=1755016894',
      priceUsd: 84,
      availability: 'unknown',
    },
  },
  {
    sourceId: 'steve_madden_us',
    item: {
      externalId: 'BPRIYA-BROWN',
      canonicalUrl: 'https://www.stevemadden.com/products/bpriya-brown',
      title: 'Priya Bag Brown',
      brand: 'Steve Madden',
      category: 'Handbags',
      imageUrl:
        'https://cdn.shopify.com/s/files/1/2170/8465/files/STEVEMADDEN_HANDBAGS_BPRIYA_BROWN_01.jpg?v=1758031549',
      priceUsd: 49.99,
      availability: 'unknown',
    },
  },
];

function toCuratedRecord(listing: CuratedListing): PresentedCatalogProduct {
  return {
    ...listing.item,
    sourceId: listing.sourceId,
    fingerprint: fingerprintOf(listing.item),
    firstSeenAt: CURATED_US_CATALOG_OBSERVED_AT,
    lastSeenAt: CURATED_US_CATALOG_OBSERVED_AT,
    lastChangedAt: CURATED_US_CATALOG_OBSERVED_AT,
    isActive: true,
    consecutiveMissingSnapshots: 0,
    selectionState: 'selected',
    selectionVersion: null,
    watchTier: 'standard',
    placements: [],
    matchedRuleId: null,
    dataOrigin: 'curated_us_snapshot',
  };
}

export const CURATED_US_CATALOG: readonly PresentedCatalogProduct[] = LISTINGS.map(
  toCuratedRecord,
);

function isLegacyDemoProduct(record: CatalogProductRecord): boolean {
  return (
    record.title.endsWith('(demo data)') ||
    record.imageUrl?.startsWith('https://picsum.photos/') === true
  );
}

/**
 * Returns live rows plus only enough curated records to reach the requested
 * per-source floor. A live record always wins on source-scoped ID or URL.
 * Legacy fictional demo rows are intentionally never presented.
 */
export function withMinimumUsCatalog(
  activeProducts: readonly CatalogProductRecord[],
  minimumPerSource = MINIMUM_PRODUCTS_PER_SOURCE,
  curatedProducts: readonly PresentedCatalogProduct[] = CURATED_US_CATALOG,
): PresentedCatalogProduct[] {
  const presented: PresentedCatalogProduct[] = activeProducts
    .filter((record) => !isLegacyDemoProduct(record))
    .map((record) => ({ ...record, dataOrigin: 'live_crawl' }));

  const seenIds = new Set(
    presented.map((record) => `${record.sourceId}:${record.externalId}`),
  );
  const seenUrls = new Set(presented.map((record) => record.canonicalUrl));

  const fallbackSourceIds = new Set(curatedProducts.map((record) => record.sourceId));
  for (const sourceId of SOURCE_IDS.filter((id) => fallbackSourceIds.has(id))) {
    let sourceCount = presented.filter((record) => record.sourceId === sourceId).length;
    if (sourceCount >= minimumPerSource) continue;

    for (const fallback of curatedProducts) {
      if (fallback.sourceId !== sourceId) continue;
      const scopedId = `${fallback.sourceId}:${fallback.externalId}`;
      if (seenIds.has(scopedId) || seenUrls.has(fallback.canonicalUrl)) continue;

      presented.push(fallback);
      seenIds.add(scopedId);
      seenUrls.add(fallback.canonicalUrl);
      sourceCount += 1;
      if (sourceCount >= minimumPerSource) break;
    }
  }

  return presented;
}
