using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace MVCSecureApp.WebAPI
{

    public struct ObjTaskAndHttpStatusCode
    {
        public Models.Task passedTask;
        public HttpResponseMessage responseReceived;
    }

    public struct ObjTaskListAndHttpStatusCode
    {
        public List<Models.Task> passedTaskList;
        public HttpResponseMessage responseReceived;
    }


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

        public async Task<ObjTaskListAndHttpStatusCode> GetCollection(AuthenticationResult token)
        {

            ObjTaskListAndHttpStatusCode returnValue = new ObjTaskListAndHttpStatusCode
            {
                passedTaskList = null, responseReceived = null
            };

            HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Get, _commonURL);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);
            returnValue.responseReceived = await HttpClientInstance.SendAsync(request);

            if (returnValue.responseReceived.IsSuccessStatusCode)
            {
                JObject o = JObject.Parse(await returnValue.responseReceived.Content.ReadAsStringAsync());
                JToken t = o.GetValue("tasks");
                if (t != null)
                {
                    returnValue.passedTaskList = new List<Models.Task>();
                    foreach (var item in t)
                    {
                        {
                            Models.Task task = JsonConvert.DeserializeObject<Models.Task>(item.ToString());
                            returnValue.passedTaskList.Add(task);
                        }
                    }
                }
            }
            return returnValue;
        }

        public async Task<ObjTaskAndHttpStatusCode> CreateNew(Models.Task task, AuthenticationResult token)
        {
            ObjTaskAndHttpStatusCode returnValue = new ObjTaskAndHttpStatusCode
            {
                passedTask = null,
                responseReceived = null
            };

            var jsonObject = JsonConvert.SerializeObject(task);
            var content = new StringContent(jsonObject.ToString(), Encoding.UTF8, "application/json");
            HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Post, _commonURL);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);
            request.Content = content;
            returnValue.responseReceived = await HttpClientInstance.SendAsync(request);
            if (returnValue.responseReceived.IsSuccessStatusCode)
            {
                string strResult = await returnValue.responseReceived.Content.ReadAsStringAsync();
                returnValue.passedTask = GetTask(strResult);
            }

            return returnValue;
        }

        public async Task<ObjTaskAndHttpStatusCode> GetDetails(int Id, AuthenticationResult token)
        {
            ObjTaskAndHttpStatusCode returnValue = new ObjTaskAndHttpStatusCode
            {
                passedTask = null,
                responseReceived = null
            };

            var url = _commonURL + "/" + Id.ToString();

            HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);
            returnValue.responseReceived = await HttpClientInstance.SendAsync(request);

            if (returnValue.responseReceived.IsSuccessStatusCode)
            {
                string strResult = await returnValue.responseReceived.Content.ReadAsStringAsync();
                returnValue.passedTask = GetTask(strResult);
            }
            return returnValue;
        }

        public async Task<ObjTaskAndHttpStatusCode> Edit(Models.Task task, AuthenticationResult token)
        {
            ObjTaskAndHttpStatusCode returnValue = new ObjTaskAndHttpStatusCode
            {
                passedTask = null,
                responseReceived = null
            };

            var url = _commonURL + "/" + task.Id.ToString();
            var jsonObject = JsonConvert.SerializeObject(task);
            var content = new StringContent(jsonObject.ToString(), Encoding.Unicode, "application/json");

            HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Put, url);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);
            request.Content = content;

            returnValue.responseReceived = await HttpClientInstance.SendAsync(request);
            if (returnValue.responseReceived.IsSuccessStatusCode)
            {
                string strResult = await returnValue.responseReceived.Content.ReadAsStringAsync();
                returnValue.passedTask = GetTask(strResult);
            }
            return returnValue;
        }

        public async Task<ObjTaskAndHttpStatusCode> Delete(int Id, AuthenticationResult token)
        {
            ObjTaskAndHttpStatusCode returnValue = new ObjTaskAndHttpStatusCode
            {
                passedTask = null,
                responseReceived = null
            };

            var url = _commonURL + "/" + Id.ToString();

            HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Delete, url);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);
            returnValue.responseReceived = await HttpClientInstance.SendAsync(request);

            if (returnValue.responseReceived.IsSuccessStatusCode)
            {
                string strResult = await returnValue.responseReceived.Content.ReadAsStringAsync();
                JObject o = JObject.Parse(strResult);
                JToken t = o.GetValue("result");
                if (t != null)
                {
                    try
                    {

                        bool bReturnValue = Convert.ToBoolean(t.ToString());
                        if (bReturnValue)
                        {
                            returnValue.passedTask = new Models.Task();
                        }
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine("Error");
                        Debug.WriteLine(ex.Message);
                    }
                }
            }
            return returnValue;
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

    }
}
