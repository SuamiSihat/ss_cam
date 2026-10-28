using System;
using System.Collections.Generic;
using SS_CAM.Models;
using SS_CAM.Services;

namespace SS_CAM.Tests.Suites
{
    public class RadioStreamServiceTests
    {
        public void TestParseM3UWithMetadata()
        {
            string m3uContent = "#EXTM3U\n" +
                                "#EXTINF:-1 tvg-logo=\"https://somafm.com/img/groove.jpg\" group-title=\"Ambient\",SomaFM: Groove Salad\n" +
                                "https://ice6.somafm.com/groovesalad-256-mp3\n" +
                                "#EXTINF:-1 group-title=\"Synthwave\",Nightwave Plaza\n" +
                                "https://radio.plaza.one/mp3\n";

            List<RadioStation> stations = PlaylistHelper.ParseM3U(m3uContent, "Test Playlist");

            Assert.IsNotNull(stations);
            Assert.AreEqual(2, stations.Count, "Should parse 2 stations from M3U");

            RadioStation st1 = stations[0];
            Assert.AreEqual("SomaFM: Groove Salad", st1.Name);
            Assert.AreEqual("https://ice6.somafm.com/groovesalad-256-mp3", st1.StreamUrl);
            Assert.AreEqual("Ambient", st1.Genre);
            Assert.AreEqual("https://somafm.com/img/groove.jpg", st1.CoverImageUrl);

            RadioStation st2 = stations[1];
            Assert.AreEqual("Nightwave Plaza", st2.Name);
            Assert.AreEqual("https://radio.plaza.one/mp3", st2.StreamUrl);
            Assert.AreEqual("Synthwave", st2.Genre);
        }

        public void TestParsePLS()
        {
            string plsContent = "[playlist]\n" +
                                "NumberOfEntries=2\n" +
                                "File1=http://stream.laut.fm/lofi\n" +
                                "Title1=Chillhop Lo-Fi\n" +
                                "File2=http://0nlineradio.radioho.st/0r-jazz\n" +
                                "Title2=Smooth Jazz\n";

            List<RadioStation> stations = PlaylistHelper.ParsePLS(plsContent, "Test PLS");

            Assert.IsNotNull(stations);
            Assert.AreEqual(2, stations.Count, "Should parse 2 stations from PLS");
            Assert.AreEqual("Chillhop Lo-Fi", stations[0].Name);
            Assert.AreEqual("http://stream.laut.fm/lofi", stations[0].StreamUrl);
            Assert.AreEqual("Smooth Jazz", stations[1].Name);
            Assert.AreEqual("http://0nlineradio.radioho.st/0r-jazz", stations[1].StreamUrl);
        }

        public void TestStationInitialsComputation()
        {
            RadioStation s1 = new RadioStation { Name = "SuamiSihat Radio" };
            Assert.AreEqual("SR", s1.Initials, "Multi-word name should use first letter of each word");

            RadioStation s2 = new RadioStation { Name = "Chillhop" };
            Assert.AreEqual("CH", s2.Initials, "Single-word name should use first two letters uppercase");

            RadioStation s3 = new RadioStation { Name = "" };
            Assert.AreEqual("?", s3.Initials, "Empty name should fallback to ?");
        }

        public void TestResolveStreamUrlLeavesDirectStreamUntouched()
        {
            string directUrl = "https://radio.plaza.one/mp3";
            string resolved = PlaylistHelper.ResolveStreamUrl(directUrl);
            Assert.AreEqual(directUrl, resolved, "Direct MP3 stream URL should return unchanged");
        }
    }
}
