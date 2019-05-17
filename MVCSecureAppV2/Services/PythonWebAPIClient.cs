using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;

namespace MVCSecureAppV2.Services
{

    public struct ObjTaskAndHttpStatusCode
    {
        public Models.ApiTask passedTask;
        public HttpResponseMessage responseReceived;
    }

    public struct ObjTaskListAndHttpStatusCode
    {
        public List<Models.ApiTask> passedTaskList;
        public HttpResponseMessage responseReceived;
    }

    public class PythonWebAPIClient
    {
        IAuthenticationProvider _authProvider;
        private static string _commonURL = null;

        private static HttpClient _httpClient = null;

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

        public PythonWebAPIClient(string PythonWebAPIURL, IAuthenticationProvider authProvider)
        {
            _commonURL = PythonWebAPIURL;
            _authProvider = authProvider;
        }

        public async Task<ObjTaskListAndHttpStatusCode> GetCollection()
        {

            ObjTaskListAndHttpStatusCode returnValue = new ObjTaskListAndHttpStatusCode
            {
                passedTaskList = null,
                responseReceived = null
            };

           
            HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Get, _commonURL);
            await _authProvider.AuthenticateRequestAsync(request);
            returnValue.responseReceived = await HttpClientInstance.SendAsync(request);

            if (returnValue.responseReceived.IsSuccessStatusCode)
            {
                JObject o = JObject.Parse(await returnValue.responseReceived.Content.ReadAsStringAsync());
                JToken t = o.GetValue("tasks");
                if (t != null)
                {
                    returnValue.passedTaskList = new List<Models.ApiTask>();
                    foreach (var item in t)
                    {
                        {
                            Models.ApiTask task = JsonConvert.DeserializeObject<Models.ApiTask>(item.ToString());
                            returnValue.passedTaskList.Add(task);
                        }
                    }
                }
            }
            return returnValue;
        }
    }
}
