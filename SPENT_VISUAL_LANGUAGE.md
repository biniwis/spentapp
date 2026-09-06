# SPENT — Visual Language Specification (Design System)

This document establishes the official visual language for SPENT, reverse-engineered directly from the 8-screen reference design (`media_1788521222914.jpg`).

---

## 1. Core Philosophy: Elevated Native iOS

- **Clean & Calm**: The background is a soft, warm, breathable off-white (`#F8F9FA` / `#FBFBFB`). Content breathes with generous whitespace.
- **Content Over Containers**: Stop putting cards inside cards. Transactions and lists sit directly on the background canvas separated by whitespace and subtle dividers, not trapped inside heavy boxes.
- **Typographic Hierarchy**: Numbers and titles are confident and bold (SF Pro Rounded / Heavy for financial figures). Secondary labels are small, muted, and legible.
- **Accents, Not Rainbows**: Color is reserved for category identity badges, status tags (e.g. `↓ 12%`, `↑ 18%`), and primary actions. Everything else is neutral monochrome.
- **No AI / Fintech Clutter**: No neon gradients, no frosted glass overload, no 3D mascot spam, no glowing outlines. Pure Apple Human Interface Guidelines craftsmanship.

---

## 2. Color System

### Base Palette
- **Canvas Background**: `Color(hex: "F8F9FA")` (Light) / pure white cards when cards are needed (`#FFFFFF`).
- **Primary Text**: `Color(hex: "111827")` (near-black, high contrast, crisp).
- **Secondary Text**: `Color(hex: "6B7280")` (muted neutral gray for timestamps, categories, subtitles).
- **Tertiary / Hairline**: `Color(hex: "E5E7EB")` / `Color(hex: "F3F4F6")` (for subtle dividers and inactive chip backgrounds).
- **Primary Action (Dark Accent)**: `Color(hex: "111827")` (solid charcoal/black for primary buttons like "Save Expense", active filter chips, and central `+` button).
- **Positive / Trend Green**: `Color(hex: "10B981")` with soft green background `Color(hex: "D1FAE5")` (for `↓ 12%` spending decrease or `↑ 18%` savings progress).

### Category Pastel Palette (Badges & Highlights)
Exact pastel pairs (icon glyph on soft tint background):
1. **Food**: Background `Color(hex: "FFEDD5")` (warm peach), Icon `Color(hex: "F97316")` (warm orange)
2. **Shopping**: Background `Color(hex: "FCE7F3")` (soft pink), Icon `Color(hex: "EC4899")` (magenta/pink)
3. **Transport**: Background `Color(hex: "DCFCE7")` (soft mint), Icon `Color(hex: "22C55E")` (fresh green)
4. **Housing**: Background `Color(hex: "E0F2FE")` (sky blue tint), Icon `Color(hex: "0284C7")` (ocean blue)
5. **Entertainment**: Background `Color(hex: "F3E8FF")` (soft lavender), Icon `Color(hex: "A855F7")` (purple)
6. **Health**: Background `Color(hex: "FFE4E6")` (soft rose), Icon `Color(hex: "F43F5E")` (coral rose)
7. **Subscriptions**: Background `Color(hex: "DBEAFE")` (periwinkle tint), Icon `Color(hex: "3B82F6")` (azure blue)
8. **Finance**: Background `Color(hex: "EDE9FE")` (soft violet), Icon `Color(hex: "8B5CF6")` (indigo/violet)
9. **Savings**: Background `Color(hex: "D1FAE5")` (soft sage), Icon `Color(hex: "10B981")` (emerald green)
10. **Miscellaneous**: Background `Color(hex: "EDE9FE")` (pale iris), Icon `Color(hex: "6366F1")` (indigo star)
11. **Other / Sorting**: Background `Color(hex: "F1F5F9")` (neutral slate), Icon `Color(hex: "64748B")` (slate gray)

---

## 3. Typography Scale

- **Hero Currency (Big KPI)**: `.system(size: 34, weight: .bold, design: .rounded)`
  - Symbol `₪` medium weight, digits heavy/bold.
- **Screen Title**: `.system(size: 28, weight: .bold, design: .default)` (left-aligned, e.g. "History", "Analytics")
- **Section Header**: `.system(size: 16, weight: .semibold, design: .default)` (e.g. "Today", "Yesterday")
- **Row Title (Merchant)**: `.system(size: 16, weight: .semibold, design: .default)`
- **Row Subtitle (Category / Time)**: `.system(size: 13, weight: .regular, design: .default)` in secondary gray.
- **Row Amount**: `.system(size: 16, weight: .bold, design: .rounded)`
- **Tag / Badge Text**: `.system(size: 12, weight: .semibold, design: .default)`
- **Button Label**: `.system(size: 16, weight: .semibold, design: .default)`

---

## 4. Component Standards

### Filter Chips (Pills)
- Height: 36pt.
- Inactive: Background `#F3F4F6`, Text `#4B5563`, corner radius 18pt.
- Active: Background `#111827` (charcoal/black), Text `#FFFFFF`, corner radius 18pt.
- Horizontal padding: 16pt.

### Circular Category Icon Badges
- Size: 44pt × 44pt perfect circle (`Circle()`).
- Background: Specific soft pastel color (from palette above).
- Icon: Centered SF Symbol, 18pt, colored with category accent.

### Transaction Row (Editorial Ledger)
- Sits directly on screen background (`#F8F9FA` or white view), not inside a container card.
- Layout:
  `[ 44pt Circular Pastel Icon ]  [ Merchant (Bold) / Category (Gray) ]  ... [ ₪Amount (Bold) / Time (Gray) ]`
- Spacing: 12pt horizontal gap, 14pt vertical padding between rows.

### Section Headers
- "Today" on left (`16pt .semibold`), Daily Total on right (`16pt .bold rounded`, e.g. "₪214").
- No background box, clean typography directly on the view.

### Primary Buttons
- Background: `#111827` (solid dark charcoal).
- Foreground: `#FFFFFF`.
- Corner radius: 24pt (smooth continuous rounded capsule/rectangle).
- Height: 54pt full-width.

---

## 5. Screen-by-Screen Roadmap

1. **History View** (First Validation Screen):
   - Replace grouped cards with editorial ledger.
   - Day sections with day sum aligned to trailing edge.
   - Filter chips at top (All, Food, Shopping, Transport).
   - Pastel circular badges with merchant/category on leading, amount/time on trailing.
2. **Analytics View**:
   - Clean month picker `< September 2026 >`.
   - Segmented capsule pills: `[ Spending | Income | Savings ]`.
   - Big hero KPI with comparison badge.
   - Lavender bar chart with highlighted active month.
   - Top Categories list with percentage and amount.
3. **Quick Add Sheet**:
   - Minimalist hero amount display: `₪0.00` with blinking cursor.
   - Native-feeling clean numeric keypad (1-9, ., 0, backspace).
   - Minimal input pill rows (Merchant, Category with pastel circle, Date).
   - Full-width dark charcoal "Save Expense" button.
4. **Categories Sheet**:
   - 3-column grid of soft pastel rounded tiles with clean typography.
5. **Profile View**:
   - Personal control center with clean avatar hero and organized grouped rows.
6. **Main City Screen**:
   - Keep 3D diorama hero and top category selector.
   - Refine frame: clean hero KPI, month badge, floating district indicator card.
