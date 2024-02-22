using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Infrastructure
{
    public static class TaskHelper
    {
        public static bool WaitforExit(this Action act, TimeSpan timeout)
        {
            var cts = new CancellationTokenSource();
            var task = Task.Factory.StartNew(act, cts.Token);
            if (Task.WaitAny(new[] { task }, timeout) < 0)
            { 
                cts.Cancel();
                return false;
            }
            else if (task.Exception != null)
            { 
                cts.Cancel();
                throw task.Exception;
            }
            return true;
        }
    }
}
