using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using MVCSecureApp.Models;
using MVCSecureApp.Utils;
using MVCSecureApp.WebAPI;

using Newtonsoft.Json.Linq;

namespace MVCSecureApp.Controllers
{
    struct AuthenticationContextAndToken
    {
        public AuthenticationContext ctx;
        public AuthenticationResult token;
    }

    [Authorize]
    public class TaskController : Controller
    {
        private TaskWebAPIWrapper _WebApiController;
        private const string UnableToAcquireToken = "Unable to acquire Token";
        private const string NoTaskReturned = "No Task Returned";

        public TaskController(TaskWebAPIWrapper WebApiController)
        {
            _WebApiController = WebApiController;
        }
        // GET: Task
        public async Task<ActionResult> Index()
        {
            try
            {
                AuthenticationContextAndToken ctx_token = await GetTokenAndAuthenticationContext();
               
                if (ctx_token.token != null)
                {
                    ObjTaskListAndHttpStatusCode rv = await _WebApiController.GetCollection(ctx_token.token);
                    if (rv.passedTaskList != null)
                    {
                        return View(rv.passedTaskList);
                    }
                    else
                    {
                        return CheckAuthenticationNoTaskError(rv.responseReceived, ctx_token.ctx, true);
                    }
                }
                else
                {
                    return Error(UnableToAcquireToken, "");
                }
            }
            catch (Exception ex)
            {
                return DisplayExceptionError(ex);
            }
        }


        // GET: Task/Details/5
        public async Task<ActionResult> Details(int id)
        {
            try
            {
                AuthenticationContextAndToken ctx_token = await GetTokenAndAuthenticationContext();
                if (ctx_token.token != null)
                {
                    ObjTaskAndHttpStatusCode rv = await _WebApiController.GetDetails(id, ctx_token.token);
                    if (rv.passedTask != null)
                    {
                        return View(rv.passedTask);
                    }
                    else
                    {
                        return CheckAuthenticationNoTaskError(rv.responseReceived, ctx_token.ctx);
                    }
                }
                else
                {
                    return Error(UnableToAcquireToken, "");
                }
            }
            catch (Exception ex)
            {
                return DisplayExceptionError(ex);
            }
        }

        // GET: Task/Create
        public ActionResult Create()
        {
            return View();
        }

        // POST: Task/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<ActionResult> Create(IFormCollection collection)
        {
            try
            {
                AuthenticationContextAndToken ctx_token = await GetTokenAndAuthenticationContext();
                if (ctx_token.token != null)
                {
                    Models.Task task = new Models.Task();
                    task.Description = collection["Description"];
                    task.Title = collection["Title"];

                    ObjTaskAndHttpStatusCode rv = await _WebApiController.CreateNew(task, ctx_token.token);
                    if (rv.passedTask != null)
                    {
                        // assumption here that the HttpStatusCode returned is +ve
                        return RedirectToAction(nameof(Index));
                    }
                    else
                    {
                        return CheckAuthenticationNoTaskError(rv.responseReceived, ctx_token.ctx);
                    }
                }
                else
                {
                    return Error(UnableToAcquireToken, "");
                }
            }
            catch (Exception ex)
            {
                return DisplayExceptionError(ex);
            }
        }

        // GET: Task/Edit/5
        public async Task<ActionResult> Edit(int id)
        {
            return await BaseImpl(id);
        }

        // POST: Task/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<ActionResult> Edit(int id, IFormCollection collection)
        {
            try
            {
                AuthenticationContextAndToken ctx_token = await GetTokenAndAuthenticationContext();
                if (ctx_token.token != null)
                {
                    // TODO: Add update logic here
                    Models.Task task = new Models.Task();
                    task.Id = collection["Id"];
                    task.Description = collection["Description"];
                    task.Title = collection["Title"];

                    task.Done = false;
                    try
                    {
                        string doneString = collection["Done"];
                        task.Done = Convert.ToBoolean(doneString.Split(',')[0]);
                    }
                    catch (Exception ex)
                    {
                        return Error(ex.Message, ex.InnerException.ToString());
                    }

                    ObjTaskAndHttpStatusCode rv = await _WebApiController.Edit(task, ctx_token.token);
                    if (rv.passedTask != null)
                    {
                        return RedirectToAction(nameof(Index));
                    }
                    else
                    {
                        return CheckAuthenticationNoTaskError(rv.responseReceived, ctx_token.ctx);
                    }
                }
                else
                {
                    return Error(UnableToAcquireToken, "");
                }
            }
            catch (Exception ex)
            {
                return DisplayExceptionError(ex);
            }
        }

        // GET: Task/Delete/5
        public async Task<ActionResult> Delete(int id)
        {
            return await BaseImpl(id);
        }

        // POST: Task/Delete/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<ActionResult> Delete(int id, IFormCollection collection)
        {
            try
            {
                AuthenticationContextAndToken ctx_token = await GetTokenAndAuthenticationContext();
                if (ctx_token.token != null)
                {
                    ObjTaskAndHttpStatusCode rv = await _WebApiController.Delete(id, ctx_token.token);

                    if (rv.passedTask != null)
                    {
                        return RedirectToAction(nameof(Index));
                    }
                    else
                    {
                        return CheckAuthenticationNoTaskError(rv.responseReceived, ctx_token.ctx);
                    }
                }
                else
                {
                    return Error(UnableToAcquireToken, "");
                }
            }
            catch (Exception ex)
            {
                return DisplayExceptionError(ex);
            }
        }

        private async Task<ActionResult> BaseImpl(int id)
        {
            AuthenticationContextAndToken ctx_token = await GetTokenAndAuthenticationContext();
            if (ctx_token.token != null)
            {
                ObjTaskAndHttpStatusCode rv = await _WebApiController.GetDetails(id, ctx_token.token);
                if (rv.passedTask != null)
                {
                    return View(rv.passedTask);
                }
                else
                {
                    return CheckAuthenticationNoTaskError(rv.responseReceived, ctx_token.ctx);
                }
            }
            else
            {
                return Error(UnableToAcquireToken, "");
            }
        }

        private ActionResult DisplayExceptionError(Exception ex)
        {
            if (ex.InnerException != null)
            {
                return Error(ex.Message, ex.InnerException.ToString());
            }
            else
            {
                return Error(ex.Message, "");
            }
        }


        private ActionResult CheckAuthenticationNoTaskError(System.Net.Http.HttpResponseMessage responseReceived, AuthenticationContext authContext, bool bList = false)
        {
            if (responseReceived.StatusCode == System.Net.HttpStatusCode.Unauthorized)
            {
                // clear cache. 
                clearCache(authContext);
                return RedirectToAction("AccessDenied", "Account");
            }
            else
            {
                if (responseReceived.StatusCode == System.Net.HttpStatusCode.BadRequest)
                {
                    clearCache(authContext);
                    //return new ChallengeResult(OpenIdConnectDefaults.AuthenticationScheme);
                }
            }

            bool displayConsentScreen = false;
            string displayString = ConsentScreenDisplay(responseReceived, out displayConsentScreen);

            if (displayConsentScreen)
            {
                string userObjectID = User.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier").Value;
                CookieOptions option = new CookieOptions();
                option.Expires = DateTime.Now.AddMinutes(60);
                Response.Cookies.Append(ErrorViewModel.PromptConsentCookie, userObjectID, option);
                return Error("Consent Required!", "Signout and Sign back in again with current user");
            }
            else
            {
                return Error(responseReceived.ReasonPhrase, displayString);
            }

        }

        private string ConsentScreenDisplay(System.Net.Http.HttpResponseMessage responseReceived, out bool displayConsentScreen)
        {
            displayConsentScreen = false; 
            var sB = new StringBuilder();

            bool bFound = false;
            foreach (var item in responseReceived.Headers)
            {
                if ("WWW-Authenticate".Equals(item.Key) || ("Content".Equals(item.Key)))
                {
                    string strValue = item.Value.FirstOrDefault();
                    sB.Append(strValue);

                    // investigate the content if it contains anything stating that consent is required. 
                    try
                    {
                        JObject jobj = JObject.Parse(strValue);
                        foreach (var strItem in jobj)
                        {
                            Debug.WriteLine(strItem.Key);
                            Debug.WriteLine(strItem.Value);

                            JValue jv = strItem.Value as JValue;
                            if (jv != null)
                            {
                                string str = jv.Value as string;
                                if (str != null)
                                {
                                    if (str.Contains("has not consented to use the application") || (str.Contains("consent_required")))
                                    {
                                        Debug.WriteLine("We need to display the consent screen here");
                                        displayConsentScreen = true;
                                        bFound = true;
                                        break;
                                    }
                                }
                            }
                        }
                    }
                    catch { }
                }

                if (bFound)
                {
                    break;
                }
            }
            return sB.ToString(); 
        }

        private void clearCache(AuthenticationContext authContext)
        {
            var todoTokens = authContext.TokenCache.ReadItems().Where(a => a.Resource == AzureAdOptions.Settings.WebAPIResourceId);
            foreach (TokenCacheItem tci in todoTokens)
                authContext.TokenCache.DeleteItem(tci);
        }



        [AllowAnonymous]
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public ActionResult Error(string errorHeader, string errorDescription)
        {
            return View("Error",new ErrorViewModel
            {
                RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier,
                ErrorDescription = errorDescription,
                ErrorHeader = errorHeader
            });
        }

        private async Task<AuthenticationContextAndToken> GetTokenAndAuthenticationContext()
        {
            AuthenticationContextAndToken returnValue = new AuthenticationContextAndToken
            {
                ctx = null, token = null
            };
            // Because we signed-in already in the WebApp, the userObjectId is know
            string userObjectID = (User.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier"))?.Value;
            // Using ADAL.Net, get a bearer token to access the TodoListService
            returnValue.ctx = new AuthenticationContext(AzureAdOptions.Settings.Authority, new NaiveSessionCache(userObjectID, HttpContext.Session));
            ClientCredential credential = new ClientCredential(AzureAdOptions.Settings.ClientId, AzureAdOptions.Settings.ClientSecret);
            returnValue.token = await returnValue.ctx.AcquireTokenSilentAsync(AzureAdOptions.Settings.WebAPIResourceId, credential, new UserIdentifier(userObjectID, UserIdentifierType.UniqueId));
            return returnValue;
           
        }
    }
}