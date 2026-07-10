-- ============================================================================
-- Monthly Complaints Report - per department, with MoM and YoY comparison
-- ============================================================================
-- Assumed schema:
--
-- CREATE TABLE Departments
-- (
--     DepartmentId    INT             NOT NULL PRIMARY KEY,
--     DepartmentName  NVARCHAR(100)   NOT NULL
-- );
--
-- CREATE TABLE Complaints
-- (
--     ComplaintId     UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
--     DepartmentId    INT              NOT NULL FOREIGN KEY REFERENCES Departments(DepartmentId),
--     CreatedDate     DATETIME2(0)     NOT NULL,
--     -- ... other complaint columns (ContactId, Description, Status, etc.)
-- );
--
-- Recommended supporting index (see performance notes below):
-- CREATE NONCLUSTERED INDEX IX_Complaints_DepartmentId_CreatedDate
--     ON Complaints (DepartmentId, CreatedDate);
-- ============================================================================

DECLARE @ReportYear  INT = YEAR(GETDATE());
DECLARE @ReportMonth INT = MONTH(GETDATE());

-- Boundaries as sargable range predicates (never wrap CreatedDate in a function)
DECLARE @CurrentMonthStart   DATE = DATEFROMPARTS(@ReportYear, @ReportMonth, 1);
DECLARE @CurrentMonthEnd     DATE = DATEADD(MONTH, 1, @CurrentMonthStart);

DECLARE @PrevMonthStart      DATE = DATEADD(MONTH, -1, @CurrentMonthStart);
DECLARE @PrevMonthEnd        DATE = @CurrentMonthStart;

DECLARE @PrevYearStart       DATE = DATEADD(YEAR, -1, @CurrentMonthStart);
DECLARE @PrevYearEnd         DATE = DATEADD(MONTH, 1, @PrevYearStart);

;WITH MonthlyCounts AS
(
    -- One row per department per calendar month that actually has complaints.
    -- Only scans the 3 relevant windows (current / prev month / same month last year),
    -- not the whole table.
    SELECT
        c.DepartmentId,
        DATEFROMPARTS(YEAR(c.CreatedDate), MONTH(c.CreatedDate), 1) AS ComplaintMonth,
        COUNT(*) AS ComplaintCount
    FROM Complaints c
    WHERE
        (c.CreatedDate >= @CurrentMonthStart AND c.CreatedDate < @CurrentMonthEnd)
        OR (c.CreatedDate >= @PrevMonthStart AND c.CreatedDate < @PrevMonthEnd)
        OR (c.CreatedDate >= @PrevYearStart AND c.CreatedDate < @PrevYearEnd)
    GROUP BY
        c.DepartmentId,
        DATEFROMPARTS(YEAR(c.CreatedDate), MONTH(c.CreatedDate), 1)
)
SELECT
    d.DepartmentId,
    d.DepartmentName,
    @CurrentMonthStart                                     AS ReportMonth,
    ISNULL(cur.ComplaintCount, 0)                          AS CurrentMonthCount,
    ISNULL(prevMonth.ComplaintCount, 0)                    AS PreviousMonthCount,
    ISNULL(prevYear.ComplaintCount, 0)                     AS SameMonthLastYearCount,
    CAST(
        CASE WHEN ISNULL(prevMonth.ComplaintCount, 0) = 0 THEN NULL
             ELSE (cur.ComplaintCount - prevMonth.ComplaintCount) * 100.0 / prevMonth.ComplaintCount
        END AS DECIMAL(10, 2)
    )                                                        AS MoMChangePercent,
    CAST(
        CASE WHEN ISNULL(prevYear.ComplaintCount, 0) = 0 THEN NULL
             ELSE (cur.ComplaintCount - prevYear.ComplaintCount) * 100.0 / prevYear.ComplaintCount
        END AS DECIMAL(10, 2)
    )                                                        AS YoYChangePercent
FROM Departments d
LEFT JOIN MonthlyCounts cur
    ON cur.DepartmentId = d.DepartmentId
   AND cur.ComplaintMonth = @CurrentMonthStart
LEFT JOIN MonthlyCounts prevMonth
    ON prevMonth.DepartmentId = d.DepartmentId
   AND prevMonth.ComplaintMonth = @PrevMonthStart
LEFT JOIN MonthlyCounts prevYear
    ON prevYear.DepartmentId = d.DepartmentId
   AND prevYear.ComplaintMonth = @PrevYearStart
ORDER BY
    d.DepartmentName;
