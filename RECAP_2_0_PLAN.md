# SPENT — Monthly Recap 2.0 · Dynamic Insight Engine Plan

מטרה: לשדרג את ה־Monthly Recap כך שהתוכן יהיה חכם, מעניין ומשתנה מחודש לחודש, בלי לגעת ב־motion language הקיים ובלי redesign.

**Motion system stays. Content system evolves.**

## Non-negotiables

- לא משנים את שפת האנימציה: rhythm/timing/pacing/transitions/entrance/`RecapBeat`/apertures.
- הריקאפ נשאר סיכום פיננסי אמיתי — Financial first, entertaining second.
- לא redesign. לא להפוך Surprise ל־trivia. לא Random אמיתי. לא LLM. הכל on-device.
- המסך האחרון (Final Portrait) נשמר כמעט 1:1; רק Micro Fact קטן נוסף.
- שיתוף/export קיים לא נפגע.

## מבנה התוכן

| חלק | אופי | שוט קיים/חדש |
|---|---|---|
| Opening | פתיחה | `.opening` (קיים) |
| Total Spend | Backbone 1 | `.total` (קיים) |
| Biggest District | Backbone 2 | `.district` (קיים) + `biggestStoryDistrict` |
| Biggest Meaningful Moment | Backbone 3 | `.insight(.biggestPurchase/biggestDay)` (קיים) |
| Hero #1 / #2 | Discovery | `.insight(...)` (קיים) |
| Things We Noticed | Discovery · multi | `.noticed([...])` (חדש) |
| Final Portrait + Micro Fact | סיום | `.portrait` (כמעט ללא שינוי) |

Cap: מקסימום 9 shots בגרסה הראשונה. חודש דל = 5 שוטים (כמו היום).

## שכבות אדריקטורליות

```
MonthlyRecapService
  └─ RecapInsightEngine      (candidate generators)
       └─ RecapInsightScoring  (Phase 4)
            └─ RecapInsightCurator (Phase 5: Hero/Noticed/Hero2/MicroFact; diversity בתוך אותו recap)
                 └─ MonthlyRecap content model
                      └─ Existing Recap UI
```

החלטות אדריכליות:
- `biggestDistrict` = אמת חשבונאית, לא משתנה (tests קיימים).
- `biggestStoryDistrict` = לצורכי storytelling בלבד; מחריג הוצאות קבועות; copy מנוסח בהתאם (לא טוען "הכי גדול בהכרח").
- Moment משתתף באותם overlap/diversity rules של Heroes/Noticed.
- Cross-month novelty נדחה לשלב שבו `RecapSnapshot` קיים (Phase 9). ב־Phase 5 רק novelty בתוך אותו recap.
- `MonthlyRecapInsightSelector` הקיים נשאר עובד עד Phase 6 (tests קיימים = gate).
- ה־curator פולט `MonthlyRecapDynamicInsight` קיים ל־UI — לא נוגעים ב־views/tests.
- Multi-insight = rows קלות (משפט + נתון), לא dashboard.

## Insight Families

accumulation, repetition, merchant, timing, streak, trend, comparison, concentration, diversity, outlier, category

## 12 Candidate Generators (Phase 3)

1. smallPurchasesAccumulation (accumulation)
2. repeatedMerchant (merchant)
3. repeatedCategory/habit — delivery/coffee/כללי (repetition)
4. busiestDay (timing)
5. noSpendStreak (streak)
6. firstHalfVsSecondHalf (comparison)
7. dayOfWeekPattern (timing)
8. spendingConcentration (concentration)
9. merchantDiversity (diversity)
10. categoryChange — MoM בלבד עד ש־baseline היסטורי קיים (category)
11. bigVsFrequent (merchant)
12. outlierPurchase (outlier)

כל candidate נושא family + scores + evidence/basis ("למה"). Deterministic (אותם data → אותו recap).

## Scoring (Phase 4)

שילוב משוקלל: surprise · relevance · contrast · confidence · novelty. כיול לפי תוצאות בפועל.
DEBUG logging: candidate/family/scores/final/selected/rejected + reason.

## שלבים

| Phase | תוכן | Verification gate |
|---|---|---|
| 1 | Audit | — (בוצע) |
| 2 | Data layer: Families/Scores/Insight | unit tests + build |
| 3 | 12 Candidate generators | unit tests + build + סקירת output על mock months |
| 4 | Scoring + DEBUG logging | unit tests + build |
| 5 | Curator (Hero1/Noticed/Hero2/MicroFact; diversity intra-recap) | unit tests + build |
| 6 | אינטגרציה: generateRecap + sequence + biggestStoryDistrict + rent-exclusion + moment/overlap | כל recap tests הקיימים + build + Preview |
| 7 | שוט Things We Noticed (sequential rows) | Preview |
| 8 | Micro Fact בפורטרט + export + accessible | Portrait tests (he/en) + build + Preview |
| 9 | RecapSnapshot (SwiftData) + archive reads snapshot | archive/SwiftData verification מלא + build |
| 10 | Debug/Design Lab: presets + candidates screen | `#if DEBUG`, mock data |

## קבצים

**Modified:** `MonthlyRecapService.swift`, `MonthlyRecapSheet.swift`, `MonthlyRecapArchiveView.swift`, `DesignLabView.swift`, `MonthlyRecapTests.swift`, docs (`MONTHLY_RECAP_DESIGN.md`, `CURRENT_ARCHITECTURE.md`).
**New:** `Services/RecapInsightEngine.swift`, `Models/RecapSnapshot.swift`, `MoneyCityTests/MonthlyRecapInsightEngineTests.swift`.

## לא נוגעים

`RecapBeat`, `RecapSceneAperture`, scene primitives, `text(at:)`, scene clock (`task(id: index)`), navigation/RTL, Reduce Motion/VO, progress capsules, share pipeline (`ImageRenderer` 1170×1950), שוטי opening/total/activity, איור העיר, כרטיסי archive, ואינטגרציות (MainCity/Analytics/Profile/CityTopBar/Notification/Budget).

## Acceptance Criteria (מתוך הבריף)

המשתמש מקבל סיכום פיננסי ברור; לפחות חלק מה־recap מביא מידע לא צפוי; recaps של חודשים שונים שונים באופן טבעי; בלי random מזויף; hero insights משמעותיים; Things We Noticed בלי מראה dashboard; בלי כפילויות; חלש לא ממלא מקום בכוח; cold start בלי history; personal baseline אחרי צבירת היסטוריה; אותו חודש = אותו recap; archived יציבים; הכל on-device; motion נשמר; portrait כמעט זהה; micro fact קטן בלבד; copy descriptive ולא judgmental.