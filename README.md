# מערכת פניות הציבור — Public Complaint Form

הפרויקט מורכב משני חלקים:

| חלק | טכנולוגיה | תיקייה |
|---|---|---|
| Frontend | Angular 19 | `PublicComplaintForm/` |
| Backend | ASP.NET Core (.NET 8, Minimal API) | `PublicComplaintForm_API/` |

> שאר סעיפי המסמך (תכולת הפרויקט, שיטת הבנייה והשיקולים, אבטחה, טיפול בשגיאות, מנגנוני קישור וקרוס-דומיין) יתווספו בהמשך. הסעיף הבא מתאר כיצד להתקין ולהפעיל את הפרויקט מקומית.

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

### בנייה לפרודקשן (אופציונלי)

```bash
# Backend
cd PublicComplaintForm_API
dotnet publish -c Release

# Frontend
cd PublicComplaintForm
ng build
```
