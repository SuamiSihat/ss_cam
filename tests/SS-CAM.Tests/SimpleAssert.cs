using System;

namespace SS_CAM.Tests
{
    public class AssertionException : Exception
    {
        public AssertionException(string message) : base(message) { }
    }

    public static class Assert
    {
        public static void IsTrue(bool condition, string message = null)
        {
            if (!condition)
            {
                throw new AssertionException(string.Format("Assert.IsTrue failed. {0}", message ?? ""));
            }
        }

        public static void IsFalse(bool condition, string message = null)
        {
            if (condition)
            {
                throw new AssertionException(string.Format("Assert.IsFalse failed. {0}", message ?? ""));
            }
        }

        public static void AreEqual<T>(T expected, T actual, string message = null)
        {
            if (expected == null && actual == null) return;
            if (expected == null || !expected.Equals(actual))
            {
                throw new AssertionException(string.Format("Assert.AreEqual failed. Expected: <{0}>, Actual: <{1}>. {2}",
                    expected != null ? expected.ToString() : "null",
                    actual != null ? actual.ToString() : "null",
                    message ?? ""));
            }
        }

        public static void AreNotEqual<T>(T notExpected, T actual, string message = null)
        {
            if (notExpected == null && actual == null)
            {
                throw new AssertionException(string.Format("Assert.AreNotEqual failed. Both values are null. {0}", message ?? ""));
            }
            if (notExpected != null && notExpected.Equals(actual))
            {
                throw new AssertionException(string.Format("Assert.AreNotEqual failed. Unexpected matching value: <{0}>. {1}",
                    actual != null ? actual.ToString() : "null",
                    message ?? ""));
            }
        }

        public static void IsNotNull(object obj, string message = null)
        {
            if (obj == null)
            {
                throw new AssertionException(string.Format("Assert.IsNotNull failed. Value is null. {0}", message ?? ""));
            }
        }

        public static void IsNull(object obj, string message = null)
        {
            if (obj != null)
            {
                throw new AssertionException(string.Format("Assert.IsNull failed. Value is not null: <{0}>. {1}", obj, message ?? ""));
            }
        }

        public static void StringContains(string expectedSubstring, string actualString, string message = null)
        {
            if (actualString == null)
            {
                throw new AssertionException(string.Format("Assert.StringContains failed. Actual string is null. {0}", message ?? ""));
            }
            if (expectedSubstring != null && !actualString.Contains(expectedSubstring))
            {
                throw new AssertionException(string.Format("Assert.StringContains failed. Expected substring: \"{0}\" not found in: \"{1}\". {2}",
                    expectedSubstring, actualString, message ?? ""));
            }
        }

        public static void Throws<TException>(Action action, string message = null) where TException : Exception
        {
            if (action == null) throw new ArgumentNullException("action");

            try
            {
                action();
            }
            catch (TException)
            {
                return; // Expected
            }
            catch (Exception ex)
            {
                throw new AssertionException(string.Format("Assert.Throws failed. Expected <{0}> but caught <{1}>: {2}. {3}",
                    typeof(TException).Name, ex.GetType().Name, ex.Message, message ?? ""));
            }

            throw new AssertionException(string.Format("Assert.Throws failed. Expected exception <{0}> was not thrown. {1}",
                typeof(TException).Name, message ?? ""));
        }
    }
}
