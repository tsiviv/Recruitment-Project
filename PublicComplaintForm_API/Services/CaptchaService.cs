using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp;
using System.Text;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Drawing.Processing;
using SixLabors.Fonts;
using PublicComplaintForm_API.Models;
using SixLabors.ImageSharp.Drawing;
using System.Diagnostics;
using Microsoft.Extensions.Caching.Memory;

namespace PublicComplaintForm_API.Services
{
    public class CaptchaService
    {
        const string availableCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

        public CaptchaService() 
        {
        }

        public CustomCaptcha GenerateCaptcha()
        {
            var captcha = new CustomCaptcha();

            var tempCode = GenerateCaptchaCode(6);
            var tempImage = GenerateCaptchaImage(tempCode);

            captcha.Image = tempImage;
            captcha.Code = tempCode;

            return captcha;
        }

        private string GenerateCaptchaCode(int length)
        {
            var random = new Random();
            var result = new StringBuilder(length);
            for (int i = 0; i < length; i++)
            {
                result.Append(availableCharacters[random.Next(availableCharacters.Length)]);
            }
            return result.ToString();
        }

        private Image GenerateCaptchaImage(string captchaCode)
        {
            const int width = 200;
            const int height = 50;

            var image = new Image<Rgba32>(width, height);
            var random = new Random();

            image.Mutate(ctx => ctx.Fill(Color.AliceBlue));

            var font = SystemFonts.CreateFont("Arial", 42, FontStyle.Regular);
            var textColor = Color.Black;
            var textOptions = new TextOptions(font);
            var textSize = TextMeasurer.MeasureSize(captchaCode, textOptions);

            var xx = (width - textSize.Width) / 2;
            var yy = (height - textSize.Height) / 2 - 5;

            image.Mutate(ctx =>
            {
                var textOptions = new RichTextOptions(font)
                {
                    Origin = new PointF(xx, yy)
                };

                // 1️⃣ Draw outline (thicker stroke)
                ctx.DrawText(textOptions, captchaCode, Pens.Solid(textColor, 1));
            });

            int dotsCount = 1000;

            for (int i = 0; i < dotsCount; i++)
            {
                int x = random.Next(0, width);
                int y = random.Next(0, height);

                var dotColor = new Rgba32((byte)random.Next(0, 255), (byte)random.Next(0, 255), (byte)random.Next(0, 255));

                image.Mutate(ctx => ctx.Fill(dotColor, new EllipsePolygon(x, y, 1)));
            }

            return image;
        }

        public bool ValidateCaptcha(string captchaSessionId, string userInput, IMemoryCache cache)
        {
            if (!cache.TryGetValue(captchaSessionId, out var storedCaptchaCode))
                return false;

            if (!storedCaptchaCode.ToString().ToLower().Equals(userInput.ToLower()))
            {
                Debug.WriteLine(storedCaptchaCode.ToString());
                Debug.WriteLine(userInput);
                return false;
            }

            return true;
        }
    }
}
