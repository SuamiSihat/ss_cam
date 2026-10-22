using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows.Media.Imaging;
using SS_CAM.Models;

namespace SS_CAM.Services
{
    public enum QrErrorCorrectionLevel
    {
        L = 0, // ~7% recovery
        M = 1, // ~15% recovery
        Q = 2, // ~25% recovery
        H = 3  // ~30% recovery
    }

    public enum QrBodyShape
    {
        Square,
        Circle,
        Rounded,
        Dots,
        Diamond,
        Classy
    }

    public enum QrEyeFrameShape
    {
        Square,
        Circle,
        Rounded
    }

    public enum QrEyeDotShape
    {
        Square,
        Circle,
        Diamond,
        Dot
    }

    public class QrCodeOptions
    {
        public string Content { get; set; }
        public QrErrorCorrectionLevel ErrorCorrection { get; set; }
        
        // Colors
        public Color ForegroundColor { get; set; }
        public Color ForegroundColor2 { get; set; }
        public bool UseGradient { get; set; }
        public float GradientAngle { get; set; }
        public Color BackgroundColor { get; set; }
        
        public Color EyeFrameColor { get; set; }
        public Color EyeDotColor { get; set; }
        public bool CustomEyeColors { get; set; }

        // Shapes
        public QrBodyShape BodyShape { get; set; }
        public QrEyeFrameShape EyeFrameShape { get; set; }
        public QrEyeDotShape EyeDotShape { get; set; }

        // Logo
        public Bitmap LogoImage { get; set; }
        public float LogoScalePercent { get; set; }
        public bool DrawLogoBackground { get; set; }

        // Output Resolution
        public int PixelSize { get; set; }

        public QrCodeOptions()
        {
            Content = QrCodeEncoderService.GetDefaultUrl();
            ErrorCorrection = QrErrorCorrectionLevel.H;
            ForegroundColor = Color.FromArgb(255, 2, 32, 87);
            ForegroundColor2 = Color.FromArgb(255, 33, 161, 247);
            UseGradient = false;
            GradientAngle = 45f;
            BackgroundColor = Color.White;
            EyeFrameColor = Color.FromArgb(255, 2, 32, 87);
            EyeDotColor = Color.FromArgb(255, 33, 161, 247);
            CustomEyeColors = false;
            BodyShape = QrBodyShape.Square;
            EyeFrameShape = QrEyeFrameShape.Square;
            EyeDotShape = QrEyeDotShape.Square;
            LogoImage = null;
            LogoScalePercent = 0.15f;
            DrawLogoBackground = true;
            PixelSize = 600;
        }
    }

    public class ClinicBranchPreset
    {
        public string Code { get; set; }
        public string Name { get; set; }
        public string WhatsAppNumber { get; set; }
        public string CheckInUrl { get; set; }
        public string GoogleReviewUrl { get; set; }

        public ClinicBranchPreset(string code, string name, string whatsapp, string checkin, string review)
        {
            Code = code;
            Name = name;
            WhatsAppNumber = whatsapp;
            CheckInUrl = checkin;
            GoogleReviewUrl = review;
        }
    }

    public class QrCodeEncoderService
    {
        private static QrCodeEncoderService _instance;

        public static QrCodeEncoderService Instance
        {
            get
            {
                if (_instance == null) _instance = new QrCodeEncoderService();
                return _instance;
            }
        }

        public static List<ClinicBranchPreset> GetClinicBranches()
        {
            List<ClinicBranchPreset> list = new List<ClinicBranchPreset>();
            list.Add(new ClinicBranchPreset("SSC-BSR", "SuamiSihat Clinic Bangsar (HQ)", "+60123456789", "https://suamisihat.clinic/checkin/bangsar", "https://g.page/r/suamisihat-bangsar/review"));
            list.Add(new ClinicBranchPreset("SSC-KD", "SuamiSihat Clinic Kota Damansara", "+60123456780", "https://suamisihat.clinic/checkin/kotadamansara", "https://g.page/r/suamisihat-kd/review"));
            list.Add(new ClinicBranchPreset("SSC-JB", "SuamiSihat Clinic Johor Bahru", "+60123456781", "https://suamisihat.clinic/checkin/jb", "https://g.page/r/suamisihat-jb/review"));
            list.Add(new ClinicBranchPreset("SSC-PNG", "SuamiSihat Clinic Penang", "+60123456782", "https://suamisihat.clinic/checkin/penang", "https://g.page/r/suamisihat-penang/review"));
            return list;
        }

        public static string GenerateBranchWhatsAppConsultUrl(string branchCode, string treatmentName)
        {
            List<ClinicBranchPreset> branches = GetClinicBranches();
            ClinicBranchPreset target = branches[0];
            foreach (ClinicBranchPreset b in branches)
            {
                if (string.Equals(b.Code, branchCode, StringComparison.OrdinalIgnoreCase))
                {
                    target = b;
                    break;
                }
            }

            string digits = Regex.Replace(target.WhatsAppNumber, @"[^0-9]", "");
            string text = Uri.EscapeDataString(string.Format("Salam sejahtera {0}. Saya ingin membuat pertanyaan sulit mengenai konsultasi {1}.", target.Name, !string.IsNullOrWhiteSpace(treatmentName) ? treatmentName : "Umum"));
            return string.Format("https://wa.me/{0}?text={1}", digits, text);
        }

        public static string GetDefaultUrl()
        {
            PluginConfig qrConfig = null;
            if (TenantConfigService.Current != null && TenantConfigService.Current.Plugins != null && TenantConfigService.Current.Plugins.TryGetValue("qr-code-studio", out qrConfig) && !string.IsNullOrWhiteSpace(qrConfig.DefaultContent))
            {
                return qrConfig.DefaultContent;
            }
            return "https://corporate.com.my";
        }

        public static string GetFilenamePrefix()
        {
            PluginConfig qrConfig = null;
            if (TenantConfigService.Current != null && TenantConfigService.Current.Plugins != null && TenantConfigService.Current.Plugins.TryGetValue("qr-code-studio", out qrConfig) && !string.IsNullOrWhiteSpace(qrConfig.FilenamePrefix))
            {
                return qrConfig.FilenamePrefix;
            }
            return "Corporate";
        }

        public double CalculateContrastRatio(Color c1, Color c2)
        {
            double l1 = GetLuminance(c1) + 0.05;
            double l2 = GetLuminance(c2) + 0.05;
            return l1 > l2 ? l1 / l2 : l2 / l1;
        }

        private static double GetLuminance(Color c)
        {
            double r = c.R / 255.0;
            double g = c.G / 255.0;
            double b = c.B / 255.0;
            r = r <= 0.03928 ? r / 12.92 : Math.Pow((r + 0.055) / 1.055, 2.4);
            g = g <= 0.03928 ? g / 12.92 : Math.Pow((g + 0.055) / 1.055, 2.4);
            b = b <= 0.03928 ? b / 12.92 : Math.Pow((b + 0.055) / 1.055, 2.4);
            return 0.2126 * r + 0.7152 * g + 0.0722 * b;
        }

        public Bitmap GenerateQrCodeBitmap(QrCodeOptions options)
        {
            if (options == null) options = new QrCodeOptions();
            if (string.IsNullOrWhiteSpace(options.Content)) options.Content = QrCodeEncoderService.GetDefaultUrl();
            bool[,] matrix = GenerateQrMatrix(options.Content, options.ErrorCorrection);

            int modules = matrix.GetLength(0);
            int quietZoneModules = 4;
            int totalModules = modules + (quietZoneModules * 2);
            int reqSize = Math.Max(200, options.PixelSize);

            int modulePixelSize = Math.Max(1, (int)Math.Round((double)reqSize / totalModules));
            int targetSize = totalModules * modulePixelSize;
            int quietZoneOffset = quietZoneModules * modulePixelSize;

            Bitmap bmp = new Bitmap(targetSize, targetSize, PixelFormat.Format32bppArgb);

            using (Graphics g = Graphics.FromImage(bmp))
            {
                bool isSquareMode = options.BodyShape == QrBodyShape.Square && options.EyeFrameShape == QrEyeFrameShape.Square && options.EyeDotShape == QrEyeDotShape.Square;
                bool isSingleLayerMode = isSquareMode && !options.CustomEyeColors;

                if (isSquareMode)
                {
                    g.SmoothingMode = SmoothingMode.None;
                    g.InterpolationMode = InterpolationMode.NearestNeighbor;
                    g.PixelOffsetMode = PixelOffsetMode.None;
                }
                else
                {
                    g.SmoothingMode = SmoothingMode.HighQuality;
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                }

                // 1. Draw Background
                using (SolidBrush bgBrush = new SolidBrush(options.BackgroundColor))
                {
                    g.FillRectangle(bgBrush, 0, 0, targetSize, targetSize);
                }

                // 2. Prepare Foreground Brush
                Brush fgBrush;
                if (options.UseGradient)
                {
                    fgBrush = new LinearGradientBrush(
                        new Rectangle(0, 0, targetSize, targetSize),
                        options.ForegroundColor,
                        options.ForegroundColor2,
                        options.GradientAngle);
                }
                else
                {
                    fgBrush = new SolidBrush(options.ForegroundColor);
                }

                Brush eyeFrameBrush = options.CustomEyeColors ? new SolidBrush(options.EyeFrameColor) : fgBrush;
                Brush eyeDotBrush = options.CustomEyeColors ? new SolidBrush(options.EyeDotColor) : fgBrush;
                Brush bgBrushSolid = new SolidBrush(options.BackgroundColor);

                // 3. Render QR Code (Single-Pass for Normal QR, Multi-Layer for Custom Shapes)
                if (isSingleLayerMode)
                {
                    for (int r = 0; r < modules; r++)
                    {
                        for (int c = 0; c < modules; c++)
                        {
                            if (!matrix[r, c]) continue;
                            int x = quietZoneOffset + c * modulePixelSize;
                            int y = quietZoneOffset + r * modulePixelSize;
                            g.FillRectangle(fgBrush, x, y, modulePixelSize, modulePixelSize);
                        }
                    }
                }
                else
                {
                    for (int r = 0; r < modules; r++)
                    {
                        for (int c = 0; c < modules; c++)
                        {
                            if (IsFinderPatternZone(r, c, modules)) continue;
                            if (!matrix[r, c]) continue;

                            int x = quietZoneOffset + c * modulePixelSize;
                            int y = quietZoneOffset + r * modulePixelSize;

                            RectangleF moduleRect = new RectangleF(x, y, modulePixelSize, modulePixelSize);
                            DrawBodyModule(g, fgBrush, moduleRect, options.BodyShape, modulePixelSize, matrix, r, c, modules);
                        }
                    }

                    DrawFinderEye(g, eyeFrameBrush, eyeDotBrush, quietZoneOffset, quietZoneOffset, modulePixelSize, options.EyeFrameShape, options.EyeDotShape, options.BackgroundColor);
                    DrawFinderEye(g, eyeFrameBrush, eyeDotBrush, quietZoneOffset + (modules - 7) * modulePixelSize, quietZoneOffset, modulePixelSize, options.EyeFrameShape, options.EyeDotShape, options.BackgroundColor);
                    DrawFinderEye(g, eyeFrameBrush, eyeDotBrush, quietZoneOffset, quietZoneOffset + (modules - 7) * modulePixelSize, modulePixelSize, options.EyeFrameShape, options.EyeDotShape, options.BackgroundColor);
                }

                // 4. Draw Central Logo Watermark if present
                if (options.LogoImage != null)
                {
                    DrawLogoOverlay(g, options.LogoImage, targetSize, options.LogoScalePercent, options.DrawLogoBackground, options.BackgroundColor);
                }

                fgBrush.Dispose();
                bgBrushSolid.Dispose();
                if (options.CustomEyeColors)
                {
                    eyeFrameBrush.Dispose();
                    eyeDotBrush.Dispose();
                }
            }

            return bmp;
        }

        private static bool IsFinderPatternZone(int r, int c, int modules)
        {
            // Top-Left (7x7)
            if (r < 7 && c < 7) return true;
            // Top-Right (7x7)
            if (r < 7 && c >= modules - 7) return true;
            // Bottom-Left (7x7)
            if (r >= modules - 7 && c < 7) return true;
            return false;
        }

        private void DrawBodyModule(Graphics g, Brush brush, RectangleF rect, QrBodyShape shape, float moduleSize, bool[,] matrix, int r, int c, int modules)
        {
            switch (shape)
            {
                case QrBodyShape.Circle:
                    // Full-size circle - touches adjacent module midpoints for better scannability
                    g.FillEllipse(brush, rect.X, rect.Y, rect.Width, rect.Height);
                    break;

                case QrBodyShape.Dots:
                    // Inset dot - discrete circular beads
                    float dotInset = moduleSize * 0.12f;
                    g.FillEllipse(brush, rect.X + dotInset, rect.Y + dotInset, rect.Width - dotInset * 2, rect.Height - dotInset * 2);
                    break;

                case QrBodyShape.Rounded:
                    bool hasTop = r > 0 && matrix[r - 1, c];
                    bool hasBottom = r < modules - 1 && matrix[r + 1, c];
                    bool hasLeft = c > 0 && matrix[r, c - 1];
                    bool hasRight = c < modules - 1 && matrix[r, c + 1];

                    bool roundTL = !hasTop && !hasLeft;
                    bool roundTR = !hasTop && !hasRight;
                    bool roundBR = !hasBottom && !hasRight;
                    bool roundBL = !hasBottom && !hasLeft;

                    if (!roundTL && !roundTR && !roundBR && !roundBL)
                    {
                        g.FillRectangle(brush, rect);
                    }
                    else
                    {
                        using (GraphicsPath path = CreateSelectiveRoundedRectPath(rect, moduleSize * 0.45f, roundTL, roundTR, roundBR, roundBL))
                        {
                            g.FillPath(brush, path);
                        }
                    }
                    break;

                case QrBodyShape.Diamond:
                    PointF[] diamondPts = new PointF[]
                    {
                        new PointF(rect.X + rect.Width / 2f, rect.Y),
                        new PointF(rect.Right, rect.Y + rect.Height / 2f),
                        new PointF(rect.X + rect.Width / 2f, rect.Bottom),
                        new PointF(rect.X, rect.Y + rect.Height / 2f)
                    };
                    g.FillPolygon(brush, diamondPts);
                    break;

                case QrBodyShape.Classy:
                    using (GraphicsPath path = CreateSelectiveRoundedRectPath(rect, moduleSize * 0.45f, true, false, true, false))
                    {
                        g.FillPath(brush, path);
                    }
                    break;

                default:
                    g.FillRectangle(brush, rect);
                    break;
            }
        }

        public BitmapImage GenerateBitmapImage(QrCodeOptions options)
        {
            using (Bitmap bmp = GenerateQrCodeBitmap(options))
            {
                using (MemoryStream ms = new MemoryStream())
                {
                    bmp.Save(ms, ImageFormat.Png);
                    ms.Position = 0;

                    BitmapImage bi = new BitmapImage();
                    bi.BeginInit();
                    bi.CacheOption = BitmapCacheOption.OnLoad;
                    bi.StreamSource = ms;
                    bi.EndInit();
                    bi.Freeze();
                    return bi;
                }
            }
        }

        public string GenerateSvgXml(QrCodeOptions options)
        {
            if (options == null) options = new QrCodeOptions();
            
            if (string.IsNullOrWhiteSpace(options.Content)) options.Content = QrCodeEncoderService.GetDefaultUrl();
            bool[,] matrix = GenerateQrMatrix(options.Content, options.ErrorCorrection);

            int modules = matrix.GetLength(0);
            int quietZoneModules = 4;
            int totalModules = modules + (quietZoneModules * 2);
            int size = Math.Max(300, options.PixelSize);
            float moduleSize = (float)size / totalModules;
            float quietZoneOffset = quietZoneModules * moduleSize;

            string fgHex = ColorToHex(options.ForegroundColor);
            string fg2Hex = ColorToHex(options.ForegroundColor2);
            string bgHex = ColorToHex(options.BackgroundColor);

            StringBuilder svg = new StringBuilder();
            svg.AppendLine(string.Format("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{0}\" height=\"{1}\" viewBox=\"0 0 {0} {1}\">", size, size));
            
            if (options.UseGradient)
            {
                double angleRad = (options.GradientAngle % 360) * Math.PI / 180.0;
                double x1 = 50.0 - 50.0 * Math.Cos(angleRad);
                double y1 = 50.0 - 50.0 * Math.Sin(angleRad);
                double x2 = 50.0 + 50.0 * Math.Cos(angleRad);
                double y2 = 50.0 + 50.0 * Math.Sin(angleRad);
                svg.AppendLine("  <defs>");
                svg.AppendLine(string.Format("    <linearGradient id=\"qrGrad\" x1=\"{0:F1}%\" y1=\"{1:F1}%\" x2=\"{2:F1}%\" y2=\"{3:F1}%\">", x1, y1, x2, y2));
                svg.AppendLine(string.Format("      <stop offset=\"0%\" stop-color=\"{0}\"/>", fgHex));
                svg.AppendLine(string.Format("      <stop offset=\"100%\" stop-color=\"{0}\"/>", fg2Hex));
                svg.AppendLine("    </linearGradient>");
                svg.AppendLine("  </defs>");
            }

            svg.AppendLine(string.Format("  <rect width=\"100%\" height=\"100%\" fill=\"{0}\"/>", bgHex));

            string fillRef = options.UseGradient ? "url(#qrGrad)" : fgHex;
            string eyeFrameHex = options.CustomEyeColors ? ColorToHex(options.EyeFrameColor) : fillRef;
            string eyeDotHex = options.CustomEyeColors ? ColorToHex(options.EyeDotColor) : fillRef;

            // 1. Render Body Modules
            bool isSquareMode = options.BodyShape == QrBodyShape.Square && options.EyeFrameShape == QrEyeFrameShape.Square && options.EyeDotShape == QrEyeDotShape.Square;
            bool isSingleLayerMode = isSquareMode && !options.CustomEyeColors;

            if (options.BodyShape == QrBodyShape.Square)
            {
                // Compact SVG Path Method (like datalog/qrcode-svg)
                StringBuilder pathData = new StringBuilder();
                for (int r = 0; r < modules; r++)
                {
                    for (int c = 0; c < modules; c++)
                    {
                        if (!isSingleLayerMode && IsFinderPatternZone(r, c, modules)) continue;
                        if (!matrix[r, c]) continue;

                        float x = quietZoneOffset + c * moduleSize;
                        float y = quietZoneOffset + r * moduleSize;
                        pathData.Append(string.Format("M{0:F2},{1:F2}h{2:F2}v{2:F2}h-{2:F2}z ", x, y, moduleSize));
                    }
                }
                if (pathData.Length > 0)
                {
                    svg.AppendLine(string.Format("  <path d=\"{0}\" fill=\"{1}\"/>", pathData.ToString().TrimEnd(), fillRef));
                }
            }
            else
            {
                for (int r = 0; r < modules; r++)
                {
                    for (int c = 0; c < modules; c++)
                    {
                        if (IsFinderPatternZone(r, c, modules)) continue;
                        if (!matrix[r, c]) continue;

                        float x = quietZoneOffset + c * moduleSize;
                        float y = quietZoneOffset + r * moduleSize;

                        if (options.BodyShape == QrBodyShape.Circle)
                        {
                            float cx = x + moduleSize / 2f;
                            float cy = y + moduleSize / 2f;
                            float rRadius = moduleSize / 2f;
                            svg.AppendLine(string.Format("  <circle cx=\"{0:F2}\" cy=\"{1:F2}\" r=\"{2:F2}\" fill=\"{3}\"/>", cx, cy, rRadius, fillRef));
                        }
                        else if (options.BodyShape == QrBodyShape.Dots)
                        {
                            float cx = x + moduleSize / 2f;
                            float cy = y + moduleSize / 2f;
                            float rRadius = (moduleSize * 0.76f) / 2f;
                            svg.AppendLine(string.Format("  <circle cx=\"{0:F2}\" cy=\"{1:F2}\" r=\"{2:F2}\" fill=\"{3}\"/>", cx, cy, rRadius, fillRef));
                        }
                        else if (options.BodyShape == QrBodyShape.Diamond)
                        {
                            float cx = x + moduleSize / 2f;
                            float cy = y + moduleSize / 2f;
                            svg.AppendLine(string.Format("  <polygon points=\"{0:F2},{1:F2} {2:F2},{3:F2} {0:F2},{4:F2} {5:F2},{3:F2}\" fill=\"{6}\"/>",
                                cx, y, x + moduleSize, cy, y + moduleSize, x, fillRef));
                        }
                        else if (options.BodyShape == QrBodyShape.Classy)
                        {
                            float cr = moduleSize * 0.45f;
                            svg.AppendLine(string.Format("  <path d=\"M{0:F2},{1:F2} h{2:F2} v{2:F2} a{3:F2},{3:F2} 0 0 1 -{3:F2},{3:F2} h-{2:F2} v-{2:F2} a{3:F2},{3:F2} 0 0 1 {3:F2},-{3:F2} z\" fill=\"{4}\"/>",
                                x + cr, y, moduleSize - cr, cr, fillRef));
                        }
                        else if (options.BodyShape == QrBodyShape.Rounded)
                        {
                            bool hasTop = r > 0 && matrix[r - 1, c];
                            bool hasBottom = r < modules - 1 && matrix[r + 1, c];
                            bool hasLeft = c > 0 && matrix[r, c - 1];
                            bool hasRight = c < modules - 1 && matrix[r, c + 1];

                            bool roundTL = !hasTop && !hasLeft;
                            bool roundTR = !hasTop && !hasRight;
                            bool roundBR = !hasBottom && !hasRight;
                            bool roundBL = !hasBottom && !hasLeft;

                            if (!roundTL && !roundTR && !roundBR && !roundBL)
                            {
                                svg.AppendLine(string.Format("  <rect x=\"{0:F2}\" y=\"{1:F2}\" width=\"{2:F2}\" height=\"{2:F2}\" fill=\"{3}\"/>", x, y, moduleSize, fillRef));
                            }
                            else
                            {
                                float cr = moduleSize * 0.45f;
                                float rTL = roundTL ? cr : 0f;
                                float rTR = roundTR ? cr : 0f;
                                float rBR = roundBR ? cr : 0f;
                                float rBL = roundBL ? cr : 0f;

                                StringBuilder d = new StringBuilder();
                                d.Append(string.Format("M{0:F2},{1:F2} ", x + rTL, y));
                                d.Append(string.Format("L{0:F2},{1:F2} ", x + moduleSize - rTR, y));
                                if (roundTR) d.Append(string.Format("A{0:F2},{0:F2} 0 0 1 {1:F2},{2:F2} ", cr, x + moduleSize, y + cr));
                                d.Append(string.Format("L{0:F2},{1:F2} ", x + moduleSize, y + moduleSize - rBR));
                                if (roundBR) d.Append(string.Format("A{0:F2},{0:F2} 0 0 1 {1:F2},{2:F2} ", cr, x + moduleSize - cr, y + moduleSize));
                                d.Append(string.Format("L{0:F2},{1:F2} ", x + rBL, y + moduleSize));
                                if (roundBL) d.Append(string.Format("A{0:F2},{0:F2} 0 0 1 {1:F2},{2:F2} ", cr, x, y + moduleSize - cr));
                                d.Append(string.Format("L{0:F2},{1:F2} ", x, y + rTL));
                                if (roundTL) d.Append(string.Format("A{0:F2},{0:F2} 0 0 1 {1:F2},{2:F2} ", cr, x + cr, y));
                                d.Append("Z");
                                svg.AppendLine(string.Format("  <path d=\"{0}\" fill=\"{1}\"/>", d.ToString(), fillRef));
                            }
                        }
                        else
                        {
                            svg.AppendLine(string.Format("  <rect x=\"{0:F2}\" y=\"{1:F2}\" width=\"{2:F2}\" height=\"{2:F2}\" fill=\"{3}\"/>", x, y, moduleSize, fillRef));
                        }
                    }
                }
            }

            if (!isSingleLayerMode)
            {
                // 2. Render Finder Eye Patterns (Top-Left, Top-Right, Bottom-Left)
                AppendSvgFinderEye(svg, quietZoneOffset, quietZoneOffset, moduleSize, options.EyeFrameShape, options.EyeDotShape, eyeFrameHex, eyeDotHex, bgHex);
                AppendSvgFinderEye(svg, quietZoneOffset + (modules - 7) * moduleSize, quietZoneOffset, moduleSize, options.EyeFrameShape, options.EyeDotShape, eyeFrameHex, eyeDotHex, bgHex);
                AppendSvgFinderEye(svg, quietZoneOffset, quietZoneOffset + (modules - 7) * moduleSize, moduleSize, options.EyeFrameShape, options.EyeDotShape, eyeFrameHex, eyeDotHex, bgHex);
            }

            // 3. Render Central Logo if present
            if (options.LogoImage != null)
            {
                float logoSize = size * options.LogoScalePercent;
                float lx = (size - logoSize) / 2f;
                float ly = (size - logoSize) / 2f;

                if (options.DrawLogoBackground)
                {
                    float bgMargin = logoSize * 0.12f;
                    float cx = lx + logoSize / 2f;
                    float cy = ly + logoSize / 2f;
                    float cr = (logoSize + bgMargin * 2) / 2f;
                    svg.AppendLine(string.Format("  <circle cx=\"{0:F2}\" cy=\"{1:F2}\" r=\"{2:F2}\" fill=\"{3}\"/>", cx, cy, cr, bgHex));
                }

                try
                {
                    using (MemoryStream ms = new MemoryStream())
                    {
                        options.LogoImage.Save(ms, ImageFormat.Png);
                        string base64 = Convert.ToBase64String(ms.ToArray());
                        svg.AppendLine(string.Format("  <image href=\"data:image/png;base64,{0}\" x=\"{1:F2}\" y=\"{2:F2}\" width=\"{3:F2}\" height=\"{3:F2}\" preserveAspectRatio=\"xMidYMid meet\"/>", base64, lx, ly, logoSize));
                    }
                }
                catch (Exception ex)
                {
                    App.LogTrace(string.Format("[QrCodeEncoderService] Failed to embed SVG logo: {0}", ex.Message));
                }
            }

            svg.AppendLine("</svg>");
            return svg.ToString();
        }

        private static void AppendSvgFinderEye(StringBuilder svg, float originX, float originY, float moduleSize, QrEyeFrameShape frameShape, QrEyeDotShape dotShape, string frameHex, string dotHex, string bgHex)
        {
            float outerSize = moduleSize * 7f;
            float innerMargin = moduleSize * 1.0f;
            float innerSize = moduleSize * 5f;
            float centerMargin = moduleSize * 2.0f;
            float centerSize = moduleSize * 3f;

            if (frameShape == QrEyeFrameShape.Circle)
            {
                float cx = originX + outerSize / 2f;
                float cy = originY + outerSize / 2f;
                svg.AppendLine(string.Format("  <circle cx=\"{0:F2}\" cy=\"{1:F2}\" r=\"{2:F2}\" fill=\"{3}\"/>", cx, cy, outerSize / 2f, frameHex));
                svg.AppendLine(string.Format("  <circle cx=\"{0:F2}\" cy=\"{1:F2}\" r=\"{2:F2}\" fill=\"{3}\"/>", cx, cy, innerSize / 2f, bgHex));
            }
            else if (frameShape == QrEyeFrameShape.Rounded)
            {
                float rx = moduleSize * 2.5f;
                float irx = moduleSize * 1.5f;
                svg.AppendLine(string.Format("  <rect x=\"{0:F2}\" y=\"{1:F2}\" width=\"{2:F2}\" height=\"{2:F2}\" rx=\"{3:F2}\" ry=\"{3:F2}\" fill=\"{4}\"/>", originX, originY, outerSize, rx, frameHex));
                svg.AppendLine(string.Format("  <rect x=\"{0:F2}\" y=\"{1:F2}\" width=\"{2:F2}\" height=\"{2:F2}\" rx=\"{3:F2}\" ry=\"{3:F2}\" fill=\"{4}\"/>", originX + innerMargin, originY + innerMargin, innerSize, irx, bgHex));
            }
            else
            {
                svg.AppendLine(string.Format("  <rect x=\"{0:F2}\" y=\"{1:F2}\" width=\"{2:F2}\" height=\"{2:F2}\" fill=\"{3}\"/>", originX, originY, outerSize, frameHex));
                svg.AppendLine(string.Format("  <rect x=\"{0:F2}\" y=\"{1:F2}\" width=\"{2:F2}\" height=\"{2:F2}\" fill=\"{3}\"/>", originX + innerMargin, originY + innerMargin, innerSize, bgHex));
            }

            if (dotShape == QrEyeDotShape.Circle || dotShape == QrEyeDotShape.Dot)
            {
                float cx = originX + outerSize / 2f;
                float cy = originY + outerSize / 2f;
                svg.AppendLine(string.Format("  <circle cx=\"{0:F2}\" cy=\"{1:F2}\" r=\"{2:F2}\" fill=\"{3}\"/>", cx, cy, centerSize / 2f, dotHex));
            }
            else if (dotShape == QrEyeDotShape.Diamond)
            {
                float cx = originX + centerMargin + centerSize / 2f;
                float cy = originY + centerMargin + centerSize / 2f;
                float top = originY + centerMargin;
                float bottom = originY + centerMargin + centerSize;
                float left = originX + centerMargin;
                float right = originX + centerMargin + centerSize;
                svg.AppendLine(string.Format("  <polygon points=\"{0:F2},{1:F2} {2:F2},{3:F2} {0:F2},{4:F2} {5:F2},{3:F2}\" fill=\"{6}\"/>",
                    cx, top, right, cy, bottom, left, dotHex));
            }
            else
            {
                svg.AppendLine(string.Format("  <rect x=\"{0:F2}\" y=\"{1:F2}\" width=\"{2:F2}\" height=\"{2:F2}\" fill=\"{3}\"/>", originX + centerMargin, originY + centerMargin, centerSize, dotHex));
            }
        }

        private void DrawFinderEye(Graphics g, Brush frameBrush, Brush dotBrush, float originX, float originY, float moduleSize, QrEyeFrameShape frameShape, QrEyeDotShape dotShape, Color bgColor)
        {
            float outerSize = moduleSize * 7f;
            float innerMargin = moduleSize * 1.0f;
            float innerSize = moduleSize * 5f;
            float centerMargin = moduleSize * 2.0f;
            float centerSize = moduleSize * 3f;

            RectangleF outerRect = new RectangleF(originX, originY, outerSize, outerSize);
            RectangleF innerRect = new RectangleF(originX + innerMargin, originY + innerMargin, innerSize, innerSize);
            RectangleF centerRect = new RectangleF(originX + centerMargin, originY + centerMargin, centerSize, centerSize);

            using (SolidBrush innerBgBrush = new SolidBrush(bgColor))
            {
                // Clear 7x7 outer bounds first to prevent underlying matrix pixels from bleeding through
                g.FillRectangle(innerBgBrush, outerRect);

                // Outer Frame
                if (frameShape == QrEyeFrameShape.Circle)
                {
                    g.FillEllipse(frameBrush, outerRect);
                    g.FillEllipse(innerBgBrush, innerRect);
                }
                else if (frameShape == QrEyeFrameShape.Rounded)
                {
                    using (GraphicsPath pOuter = CreateRoundedRectPath(outerRect, moduleSize * 2.5f))
                    using (GraphicsPath pInner = CreateRoundedRectPath(innerRect, moduleSize * 1.5f))
                    {
                        g.FillPath(frameBrush, pOuter);
                        g.FillPath(innerBgBrush, pInner);
                    }
                }
                else
                {
                    g.FillRectangle(frameBrush, outerRect);
                    g.FillRectangle(innerBgBrush, innerRect);
                }

                // Inner Center Dot
                if (dotShape == QrEyeDotShape.Circle || dotShape == QrEyeDotShape.Dot)
                {
                    g.FillEllipse(dotBrush, centerRect);
                }
                else if (dotShape == QrEyeDotShape.Diamond)
                {
                    PointF[] diamond = new PointF[]
                    {
                        new PointF(centerRect.X + centerRect.Width / 2f, centerRect.Y),
                        new PointF(centerRect.Right, centerRect.Y + centerRect.Height / 2f),
                        new PointF(centerRect.X + centerRect.Width / 2f, centerRect.Bottom),
                        new PointF(centerRect.X, centerRect.Y + centerRect.Height / 2f)
                    };
                    g.FillPolygon(dotBrush, diamond);
                }
                else
                {
                    g.FillRectangle(dotBrush, centerRect);
                }
            }
        }

        private void DrawLogoOverlay(Graphics g, Bitmap logo, int targetSize, float scalePercent, bool drawBackground, Color bgColor)
        {
            float logoSize = targetSize * scalePercent;
            float x = (targetSize - logoSize) / 2f;
            float y = (targetSize - logoSize) / 2f;
            RectangleF logoRect = new RectangleF(x, y, logoSize, logoSize);

            if (drawBackground)
            {
                float bgMargin = logoSize * 0.12f;
                RectangleF bgRect = new RectangleF(x - bgMargin, y - bgMargin, logoSize + bgMargin * 2, logoSize + bgMargin * 2);
                using (SolidBrush brush = new SolidBrush(bgColor))
                {
                    g.FillEllipse(brush, bgRect);
                }
            }

            g.DrawImage(logo, logoRect);
        }

        private static GraphicsPath CreateRoundedRectPath(RectangleF rect, float cornerRadius)
        {
            GraphicsPath path = new GraphicsPath();
            float diameter = cornerRadius * 2f;
            if (diameter > rect.Width) diameter = rect.Width;
            if (diameter > rect.Height) diameter = rect.Height;

            path.AddArc(rect.X, rect.Y, diameter, diameter, 180, 90);
            path.AddArc(rect.Right - diameter, rect.Y, diameter, diameter, 270, 90);
            path.AddArc(rect.Right - diameter, rect.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(rect.X, rect.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }

        private static GraphicsPath CreateSelectiveRoundedRectPath(
            RectangleF rect,
            float cornerRadius,
            bool roundTL,
            bool roundTR,
            bool roundBR,
            bool roundBL)
        {
            GraphicsPath path = new GraphicsPath();
            float maxR = Math.Min(rect.Width, rect.Height) / 2f;
            float rTL = roundTL ? Math.Min(cornerRadius, maxR) : 0f;
            float rTR = roundTR ? Math.Min(cornerRadius, maxR) : 0f;
            float rBR = roundBR ? Math.Min(cornerRadius, maxR) : 0f;
            float rBL = roundBL ? Math.Min(cornerRadius, maxR) : 0f;

            // Start at top edge after top-left corner
            path.AddLine(rect.X + rTL, rect.Y, rect.Right - rTR, rect.Y);

            // Top-Right Corner
            if (rTR > 0)
                path.AddArc(rect.Right - 2 * rTR, rect.Y, 2 * rTR, 2 * rTR, 270, 90);

            // Right edge
            path.AddLine(rect.Right, rect.Y + rTR, rect.Right, rect.Bottom - rBR);

            // Bottom-Right Corner
            if (rBR > 0)
                path.AddArc(rect.Right - 2 * rBR, rect.Bottom - 2 * rBR, 2 * rBR, 2 * rBR, 0, 90);

            // Bottom edge
            path.AddLine(rect.Right - rBR, rect.Bottom, rect.X + rBL, rect.Bottom);

            // Bottom-Left Corner
            if (rBL > 0)
                path.AddArc(rect.X, rect.Bottom - 2 * rBL, 2 * rBL, 2 * rBL, 90, 90);

            // Left edge
            path.AddLine(rect.X, rect.Bottom - rBL, rect.X, rect.Y + rTL);

            // Top-Left Corner
            if (rTL > 0)
                path.AddArc(rect.X, rect.Y, 2 * rTL, 2 * rTL, 180, 90);

            path.CloseFigure();
            return path;
        }

        private static string ColorToHex(Color c)
        {
            return string.Format("#{0:X2}{1:X2}{2:X2}", c.R, c.G, c.B);
        }

        private bool[,] GenerateQrMatrix(string text, QrErrorCorrectionLevel ecLevel)
        {
            if (string.IsNullOrEmpty(text)) text = QrCodeEncoderService.GetDefaultUrl();

            try
            {
                QRCoder.QRCodeGenerator.ECCLevel ecc;
                switch (ecLevel)
                {
                    case QrErrorCorrectionLevel.L: ecc = QRCoder.QRCodeGenerator.ECCLevel.L; break;
                    case QrErrorCorrectionLevel.M: ecc = QRCoder.QRCodeGenerator.ECCLevel.M; break;
                    case QrErrorCorrectionLevel.Q: ecc = QRCoder.QRCodeGenerator.ECCLevel.Q; break;
                    case QrErrorCorrectionLevel.H: default: ecc = QRCoder.QRCodeGenerator.ECCLevel.H; break;
                }

                using (QRCoder.QRCodeGenerator qrGen = new QRCoder.QRCodeGenerator())
                using (QRCoder.QRCodeData qrData = qrGen.CreateQrCode(text, ecc))
                {
                    int modules = qrData.ModuleMatrix.Count;
                    bool[,] matrix = new bool[modules, modules];
                    for (int r = 0; r < modules; r++)
                    {
                        System.Collections.BitArray row = qrData.ModuleMatrix[r];
                        for (int c = 0; c < modules; c++)
                        {
                            matrix[r, c] = row[c];
                        }
                    }
                    return matrix;
                }
            }
            catch (Exception ex)
            {
                App.LogTrace("[QrCodeEncoderService] GenerateQrMatrix: " + ex.Message);
                throw;
            }
        }
    }
}
