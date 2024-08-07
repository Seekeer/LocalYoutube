using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;

namespace API.FilmDownload
{
    internal class LocalPCHelper
    {
        internal static void StartAnydesk()
        {
            _RunShell(GetAnydeskPath());
        }

        internal static void StopAnydesk()
        {
            _CloseAllProcess("AnyDesk");
        }

        internal static void SuspendPC()
        {
            SetSuspendState(true, true, true);
        }

        [DllImport("Powrprof.dll", CharSet = CharSet.Auto, ExactSpelling = true)]
        public static extern bool SetSuspendState(bool hiberate, bool forceCritical, bool disableWakeEvent);

        public static string GetAnydeskPath()
        {
            return @"C:\Program Files (x86)\AnyDesk\AnyDesk.exe";
        }

        private static bool _CloseAllProcess(string name)
        {
            var processes = Process.GetProcessesByName(name);
            foreach (Process proc in processes)
                proc.Kill();

            return processes.Any();
        }

        private static bool _RunShell(string parameters)
        {
            var process = new Process();
            process.StartInfo.FileName = parameters;
            var dirInfo = new DirectoryInfo(parameters);
            process.StartInfo.WorkingDirectory = dirInfo.Parent.FullName;
            return process.Start();
        }
    }
}