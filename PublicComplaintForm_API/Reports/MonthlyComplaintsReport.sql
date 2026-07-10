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
-- The query filters only on CreatedDate (no DepartmentId predicate), so CreatedDate
-- must lead the key. DepartmentId is included so the index alone covers the query
-- (no key/RID lookup into the clustered index).
-- CREATE NONCLUSTERED INDEX IX_Complaints_CreatedDate_DepartmentId
--     ON Complaints (CreatedDate) INCLUDE (DepartmentId);
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

;WITH DepartmentCounts AS
(
    -- Single pass over the 3 relevant windows only (current / prev month / same month
    -- last year) - never scans the months in between. Each window is bucketed directly
    -- into its own conditional SUM ("pivot" via conditional aggregation), so there is no
    -- need to compute a per-row calendar-month key or to join the result back to itself
    -- once per comparison.
    SELECT
        c.DepartmentId,
        SUM(CASE WHEN c.CreatedDate >= @CurrentMonthStart AND c.CreatedDate < @CurrentMonthEnd THEN 1 ELSE 0 END) AS CurrentMonthCount,
        SUM(CASE WHEN c.CreatedDate >= @PrevMonthStart    AND c.CreatedDate < @PrevMonthEnd    THEN 1 ELSE 0 END) AS PreviousMonthCount,
        SUM(CASE WHEN c.CreatedDate >= @PrevYearStart     AND c.CreatedDate < @PrevYearEnd     THEN 1 ELSE 0 END) AS SameMonthLastYearCount
    FROM Complaints c
    WHERE
        (c.CreatedDate >= @CurrentMonthStart AND c.CreatedDate < @CurrentMonthEnd)
        OR (c.CreatedDate >= @PrevMonthStart AND c.CreatedDate < @PrevMonthEnd)
        OR (c.CreatedDate >= @PrevYearStart AND c.CreatedDate < @PrevYearEnd)
    GROUP BY
        c.DepartmentId
)
SELECT
    d.DepartmentId,
    d.DepartmentName,
    @CurrentMonthStart                                     AS ReportMonth,
    ISNULL(dc.CurrentMonthCount, 0)                        AS CurrentMonthCount,
    ISNULL(dc.PreviousMonthCount, 0)                       AS PreviousMonthCount,
    ISNULL(dc.SameMonthLastYearCount, 0)                   AS SameMonthLastYearCount,
    CAST(
        CASE WHEN ISNULL(dc.PreviousMonthCount, 0) = 0 THEN NULL
             ELSE (dc.CurrentMonthCount - dc.PreviousMonthCount) * 100.0 / dc.PreviousMonthCount
        END AS DECIMAL(10, 2)
    )                                                        AS MoMChangePercent,
    CAST(
        CASE WHEN ISNULL(dc.SameMonthLastYearCount, 0) = 0 THEN NULL
             ELSE (dc.CurrentMonthCount - dc.SameMonthLastYearCount) * 100.0 / dc.SameMonthLastYearCount
        END AS DECIMAL(10, 2)
    )                                                        AS YoYChangePercent
FROM Departments d
LEFT JOIN DepartmentCounts dc
    ON dc.DepartmentId = d.DepartmentId
ORDER BY
    d.DepartmentName;
