using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using MVCSecureApp.Models;
using MVCSecureApp.Utils;
using MVCSecureApp.WebAPI;

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
                        return CheckAuthenticationNoTaskError(rv.httpCode, ctx_token.ctx);
                    }
                }
                else
                {
                    return ErrorViewTask(UnableToAcquireToken);
                }
            }
            catch
            {
                return ErrorCatchHandler(true);
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
                        return CheckAuthenticationNoTaskError(rv.httpCode, ctx_token.ctx);
                    }
                }
                else
                {
                    return ErrorViewTask(UnableToAcquireToken);
                }
            }
            catch
            {
                return ErrorCatchHandler();
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
                        return CheckAuthenticationNoTaskError(rv.httpCode, ctx_token.ctx);
                    }
                }
                else
                {
                    return ErrorViewTask(UnableToAcquireToken);
                }
            }
            catch
            {
                return ErrorCatchHandler();
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
                    catch { }

                    ObjTaskAndHttpStatusCode rv = await _WebApiController.Edit(task, ctx_token.token);
                    if (rv.passedTask != null)
                    {
                        return RedirectToAction(nameof(Index));
                    }
                    else
                    {
                        return CheckAuthenticationNoTaskError(rv.httpCode, ctx_token.ctx);
                    }
                }
                else
                {
                    return ErrorViewTask(UnableToAcquireToken);
                }
            }
            catch
            {
                return ErrorCatchHandler();
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
                        return CheckAuthenticationNoTaskError(rv.httpCode, ctx_token.ctx);
                    }
                }
                else
                {
                    return ErrorViewTask(UnableToAcquireToken);
                }
            }
            catch
            {
                return ErrorCatchHandler();
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
                    return CheckAuthenticationNoTaskError(rv.httpCode, ctx_token.ctx);
                }
            }
            else
            {
                return ErrorViewTask(UnableToAcquireToken);
            }
        }

        private ViewResult ErrorViewTask(string errorMessage, string ViewBagErrorMessage = ErrorViewModel.ErrorUnexpectedError)
        {
            Models.Task task = new Models.Task();
            task.Description = errorMessage;
            task.Title = "Error ! " + errorMessage;
            ViewBag.ErrorMessage = ViewBagErrorMessage;
            return View(task);
        }

        private ActionResult CheckAuthenticationNoTaskError(System.Net.HttpStatusCode statusCode, AuthenticationContext authContext)
        {
            if (statusCode == System.Net.HttpStatusCode.Unauthorized)
            {
                // clear cache. 
                var todoTokens = authContext.TokenCache.ReadItems().Where(a => a.Resource == AzureAdOptions.Settings.WebAPIResourceId);
                foreach (TokenCacheItem tci in todoTokens)
                    authContext.TokenCache.DeleteItem(tci);

                return RedirectToAction("AccessDenied", "Account");
            }
            else
            {
                return ErrorViewTask(NoTaskReturned);
            }
        }

        private ActionResult ErrorViewTaskList(string errorMessage, string ViewBagErrorMessage = ErrorViewModel.ErrorUnexpectedError)
        {
            List<Models.Task> tempList = new List<Models.Task>();
            Models.Task task = new Models.Task();
            task.Description = errorMessage;
            task.Title = "Error ! " + errorMessage;
            tempList.Add(task);
            ViewBag.ErrorMessage = ViewBagErrorMessage;
            return View(tempList);
        }

        private ActionResult ErrorCatchHandler(bool bList = false)
        {
            if (HttpContext.Request.Query["reauth"] == "True")
            {
                return new ChallengeResult(OpenIdConnectDefaults.AuthenticationScheme);
            }
            if (bList)
            { return ErrorViewTaskList("(Sign-in required to view to do list.)", ErrorViewModel.ErrorAuthorizationRequired); }
            else
            { return ErrorViewTask("(Sign-in required to view to do list.)", ErrorViewModel.ErrorAuthorizationRequired); }
            
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