using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace MVCSecureApp.WebAPI
{
    public sealed class TaskWebAPIWrapper
    {
        private static HttpClient _httpClient = null;
        private static Uri _commonURL = null;


        public TaskWebAPIWrapper(Uri PythonWebAPIURL)
        {
            _commonURL = PythonWebAPIURL;
        }

        public static HttpClient HttpClientInstance
        {
            get
            {
                if (_httpClient == null)
                {
                    Initialize();
                }
                return _httpClient;
            }
        }


        public static void Initialize()
        {
            _httpClient = new HttpClient();
            _httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36");
        }

        public List<Models.Task> GetCollection()
        {
            List<Models.Task> rv = new List<Models.Task>();
            var response = HttpClientInstance.GetStringAsync(_commonURL).Result;
            JObject o = JObject.Parse(response);
            JToken t = o.GetValue("tasks");
            if (t != null)
            {
                foreach (var item in t)
                {
                    {
                        Models.Task task = JsonConvert.DeserializeObject<Models.Task>(item.ToString());
                        Debug.Assert(task != null);
                        rv.Add(task);
                        Debug.WriteLine(task.Id);
                        Debug.WriteLine(task.Description);
                    }
                }
            }
            return rv;
        }


        public async Task<Models.Task> CreateNew(Models.Task task)
        {
            Models.Task rv = null;
            var jsonObject = JsonConvert.SerializeObject(task);
            var content = new StringContent(jsonObject.ToString(), Encoding.UTF8, "application/json");
            var result = HttpClientInstance.PostAsync(_commonURL, content).Result;

            if (result.IsSuccessStatusCode)
            {
                string strResult = await result.Content.ReadAsStringAsync();
                rv = GetTask(strResult);
            }

            return rv;
        }


        public Models.Task GetDetails(int Id)
        {
            Models.Task rv = null;

            var url = _commonURL + "/" + Id.ToString();
            var response = HttpClientInstance.GetStringAsync(new Uri(url)).Result;
            rv = GetTask(response);
            return rv;
        }

        public async Task<Models.Task> Edit(Models.Task task)
        {
            Models.Task rv = null;

            var url = _commonURL + "/" + task.Id.ToString();

            var jsonObject = JsonConvert.SerializeObject(task);
            var content = new StringContent(jsonObject.ToString(), Encoding.Unicode, "application/json");

            var response = HttpClientInstance.PutAsync(new Uri(url), content).Result;

            if (response.IsSuccessStatusCode)
            {
                string strResult = await response.Content.ReadAsStringAsync();
                rv = GetTask(strResult);
            }
            return rv;
        }

        public async Task<bool> Delete(int Id)
        {
            bool brv = false;

            var url = _commonURL + "/" + Id.ToString();
            var response = HttpClientInstance.DeleteAsync(new Uri(url)).Result;

            if (response.IsSuccessStatusCode)
            {
                string strResult = await response.Content.ReadAsStringAsync();
                JObject o = JObject.Parse(strResult);
                JToken t = o.GetValue("result");
                if (t != null)
                {
                    try
                    {
                        brv = Convert.ToBoolean(t.ToString());
                    }
                    catch(Exception ex)
                    {
                        Debug.WriteLine("Error");
                        Debug.WriteLine(ex.Message);
                    }
                }
            }
            return brv;
        }


        private Models.Task GetTask(string strResult)
        {
            Models.Task rv = null;
            JObject o = JObject.Parse(strResult);
            JToken t = o.GetValue("task");
            if (t != null)
            {
                rv = JsonConvert.DeserializeObject<Models.Task>(t.ToString());
            }
            return rv;
        }


        //private async Task<string> GetAccessTokenAsync()
        //{
        //    var context = new AuthenticationContext(_settings.Authority);
        //    AuthenticationResult result;
        //    try
        //    {
        //        result = await context.AcquireTokenSilentAsync(_settings.ApiResourceUri, _settings.ClientId);
        //    }
        //    catch (AdalSilentTokenAcquisitionException)
        //    {
        //        DeviceCodeResult deviceCodeResult = await context.AcquireDeviceCodeAsync(_settings.ApiResourceUri, _settings.ClientId);
        //        Console.WriteLine(deviceCodeResult.Message);
        //        result = await context.AcquireTokenByDeviceCodeAsync(deviceCodeResult);
        //    }
        //    return result.AccessToken;
        //}
    }
}
