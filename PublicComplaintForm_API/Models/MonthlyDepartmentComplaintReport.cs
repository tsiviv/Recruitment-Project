namespace PublicComplaintForm_API.Models
{
    public class MonthlyDepartmentComplaintReport
    {
        public string DepartmentName { get; set; } = string.Empty;
        public int Year { get; set; }
        public int Month { get; set; }
        public int CurrentMonthCount { get; set; }
        public int PreviousMonthCount { get; set; }
        public int SameMonthLastYearCount { get; set; }
        public decimal? MoMChangePercent { get; set; }
        public decimal? YoYChangePercent { get; set; }
    }
}
