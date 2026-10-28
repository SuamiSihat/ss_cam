using System;
using System.Diagnostics;
using System.Reflection;
using SS_CAM.Tests.Suites;

namespace SS_CAM.Tests
{
    public class Program
    {
        public static int Main(string[] args)
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("============================================================");
            Console.WriteLine("SS-CAM Windows Desktop Automated Unit-Test Suite (SS-CAM.Tests)");
            Console.WriteLine("============================================================");
            Console.ResetColor();

            Stopwatch totalSw = Stopwatch.StartNew();
            int passed = 0;
            int failed = 0;

            Type[] suiteTypes = new Type[]
            {
                typeof(FrontmatterServiceTests),
                typeof(PortalAuthServiceTests),
                typeof(AssetNamingServiceTests),
                typeof(RadioStreamServiceTests),
                typeof(TenantConfigServiceTests)
            };

            foreach (Type suiteType in suiteTypes)
            {
                Console.WriteLine();
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine(string.Format("--- Suite: {0} ---", suiteType.Name));
                Console.ResetColor();

                object suiteInstance = Activator.CreateInstance(suiteType);
                MethodInfo[] methods = suiteType.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);

                foreach (MethodInfo method in methods)
                {
                    if (method.GetParameters().Length > 0) continue;

                    Stopwatch sw = Stopwatch.StartNew();
                    try
                    {
                        method.Invoke(suiteInstance, null);
                        sw.Stop();
                        passed++;

                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.Write("  [PASS] ");
                        Console.ResetColor();
                        Console.WriteLine(string.Format("{0} ({1}ms)", method.Name, sw.ElapsedMilliseconds));
                    }
                    catch (TargetInvocationException ex)
                    {
                        sw.Stop();
                        failed++;
                        Exception inner = ex.InnerException ?? ex;

                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.Write("  [FAIL] ");
                        Console.ResetColor();
                        Console.WriteLine(string.Format("{0} ({1}ms)", method.Name, sw.ElapsedMilliseconds));

                        Console.ForegroundColor = ConsoleColor.DarkRed;
                        Console.WriteLine(string.Format("         {0}", inner.Message));
                        if (inner.StackTrace != null)
                        {
                            string[] lines = inner.StackTrace.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.RemoveEmptyEntries);
                            if (lines.Length > 0)
                            {
                                Console.WriteLine(string.Format("         {0}", lines[0].Trim()));
                            }
                        }
                        Console.ResetColor();
                    }
                    catch (Exception ex)
                    {
                        sw.Stop();
                        failed++;

                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.Write("  [FAIL] ");
                        Console.ResetColor();
                        Console.WriteLine(string.Format("{0}: {1}", method.Name, ex.Message));
                    }
                }
            }

            totalSw.Stop();
            Console.WriteLine();
            Console.WriteLine("============================================================");
            if (failed == 0)
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine(string.Format("ALL TESTS PASSED: {0} passed / 0 failed (Total: {1}ms)", passed, totalSw.ElapsedMilliseconds));
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine(string.Format("TESTS FAILED: {0} passed / {1} failed (Total: {2}ms)", passed, failed, totalSw.ElapsedMilliseconds));
            }
            Console.ResetColor();
            Console.WriteLine("============================================================");

            Environment.ExitCode = (failed > 0 ? 1 : 0);
            return Environment.ExitCode;
        }
    }
}
