# SPENT — Design Constitution

> Canonical visual and interaction language for the SPENT iOS app.
>
> This document is the source of truth for all UI, visual design, illustration, motion, and presentation decisions.
> When a screen-specific prompt conflicts with this document, this document wins unless the product owner explicitly overrides it.

---

# 1. The One-Sentence Rule

**SPENT is minimalist in structure, expressive in color, native in interaction, and human in tone.**

Minimalism controls **complexity** — it does not remove personality.

SPENT is NOT an all-white productivity app.
SPENT is NOT a neon fintech concept.
SPENT is a clean, modern, colorful city world built with Apple-like discipline.

---

# 2. What SPENT Should Feel Like

Every screen should feel:

- modern
- young
- clean
- graphic
- warm
- intentional
- slightly playful
- confident
- native to iOS
- visually authored rather than generated

SPENT should feel like a designer deliberately chose every element.

It should never feel like:

- a generic finance dashboard
- an AI-generated Dribbble concept
- a crypto app
- a SaaS product
- a children's game
- a bank app with a city pasted on top
- a sterile white productivity tool

The product has a city at its center.  
That gives the interface permission to have **life, color, illustration, motion, and personality**.

The discipline comes from hierarchy and restraint.

---

# 3. Core Design Tension

SPENT intentionally lives between two poles:

## Calm interface

Financial information must remain:

- easy to scan
- legible
- trustworthy
- spacious
- calm
- understandable in one glance

## Expressive city world

The product may also use:

- vivid color
- illustrated architecture
- geometric shapes
- editorial compositions
- playful transitions
- city metaphors
- character
- visual surprises

The solution is not to choose one side.

The rule is:

> **Information stays calm. Personality appears in controlled moments.**

Functional screens lean calmer.

Storytelling, city, onboarding, recap, archive, celebrations, and empty states may become more graphic and expressive.

---

# 4. Color Philosophy

## Color is part of the brand

Color is not a tiny decorative exception.

SPENT uses color with intention, maturity, and authorial voice.

The interface is calm and spacious, but the custom bespoke icons remain intensely colorful and characterful.

Do not desaturate the app in the name of minimalism.
Color is concentrated, not removed.

## Core Canvas & Neutral Foundation

### Canvas / Default App Background
`#FFFFFF` Pure White

The default application canvas is pure clean white.
Lots of white breathing room allows strong typography and small confident fields of color to pop.

### Supporting Warm Surface
`#FFF2E6` Warm Cream

Warm Cream is a selective supporting surface (onboarding, empty states, special editorial cards, icon interior fills). It is NOT the universal app canvas.

### Jet Black / High-Contrast Ink
`#000000` Jet Black

Use for:
- major titles & typography
- important numbers
- icon outlines & structural frames
- selected state outlines & active indicators
- opacity-derived secondary text (0.60), muted text (0.40), and borders (0.08)

---

# 5. SPENT Canonical Palette (V2)

The entire application UI derives from this unified canonical 8-color family:

- **White** — `#FFFFFF` (Default app canvas, cards, breathing room)
- **Warm Cream** — `#FFF2E6` (Warm supporting surface, editorial modules, empty states)
- **Neon Lime** — `#D1D175` (Special accent: weekly rewards, companions, highlights)
- **Baby Blue** — `#D7E7FF` (Soft supporting surface, icon fills, informational fields)
- **Jet Black** — `#000000` (Typography, outlines, strong navigation state)
- **Orange Red** — `#FF6446` (Strong warm accent: destructive, alerts, high-energy details)
- **Lucky Green** — `#2D9E65` (Primary brand color: central "+", primary CTA, savings identity)
- **Violet Blue** — `#5653E8` (Secondary brand color: analytics, data series, editorial moments)

## Color Hierarchy & Rules

1. **Hierarchy**:
   - MOST: White `#FFFFFF`
   - NEXT: Jet Black `#000000` & opacity-derived neutrals
   - SUPPORTING: Warm Cream `#FFF2E6`, Baby Blue `#D7E7FF`
   - PRIMARY ACTION: Lucky Green `#2D9E65`
   - SECONDARY EXPRESSIVE: Violet Blue `#5653E8`
   - STRONG ACCENT: Orange Red `#FF6446`
   - SPECIAL ACCENT: Neon Lime `#D1D175`

2. **Colorful Icons inside Quiet Containers**:
   Custom MoneyIcons stay colorful and illustrated with multicolor fills from the canonical paintbox.
   Containers behind icons stay quiet (white, Warm Cream, or subtle neutral).
   Do not nest a colorful icon inside a colorful circle inside a colorful card.

3. **No Moral Red/Green Coding**:
   SPENT's tone is descriptive and non-judgmental.
   Do not use Green = "You were good" or Red = "You were bad".
   Month-over-month spending differences use neutral/brand colors, arrows, and numbers rather than moral red/green.
   Orange Red is reserved for destructive actions, errors, and genuine warnings.

4. **Calm Chrome vs. Storytelling**:
   Functional screens (City chrome, History, Budget, Settings) remain calm and predominantly white.
   Onboarding, Monthly Recap, and Weekly Companions may use graphic color blocks and expressive moments.

5. **The 3D City Diorama is Separate**:
   The 3D diorama has its own living architectural visual world.
   The UI surrounds and frames the city; do not alter diorama materials, lighting, or 3D assets to match the UI palette.

---

# 6. What “No AI Design” Actually Means

Do NOT interpret “avoid AI design” as “remove color”.

The problem is not bright color.

The problem is the generic bundle of visual effects that makes generated interfaces all look the same.

## Never default to

- neon purple-blue gradients
- glowing borders
- luminous blur halos
- glassmorphism everywhere
- floating translucent cards
- mesh-gradient wallpaper
- giant gradient blobs
- colored glow shadows
- glossy 3D coins
- glossy 3D app-icon objects
- shiny trophies
- floating sparkles
- random stars
- confetti as a default reward language
- excessive pills
- cards inside cards inside cards
- decorative charts with no information purpose
- random abstract blobs behind text
- gradient text
- fake depth everywhere
- “premium fintech” visual clichés

## Allowed and encouraged

- flat vivid colors
- pastels
- graphic color blocks
- simple geometric forms
- editorial illustration
- asymmetrical composition
- bold typography
- cropped city scenes
- playful architecture
- small visual surprises
- native motion
- restrained 2D / 2.5D depth

A good test:

> If the screen would look at home in ten unrelated AI-generated fintech apps, it is not SPENT.

---

# 7. Color Has Three Roles

Do not mix these roles carelessly.

## A. Semantic color

Color communicates meaning.

Examples:
- category identity
- destructive Orange Red
- savings / park Lucky Green
- selected states
- warning / confirmation states

Keep these consistent.

## B. Brand color

Color identifies SPENT.

Examples:
- Lucky Green (#2D9E65)
- Violet Blue (#5653E8)
- Jet Black (#000000)
- canonical icon palette

These can recur across screens.

## C. Editorial color

Color creates mood or identity without implying financial judgment.

Examples:
- a monthly recap card with a coral city
- a blue archive postcard
- a golden onboarding illustration

Editorial color must never accidentally mean:
- green = user was good
- red = user was bad

unless the product explicitly defines that semantic meaning.

---

# 8. Surface System

SPENT uses surfaces intentionally.

The existing code already provides a surface system and three primary radii.

## Radii

- Small controls / chips: `12pt`
- Standard cards: `20pt`
- Hero surfaces / large sheets: `24pt`

Do not invent a new radius for each component.

A new radius requires a real design reason.

## Default surface logic

Functional information should often sit directly on the canvas.

Do NOT automatically wrap every section in a card.

Prefer:
- whitespace
- hierarchy
- dividers
- alignment
- spacing

over:
- container after container

Cards are appropriate when they:
- group a coherent module
- create a tappable object
- isolate a hero moment
- represent a physical metaphor
- need clipping for an illustration
- create a clear interaction target

## Colored surfaces

A colored surface is allowed when:
- it carries category / semantic identity
- it is part of an editorial scene
- it intentionally gives a month/story its own identity
- it supports an illustration

It is not allowed merely because “the screen needs more color”.

---

# 9. Shadows and Depth

SPENT should feel crisp, not floaty.

Default:
- flat
- hairline
- extremely soft ambient shadow

Use blur shadows sparingly.

Good maximum direction:

```swift
.shadow(
    color: Color.deepNavy.opacity(0.03...0.06),
    radius: 8...12,
    y: 2...4
)
```

Strong depth should be reserved for objects that actually float:
- add button
- floating tab / overlay
- temporary action UI

Avoid:
- black drop shadows
- colored shadows
- shadow stacks
- glow
- fake 3D elevation on every element

---

# 10. Typography

Typography should feel like iOS, not a branding experiment.

Use:
- SF Pro / system default for interface text
- SF Rounded / rounded design for expressive financial numbers, selected labels, city moments, and places already established in the app

Do not introduce decorative fonts.

## Recommended hierarchy

### Screen title
Approximately:
`28pt / bold / default`

### Hero financial value
Approximately:
`30–36pt / bold or heavy / rounded`

### Section header
Approximately:
`16pt / semibold`

### Row title
Approximately:
`16pt / semibold`

### Row amount
Approximately:
`16–18pt / bold / rounded`

### Secondary text
Approximately:
`12–13pt / regular or medium`

### Chips / metadata
Approximately:
`10–12pt / semibold`

Exact sizes may adapt to the screen.

Do not reduce accessibility or readability to preserve a rigid layout.

---

# 11. Numbers Are Visual Anchors

Money values are one of SPENT's strongest visual elements.

Treat important numbers as objects in the composition.

Good:
- confident size
- strong weight
- space around them
- simple supporting label
- one number per visual beat

Bad:
- dashboard grids full of equally loud KPIs
- five numbers competing in one card
- tiny financial figures surrounded by decoration

For narrative screens:

> **one idea, one number, one frame**

is the preferred rhythm.

---

# 12. Layout & Spacing

Use a disciplined spacing rhythm.

Prefer values from:
- 4
- 8
- 12
- 16
- 20
- 24
- 32

Do not use arbitrary 13 / 17 / 19 / 27 spacing repeatedly unless optical correction genuinely requires it.

General screen margins:
approximately `20pt` where appropriate.

Use whitespace actively.

Whitespace is not empty space waiting to be decorated.

It creates hierarchy.

---

# 13. Functional Screens

Examples:
- History
- transaction lists
- settings
- profile controls
- filters
- search
- edit forms

These should be the calmest part of the app.

Preferred language:

- off-white canvas
- strong title
- direct content
- category color in icons / badges / selected states
- clear rows
- light dividers
- minimal containers
- native controls
- limited animation

The History ledger is a key reference:

> Transactions sit directly on the background rather than each being trapped in a separate heavy card.

Do not turn functional screens into illustrated posters.

---

# 14. Expressive Screens

Examples:
- Main City
- Monthly Recap
- Recap Archive
- Onboarding
- Weekly companions
- city unlock / arrival moments
- special empty states

These screens may use more:

- color
- illustration
- custom composition
- geometric shapes
- large type
- narrative motion
- cropped visual scenes
- editorial pacing

They still must follow the same typography, colors, spacing discipline, and interaction language.

Expressive does NOT mean visual chaos.

---

# 15. The City Is the Hero

The 3D city is not a decorative background.

It is the central metaphor of the product.

Whenever the real city is visible:

- do not cover it with excessive UI
- do not compete with it using unrelated graphics
- overlays should recede
- financial information should be concise
- controls should feel like instruments around the city, not a dashboard sitting on it

City = what happened.

Park / nature = how the month feels.

Do not invert that relationship casually.

---

# 16. Illustration Language

SPENT illustration should feel:

- geometric
- graphic
- architectural
- clean
- youthful
- slightly playful
- digitally drawn
- intentionally simplified

Suitable:
- city silhouettes
- mini buildings
- roads
- trees
- benches
- small vehicles
- simple residents / companions
- construction scenes
- low-poly or 2.5D-inspired compositions
- flat vector shapes

Avoid:
- Pixar-like rendering
- clay-style 3D
- stock corporate vector people
- glossy mascot art
- fake realism
- hyper-detailed architecture
- generic stock isometric city packs
- emojis used as final product illustration

At small scale:
**silhouette beats detail.**

---

# 17. Icon Language

Use the existing `MoneyIcon` / bespoke icon system where possible.

Icons should feel:
- minimal
- digital
- recognizable
- slightly illustrative
- confident
- reasonably thick in stroke / visual weight

Category identity should use the established category color family.

Avoid:
- random SF Symbols when a signature SPENT icon exists
- generic gray circles behind every icon
- thin inconsistent strokes
- mixing many unrelated icon styles
- glossy icon tiles

SF Symbols are acceptable for system-level affordances when a SPENT-specific icon would add no value.

---

# 18. Motion Philosophy

SPENT should respond to the user.

A tap should feel acknowledged.

Use:
- subtle scale
- opacity
- short translation
- spring
- haptic feedback
- small stagger
- object arrival / build animation when it reinforces the city metaphor

Typical motion:
- fast UI feedback: ~120–220ms
- state transition: ~220–350ms
- stagger between related items: ~40–60ms

Springs should settle cleanly.

Do not create:
- endless ambient movement
- bouncing for attention
- exaggerated elastic motion
- motion on every object
- animation that blocks navigation

Respect:
`accessibilityReduceMotion`

With Reduce Motion:
- preserve state clarity
- remove unnecessary translation / scale choreography
- allow simple opacity or immediate completion

---

# 19. Haptics

Use haptics as confirmation, not decoration.

Good moments:
- selection
- successful save
- category snap
- long-press quick action
- companion joins city
- meaningful navigation state

Avoid vibrating on every minor scroll or hover-like state.

---

# 20. Interaction Language

SPENT should feel physically responsive.

When the user acts:
1. the control visually responds immediately
2. the state change is understandable
3. the result appears quickly
4. haptic feedback may confirm
5. the UI settles

No dead taps.

No unclear delayed changes.

No animation that makes the user wonder whether the action worked.

Touch targets should be at least approximately `44×44pt` where possible.

---

# 21. Cards vs. Content

Before adding a card, ask:

> Does this content truly need a container?

If no, remove the card.

Use a card when:
- the entire object is tappable
- it represents a separate object/story
- clipping matters
- background identity matters
- it is a hero module

Do not create:
- card
  - inside card
    - inside colored tile
      - inside pill

This is one of the fastest ways to make SPENT feel AI-generated.

---

# 22. Pills and Capsules

Pills are controls, statuses, and filters.

They are not decoration.

Valid:
- selected filter
- status
- compact mode switch
- small metadata state
- action chip

Invalid:
- every label placed inside a pill
- decorative words floating in capsules
- three status pills where typography would be clearer

---

# 23. Data Visualization

Charts should answer a specific question.

Prefer:
- one focused chart
- direct labels
- category colors
- readable axis / context
- scrub interaction when useful

Avoid:
- dashboards full of unrelated charts
- decorative charts
- excessive legends
- gradients just to make bars look expensive
- 3D charts

Data remains the content.
Visual style supports it.

---

# 24. Narrative & Recap Screens

The recap language is editorial.

Key principles:

- one data point per visual beat
- strong typography
- simple graphic city illustration
- build-up and reveal
- retain context between transitions
- do not fade through empty screens unnecessarily
- no autoplay by default
- no fake statistic
- no weak insight just to fill space

Color and motion can be richer here than on utility screens.

Still avoid game-reward clichés.

---

# 25. Gamification Boundary

SPENT may feel alive and rewarding without becoming a game.

Allowed:
- city grows
- a companion arrives
- a building appears
- a park changes
- a small weekly addition
- visual progress
- subtle arrival animation

Avoid by default:
- XP
- levels
- coins
- streak pressure
- trophy language
- “LEVEL UP”
- confetti
- shame
- praise for spending less
- red failure states for normal financial behavior

The city describes behavior.
It does not judge the user.

---

# 26. Tone of Voice

Copy should feel:

- concise
- human
- observant
- calm
- a little poetic when the city metaphor helps
- never patronizing
- never childish
- never bank-like

Avoid:
- “Great job!”
- “You crushed it!”
- “Bad spending!”
- “Failure”
- guilt
- shame
- fake celebration

Prefer descriptive language:

- “העיר הייתה שקטה”
- “השבוע הצטרף חבר חדש”
- “החודש הרובע הזה היה עמוס יותר”
- “העיר עדיין נבנית”

The app can have personality without telling the user how to feel.

---

# 27. RTL / LTR

Hebrew is a first-class layout, not an afterthought.

New components should support Hebrew RTL and English LTR where relevant.

Mirror spatial logic where appropriate.

Do not simply reverse all imagery if doing so makes the composition worse.

Text alignment, chevrons, navigation direction, and action order must remain correct.

Illustrations may use art-directed mirroring.

---

# 28. Accessibility

Accessibility is part of the design language.

Always consider:
- Dynamic Type
- VoiceOver
- Reduce Motion
- contrast
- 44pt touch targets
- semantic labels
- decorative artwork hidden from accessibility
- text alternatives for complex illustrated scenes

Do not sacrifice readability to preserve a rigid layout.

If necessary:
- grow the component
- simplify the illustration
- reflow the layout

---

# 29. Empty States

Empty does not mean broken.

Empty states should:
- explain what is happening
- tell the user what appears here
- optionally offer one useful action
- feel calm
- use a restrained illustration or icon if useful

Do not fill empty states with fake data.

Do not over-celebrate an empty ledger.

---

# 30. Destructive Actions

Destructive behavior should remain clear and conventional.

Use:
- established destructive red
- clear label
- native interaction expectation
- confirmation only when consequences justify it

Do not turn delete into a playful brand moment.

---

# 31. Screen Personality Budget

Every screen gets a limited visual personality budget.

Before adding a decorative element ask:

1. What is the visual hero?
2. What is the primary action?
3. Where does color belong?
4. What can be removed?

A screen should normally have:
- one visual hero
- one main hierarchy
- one dominant accent family

Not five.

This is how SPENT can stay colorful without becoming noisy.

---

# 32. Color Budget

A useful default:

### Functional screen
- neutral canvas
- ink
- one primary accent
- category colors only where they carry identity

### Expressive screen
- neutral or softly tinted foundation
- 1 dominant palette
- 1 supporting palette
- small additional semantic colors if necessary

Do not mechanically enforce exact counts.
Use this as a discipline check.

---

# 33. Shape Language

Use shapes intentionally.

Good:
- circles for category identity
- continuous rounded rectangles for surfaces
- flat geometric fields for editorial art
- simple architectural polygons
- cropped shapes that imply a larger world

Avoid:
- arbitrary blobs
- wavy SaaS backgrounds
- decorative rings
- random dots
- floating geometry with no relationship to content

---

# 34. Photography / Render Rule

The main city can be genuinely dimensional.

The interface should not imitate photographic realism.

Do not use:
- fake lens flares
- depth-of-field blur for ordinary UI
- cinematic bloom
- shiny metallic UI
- realism as decoration

SPENT's beauty comes from composition and art direction, not rendering effects.

---

# 35. New Design Decision Ladder

When implementing a new UI, follow this order:

1. Reuse an existing SPENT component.
2. Reuse an existing token.
3. Reuse an existing pattern.
4. Extend an existing component.
5. Create a new local component.
6. Add a new design token only if the concept cannot be expressed with the existing system.

Do not jump straight to #6.

---

# 36. Canonical SPENT Formula

When uncertain, use this formula:

> **Clean native structure**
> + **strong typography**
> + **intentional whitespace**
> + **SPENT's vivid color family**
> + **one expressive visual idea**
> + **subtle responsive motion**
> + **city-world personality**
> − **AI visual clichés**
> − **container clutter**
> − **judgmental finance language**

That is SPENT.

---

# 37. Final North Star

SPENT should feel like:

**a modern iOS app designed by a visual designer who happens to love small cities, not a finance app decorated by an AI.**

It can be colorful.

It can be graphic.

It can be playful.

It can sometimes be visually bold.

But it must always be:

- intentional
- readable
- coherent
- calm where information matters
- expressive where story matters
- unmistakably SPENT.
