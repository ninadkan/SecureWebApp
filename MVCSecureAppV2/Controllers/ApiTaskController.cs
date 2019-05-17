using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.Identity.Client;
using Microsoft.Identity.Web.Client;
using MVCSecureAppV2.Infrastructure;
using MVCSecureAppV2.Models;
using MVCSecureAppV2.Services;

namespace MVCSecureAppV2.Controllers
{
    [Authorize]
    public class ApiTaskController : Controller
    {
        readonly ITokenAcquisition tokenAcquisition;
        readonly PythonWebAPIOptions webOptions;


        public ApiTaskController(ITokenAcquisition tokenAcquisition,
                              IOptions<PythonWebAPIOptions> webOptionValue)
        {
            this.tokenAcquisition = tokenAcquisition;
            this.webOptions = webOptionValue.Value;
        }




        [MsalUiRequiredExceptionFilter(Scopes = new[] { Constants.ScopeUserRead })]
        public async Task<IActionResult> Index()
        {
            //try
            //{
                PythonWebAPIClient client = GetPythonWebServiceClient(new[] { Constants.BearerAuthorizationScheme, Constants.ScopeUserImpersonation });
                ObjTaskListAndHttpStatusCode rv = await client.GetCollection();
                if (rv.passedTaskList != null)
                {
                    return View(rv.passedTaskList);
                }
                else
                {
                    return Error();
                }
            //}
            //catch (MsalUiRequiredException ex)
            //{
            //    // store a cookie for the user to understand that we need to prompt for new consent
            //    string userObjectID = User.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier").Value;
            //    CookieOptions option = new CookieOptions();
            //    option.Expires = DateTime.Now.AddMinutes(60);
            //    Response.Cookies.Append(ErrorViewModel.PromptConsentCookie, userObjectID, option);

            //    return View("Error", new ErrorViewModel
            //    {
            //        RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier,
            //        ErrorDescription = "Sign-out and Sign Back in",  //(ex.InnerException == null)?ex.InnerException.ToString():"",
            //        ErrorHeader = "Error" //ex.Message
            //    });
            //}
            //catch (Exception ex)
            //{
            //    Debug.WriteLine(ex.Message);
            //    return View("Error", new ErrorViewModel
            //    {
            //        RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier,
            //        ErrorDescription = (ex.InnerException == null) ? ex.InnerException.ToString():"",
            //        ErrorHeader = ex.Message
            //    });
            //}
        }


        private PythonWebAPIClient GetPythonWebServiceClient(string[] scopes)
        {
            return PythonWebAPIClientFactory.GetAuthenticatedPythonWebClient(async () =>
            {
                string result = await tokenAcquisition.GetAccessTokenOnBehalfOfUser(
                       HttpContext, scopes);
                return result;
            }, webOptions.PythonWebAPI_URL);
        }


        [AllowAnonymous]
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}