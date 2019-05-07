using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Mvc;
using MVCSecureApp.Utils;
using MVCSecureApp.Models;

namespace MVCSecureApp.Controllers
{
    [Route("[controller]/[action]")]
    public class AccountController : Controller
    {
        [HttpGet]
        public IActionResult SignIn()
        {
            var redirectUrl = Url.Action(nameof(HomeController.Index), "Home");

            var authenticationProperties = new AuthenticationProperties
            {
                RedirectUri = redirectUrl,
                AllowRefresh = true
            };

            string cookieValueFromContext = HttpContext.Request.Cookies[ErrorViewModel.PromptConsentCookie];

            //read cookie from Request object  
            if (!string.IsNullOrWhiteSpace(cookieValueFromContext))
            { 
                authenticationProperties.Items["prompt"] = "consent";
                // Remove the cookie such that the next time login does not ask for the consent once again
                HttpContext.Response.Cookies.Delete(ErrorViewModel.PromptConsentCookie);
            }
            
            return Challenge(
                authenticationProperties,
                OpenIdConnectDefaults.AuthenticationScheme);
        }

        [HttpGet]
        public IActionResult SignOut()
        {
            // Remove all cache entries for this user and send an OpenID Connect sign-out request.
            string userObjectID = User.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier").Value;
            var authContext = new Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext(AzureAdOptions.Settings.Authority,
                                                        new NaiveSessionCache(userObjectID, HttpContext.Session));
            authContext.TokenCache.Clear();

            // Let Azure AD sign-out
            var callbackUrl = Url.Action(nameof(SignedOut), "Account", values: null, protocol: Request.Scheme);
            return SignOut(
                new AuthenticationProperties { RedirectUri = callbackUrl, AllowRefresh = true },
                CookieAuthenticationDefaults.AuthenticationScheme,
                OpenIdConnectDefaults.AuthenticationScheme);
        }

        [HttpGet]
        public IActionResult SignedOut()
        {
            if (User.Identity.IsAuthenticated)
            {
                // Redirect to home page if the user is authenticated.
                return RedirectToAction(nameof(HomeController.Index), "Home");
            }

            return View();
        }

        [HttpGet]
        public IActionResult AccessDenied()
        {
            return View();
        }

    }
}