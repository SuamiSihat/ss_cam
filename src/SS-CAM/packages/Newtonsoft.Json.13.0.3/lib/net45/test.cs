using System;
using Newtonsoft.Json.Linq;

class Program {
    static void Main() {
        string json = ""{ 'prayers': [ { 'day': 1, 'hijri': '1448' }, { 'day': 10, 'hijri': '1448' } ] }"";
        var jObj = JObject.Parse(json);
        var arr = (jObj[""prayers""] ?? jObj[""prayerTime""]) as JArray;
        Console.WriteLine($""Count: {arr.Count}"");
        int todayDay = 10;
        foreach (var tok in arr) {
            if (tok[""day""] != null) {
                int d;
                if (int.TryParse(tok[""day""].ToString(), out d) && d == todayDay) {
                    Console.WriteLine($""Found day: {d}"");
                    break;
                }
            }
        }
    }
}
