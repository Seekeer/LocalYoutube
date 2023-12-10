using System.Collections.Generic;
using System.Threading.Tasks;
using System.IO;
using System;
using System.Globalization;
using System.Net.Http;
using TwoCaptcha.Captcha;
using TwoCaptcha.Exceptions;
using TwoCaptcha;

namespace API.FilmDownload
{

    public class Solver : VkNet.Utils.AntiCaptcha.ICaptchaSolver
    {
        private string _apiCode = "0f5f69b403d68605115fb3fa462315ee";

        public void CaptchaIsFalse()
        {
        }

        public string Solve(string url)
        {
            NLog.LogManager.GetCurrentClassLogger().Error("Captcha call");

            try
            {
                var client = new CommonControls.Captcha.ExternalCode.TwoCaptchaClass(_apiCode);

                var dir = Path.Combine("Downloads", "VK");
                Directory.CreateDirectory(dir);
                var filename = Path.Combine(dir, $"{Guid.NewGuid().ToString()}.jpeg");
                (new System.Net.WebClient()).DownloadFile(url, filename);
                var captcha = new Normal();
                captcha.SetFile(filename);
                captcha.SetMinLen(4);
                captcha.SetMaxLen(20);
                captcha.SetCaseSensitive(true);

                var task = client.Solve(captcha);
                task.Wait();

                return captcha.Code;
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
                return "a";
            }
        }
    }

    public class Rotate : Captcha2
    {
        public Rotate() : base()
        {
            parameters["method"] = "rotatecaptcha";
        }

        public Rotate(string filePath) : this(new FileInfo(filePath))
        {
        }

        public Rotate(FileInfo file) : this()
        {
            SetFile(file);
        }

        public Rotate(List<FileInfo> files) : this()
        {
            SetFiles(files);
        }

        public void SetFile(String filePath)
        {
            SetFile(new FileInfo(filePath));
        }

        public void SetFile(FileInfo file)
        {
            files["file_1"] = file;
        }

        public void SetFiles(List<FileInfo> files)
        {
            int n = 1;

            foreach (FileInfo file in files)
            {
                this.files["file_" + n++] = file;
            }
        }

        public void SetAngle(double angle)
        {
            parameters["angle"] = Convert.ToString(angle).Replace(',', '.');
        }

        public void SetLang(String lang)
        {
            parameters["lang"] = lang;
        }

        public void SetHintText(String hintText)
        {
            parameters["textinstructions"] = hintText;
        }

        public void SetHintImg(String base64)
        {
            parameters["imginstructions"] = base64;
        }

        public void SetHintImg(FileInfo hintImg)
        {
            files["imginstructions"] = hintImg;
        }
    }
    public class Text : Captcha2
    {
        public Text() : base()
        {
            parameters["method"] = "post";
        }

        public Text(string text) : this()
        {
            SetText(text);
        }

        public void SetText(string text)
        {
            parameters["textcaptcha"] = text;
        }

        public void SetLang(string lang)
        {
            parameters["lang"] = lang;
        }
    }
}
public class ReCaptcha : Captcha2
{
    public ReCaptcha() : base()
    {
        parameters["method"] = "userrecaptcha";
    }

    public void SetSiteKey(string siteKey)
    {
        parameters["googlekey"] = siteKey;
    }

    public void SetUrl(string url)
    {
        parameters["pageurl"] = url;
    }

    public void SetInvisible(bool invisible)
    {
        parameters["invisible"] = invisible ? "1" : "0";
    }

    public void SetVersion(string version)
    {
        parameters["version"] = version;
    }

    public void SetAction(string action)
    {
        parameters["action"] = action;
    }

    public void SetDomain(string domain)
    {
        parameters["domain"] = domain;
    }

    public void SetScore(double score)
    {
        parameters["min_score"] = Convert.ToString(score).Replace(',', '.');
    }
}

namespace TwoCaptcha.Captcha
{
    public class Normal : Captcha2
    {
        public Normal() : base()
        {
        }

        public Normal(String filePath) : this(new FileInfo(filePath))
        {
        }

        public Normal(FileInfo file) : this()
        {
            SetFile(file);
        }

        public void SetFile(string filePath)
        {
            SetFile(new FileInfo(filePath));
        }

        public void SetFile(FileInfo file)
        {
            files["file"] = file;
        }

        public void SetBase64(String base64)
        {
            parameters["body"] = base64;
        }

        public void SetPhrase(bool phrase)
        {
            parameters["phrase"] = phrase ? "1" : "0";
        }

        public void SetCaseSensitive(bool caseSensitive)
        {
            parameters["regsense"] = caseSensitive ? "1" : "0";
        }

        public void SetCalc(bool calc)
        {
            parameters["calc"] = calc ? "1" : "0";
        }

        public void SetNumeric(int numeric)
        {
            parameters["numeric"] = Convert.ToString(numeric);
        }

        public void SetMinLen(int length)
        {
            parameters["min_len"] = Convert.ToString(length);
        }

        public void SetMaxLen(int length)
        {
            parameters["max_len"] = Convert.ToString(length);
        }

        public void SetLang(String lang)
        {
            parameters["lang"] = lang;
        }

        public void SetHintText(String hintText)
        {
            parameters["textinstructions"] = hintText;
        }

        public void SetHintImg(String base64)
        {
            parameters["imginstructions"] = base64;
        }

        public void SetHintImg(FileInfo hintImg)
        {
            files["imginstructions"] = hintImg;
        }
    }
}
namespace TwoCaptcha.Captcha
{
    public class KeyCaptcha : Captcha2
    {
        public KeyCaptcha() : base()
        {
            parameters["method"] = "keycaptcha";
        }

        public void SetUserId(int userId)
        {
            SetUserId(Convert.ToString(userId));
        }

        public void SetUserId(string userId)
        {
            parameters["s_s_c_user_id"] = userId;
        }

        public void SetSessionId(string sessionId)
        {
            parameters["s_s_c_session_id"] = sessionId;
        }

        public void SetWebServerSign(string sign)
        {
            parameters["s_s_c_web_server_sign"] = sign;
        }

        public void SetWebServerSign2(string sign)
        {
            parameters["s_s_c_web_server_sign2"] = sign;
        }

        public void SetUrl(string url)
        {
            parameters["pageurl"] = url;
        }
    }
}
namespace TwoCaptcha.Captcha
{
    public class HCaptcha : Captcha2
    {
        public HCaptcha() : base()
        {
            parameters["method"] = "hcaptcha";
        }

        public void SetSiteKey(string siteKey)
        {
            parameters["sitekey"] = siteKey;
        }

        public void SetUrl(string url)
        {
            parameters["pageurl"] = url;
        }
    }
}
namespace TwoCaptcha.Captcha
{
    public class Grid : Captcha2
    {
        public Grid() : base()
        {
        }

        public Grid(string filePath) : this(new FileInfo(filePath))
        {
        }

        public Grid(FileInfo file) : this()
        {
            SetFile(file);
        }

        public void SetFile(String filePath)
        {
            SetFile(new FileInfo(filePath));
        }

        public void SetFile(FileInfo file)
        {
            files["file"] = file;
        }

        public void SetBase64(String base64)
        {
            parameters["body"] = base64;
        }

        public void SetRows(int rows)
        {
            parameters["recaptcharows"] = Convert.ToString(rows);
        }

        public void SetCols(int cols)
        {
            parameters["recaptchacols"] = Convert.ToString(cols);
        }

        public void SetPreviousId(int previousId)
        {
            parameters["previousID"] = Convert.ToString(previousId);
        }

        public void SetCanSkip(bool canSkip)
        {
            parameters["can_no_answer"] = canSkip ? "1" : "0";
        }

        public void SetLang(String lang)
        {
            parameters["lang"] = lang;
        }

        public void SetHintText(String hintText)
        {
            parameters["textinstructions"] = hintText;
        }

        public void SetHintImg(String base64)
        {
            parameters["imginstructions"] = base64;
        }

        public void SetHintImg(FileInfo hintImg)
        {
            files["imginstructions"] = hintImg;
        }
    }
}
namespace TwoCaptcha.Captcha
{
    public class GeeTest : Captcha2
    {
        public GeeTest() : base()
        {
            parameters["method"] = "geetest";
        }

        public void SetGt(string gt)
        {
            parameters["gt"] = gt;
        }

        public void SetChallenge(string challenge)
        {
            parameters["challenge"] = challenge;
        }

        public void SetUrl(string url)
        {
            parameters["pageurl"] = url;
        }

        public void SetApiServer(string apiServer)
        {
            parameters["api_server"] = apiServer;
        }
    }
}
namespace TwoCaptcha.Captcha
{
    public class FunCaptcha : Captcha2
    {
        public FunCaptcha() : base()
        {
            parameters["method"] = "funcaptcha";
        }

        public void SetSiteKey(string siteKey)
        {
            parameters["publickey"] = siteKey;
        }

        public void SetUrl(string url)
        {
            parameters["pageurl"] = url;
        }

        public void SetSUrl(string sUrl)
        {
            parameters["surl"] = sUrl;
        }

        public void SetUserAgent(string userAgent)
        {
            parameters["userAgent"] = userAgent;
        }

        public void SetData(string key, string value)
        {
            parameters["data[" + key + "]"] = value;
        }
    }
}
namespace TwoCaptcha.Captcha
{
    public class Coordinates : Captcha2
    {
        public Coordinates() : base()
        {
            parameters["coordinatescaptcha"] = "1";
        }

        public Coordinates(string filePath) : this(new FileInfo(filePath))
        {
        }

        public Coordinates(FileInfo file) : this()
        {
            SetFile(file);
        }

        public void SetFile(string filePath)
        {
            SetFile(new FileInfo(filePath));
        }

        public void SetFile(FileInfo file)
        {
            files["file"] = file;
        }

        public void SetBase64(string base64)
        {
            parameters["body"] = base64;
        }

        public void SetLang(string lang)
        {
            parameters["lang"] = lang;
        }

        public void SetHintText(string hintText)
        {
            parameters["textinstructions"] = hintText;
        }

        public void SetHintImg(string base64)
        {
            parameters["imginstructions"] = base64;
        }

        public void SetHintImg(FileInfo hintImg)
        {
            files["imginstructions"] = hintImg;
        }
    }
}
namespace TwoCaptcha.Captcha
{
    public class Capy : Captcha2
    {
        public Capy() : base()
        {
            parameters["method"] = "capy";
        }

        public void SetSiteKey(string siteKey)
        {
            parameters["captchakey"] = siteKey;
        }

        public void SetUrl(string url)
        {
            parameters["pageurl"] = url;
        }

        public void SetApiServer(string apiServer)
        {
            parameters["api_server"] = apiServer;
        }

    }
}
namespace TwoCaptcha.Captcha
{
    public abstract class Captcha2
    {
        public string Id { get; set; }
        public string Code { get; set; }

        protected Dictionary<string, string> parameters;
        protected Dictionary<string, FileInfo> files;

        public Captcha2()
        {
            parameters = new Dictionary<string, string>();
            files = new Dictionary<string, FileInfo>();
        }

        public void SetProxy(string type, string uri)
        {
            parameters["proxy"] = uri;
            parameters["proxytype"] = type;
        }

        public void SetSoftId(int softId)
        {
            parameters["soft_id"] = Convert.ToString(softId);
        }

        public void SetCallback(String callback)
        {
            parameters["pingback"] = callback;
        }

        public Dictionary<string, string> GetParameters()
        {
            var parameters = new Dictionary<string, string>(this.parameters);

            if (!parameters.ContainsKey("method"))
            {
                if (parameters.ContainsKey("body"))
                {
                    parameters["method"] = "base64";
                }
                else
                {
                    parameters["method"] = "post";
                }
            }

            return parameters;
        }

        public Dictionary<string, FileInfo> GetFiles()
        {
            return new Dictionary<string, FileInfo>(files);
        }
    }
}
namespace TwoCaptcha.Captcha
{
    public class Canvas : Captcha2
    {
        public Canvas() : base()
        {
            parameters["canvas"] = "1";
            parameters["recaptcha"] = "1";
        }

        public void SetFile(string filePath)
        {
            SetFile(new FileInfo(filePath));
        }

        public void SetFile(FileInfo file)
        {
            files["file"] = file;
        }

        public void SetBase64(string base64)
        {
            parameters["body"] = base64;
        }

        public void SetPreviousId(int previousId)
        {
            parameters["previousID"] = Convert.ToString(previousId);
        }

        public void SetCanSkip(bool canSkip)
        {
            parameters["can_no_answer"] = canSkip ? "1" : "0";
        }

        public void SetLang(string lang)
        {
            parameters["lang"] = lang;
        }

        public void SetHintText(string hintText)
        {
            parameters["textinstructions"] = hintText;
        }

        public void SetHintImg(string base64)
        {
            parameters["imginstructions"] = base64;
        }

        public void SetHintImg(FileInfo hintImg)
        {
            files["imginstructions"] = hintImg;
        }
    }
}
namespace TwoCaptcha
{
    public class ApiClient
    {
        /**
         * API server
         */
        private string baseUrl = "https://2captcha.com/";

        /**
         * Network client
         */
        private readonly HttpClient client = new HttpClient();

        public ApiClient()
        {
            client.BaseAddress = new Uri(baseUrl);
        }

        public virtual async Task<string> In(Dictionary<string, string> parameters, Dictionary<string, FileInfo> files)
        {
            var content =
                new MultipartFormDataContent("Upload----" + DateTime.UtcNow.ToString(CultureInfo.InvariantCulture));

            foreach (KeyValuePair<string, string> p in parameters)
            {
                content.Add(new StringContent(p.Value), p.Key);
            }

            foreach (KeyValuePair<string, FileInfo> f in files)
            {
                var fileStream = new StreamContent(new MemoryStream(File.ReadAllBytes(f.Value.FullName)));
                content.Add(fileStream, f.Key, f.Value.Name);
            }

            var request = new HttpRequestMessage(HttpMethod.Post, "in.php")
            {
                Content = content
            };

            return await Execute(request).ConfigureAwait(false);
        }

        public virtual async Task<string> Res(Dictionary<string, string> parameters)
        {
            var request = new HttpRequestMessage(HttpMethod.Get, "res.php?" + BuildQuery(parameters));

            return await Execute(request).ConfigureAwait(false);
        }

        private string BuildQuery(Dictionary<string, string> parameters)
        {
            string query = "";

            foreach (KeyValuePair<string, string> p in parameters)
            {
                if (query.Length > 0)
                {
                    query += "&";
                }

                query += p.Key + "=" + Uri.EscapeDataString(p.Value);
            }

            return query;
        }

        private async Task<string> Execute(HttpRequestMessage request)
        {
            var response = await client.SendAsync(request).ConfigureAwait(false);

            string body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);

            if (!response.IsSuccessStatusCode)
            {
                throw new NetworkException("Unexpected response: " + body);
            }

            if (body.StartsWith("ERROR_"))
            {
                throw new ApiException(body);
            }

            return body;
        }
    }
}
namespace TwoCaptcha.Exceptions
{
    public class ApiException : Exception
    {

        public ApiException(string message) : base(message)
        {

        }

    }
}

namespace TwoCaptcha.Exceptions
{
    public class ValidationException : Exception
    {

        public ValidationException(string message) : base(message)
        {

        }

    }
}
namespace TwoCaptcha.Exceptions
{
    public class TimeoutException : Exception
    {

        public TimeoutException(string message) : base(message)
        {

        }

    }
}
namespace TwoCaptcha.Exceptions
{
    public class NetworkException : Exception
    {

        public NetworkException(string message) : base(message)
        {

        }

    }
}
namespace CommonControls.Captcha.ExternalCode
{
    public class TwoCaptchaClass
    {
        /**
         * API KEY
         */
        public string ApiKey { get; set; }

        /**
         * ID of software developer. Developers who integrated their software
         * with our service get reward: 10% of spendings of their software users.
         */
        public int SoftId { get; set; }

        /**
         * URL to which the result will be sent
         */
        public string Callback { get; set; }

        /**
         * How long should wait for captcha result (in seconds)
         */
        public int DefaultTimeout { get; set; } = 120;

        /**
         * How long should wait for recaptcha result (in seconds)
         */
        public int RecaptchaTimeout { get; set; } = 600;

        /**
         * How often do requests to `/res.php` should be made
         * in order to check if a result is ready (in seconds)
         */
        public int PollingInterval { get; set; } = 10;

        /**
         * Helps to understand if there is need of waiting
         * for result or not (because callback was used)
         */
        private bool lastCaptchaHasCallback;

        /**
         * Network client
         */
        private ApiClient apiClient;

        /**
         * TwoCaptcha constructor
         */
        public TwoCaptchaClass()
        {
            apiClient = new ApiClient();
        }

        /**
         * TwoCaptcha constructor
         *
         * @param apiKey
         */
        public TwoCaptchaClass(string apiKey) : this()
        {
            ApiKey = apiKey;
        }

        /**
         * @param apiClient
         */
        public void SetApiClient(ApiClient apiClient)
        {
            this.apiClient = apiClient;
        }

        /**
         * Sends captcha to `/in.php` and waits for it's result.
         * This helper can be used instead of manual using of `send` and `getResult` functions.
         *
         * @param captcha
         * @throws Exception
         */
        public async Task Solve(Captcha2 captcha)
        {
            var waitOptions = new Dictionary<string, int>();

            if (captcha.GetType() == typeof(ReCaptcha))
            {
                waitOptions["timeout"] = RecaptchaTimeout;
            }

            await Solve(captcha, waitOptions).ConfigureAwait(false);
        }

        /**
         * Sends captcha to `/in.php` and waits for it's result.
         * This helper can be used instead of manual using of `send` and `getResult` functions.
         *
         * @param captcha
         * @param waitOptions
         * @throws Exception
         */
        public async Task Solve(Captcha2 captcha, Dictionary<string, int> waitOptions)
        {
            captcha.Id = await Send(captcha).ConfigureAwait(false);

            if (!lastCaptchaHasCallback)
            {
                await WaitForResult(captcha, waitOptions).ConfigureAwait(false);
            }
        }

        /**
         * This helper waits for captcha result, and when result is ready, returns it
         *
         * @param captcha
         * @param waitOptions
         * @throws Exception
         */
        public async Task WaitForResult(Captcha2 captcha, Dictionary<string, int> waitOptions)
        {
            long startedAt = CurrentTime();

            int timeout = waitOptions.TryGetValue("timeout", out timeout) ? timeout : DefaultTimeout;
            int pollingInterval = waitOptions.TryGetValue("pollingInterval", out pollingInterval)
                ? pollingInterval
                : PollingInterval;

            while (true)
            {
                long now = CurrentTime();

                if (now - startedAt < timeout)
                {
                    await Task.Delay(pollingInterval * 1000).ConfigureAwait(false);
                }
                else
                {
                    break;
                }

                try
                {
                    string result = await GetResult(captcha.Id).ConfigureAwait(false);
                    if (result != null)
                    {
                        captcha.Code = result;
                        return;
                    }
                }
                catch (NetworkException)
                {
                    // ignore network errors
                }
            }

            throw new TwoCaptcha.Exceptions.TimeoutException("Timeout " + timeout + " seconds reached");
        }

        private long CurrentTime()
        {
            return Convert.ToInt64((DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalSeconds);
        }

        /**
         * Sends captcha to '/in.php', and returns its `id`
         *
         * @param captcha
         * @return
         * @throws Exception
         */
        public async Task<string> Send(Captcha2 captcha)
        {
            var parameters = captcha.GetParameters();
            var files = captcha.GetFiles();

            SendAttachDefaultParameters(parameters);

            ValidateFiles(files);

            string response = await apiClient.In(parameters, files).ConfigureAwait(false);

            if (!response.StartsWith("OK|"))
            {
                throw new ApiException("Cannot recognise api response (" + response + ")");
            }

            return response.Substring(3);
        }

        /**
         * Returns result of captcha if it was solved or `null`, if result is not ready
         *
         * @param id
         * @return
         * @throws Exception
         */
        public async Task<string> GetResult(String id)
        {
            var parameters = new Dictionary<string, string>();
            parameters["action"] = "get";
            parameters["id"] = id;

            string response = await Res(parameters).ConfigureAwait(false);

            if (response.Equals("CAPCHA_NOT_READY"))
            {
                return null;
            }

            if (!response.StartsWith("OK|"))
            {
                throw new ApiException("Cannot recognise api response (" + response + ")");
            }

            return response.Substring(3);
        }

        /**
         * Gets account's balance
         *
         * @return
         * @throws Exception
         */
        public async Task<double> Balance()
        {
            string response = await Res("getbalance");
            return Convert.ToDouble(response);
        }

        /**
         * Reports if captcha was solved correctly (sends `reportbad` or `reportgood` to `/res.php`)
         *
         * @param id
         * @param correct
         * @throws Exception
         */
        public async Task Report(string id, bool correct)
        {
            var parameters = new Dictionary<string, string>();
            parameters["id"] = id;

            if (correct)
            {
                parameters["action"] = "reportgood";
            }
            else
            {
                parameters["action"] = "reportbad";
            }

            await Res(parameters);
        }

        /**
         * Makes request to `/res.php`
         *
         * @param action
         * @return
         * @throws Exception
         */
        private async Task<string> Res(string action)
        {
            var parameters = new Dictionary<string, string>();
            parameters["action"] = action;
            return await Res(parameters);
        }

        /**
         * Makes request to `/res.php`
         *
         * @param params
         * @return
         * @throws Exception
         */
        private async Task<string> Res(Dictionary<string, string> parameters)
        {
            parameters["key"] = ApiKey;
            return await apiClient.Res(parameters).ConfigureAwait(false);
        }

        /**
         * Attaches default parameters to request
         *
         * @param params
         */
        private void SendAttachDefaultParameters(Dictionary<string, string> parameters)
        {
            parameters["key"] = ApiKey;

            if (Callback != null)
            {
                if (!parameters.ContainsKey("pingback"))
                {
                    parameters["pingback"] = Callback;
                }
                else if (parameters["pingback"].Length == 0)
                {
                    parameters.Remove("pingback");
                }
            }

            lastCaptchaHasCallback = parameters.ContainsKey("pingback");

            if (SoftId != 0 && !parameters.ContainsKey("soft_id"))
            {
                parameters["soft_id"] = Convert.ToString(SoftId);
            }
        }

        /**
         * Validates if files parameters are correct
         *
         * @param files
         * @throws ValidationException
         */
        private void ValidateFiles(Dictionary<string, FileInfo> files)
        {
            foreach (KeyValuePair<string, FileInfo> entry in files)
            {
                FileInfo file = entry.Value;

                if (!file.Exists)
                {
                    throw new ValidationException("File not found: " + file.FullName);
                }
            }
        }
    }
}
