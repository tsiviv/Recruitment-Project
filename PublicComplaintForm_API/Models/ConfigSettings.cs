namespace PublicComplaintForm_API.Models
{
    public class ConfigSettings
    {
        public string LocalSQL { get; set; } = string.Empty;
        public string SaveFileFolder { get; set; } = string.Empty;
        public string SurveySQLConnectionString { get; set; } = string.Empty;
        public List<string> EmailList { get; set; } = new();
    }
}