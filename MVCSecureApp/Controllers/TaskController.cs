using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using MVCSecureApp.WebAPI;

namespace MVCSecureApp.Controllers
{
    public class TaskController : Controller
    {
        private TaskWebAPIWrapper _WebApiController;

        public TaskController(TaskWebAPIWrapper WebApiController)
        {
            _WebApiController = WebApiController;
        }
        // GET: Task
        public ActionResult Index()
        {
            return View(_WebApiController.GetCollection());
        }

        // GET: Task/Details/5
        public ActionResult Details(int id)
        {
            return View(_WebApiController.GetDetails(id));
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
                Models.Task task = new Models.Task();
                task.Description = collection["Description"];
                task.Title = collection["Title"];
                // Done is set to False at the start
                Models.Task newTask = await _WebApiController.CreateNew(task);
                if (newTask != null)
                {
                    return RedirectToAction(nameof(Index));
                }
                else
                {
                    return View();
                }
            }
            catch
            {
                return View();
            }
        }

        // GET: Task/Edit/5
        public ActionResult Edit(int id)
        {
            return BaseEdit(id);
        }

        // POST: Task/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<ActionResult> Edit(int id, IFormCollection collection)
        {
            try
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

                Models.Task newTask = await _WebApiController.Edit(task);
                if (newTask != null)
                {
                    return RedirectToAction(nameof(Index));
                }
                else
                {
                    return BaseEdit(id);
                }
            }
            catch
            {
                return BaseEdit(id);
            }
        }

        public ActionResult BaseEdit(int id)
        {
            return View(_WebApiController.GetDetails(id));
        }

        // GET: Task/Delete/5
        public ActionResult Delete(int id)
        {
            return BaseDelete(id);
        }

        // POST: Task/Delete/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<ActionResult> Delete(int id, IFormCollection collection)
        {
            try
            {
                bool rv = await _WebApiController.Delete(id);
                if (rv)
                {
                    return RedirectToAction(nameof(Index));
                }
                else
                {
                    return BaseDelete(id);
                }
            }
            catch
            {
                return BaseDelete(id);
            }
        }

        public ActionResult BaseDelete(int id)
        {
            return View(_WebApiController.GetDetails(id));
        }

    }
}