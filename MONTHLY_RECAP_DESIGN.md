# SPENT Monthly Recap — current implementation

The recap is a native SwiftUI editorial story, separate from the interactive Three.js city.
Use `MonthlyRecapSheet` → `RecapSceneFrame` and the reusable city shapes in that file.
Colors come from `IconPalette`, category theme colors and the existing SPENT canvas/ink.
There are no cards, gradients, badges, game rewards or charts inside the story.

## Sequence and pacing

Five anchors: month, spending, purchase activity, leading district, final portrait.
`MonthlyRecapInsightSelector` inserts up to two distinct stories before the portrait.
A month with sufficient signal has seven scenes; sparse months have five or six.
An empty district is a quiet park, never an invented category or statistic.

| Shot | Stage/object | Hero reveal | Detail/hold | Authored duration |
| --- | --- | --- | --- | --- |
| Opening | sun at 0.5s | masked month at 1.0s | year at 1.8s, skyline at 2.3s, windows at 3.2s | 4.4s |
| Total | staggered skyline at 0.6s | amount at 1.9s | statement at 3.0s, light wave at 3.5s | 5.2s |
| Activity | cropped building facade | masked count at 0.5s | windows at 1.4s, purchase label at 2.1s | 4.2s |
| District | category architecture at 0.7s | category at 2.8s | amount/share at 3.5s | 5.0s |
| Dynamic | repeated shops / tower / road / skylines / park | 2.2–3.0s | supporting fact after hero | 5.4s each |
| Portrait | storefront recedes, skyline and park enter | title at 3.7s | summary at 4.3s, caption at 4.8s, one car at 5.2s | 6.2s |

The seven-scene authored sequence is about 36 seconds plus user reading time. There is
**no automatic slide advancement**. Each shot settles and holds indefinitely. Do not
reintroduce autoplay as the default. Right-side tap / left swipe goes forward; left-side
tap / right swipe goes back, including Hebrew, per the product brief. Explicit accessible
Previous/Next buttons and Close are always available; no animation locks navigation.

Transitions reveal the incoming scene through a ground wipe, expanding facade or window
aperture. They retain the outgoing frame rather than fading through a blank screen. These
are graphic transitions, not a camera simulation or shared live 3D geometry.

## Data selection

The selector returns typed scene models with kind, values, category, merchant, date,
visual theme, score and copy variant. Views format supplied facts; they do not rank data.

- Savings, nonpositive and nonfinite values are not spending candidates.
- Fewer than four purchases: no dynamic stories.
- Merchant repeat: at least three visits, at least five or 25% of purchases, and a 1.5× lead
  over the next merchant. Merchant keys use existing normalization.
- Purchase: at least 3× average purchase; explicit recurring/installment metadata and
  conservative fixed-category/name rules are excluded.
- Day: at least two variable purchases and 2.2× average **active variable-spending day**,
  with at least three such days. Copy explicitly says non-recurring purchases.
- Month: at least 15% change, with a completed month and a positive previous baseline.
- Category: at least 40% change plus material absolute/baseline floors; the leading
  category is excluded because it already has a fixed scene.
- Weekend: at least eight purchases and 65% on Friday/Saturday; copy names those days.
- Rank deterministically and take at most two distinct visual and semantic themes.
  Exclude same-category pairs, a large purchase and its same-day story, and an overall
  month change paired with a category change.
- Never pad weak data with invented insights. Additional candidate types require their
  own reliable data and eligibility tests before they are added.

## Accessibility, lifecycle and share

Reduce Motion and VoiceOver show the completed frame immediately. Backgrounding suspends
the scene clock; the task is cancelled on navigation/dismissal and stops at the final hold.
The illustrated frame has one complete semantic label. Accessibility text sizes also get
a scrollable native text transcript. Hero values fit the frame; Hebrew and English use
explicit localized copy and numeric/currency formatting.

The final Share button opens the system share sheet only on user action. `ImageRenderer`
exports the same final portrait at 1170×1950 with SPENT branding, without navigation,
progress or buttons. Done dismisses the recap without jumping to a different month.

## Validation

Swift tests cover sparse-month anchors, merchant normalization/ranking, independent
stories, fixed/savings exclusion, partial-month comparison, overlapping stories and the
exact month boundary. Visual QA renders actual SwiftUI scenes in Hebrew and English,
including intermediate total-spend reveal frames. Physical-device motion/large accessibility
font comfort should still be reviewed with product feedback.
