using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using SS_CAM.Models;

namespace SS_CAM.Services
{
    public class RegulatoryInfraction
    {
        public string Term { get; set; }
        public string Reason { get; set; }
        public string Recommendation { get; set; }

        public RegulatoryInfraction(string term, string reason, string recommendation)
        {
            Term = term;
            Reason = reason;
            Recommendation = recommendation;
        }
    }

    public class RegulatoryAuditResult
    {
        public bool IsCompliant { get; set; }
        public bool HasApprovalCode { get; set; }
        public string ApprovalCode { get; set; }
        public bool HasDisclaimer { get; set; }
        public List<RegulatoryInfraction> Infractions { get; set; }
        public List<string> Suggestions { get; set; }

        public RegulatoryAuditResult()
        {
            Infractions = new List<RegulatoryInfraction>();
            Suggestions = new List<string>();
            IsCompliant = true;
        }
    }

    public class ClinicalApprovedClaim
    {
        public string Category { get; set; }
        public string TreatmentName { get; set; }
        public string ApprovedClaim { get; set; }
        public string ReferenceCode { get; set; }

        public ClinicalApprovedClaim(string category, string treatmentName, string claim, string refCode)
        {
            Category = category;
            TreatmentName = treatmentName;
            ApprovedClaim = claim;
            ReferenceCode = refCode;
        }
    }

    /// <summary>
    /// Regulatory compliance engine for Ministry of Health (KKM) and
    /// Medicines Advertisement Board (LIU/MAB) guidelines under Medicines (Advertisement and Sale) Act 1956.
    /// Compatible with C# 5 syntax.
    /// </summary>
    public static class RegulatoryComplianceService
    {
        // Prohibited terms under KKM / LIU guidelines that constitute misleading or absolute medical claims
        private static readonly Dictionary<string, string> ProhibitedTerms = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "100% sembuh", "Tuntutan jaminan kesembuhan mutlak dilarang di bawah Akta Iklan Ubat 1956." },
            { "pasti sembuh", "Tuntutan kesembuhan tanpa syarat tidak dibenarkan oleh KKM." },
            { "pasti berkesan", "Keberkesanan klinikal berbeza mengikut individu; perkataan mutlak dilarang." },
            { "tanpa kesan sampingan", "Tiada prosedur atau ubat yang boleh dijamin bebas kesan sampingan 100%." },
            { "ubat kuat", "Istilah 'ubat kuat' dilarang secara mutlak dalam pengiklanan perubatan sah." },
            { "ajaib", "Perkataan 'ajaib' atau 'miracle cure' melanggar standard Lembaga Iklan Ubat (LIU)." },
            { "sembuh serta-merta", "Tuntutan penyembuhan segera atau magis dilarang oleh KKM." },
            { "guaranteed cure", "Tuntutan jaminan sembuh dilarang dalam bahasa Inggeris." },
            { "100% effective", "Tuntutan keberkesanan mutlak dilarang." },
            { "no side effects", "Tuntutan sifar kesan sampingan melanggar garis panduan LIU." }
        };

        // Standard KKM LIU approval code patterns (e.g. KKLIU 1234/2026, KKM/LIU/B/1234/2026, MAL12345678X)
        private static readonly Regex ApprovalCodeRegex = new Regex(
            @"\b(KKLIU|KKM\/LIU|LIU|MAL)\s*[:\/\-\s]?\s*([A-Za-z0-9\/\-]+)\b",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);

        // Required disclaimer indicator patterns
        private static readonly string[] DisclaimerKeywords = new string[]
        {
            "nasihat doktor",
            "tujuan edukasi",
            "professional medical advice",
            "educational purposes",
            "doktor bertauliah",
            "consult a doctor",
            "sila rujuk doktor"
        };

        public static RegulatoryAuditResult AuditContent(string text)
        {
            RegulatoryAuditResult result = new RegulatoryAuditResult();

            if (string.IsNullOrWhiteSpace(text))
            {
                result.IsCompliant = true;
                return result;
            }

            // 1. Check for prohibited claims
            foreach (KeyValuePair<string, string> pair in ProhibitedTerms)
            {
                if (text.IndexOf(pair.Key, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    result.Infractions.Add(new RegulatoryInfraction(
                        pair.Key,
                        pair.Value,
                        string.Format("Gantikan '{0}' dengan penerangan klinikal objektif berasaskan sains perubatan.", pair.Key)
                    ));
                }
            }

            // 2. Check for Approval Code
            Match match = ApprovalCodeRegex.Match(text);
            if (match.Success)
            {
                result.HasApprovalCode = true;
                result.ApprovalCode = match.Value.Trim();
            }

            // 3. Check for Mandatory Disclaimer
            bool hasDisclaimer = false;
            foreach (string kw in DisclaimerKeywords)
            {
                if (text.IndexOf(kw, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    hasDisclaimer = true;
                    break;
                }
            }
            result.HasDisclaimer = hasDisclaimer;

            // 4. Determine overall compliance
            if (result.Infractions.Count > 0)
            {
                result.IsCompliant = false;
                result.Suggestions.Add(string.Format("Dikesan {0} frasa tidak patuh garis panduan KKM/LIU. Sila padam atau ganti.", result.Infractions.Count));
            }

            if (!result.HasDisclaimer)
            {
                result.Suggestions.Add("Tambahkan penafian perubatan (Medical Disclaimer) wajib di bahagian bawah bahan.");
            }

            return result;
        }

        public static string GetStandardMedicalDisclaimer(bool english = false)
        {
            if (english)
            {
                return "Disclaimer: This material is for patient educational purposes only and does not substitute professional clinical diagnosis. Please consult our certified medical doctors for a personalized consultation.";
            }

            return "Penafian KKM: Maklumat ini adalah untuk tujuan edukasi pesakit sahaja dan tidak menggantikan nasihat klinikal profesional. Sila rujuk doktor perubatan bertauliah di klinik kami untuk diagnosis dan pelan rawatan yang tepat.";
        }

        public static List<ClinicalApprovedClaim> GetApprovedClaims()
        {
            List<ClinicalApprovedClaim> list = new List<ClinicalApprovedClaim>();

            list.Add(new ClinicalApprovedClaim(
                "ESWT",
                "Terapi Gelombang Kejutan (ESWT)",
                "Membantu merangsang neovaskularisasi dan melancarkan peredaran darah mikro tisu secara non-invasif.",
                "KKM/LIU/B/0812/2026"
            ));

            list.Add(new ClinicalApprovedClaim(
                "TRT",
                "Terapi Penggantian Testosteron (TRT)",
                "Pelan rawatan perubatan berasaskan ujian profil darah bagi menyokong tahap hormon optimum lelaki dewasa.",
                "KKM/LIU/B/0813/2026"
            ));

            list.Add(new ClinicalApprovedClaim(
                "PE_ED",
                "Rehabilitasi Kesihatan Lelaki",
                "Pendekatan klinikal bersepadu menggabungkan terapi fizikal dan bimbingan gaya hidup sihat.",
                "KKM/LIU/B/0814/2026"
            ));

            list.Add(new ClinicalApprovedClaim(
                "WELLNESS",
                "Saringan Kesihatan Holistik",
                "Pemeriksaan kesihatan menyeluruh meliputi paras glukosa, kolesterol, dan fungsi organ penting.",
                "KKM/LIU/B/0815/2026"
            ));

            return list;
        }
    }
}
