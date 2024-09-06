using HtmlAgilityPack;
using OpenQA.Selenium.Chrome;
using System;
using System.Management;
using System.Text;
using System.Threading;

namespace API.FilmDownload
{
    public static class HTMLHelper
    {
        public static string GetHREF(this HtmlNode node)
        {
            return node.GetAttributeValue("href", "");
        }
    }

    public class WebDriverPageLoader : IWebPageLoader
    {
        private ChromeDriverService _service;
        private ChromeDriver _driver;
        private readonly TimeSpan _waitTime;
        private readonly bool _disposeAfterGet;

        public WebDriverPageLoader(TimeSpan waitTime, bool disposeAfterGet)
        {
            _waitTime = waitTime;
            _disposeAfterGet = disposeAfterGet;
        }

        public HtmlDocument GetDocument(string url, Encoding encoding = null)
        {
            var html = _GetHTML(url);

            var doc = new HtmlDocument();
            doc.LoadHtml(html);
            return doc;
        }

        public string GetStringDocument(string url)
        {
            return _GetHTML(url);
        }

        private string _GetHTML(string url)
        {
            InitDriver();

            _driver.Navigate().GoToUrl(url);

            Thread.Sleep(_waitTime);
            var html = _driver.PageSource;

            if(_disposeAfterGet)
                Dispose();

            return html;
        }

        public void Dispose()
        {
            _driver?.Dispose();
            _service?.Dispose();
            _driver = null;
            _service = null;
        }

        private void InitDriver(int tryNumber = 0)
        {
            if (_service == null || _driver == null)
            {
                try
                {
                    _service = _CreateDriverService();
                    _driver = _CreateChromeDriver(_service);
                }
                catch (Exception ex)
                {
                    if (tryNumber > 1)
                        throw;

                    this.Dispose();
                    ForceKillChromedriverProcess();
                    InitDriver(tryNumber++);
                }
            }
        }

        private static ChromeDriverService _CreateDriverService()
        {
            var driverService = ChromeDriverService.CreateDefaultService();
            driverService.Port = 59589;
            driverService.HideCommandPromptWindow = true;
            return driverService;
        }

        private ChromeDriver _CreateChromeDriver(ChromeDriverService service)
        {
            var opt = new ChromeOptions();
            //opt.AddArgument("--headless");

            opt.AddArgument("start-maximized");
            opt.AddArgument("--disable-popup-blocking");
            opt.AddArgument("--disable-notifications");
            opt.AddArgument("--mute-audio");

            opt.AddArgument("--disable-blink-features");
            opt.AddArgument("--disable-app-list-dismiss-on-blur");
            opt.AddArgument("--disable-core-animation-plugins");
            opt.AddArgument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Safari/537.36");

            opt.AddExcludedArgument("enable-automation");//for hiding chrome being controlled by automation..
            //opt.AddAdditionalCapability("useAutomationExtension", false);

            //var proxyStr = Proxy;
            //if (!string.IsNullOrEmpty(proxyStr))
            //{
            //    if (this.ProxyZip)
            //        opt.AddExtension(proxyStr);
            //    else
            //        opt.AddArguments($"--proxy-server={proxyStr}");
            //}
            var driver = new ChromeDriver(service, opt);

            return driver;
        }

        public void ForceKillChromedriverProcess()
        {
            try
            {
                System.Diagnostics.Process[] processes = System.Diagnostics.Process.GetProcessesByName("chromedriver");
                for (int p = 0; p < processes.Length; p++)
                {
                    ManagementObjectSearcher commandLineSearcher =
                            new ManagementObjectSearcher("SELECT CommandLine FROM Win32_Process WHERE ProcessId = " + processes[p].Id);
                    String commandLine = "";
                    foreach (ManagementObject commandLineObject in commandLineSearcher.Get())
                    {
                        commandLine += (String)commandLineObject["CommandLine"];
                    }

                    String script_pid_str = (new System.Text.RegularExpressions.Regex("--scriptpid-(.+?) ")).Match(commandLine).Groups[1].Value;

                    if (!script_pid_str.Equals(""))
                    {
                        processes[p].Kill();
                        break;
                    }
                }
            }
            catch (Exception ex)
            {
            }
        }

    }
}