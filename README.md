# מערכת פניות הציבור — Public Complaint Form

מערכת מקוונת המאפשרת לאזרח להגיש פנייה/בקשה או תלונה לגורם ציבורי (בהשראת "פניות הציבור" בבתי המשפט), כולל אימות CAPTCHA, העלאת מסמכים, ולאחר מכן קבלת סקר שביעות רצון. המערכת בנויה כשני פרויקטים נפרדים המתקשרים דרך REST API.

## תוכן עניינים

1. [תכולת הפרויקט](#תכולת-הפרויקט)
2. [ארכיטקטורה ושיטת הבנייה](#ארכיטקטורה-ושיטת-הבנייה)
3. [רכיבים עיקריים ושיקולי תכנון](#רכיבים-עיקריים-ושיקולי-תכנון)
4. [אבטחה](#אבטחה)
5. [טיפול בשגיאות](#טיפול-בשגיאות)
6. [מנגנוני קישור בין השכבות ו-CORS](#מנגנוני-קישור-בין-השכבות-ו-cors)
7. [התקנה והפעלה](#התקנה-והפעלה)

---

## תכולת הפרויקט

| חלק | טכנולוגיה | תיקייה |
|---|---|---|
| Frontend | Angular 19 (Standalone Components) | `PublicComplaintForm/` |
| Backend | ASP.NET Core / .NET 8 (Minimal API) | `PublicComplaintForm_API/` |

### זרימת המשתמש (Frontend)

טופס אשף (Wizard) בן 5 שלבים, שכל שלב הוא Route נפרד תחת `MainFormComponent`, עם פס התקדמות (breadcrumbs):

| Route | Component | תיאור |
|---|---|---|
| `/` | `ContactTypeComponent` | בחירת סוג הפנייה (בקשה/תלונה) + סימון "פנייה חוזרת" |
| `/step2` | `ContactorDetailsComponent` | פרטי הפונה (שם, ת.ז, טלפון, אימייל, כתובת), כולל אפשרות "פנייה בשם אדם אחר" |
| `/step3` | `ContactDetailsComponent` | פרטי הפנייה — תיאור, מספר תיק, בית משפט רלוונטי |
| `/step4` | `DocumentUploadComponent` | העלאת מסמכים תומכים (עד 10MB לקובץ, 50MB בסך הכול) |
| `/step5` | `SummaryComponent` | סיכום כל הנתונים, אימות CAPTCHA, ושליחה סופית |
| `/done` | `FinishedComponent` | מסך סיום |

בנוסף, זרימה נפרדת לסקר שביעות רצון:

| Route | Component | תיאור |
|---|---|---|
| `/survey/:id` | `SurveyPageComponent` | סקר שביעות רצון (דירוגי כוכבים + טקסט חופשי) |
| `/survey-thank-you` | `SurveyThankYouComponent` | מסך תודה לאחר שליחת הסקר |

### נקודות קצה (Backend API)

| Method | Path | תיאור |
|---|---|---|
| GET | `/` | בדיקת תקינות (health check) |
| GET | `/courts` | רשימת בתי משפט (לתפריט הבחירה בשלב 3) |
| GET | `/captcha` | הפקת CAPTCHA (תמונה + מזהה session) |
| POST | `/survey` | שליחת סקר שביעות רצון |
| POST | `/submit-form` | שליחת הפנייה המלאה (multipart/form-data: שדות + קבצים) |
| GET | `/log?lines=N` | צפייה ב-N השורות האחרונות של קובץ הלוג |
| POST | `/send-email` | שליחת מייל התרעה כאשר בקשה נחסמה |
| GET | `/reports/monthly-complaints?year=&month=` | דוח פניות חודשי לפי מחלקה (ראו הרחבה למטה) |

---

## ארכיטקטורה ושיטת הבנייה

### Frontend — Angular

- **Standalone Components** בלבד (ללא `NgModule` קלאסי חוץ מ-`app.module.ts` הישן שאינו בשימוש בפועל), עם `provideRouter` ב-`app.config.ts`.
- **ניהול מצב הטופס**: `FormHandlerService` הוא singleton שמחזיק 3 `FormGroup` (אחד לכל שלב לוגי) ומערך קבצים שהועלו. כל קומפוננטת שלב שולפת/מעדכנת את החלק שלה דרך `getStepValues()` / `updateStepFields()`. כך הנתונים נשמרים בזיכרון בין מעברי Route (אך לא שורדים רענון דף — decision מכוון, שכן אין דרישה ל-persistence בצד הלקוח).
- **שליחה סופית**: `FormHandlerService.doSubmitForm()` "משטח" (flatten) את שלושת ה-FormGroup לאובייקט אחד, בונה `FormData` (multipart) עם כל השדות + הקבצים + קוד ה-CAPTCHA, ושולח ל-`/submit-form`.
- **קונפיגורציה סביבתית**: `ConfigService` טוען את `public/config.json` בזמן ריצה (לא בזמן build), ובוחר את כתובת ה-API המתאימה לפי `window.location.hostname` (`localhost` / `dmztest` / `crm9d` / `production` / `dmztest_f5`). כך אותו build (dist) יכול לרוץ מול מספר סביבות backend שונות בלי לבנות מחדש.
- **ניווט בין שלבים**: `BreadcrumbsManagerService` (BehaviorSubject) משדר את השלב הנוכחי ל-`MainFormComponent`, שמעדכן את מחלקות ה-CSS של פס ההתקדמות.

### Backend — ASP.NET Core Minimal API

- כל נקודות הקצה מוגדרות ישירות ב-`Program.cs` (Minimal API — ללא Controllers), בסגנון function-per-endpoint.
- **שכבת שירותים (Services/)**:
  - `DatabaseService` — שכבת גישה לנתונים. **בכוונה שכבת stub** בשלב זה (כל מתודה מחזירה ערך ריק/ברירת מחדל, ללא חיבור DB אמיתי) — כך שאר המערכת (Endpoints, Frontend) ניתנת לפיתוח ובדיקה מקצה לקצה בלי תלות בזמינות מסד נתונים.
  - `CaptchaService` — מפיק קוד CAPTCHA אקראי ומצייר אותו לתמונה (SixLabors.ImageSharp) עם רעש (dots) להקשחה מול OCR פשוט.
  - `SanitizingService` — מנקה (Sanitize) כל שדה מחרוזת בנתוני הטופס באמצעות `Ganss.Xss.HtmlSanitizer` לפני שהם ממשיכים בטיפול.
  - `LogService` — קורא את N השורות האחרונות מקובץ הלוג עבור endpoint הדיאגנוסטיקה `/log`.
- **לוגים**: log4net (`log4net.config`), כותב לקובץ `logs/app.log`. אתחול הלוגר מתבצע *לפני* קריאת קונפיגורציית הסביבה, כך שגם כשל בטעינת קונפיגורציה בזמן עלייה נרשם ללוג.
- **קונפיגורציה לפי סביבה**: משתנה סביבה `ServerIdentity` (למשל `DMZTEST`/`CRM9D`/`PROD`) קובע איזה סעיף ב-`appsettings.json` ייטען (מחרוזות התחברות, נתיב שמירת קבצים, רשימת תפוצה למיילים). כשלא מוגדר (כמו בסביבת פיתוח מקומית) — נופל בחזרה לברירות מחדל בטוחות.

---

## רכיבים עיקריים ושיקולי תכנון

- **הפרדת אחריות בין שלבי הטופס לבין השליחה**: כל שלב "יודע" רק על עצמו ומתעדכן מול `FormHandlerService`, ורק שלב הסיכום (`SummaryComponent`) אחראי לאיחוד הנתונים ולשליחה בפועל — כך אפשר להוסיף/להסיר שלבים בלי לגעת בלוגיקת השליחה.
- **בחירת בית משפט**: הרשימה מגיעה מ-`GET /courts`; ה-Frontend כולל גם רשימת ברירת מחדל (hardcoded) כדי שהעמוד יישאר שמיש גם אם ה-API עדיין לא מחובר למסד נתונים אמיתי.
- **דוח פניות חודשי (`/reports/monthly-complaints`)**: משום שאין חיבור DB אמיתי בשלב זה, `DatabaseService.GetMonthlyComplaintReport` מייצר נתוני דמה **דטרמיניסטיים** (מבוססי seed לפי מחלקה+שנה+חודש) — כך שאותה בקשה תמיד מחזירה אותן תוצאות, מה שמאפשר לבדוק את ה-Endpoint וה-Contract שלו כאילו הוא מגובה DB אמיתי. שאילתת ה-SQL המלאה לדוח (כולל השוואת MoM ו-YoY לפי מחלקה) נמצאת ב-`PublicComplaintForm_API/Reports/MonthlyComplaintsReport.sql`, עם הסבר והצעות ייעול ביצועים בגוף הקובץ.
- **העלאת קבצים**: מתבצעת רק אם קיימים קבצים בבקשה (ולא נוצרת תיקייה ריקה סתם), לכל פנייה מוקצה תיקיית העלאה נפרדת לפי `Guid` (`inquiryId`) כדי למנוע התנגשויות/דריסת קבצים בעלי שם זהה משני משתמשים שונים.

---

## אבטחה

| הגנה | איפה | הסבר |
|---|---|---|
| **CAPTCHA** | `CaptchaService` + `/captcha`, `/submit-form` | קוד CAPTCHA מיוצר בצד השרת ונשמר ב-`IMemoryCache` לפי מזהה session אקראי (GUID), עם תפוגה של שעה. מאומת מול קלט המשתמש בעת שליחת הטופס — מונע שליחות אוטומטיות/בוטים. |
| **Sanitization** | `SanitizingService` | כל שדה טקסט חופשי (כולל תיאור הפנייה) עובר ניקוי HTML לפני שהוא מוחזר/מטופל, כהגנה מפני XSS מאוחסן/משתקף. |
| **אימות סוגי קבצים** | `/submit-form` | רשימת סיומות מותרות בלבד (`.pdf .doc .docx .png .jpeg .jpg .gif .ogg .mp4 .mp3 .msg`) — קובץ בסיומת אחרת נדחה עם הודעה ברורה, ולא נשמר לדיסק. |
| **כותרות אבטחה (Security Headers)** | Middleware ב-`Program.cs` | `Referrer-Policy: same-origin`, `X-Frame-Options: DENY`, `Content-Security-Policy: frame-ancestors 'none'` — מניעת Clickjacking והדלפת referrer. |
| **הסתרת פרטי שגיאה פנימיים** | Global Exception Handler + `BuildErrorResponse` | תגובת שגיאה ללקוח כוללת הודעה כללית + `requestId` בלבד; הודעת החריגה המלאה (Exception + Stack Trace) נרשמת ללוג בצד השרת ואינה נחשפת ללקוח — מונע דליפת מידע פנימי (מבנה קוד, נתיבים וכו') שיכול לסייע לתוקף. |
| **CORS מוגבל** | `Program.cs` | מדיניות בשם `LocalDev` מרשה מקור (`origin`) יחיד וידוע בלבד (`http://localhost:4200`), פעילה רק בסביבת `Development` — אין `AllowAnyOrigin`. פירוט בסעיף הבא. |
| **ללא Secrets בקוד** | `appsettings.json` | ערכי מחרוזות התחברות/נתיבים הם placeholders (`"CONNECTION STRING"`, `"PATH"`) בלבד; ערכים אמיתיים אמורים להגיע ממקור קונפיגורציה מאובטח בסביבת הפרודקשן (ולא מתוך ה-repository). |
| **Antiforgery — הערת תכנון** | `Program.cs` | המערכת מגדירה `AddAntiforgery` עם כותרת `X-CSRF-TOKEN`, אך מבטלת אותה במפורש (`.DisableAntiforgery()`) על `/survey` ו-`/submit-form`. ההחלטה מכוונת: אלו נקודות קצה ציבוריות, ללא Cookie/Session מבוססי משתמש מזוהה, כך שאין להן "הקשר" שממנו CSRF Token נגזר. ה-CAPTCHA ממלא בפועל את תפקיד ההגנה מפני שליחה אוטומטית/לא רצויה. ברגע שתתווסף הזדהות משתמשים (Authentication) יש להפעיל מחדש את ההגנה עבור ה-Endpoints הרלוונטיים. |

---

## טיפול בשגיאות

- **עקביות**: כל Endpoint עוטף את הלוגיקה שלו ב-`try/catch`. שגיאה בלתי צפויה מטופלת ע"י פונקציית עזר משותפת אחת — `BuildErrorResponse(log, ex, logMessage, publicMessage, statusCode)` — כדי שכל תגובות השגיאה יהיו באותה צורה בדיוק:
  ```json
  { "error": "הודעה קצרה וברורה", "requestId": "..." }
  ```
  עם קוד HTTP מתאים (ברירת מחדל `500 Internal Server Error`; `400 Bad Request` לקלט לא תקין).
- **Global Exception Handler**: כל חריגה שלא נתפסה מפורשות (בסביבת Production) נלכדת ב-Middleware גלובלי, נרשמת ללוג, ומוחזרת ללקוח באותו פורמט אחיד דרך אותה פונקציית עזר — כלומר אין "מסלול שגיאה" שונה בין קריסה בתוך Endpoint ספציפי לבין קריסה שלא נצפתה מראש.
- **הפרדה בין "שגיאת קלט צפויה" ל"תקלה בלתי צפויה"**: לדוגמה ב-`/submit-form`, מקרים כמו "קובץ עם סיומת לא חוקית" או "CAPTCHA שגוי" הם חלק מהזרימה התקינה של האפליקציה (Business validation) ומוחזרים כ-`200 OK` עם טקסט ברור שה-Frontend כבר יודע לפרש — לעומת חריגה טכנית אמיתית (למשל כשל בכתיבה לדיסק) שמטופלת ע"י ה-`catch` הכללי ומוחזרת כ-`500` עם המבנה האחיד שלמעלה. כך חוזה התגובה (Response Contract) הקיים מול ה-Frontend לא השתנה, אבל תקלות אמיתיות מדווחות בצורה נכונה וברת-אבחון.
- **לוגים לפעולות ולשגיאות**: לצד רישום כניסה לכל Endpoint (`log.Info`), נוספו רישומי `log.Warn` בנקודות החלטה חשובות שלא תועדו קודם (CAPTCHA שגוי, סיומת קובץ לא חוקית, סקר שכבר נשלח, כשל בטעינת קונפיגורציה בעליית השרת) — ניתן לצפות בהם דרך `/log?lines=N`.

---

## מנגנוני קישור בין השכבות ו-CORS

### איך ה-Frontend "מוצא" את ה-Backend

הבעיה: אותו build של ה-Angular app צריך לרוץ מול backend שונה בכל סביבה (מקומי / DMZ / CRM / פרודקשן), בלי לבנות מחדש בכל פעם.

הפתרון — `ConfigService`:
1. בזמן עליית האפליקציה נטען `public/config.json` (קובץ **סטטי**, לא מוטמע ב-bundle של ה-build — כך שניתן לערוך אותו אחרי הפריסה בלי build מחדש).
2. הקובץ ממפה `hostname → apiUrl` עבור כל סביבה (`localhost`, `dmztest`, `crm9d`, `production`, `dmztest_f5`).
3. `ConfigService.getApiUrl()` בודק את `window.location.hostname` בזמן ריצה ומחזיר את כתובת ה-API המתאימה.
4. כל שירות שמדבר עם ה-API (`FormHandlerService`, `CaptchaService`, `CourtHandlerService`, `SurveyPageComponent`) קורא ל-`ConfigService.getApiUrl()` לפני כל קריאת HTTP.

### ניווט פנימי (בין שלבי הטופס)

מבוסס Angular Router רגיל (`app.routes.ts`) עם `RouterOutlet` בתוך `MainFormComponent`. כל שלב עובר לשלב הבא/קודם באמצעות `router.navigate([...])`, כאשר `FormHandlerService` הוא ה"זיכרון" המשותף שמבטיח שהנתונים לא אובדים במעבר בין ה-Routes (ל-Route אין מצב פנימי משלו).

### CORS

- Backend מגדיר מדיניות CORS בשם `LocalDev` שמאפשרת בקשות אך ורק מ-`http://localhost:4200` (המקור של שרת הפיתוח של Angular), עם כל השיטות (`AllowAnyMethod`) וכל הכותרות (`AllowAnyHeader`).
- המדיניות מופעלת (`app.UseCors("LocalDev")`) **רק** כאשר `Environment.IsDevelopment()` — כלומר בסביבת Production אין כלל מדיניות CORS מוגדרת/פעילה כברירת מחדל.
- הסיבה שבכלל נדרש CORS בפיתוח: שרת הפיתוח של Angular (`ng serve`, פורט 4200) ושרת ה-API (פורט 5209) נחשבים "מקורות" (origins) שונים מבחינת הדפדפן (פורט שונה = origin שונה), ולכן קריאות `fetch`/`XHR` ביניהם חסומות כברירת מחדל ללא הרשאת CORS מפורשת מהשרת.
- בסביבת Production אמיתית, הציפייה היא שה-Frontend וה-API יוגשו תחת אותו domain (או מאחורי Reverse Proxy משותף), כך שלא יידרש CORS כלל — ואם בכל זאת יידרש (domain נפרד), יש להוסיף מדיניות ייעודית ומצומצמת (origin ספציפי, לא Wildcard) באותה תבנית.

---

## התקנה והפעלה

### דרישות מוקדמות

- [Node.js](https://nodejs.org/) (גרסה 18 ומעלה) + npm
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)

### 1. הפעלת ה-Backend (API)

```bash
cd PublicComplaintForm_API
dotnet restore
dotnet run --launch-profile http
```

השרת יאזין בכתובת: `http://localhost:5209`

**הערות:**
- קונפיגורציית סביבה (מחרוזות התחברות, נתיב שמירת קבצים) נטענת לפי משתנה הסביבה `ServerIdentity` (למשל `DMZTEST` / `CRM9D` / `PROD`, ראו `appsettings.json`). כשהוא לא מוגדר (המצב המקומי הרגיל), הקוד נופל לברירת מחדל מקומית — שמירת קבצים מתבצעת לתיקיית `Uploads/` בתוך תיקיית הפרויקט.
- ה-API כולל מדיניות CORS בשם `LocalDev` המאפשרת גישה מ-`http://localhost:4200`, פעילה רק בסביבת `Development`.

### 2. הפעלת ה-Frontend (Angular)

```bash
cd PublicComplaintForm
npm install
npm start
```

האפליקציה תהיה זמינה בכתובת: `http://localhost:4200`

**הערה:** הקובץ `PublicComplaintForm/public/config.json` מגדיר את כתובת ה-API לכל סביבה (`localhost`, `dmztest`, `crm9d`, `production`, `dmztest_f5`) לפי `hostname`. להרצה מקומית יש לוודא שהמפתח `localhost.apiUrl` מצביע לכתובת ה-API המקומית:

```json
"localhost": {
    "apiUrl": "http://localhost:5209"
}
```

### 3. בדיקת תקינות

- Backend: `http://localhost:5209/` אמור להחזיר `"API is running..."`.
- Frontend: פתיחת `http://localhost:4200/` אמורה להציג את שלב "סוג הפנייה" הראשון בטופס.
- דוח פניות חודשי (נתוני דמה): `http://localhost:5209/reports/monthly-complaints`
- לוגים: `http://localhost:5209/log?lines=50`

### בנייה לפרודקשן (אופציונלי)

```bash
# Backend
cd PublicComplaintForm_API
dotnet publish -c Release

# Frontend
cd PublicComplaintForm
ng build
```
