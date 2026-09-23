# SPENT — Git Workflow & Parallel Development

מדריך עבודה ב-Git עבור פיתוח מקבילי ב-SPENT: גרסת Production יציבה לצד פיתוח ארוך טווח של Shared Mode.

---

## 1. מבנה הסביבות (Worktrees)

כדי לעבוד במקביל בלי להחליף branches כל הזמן ובלי לסכן קוד לא מוכן, קיימות שתי תיקיות עבודה נפרדות:

1. **תיקיית Production הראשית:**
   - **מיקום:** `/Users/bnymynwysmn/Desktop/אפליקציה תואר/כסף`
   - **Branch:** `main`
   - **מטרה:** תיקוני באגים שוטפים, גרסאות TestFlight, והפצות ל-App Store.

2. **תיקיית Shared Mode (פיתוח שיתוף):**
   - **מיקום:** `/Users/bnymynwysmn/Desktop/אפליקציה תואר/spentapp-shared`
   - **Branch:** `feature/shared-mode`
   - **מטרה:** פיתוח מתמשך של פיצ'ר השיתוף, CloudKit, מודלים של Ledger ו-UI שיתופי.

---

## 2. חוקי הברזל

* **`main` הוא תמיד Production:** כל קוד שנמצא ב-`main` חייב להיות יציב ומוכן לבנייה לחנות / למשתמשים.
* **אין להכניס קוד לא גמור ל-`main`:** העבודה על `feature/shared-mode` לעולם לא מתמזגת ל-`main` עד להכרזה מפורשת שהפיצ'ר מוכן במלואו לשחרור.
* **כיוון הסנכרון הוא חד-סטרי:** 
  $$\text{fix branch} \longrightarrow \text{main} \longrightarrow \text{feature/shared-mode}$$
  כל תיקון או פיצ'ר שנכנס ל-`main` מתמזג לתוך `feature/shared-mode` כדי לשמור אותו מעודכן, אך לעולם לא להיפך.

---

## 3. פקודות עבודה יומיומיות

### א. ביצוע תיקון באג ב-Production (Bug Fix)
יש לבצע מתוך תיקיית ה-Production הראשית (`/Users/bnymynwysmn/Desktop/אפליקציה תואר/כסף`):

```bash
# 1. ודא שאתה על main מעודכן ונקי
git switch main
git pull --ff-only origin main

# 2. פתח ענף תיקון ייעודי
git switch -c fix/issue-name

# 3. בצע את התיקון, בדוק אותו, וקמט
git add .
git commit -m "fix: brief description of fix"

# 4. מיזוג ל-main ודחיפה
git switch main
git merge fix/issue-name
git push origin main

# 5. מחיקת ענף התיקון הזמני
git branch -d fix/issue-name
```

### ב. סנכרון התיקון לתוך סביבת Shared Mode
לאחר ש-`main` עודכן, יש לסנכרן את השינויים לתוך סביבת ה-Shared Mode.
יש לבצע מתוך תיקיית `spentapp-shared`:

```bash
# בתוך תיקיית spentapp-shared:
git fetch origin
git merge origin/main
git push origin feature/shared-mode
```

### ג. המשך פיתוח שוטף ב-Shared Mode
פשוט פותחים את Xcode מתוך התיקייה:
`/Users/bnymynwysmn/Desktop/אפליקציה תואר/spentapp-shared`
ועובדים כרגיל.

```bash
# שמירת עבודה שוטפת:
git add .
git commit -m "feat(shared): description of progress"
git push origin feature/shared-mode
```

---

## 4. חוקי שחרור (Release Checklist)

לפני יצירת Archive, TestFlight או App Store Release:

1. ודא שאתה עובד בתיקיית ה-Production הראשית.
2. ודא שה-branch הנוכחי הוא `main`:
   ```bash
   git branch --show-current
   ```
3. ודא שה-working tree נקי לחלוטין:
   ```bash
   git status
   ```
4. ודא שאין שינויים שממתינים למשיכה:
   ```bash
   git fetch origin
   git log HEAD..origin/main
   ```
5. ודא שאין קוד של Shared Mode ב-`main`.
