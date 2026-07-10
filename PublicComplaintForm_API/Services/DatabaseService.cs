using PublicComplaintForm_API.Models;
using Microsoft.Data.SqlClient;
using System.Linq;
using Dapper;
using Microsoft.SqlServer.Server;
using log4net;

namespace PublicComplaintForm_API.Services
{
    public class DatabaseService
    {
        private readonly string _connectionString = string.Empty;
        private readonly string _surveyConnectionString = string.Empty;

        private readonly ILog _logger;

        public DatabaseService(ILog logger)
        {
            _logger = logger;
        }

        public DatabaseService(string connectionString, string surveyConnectionString, ILog logger)
        {
            _connectionString = connectionString ?? string.Empty;
            _surveyConnectionString = surveyConnectionString ?? string.Empty;
            _logger = logger;
        }

        public async Task<Guid> GetCourtId(string courtName)
        {
            return Guid.Empty;
        }

        public async Task<Guid> GetCityId(string cityName)
        {
            return Guid.Empty;
        }

        public async Task<Guid> DoesContactExist(string IdNumber)
        {
            return Guid.Empty;
        }

        public async Task<List<Court>> FetchCourtList()
        {
            return new List<Court>();
        }

        public async Task<Guid> InsertContact(PublicComplaintData formData)
        {
            return Guid.Empty;
        }

        public async Task<bool> InsertComplaint(
            PublicComplaintData formData,
            Guid contactId,
            Guid inquiryId,
            bool receivedFiles)
        {
            return false;
        }

        public async Task<bool> CanSubmitSurvey(SurveyData surveyData)
        {
            return false;
        }

        public async Task SubmitSurvey(SurveyData surveyData)
        {
            return;
        }

        public async Task SubmitForm(
            PublicComplaintData formData,
            List<string> files,
            Guid inquiryId,
            bool receivedFiles)
        {
            return;
        }

        // NOTE: Against a real database this would run the aggregated report query
        // (Reports/MonthlyComplaintsReport.sql) via Dapper against the Complaints/
        // Departments tables, parameterized by @ReportYear/@ReportMonth. No live DB
        // is wired up in this environment, so deterministic dummy data is generated
        // instead, in the same shape the real query would return.
        public async Task<List<MonthlyDepartmentComplaintReport>> GetMonthlyComplaintReport(int year, int month)
        {
            var departments = new[]
            {
                "מחלקת פניות ותלונות",
                "מחלקת גבייה",
                "מחלקת מידע ומוקד",
                "מחלקת הוצאה לפועל",
                "מחלקת בתי משפט"
            };

            var (prevMonthYear, prevMonth) = month == 1 ? (year - 1, 12) : (year, month - 1);

            var report = departments.Select(department =>
            {
                var currentCount = GenerateDeterministicCount(department, year, month);
                var previousMonthCount = GenerateDeterministicCount(department, prevMonthYear, prevMonth);
                var sameMonthLastYearCount = GenerateDeterministicCount(department, year - 1, month);

                return new MonthlyDepartmentComplaintReport
                {
                    DepartmentName = department,
                    Year = year,
                    Month = month,
                    CurrentMonthCount = currentCount,
                    PreviousMonthCount = previousMonthCount,
                    SameMonthLastYearCount = sameMonthLastYearCount,
                    MoMChangePercent = CalculatePercentChange(currentCount, previousMonthCount),
                    YoYChangePercent = CalculatePercentChange(currentCount, sameMonthLastYearCount)
                };
            }).ToList();

            return await Task.FromResult(report);
        }

        private static int GenerateDeterministicCount(string department, int year, int month)
        {
            var seed = HashCode.Combine(department, year, month);
            var random = new Random(seed);
            return random.Next(50, 300);
        }

        private static decimal? CalculatePercentChange(int current, int previous)
        {
            if (previous == 0)
                return null;

            return Math.Round((current - previous) * 100m / previous, 2);
        }
    }
}
