using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Infrastructure
{
    public static class TimeHelper
    {
        public static TimeSpan ParseTS(this string timestamp)
        {
            if (string.IsNullOrEmpty(timestamp))
                return TimeSpan.Zero;

            try
            {
                return TimeSpan.ParseExact(timestamp, new string[] { "h\\:mm\\:ss", "mm\\:ss", "m\\:ss" }, CultureInfo.InvariantCulture); 
            }
            catch (Exception ex)
            {
                return TimeSpan.Zero;
            }
        }
    }
}
