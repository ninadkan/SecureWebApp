using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace MVCSecureApp.Controllers
{
    [Authorize]
    public class JScriptController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }
    }
}