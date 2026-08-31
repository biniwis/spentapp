# 🏙️ MoneyCity (iOS)

אפליקציית מעקב הוצאות אוטומטית המבוססת על Apple Pay ו-Shortcuts, שהופכת את ההתנהגות הפיננסית החודשית שלך לעיר חיה, יפה ואיזומטרית (Living Diorama).

---

## 📂 מבנה הפרויקט

```
MoneyCity/
├── MoneyCityApp.swift                 # נקודת כניסה ראשית (SwiftUI + SwiftData)
├── Models/
│   ├── SpendingCategory.swift         # קטגוריות, אימוג'ים, תגיות מרחפות וצבעים
│   ├── Transaction.swift              # מודל עסקה ב-SwiftData
│   ├── BuildingTile.swift             # מודל אריח ומבנה בדיורמה
│   └── MonthlyCity.swift              # חישוב דיורמה חודשית
├── Intents/
│   ├── RecordTransactionIntent.swift  # AppIntent שמופעל ברקע ע״י Shortcuts מ-Apple Pay
│   └── MoneyCityShortcuts.swift       # חשיפת ה-Shortcut לאפליקציית Shortcuts ול-Siri
├── Services/
│   ├── DatabaseService.swift          # ניהול SwiftData Container
│   ├── CategorizationEngine.swift     # מנוע סיווג חכם (מילון ישראלי + למידה)
│   └── CitySimulationEngine.swift     # אלגוריתם מיפוי ההוצאות למבנים, קו רקיע ופארקים
└── Views/
    ├── MainCityView.swift             # המסך הראשי
    ├── Diorama/
    │   ├── CityDioramaCanvas.swift    # קנבס איזומטרי תלת-ממדי עם פודיום מואר
    │   └── BuildingView.swift         # רינדור מבנה / קיוסק / מגדל / פארק חיסכון
    ├── Components/
    │   ├── FloatingBottomBar.swift    # טיפוגרפיה חלקה, צ'יפים מעוצבים וכפתור +
    │   └── MonthScrubberView.swift    # ניווט חודשים ומסע בזמן
    ├── Modals/
    │   ├── QuickAddSheet.swift        # הוספה מהירה של מזומן/ביט ב-2 שניות (טאפ 1 לשמירה)
    │   └── TransactionFeedSheet.swift # יומן עסקאות עם עריכת סיווג בטאפ אחד
    └── Onboarding/
        └── OnboardingWizardView.swift # הדרכת הגדרת Shortcuts ובדיקת "זרע ראשון"
```

---

## ⚡ איך להגדיר את ה-Shortcut באייפון (Personal Automation)

1. פתח את אפליקציית **Shortcuts** באייפון.
2. עבור לטאב **Automation** ולחץ על **New Automation (+)**.
3. גלול ובחר ב-**Transaction** (Wallet).
4. סמן:
   * **Card:** Any Card (כל הכרטיסים).
   * **Category:** Any Category.
   * סמן **Run Immediately** (הפעל מיד ללא שאלה).
5. בחר בפעולה: **Record Transaction in MoneyCity** (`RecordTransactionIntent`).
6. סיימת! מעכשיו כל תשלום ב-Apple Pay ייקלט שקט ברקע ויבנה את העיר שלך.
