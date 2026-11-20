---
name: Vouchsafe
description: Trust tools for BNB Chain where one Agent ID is one voice, drawn as an open passport.
colors:
  cover-navy: "#14233F"
  cover-deep: "#0C1729"
  burgundy: "#7A1F35"
  burgundy-ink: "#FFFFFF"
  accent-text: "#7A1F35"
  security-mint: "#DDE8E2"
  security-mint-2: "#D2E0D9"
  guilloche-teal: "#3E8E8A"
  guilloche-wash: "rgba(62,142,138,.16)"
  ink: "#12203A"
  ink-2: "#34485F"
  ink-3: "#4F6377"
  rule: "rgba(18,32,58,.18)"
  gold-foil: "#C9A54C"
  stitch: "rgba(201,165,76,.55)"
  cover-text: "#C7D3E0"
  cover-text-soft: "#AFC0D2"
  cover-link: "#E3EAF2"
  stamp-red: "#B3261E"
  stamp-green: "#1F7A4D"
  stamp-violet: "#5B3E96"
  stamp-blue: "#1E5AA8"
  stamp-amber: "#A15C07"
  cover-board: "#1B2E50"
  page-edge: "#C6D3CC"
  page-edge-2: "#B5C4BC"
  perforation-hole: "rgba(12,23,41,.62)"
  perforation-rim: "rgba(255,255,255,.55)"
  laminate-rose: "#FF6FB5"
  laminate-gold: "#FFD36B"
  laminate-mint: "#8DFF9B"
  laminate-cyan: "#6BE6FF"
  laminate-iris: "#9A8CFF"
  night-cover: "#0A1322"
  night-cover-deep: "#060C17"
  night-paper: "#13223A"
  night-paper-2: "#172A45"
  night-print: "#5FB3AD"
  night-print-wash: "rgba(95,179,173,.13)"
  night-ink: "#E4EEE9"
  night-ink-2: "#B9CCC4"
  night-ink-3: "#93A9A1"
  night-rule: "rgba(228,238,233,.16)"
  night-burgundy: "#B4425D"
  night-accent-text: "#EBA3B5"
  night-gold: "#D6B65E"
  night-stitch: "rgba(214,182,94,.45)"
  night-stamp-red: "#F0675C"
  night-stamp-green: "#4FC08A"
  night-stamp-violet: "#A88BE6"
  night-stamp-blue: "#6FA2EE"
  night-stamp-amber: "#E7A33E"
  night-cover-board: "#12203A"
  night-page-edge: "#1E3150"
  night-page-edge-2: "#192A45"
  night-perforation-hole: "#02060E"
  night-perforation-rim: "rgba(150,200,190,.45)"
typography:
  display:
    fontFamily: "Bodoni Moda, Didot, Bodoni 72, serif"
    fontSize: "min(13.2cqi, 96px)"
    fontWeight: 500
    lineHeight: 0.92
    letterSpacing: "0.02em"
  headline:
    fontFamily: "Bodoni Moda, Didot, Bodoni 72, serif"
    fontSize: "min(clamp(36px, 5vw, 72px), 14cqi)"
    fontWeight: 500
    lineHeight: 0.92
    letterSpacing: "0.02em"
  title:
    fontFamily: "Bodoni Moda, Didot, Bodoni 72, serif"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "0.22em"
  numeral:
    fontFamily: "Bodoni Moda, Didot, Bodoni 72, serif"
    fontSize: "30px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "0.01em"
  lede:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(17px, 1.6vw, 20px)"
    fontWeight: 400
    lineHeight: 1.55
  body:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.6
  field-value:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 500
    lineHeight: 1.35
  label:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "11.5px"
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: "0.16em"
  mrz:
    fontFamily: "Martian Mono, ui-monospace, Menlo, monospace"
    fontSize: "clamp(10px, 1.02vw, 13.5px)"
    fontWeight: 500
    lineHeight: 1.7
    letterSpacing: "0.12em"
    fontVariation: "'wdth' 87.5"
  mono:
    fontFamily: "Martian Mono, ui-monospace, Menlo, monospace"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.45
    fontVariation: "'wdth' 87.5"
rounded:
  hairline: "2px"
  stamp-tag: "3px"
  ink-tag: "4px"
  slot: "6px"
  control: "8px"
  stamp: "10px"
  page: "14px"
  tooling-phone: "17px"
  tooling: "19px"
  tooling-outer: "21px"
  round-stamp: "50%"
spacing:
  gutter: "20px"
  gutter-phone: "12px"
  field-gap: "14px"
  page-pad: "clamp(28px, 4vw, 56px)"
  spread-gap: "40px"
  spread-gap-phone: "20px"
  column-gap: "clamp(24px, 4vw, 56px)"
  container: "1240px"
components:
  button-primary:
    backgroundColor: "{colors.burgundy}"
    textColor: "{colors.burgundy-ink}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "14px 20px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "14px 20px"
  field-input:
    textColor: "{colors.ink}"
    typography: "{typography.mono}"
    rounded: "{rounded.control}"
    padding: "14px 13px"
  data-field-label:
    textColor: "{colors.ink-3}"
    typography: "{typography.label}"
  data-field-value:
    textColor: "{colors.ink}"
    typography: "{typography.field-value}"
  passport-page:
    backgroundColor: "{colors.security-mint}"
    textColor: "{colors.ink}"
    rounded: "{rounded.page}"
    padding: "{spacing.page-pad}"
  cover-bar:
    backgroundColor: "{colors.cover-navy}"
    textColor: "{colors.cover-text}"
    height: "60px"
  verdict-stamp:
    textColor: "{colors.stamp-violet}"
    rounded: "{rounded.stamp}"
    padding: "9px 16px 8px"
  verdict-stamp-round:
    textColor: "{colors.stamp-green}"
    rounded: "{rounded.round-stamp}"
    padding: "22px"
  ink-tag:
    textColor: "{colors.stamp-red}"
    rounded: "{rounded.ink-tag}"
    padding: "4px 7px 3px"
  mrz-strip:
    textColor: "{colors.ink}"
    typography: "{typography.mrz}"
---

# Design System: Vouchsafe

## Overview

**Creative North Star: "The Passport Page"**

Agent ID is a passport and Vouchsafe is the stamp it earns, so the whole site is one passport held open. The body of the page is the navy cover leather; every section is a spread of security paper laid on top of it, two pages joined at a stitched gutter. Paper carries the information, the cover carries the chrome (sticky bar, footer), and the only things that move are leaves turning in and stamps pressing down.

The paper is pale mint printed with a generative teal guilloche, drawn in script at load from the live `--print` color so it re-inks itself in the night theme. Burgundy is the document's structural accent and the color of every action. Gold foil belongs to the cover: the wordmark, the seal on the issuing page, the gutter stitching and the focus ring. Verdicts are never typeset in a UI color; they arrive as rubber-stamp ink (double-ruled border, displacement filter, grain mask, multiply blend) in red, green, violet, blue or amber. Engraved Bodoni caps title the documents, Schibsted Grotesk fills the numbered fields, and Martian Mono is held for the machine-readable zone and addresses.

Density is document-like: generous page padding, hairline rules between field rows, tabular figures, and labels that read as printed form captions. The night theme is the cover leather itself: paper turns navy, the guilloche turns a brighter teal, stamp inks lift for contrast and stop multiplying.

**Key Characteristics:**
- One passport, opened: two-page spreads on a dashed gold stitch and a shaded gutter; full-width single pages for the ledger and the notes.
- Security paper with procedural guilloche and a spirograph crest, never a raster texture.
- Numbered data-page fields ("1 · Address to check") with tracked uppercase labels.
- Rubber-stamp verdicts that press in once; a two-line MRZ that retypes from each result.
- Motion limited to two verbs: leaves turn, stamps press. Both stop under reduced motion.

## Colors

A document palette: grained navy leather cover, mint security paper with teal print, one burgundy action color, gold foil on the cover only, five stamp inks reserved for verdicts, and a laminate spectrum that is only ever seen through the security print.

### Primary
- **Passport Burgundy** (burgundy): every action. The Check and Sift buttons, the input focus ring, the Sift progress fill, endorsement hover text (via accent-text). Brightens to a rose burgundy at night, with accent-text lifting to a pale rose so linked text keeps AA on navy paper.

### Secondary
- **Cover Navy** (cover-navy, cover-deep): the page body, sticky bar (82% mixed with transparency under a blur), footer, theme-color and favicon. Cover-deep is the text color on gold selection.
- **Gold Foil** (gold-foil, stitch): the wordmark, the seal on the issuing page, the dashed gutter stitch, `::selection`, the 2px focus outline and nav hover. It is foil, so it never fills a surface.

### Tertiary
- **Guilloche Teal** (guilloche-teal, guilloche-wash): the security print itself (strokes at 16% opacity), the crest rosette at 40%, link underlines, the photo-slot hatch, table row hover, empty verdict bars and the scrollbar thumb.
- **Stamp Inks** (stamp-red, stamp-green, stamp-violet, stamp-blue, stamp-amber): verdicts and statuses only. Mapped as SAFE green, HONEYPOT amber, RUG red, DRAINER violet, PHISHING blue; result stamps use red (reported harmful), green (reported safe), blue (no record), violet (not settled / pending / in build).

- **Laminate Spectrum** (laminate-rose, -gold, -mint, -cyan, -iris): the holographic laminate on the data page and the kinegram patch. Never a fill, never text: it shows only through the guilloche-line mask (multiply at 24% on paper, screen at 13% at night) or inside the kinegram's rosette mask.

### Neutral
- **Security Mint** (security-mint, security-mint-2): the paper of every page; mint-2 is the photo-slot fill.
- **Passport Ink** (ink, ink-2, ink-3): titles and field values; body copy and ledes; labels, hints, MRZ on secondary pages and timestamps.
- **Printed Rule** (rule): hairlines between rows, input and slot borders, dashed empty states.
- **Cover Board and Page Edges** (cover-board, page-edge, page-edge-2): the raised leather board each spread sits on and the stacked page edges showing under it.
- **Perforation** (perforation-hole, perforation-rim): laser holes of the serial; the hole is the cover showing through, the rim a lighter edge so the holes read in both themes.
- **Cover Text** (cover-text, cover-text-soft, cover-link): nav and footer copy on navy. These are literal values in the build rather than custom properties.

### Named Rules
**The Ink Is the Verdict Rule.** A stamp ink appears only where it states a verdict or status (stamps, ink tags, verdict bars, legend swatches, Sift yes/no/same-holder, the live dot). It never decorates a heading or a button.

**The Foil on the Cover Rule.** Gold sits on the navy cover, on the seal, on the stitch, on the tooled line around each cover board, and on focus. It is never body text on paper and never a fill.

**The Laminate Shows Through the Print Rule.** Holographic colour is only ever visible through the security print or a kinegram mask, at low strength. It never floods a surface, never sits behind text unmasked, and never appears outside the data page and its kinegram.

**The One Action Color Rule.** Burgundy is the only color a user presses. Ghost buttons are ink on a rule border, not a second hue.

## Typography

**Display Font:** Bodoni Moda (with Didot, Bodoni 72, serif), optical sizes 6..96, weights 500 and 700
**Body Font:** Schibsted Grotesk (with ui-sans-serif, system-ui), weights 400 to 700
**Label/Mono Font:** Martian Mono at 87.5 width (with ui-monospace, Menlo), weights 400 and 500

**Character:** Engraved high-contrast caps for the document's own titles against a crisp, slightly condensed grotesque for everything a person fills in; the mono reads as OCR, so it stays in the machine zone.

### Hierarchy
- **Display** (500, min(13.2cqi, 96px), 0.92): the issuing-page wordmark, uppercase, sized to the page's container so it never overflows a single page. The first syllable or key word is set in 700 ("**Vouch**safe").
- **Headline** (500, min(clamp(36px,5vw,72px),14cqi), 0.92): each spread's title (Shield, Sift, Errands), uppercase, key word in 700. The base `.title` scale is clamp(40px,6.4vw,92px).
- **Title** (700, 14 to 18px, 1 to 1.3, tracked 0.14em to 0.22em, uppercase): data-page heads (15px, 0.22em), section subheads (14px, 0.2em), endorsement names (18px, 0.14em), Errands steps and notes (15px, 0.16em / 0.14em).
- **Numeral** (Bodoni 700, 30px, 1): Sift tally counts.
- **Lede** (400, clamp(17px,1.6vw,20px), 1.55): the opening paragraph of each page, ink-2, capped at 34ch; bold runs lift to ink at 600.
- **Body** (400, 16px, 1.6): running copy in ink-2, capped at 62ch; secondary rows run 14.5px; notes and hints 13px in ink-3.
- **Field value** (500, 17px, 1.35): data-page answers; 15.5px on the issuing page and work permit.
- **Label** (600, 11.5px, 0.16em, uppercase): every field caption and table header, ink-3, numbered on the data page.
- **MRZ** (Martian Mono 500, clamp(10px,1.02vw,13.5px), 1.7, 0.12em): the two 44-character machine lines; 11px with no tracking on phones. Mono at 13px / 14px for addresses and the address input; 11px for live status and stamp sub-lines.

### Named Rules
**The Engraved Caps Rule.** Bodoni is set uppercase and tracked when small (0.14em and up) or tight when large (0.02em). It names documents and sections; it never runs as a paragraph.

**The Machine Zone Rule.** Martian Mono is for what a machine would read: MRZ lines, addresses, block numbers, CLI commands, live status. Human prose is never mono.

## Layout

The page is a single centred column (max 1240px, 20px side gutter, 12px under 560px) on the cover. Each section is a spread: a two-column grid of equal pages with 14px outer corners, sitting on a 12px raised cover board (7px on phones) ringed by a gold tooled line, 58px between spreads (30px on phones), and page padding of clamp(28px,4vw,56px). A 44px shaded gradient marks the fold and a 1.5px dashed gold stitch runs down it, inset 18px top and bottom. Single-page spreads span both columns and drop the gutter. Pages are inline-size containers so display type scales to the page, not the viewport.

Inside the data page, a 7:9 photo slot (140 to 190px) sits beside a field stack with 24px between; result fields pair in two columns with 14px gaps. Pages that carry an MRZ reserve clamp(110px,10vw,130px) of bottom padding and pin the strip to the page foot. Content columns inside wide pages split 1.2fr / 1fr with a clamp(24px,4vw,56px) gap.

At 900px and below, spreads stack one page at a time, the gutter and stitch become a dashed gold seam across the top of the second page, and on the hero the data page comes first so the Check field is the first thing a phone sees. At 560px and below the photo slot hides, the Check button drops under the input at full width, the stamp leaves the slot and sits under the fields, ledgers and tallies go to two columns, and the corner page stamp falls into the flow.

## Elevation & Depth

Depth is physical, not interface: the paper sits on a raised board on a grained leather cover, and the page block's stacked edges show beneath each spread. Each spread casts one soft, deep shadow onto the navy; the fold is a shaded gradient; the seal is embossed with paired drop-shadows. Inside a page everything is flat and separated by printed rules. The sticky bar floats on blur and translucency, not a shadow.

### Shadow Vocabulary
- **Page block and board** (`box-shadow: 0 1px 0 var(--edge), 0 3px 0 var(--edge-2), 0 4px 0 var(--edge), 0 6px 0 var(--edge-2), 0 0 0 12px var(--board), 0 34px 70px -18px rgba(0,0,0,.6), 0 10px 24px -8px rgba(0,0,0,.45)`): every spread; the stacked edges, then the board ring, then the cast shadow onto the leather.
- **Tooled line** (`.tool`: a 1px gold border at 7px outside the paper, 19px corners, 55% opacity, with a 0.6px inner companion at 21px): the foil tooling on every board.
- **Leather** (generated SVG noise: a fine 240px pebble tile and a 900px mottle tile on cover navy, plus a top highlight and bottom vignette behind content): the cover surface.
- **Gutter fold** (`linear-gradient(90deg, transparent, rgba(0,0,0,.10) 42%, rgba(0,0,0,.16) 50%, rgba(0,0,0,.10) 58%, transparent)`, 44px wide): the centre of every two-page spread.
- **Foil emboss** (`filter: drop-shadow(0 1px 0 rgba(255,255,255,.35)) drop-shadow(0 -1px 0 rgba(0,0,0,.18))`): the gold seal only.
- **Button press** (`box-shadow: 0 6px 14px -8px rgba(0,0,0,.45)`): the burgundy button sits slightly proud of the paper.
- **Focus well** (`box-shadow: 0 0 0 4px` burgundy at 18%): a focused input.

### Named Rules
**The Paper Lies Flat Rule.** Nothing printed on a page casts a shadow except the action button, the embossed foil seal and the live dot's ink halo. Hierarchy on paper comes from rules, type and ink.

## Shapes

Paper corners are softly rounded (14px) only on the outside of a spread; inner corners at the gutter are square, and stacked pages square their shared edge. Controls take 8px, the photo slot and code blocks 6px, ink tags 4px and the small endorsement status stamp 3px. Verdict stamps are 10px rectangles with a 3px double border (4 to 5px on the big result stamp) or full circles, always rotated a few degrees off true (-2deg to -11deg, +9deg for the Shield corner stamp, randomised between -4deg and -11deg on each result). Rules are hairlines (1px) between rows and 1.5px solid ink at the head of a ledger, table or step list. Dashed lines mean either the stitch (gold) or an empty state (rule).

## Components

### Buttons
Pressed like a rubber stamp handle: firm, single color.
- **Shape:** gently rounded (8px).
- **Primary:** burgundy fill, white text, Schibsted 600 15px with 0.02em tracking, 14px 20px padding, the button-press shadow.
- **Hover / Focus:** brightness to 1.08 on hover; translateY(1px) on press with the house ease; gold 2px focus outline offset 3px; disabled at 55% opacity with a progress cursor and a verb label ("Reading…", "Sifting…").
- **Ghost:** transparent, ink text, 1.5px rule border, no shadow (Download CSV). File-picker buttons follow the ghost pattern at 13px with 6px corners.

### Inputs / Fields
- **Style:** Martian Mono 14px ink on paper lightened 45% toward white (black at 18% in the night theme), 1.5px rule border, 8px corners, 14px 13px padding; placeholder in ink-3.
- **Focus:** border turns burgundy with a 4px burgundy well at 18%; no outline.
- **Textarea:** the same field at 12.5px, 170px minimum, vertical resize.

### Data Field
The passport's printed form line. A tracked uppercase label (11.5px, 0.16em, ink-3) sits 5px above a 17px value in ink; values that are machine data switch to mono 13px. On the data page labels are numbered in reading order ("1 · Address to check" through "5 · Read at block"). Fields stack with 14px gaps and pair in two columns for results.

### Navigation
The cover bar: sticky, 60px tall, cover navy at 82% with saturate(1.2) blur(10px) and a gold hairline at 18% beneath. The gold wordmark is Bodoni 600 15px tracked 0.28em beside a 28px seal glyph. Links are Schibsted 500 14px in cover-text, no underline, turning gold on hover over 0.2s. Below 900px the gap tightens to 16px at 13.5px and the GitHub link is dropped.

### Endorsements List
The issuing page lists the products as printed endorsements: a 440px list between rules, each row a Bodoni 700 18px name, a 14.5px description in ink-2, and a small mono status stamp (11px, 1.4px border, 3px corners, rotated -3deg) in stamp green for LIVE or violet for IN BUILD. Hover turns the row's link to accent-text.

### Verdict Stamp (signature)
The rubber stamp: uppercase Schibsted 700 15px tracked 0.14em inside a 3px double border in the stamp's ink, with a mono 10.5px sub-line. It is roughened by an SVG turbulence displacement filter, masked with generated grain and multiplied into the paper at 90% opacity (normal blend at night). Variants: `harm` red, `safe` green, `none` blue, `pend` violet; `big` (clamp(20px,2.4vw,28px), 5px border) and `round` (circle, 22px padding). The result stamp lands centred over the photo slot, hiding the placeholder, and presses in over 0.62s: from 1.7x scale and transparent, to 0.94x at 55%, settling at 1x, with its rotation held throughout.

### Ink Tag
A small inline stamp for feed rows: Schibsted 700 11px tracked 0.1em, uppercase, 1.5px border in the verdict ink, 4px corners, rotated -2deg. In the Latest stamps feed older rows print fainter (opacity steps of 0.06 down to 0.5).

### MRZ Strip
Two 44-character lines of chevron-padded uppercase under a rule, at the foot of the data page and the visa pages. The data-page strip retypes from each result (three characters every 16ms) and carries a real check digit; it prints instantly under reduced motion.

### Ledger and Tally
Counts are printed, not carded: a four-column row between a 1.5px ink rule and a hairline, labels above mono 17px values (ledger) or Bodoni 30px numerals (Sift tally). Two columns on phones. Verdict mix is a 9px bar of ink segments split by 1.5px paper gaps.

### Holographic Laminate and Kinegram (signature material)
The data page carries a passport laminate: a conic spectrum of the five laminate inks, visible only through a 300x150 guilloche-line mask, multiplied at 24% on paper and screened at 13% at night. Its centre follows the pointer over the page and, on touch, the page's position in the viewport (a continuous, clamped mapping, never a modulo). A 66px kinegram (54px on phones) sits on the photo slot's corner: the same spectrum inside a rosette-and-V mask, 85% at full colour on paper and 50%, desaturated and screened at night. On phones, with the slot hidden, it sits above the stamp's right corner. Static under reduced motion.

### Perforated Serial
Every right-hand and full-width page is laser-perforated with the same serial, VS000001, as on a real passport: a 5x7 dot font (1.05 radius on a 4px pitch) in perforation-hole with a 0.45px perforation-rim, rotated to run down the outer edge on desktop and across the top edge on phones.

### Leaf Turn (motion)
On two-page spreads the right page turns over from the gutter when the spread enters the viewport: from rotateY(-84deg) about its left edge (perspective 2400px) and transparent, to flat over 1.25s on cubic-bezier(.16,1,.3,1), while the spread itself only rises 16px. On phones the page turns down from its top edge (rotateX(-70deg)). Full-width pages lift from rotateX(6deg) and a 28px drop. Runs once per leaf, only when motion is allowed; horizontal overflow during the turn is clipped.

## Do's and Don'ts

### Do:
- **Do** lay every new section on paper as a spread or a full-width single page on the navy cover, with the gutter stitch for two-page spreads.
- **Do** caption every value with a tracked uppercase label (11.5px, 0.16em) and number them when they form a reading sequence.
- **Do** state verdicts as stamps or ink tags in the mapped stamp ink, rotated a few degrees, and pair each with a plain-language line.
- **Do** keep burgundy (#7A1F35 light, #B4425D night) as the single action color and gold (#C9A54C) on the cover, seal, stitch and focus ring.
- **Do** draw security texture procedurally from `--print` so it follows the theme.
- **Do** give every motion a reduced-motion state that shows the end result immediately.
- **Do** define both themes for any new token, under `prefers-color-scheme: dark` guarded by `:root:not([data-theme="light"])` and again under `:root[data-theme="dark"]`.

### Don't:
- **Don't** use a stamp ink for decoration, headings or buttons.
- **Don't** set prose, buttons or labels in Martian Mono; it belongs to the machine zone and addresses.
- **Don't** put shadows on anything printed on the page other than the action button, the foil seal emboss and the live dot's halo.
- **Don't** fill a surface with gold or set body text in gold on paper.
- **Don't** add motion beyond the leaf turn, the stamp press and the MRZ retype.
