"""
This script runs the application using a development server.
It contains the definition of routes and views for the application.
"""
from flask import Flask, jsonify, abort, make_response
from flask import url_for
from flask import request, Response
from flask_cors import CORS
import json
import validateJWT
import appSecrets
import storageBlobService
import securityImpl

app = Flask(__name__)

CORS(app)

securityObj = securityImpl.securityImpl()

# Make the WSGI interface available at the top level so wfastcgi can get it.
wsgi_app = app.wsgi_app

@app.errorhandler(401)
def custom_401(error):
    return Response('Unauthorized', 401, {'Content-Type': 'text/html', 'WWW-Authenticate':'Basic realm="Login Required"'})

@app.errorhandler(400)
def custom_400(error):
    return Response('Unauthorized', 400, {'Content-Type': 'text/html', 'WWW-Authenticate':'Basic realm="Consent Required"'})

@app.errorhandler(404)
def not_found(error):
     return make_response(jsonify({'error': 'Not found'}), 404)

@app.route('/')
def hello():
    """Renders a sample page."""
    return "Hello World!"


@app.route('/todo/api/v1.0/tasks', methods=['GET'])
def get_tasks():
    return coreValidationAndProcessing(request, get_tasksImpl)

@app.route('/todo/api/v1.0/tasks/<int:task_id>', methods=['GET'])
def get_task(task_id):
    return coreValidationAndProcessing(request, get_taskImpl, task_id)

@app.route('/todo/api/v1.0/tasks', methods=['POST'])
def create_task():
    return coreValidationAndProcessing(request, create_taskImpl)

@app.route('/todo/api/v1.0/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    return coreValidationAndProcessing(request, update_taskImpl, task_id)

@app.route('/todo/api/v1.0/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    return coreValidationAndProcessing(request, delete_taskImpl, task_id)

def coreValidationAndProcessing(request, funcInvoke, task_id=None):
    global securityObj
    bRV, re = securityObj.validateRequest(request)
    if (bRV):
        tasks, storageBlobWrapper = readContentIntoTasks()
        if (task_id):
            return funcInvoke(task_id, tasks, storageBlobWrapper,request)
        else:
            return funcInvoke(tasks, storageBlobWrapper,request)
    else:
        return constructResponseObject(re)

def constructResponseObject(responsePassed):
    """
    constructs an Error response object, even if the 
    """
    if (not (responsePassed is None)):
        temp_resp = Response()
        temp_resp.status_code = responsePassed.status_code or 404
        if((temp_resp.status_code >= 200) and (temp_resp.status_code < 300)):
            temp_resp.status_code = 404
            temp_resp.reason = 'Bad Request'
            details = 'UnexpectedError'
            temp_resp.headers = {'Content-Type': 'text/html', 'Warning': details}
        else:
            temp_resp.reason = responsePassed.reason or 'Bad Request'
            details = responsePassed.content or 'UnexpectedError'
            temp_resp.headers = {'Content-Type': 'text/html', 'WWW-Authenticate': details}
    else:
        temp_resp = Response()
        temp_resp.reason = 'Bad Request'
        temp_resp.status_code = 404
        details = 'UnexpectedError'
        temp_resp.headers = {'Content-Type': 'text/html', 'WWW-Authenticate': details}

    return temp_resp


def readContentIntoTasks():
    global securityObj
    storageBlobWrapper = securityObj.get_StorageObject()
    content = storageBlobWrapper.get_blob_content()
    tasks = None
    if (content and len(content)>0):
        tasks = json.loads(content)
    return tasks, storageBlobWrapper

def get_tasksImpl(tasks, storageBlobWrapper, request):
    return jsonify({'tasks': tasks})

def get_taskImpl(task_id, tasks, storageBlobWrapper, request):
    if (tasks == None or len(tasks) == 0):
        abort(404)
    task = [task for task in tasks if task['id'] == task_id]
    if len(task) == 0:
        abort(404)
    return jsonify({'task': task[0]})

def create_taskImpl(tasks, storageBlobWrapper, request):
    if not request.json or not 'title' in request.json:
        abort(400)

    if (tasks == None or len(tasks) == 0):
        tasks = list()
        task = {
            'id': 1,
            'title': request.json['title'],
            'description': request.json.get('description', ""),
            'done': False
        }
    else:
        task = {
            'id': tasks[-1]['id'] + 1,
            'title': request.json['title'],
            'description': request.json.get('description', ""),
            'done': False
        }
    tasks.append(task)
    storageBlobWrapper.update_blob_content(json.dumps(tasks))
    return jsonify({'task': task}), 201

def update_taskImpl(task_id, tasks, storageBlobWrapper, request):
    if (tasks == None or len(tasks) == 0):
        abort(404)

    task = [task for task in tasks if task['id'] == task_id]
    if len(task) == 0:
        abort(404)
    if not request.json:
        abort(400)
    if 'title' not in request.json :
        abort(400)
    if 'description' not in request.json:
        abort(400)
    if 'done' not in request.json:
        abort(400)

    task[0]['title'] = request.json.get('title', task[0]['title'])
    task[0]['description'] = request.json.get('description', task[0]['description'])
    task[0]['done'] = request.json.get('done', task[0]['done'])
    # save it back to storage
    for idx, item in enumerate(tasks):
        if (item['id'] == task_id):
            item['title'] = task[0]['title']
            item['description'] = task[0]['description']
            item['done'] = task[0]['done']
    storageBlobWrapper.update_blob_content(json.dumps(tasks))       
    return jsonify({'task': task[0]})

def delete_taskImpl(task_id, tasks, storageBlobWrapper, request):
    if (tasks == None or len(tasks) == 0):
        abort(404)

    task = [task for task in tasks if task['id'] == task_id]
    if len(task) == 0:
        abort(404)

    tasks.remove(task[0])
    storageBlobWrapper.update_blob_content(json.dumps(tasks))     
    return jsonify({'result': True})

if __name__ == '__main__':
    import os
    HOST = os.environ.get('SERVER_HOST', 'localhost')
    try:
        PORT = int(os.environ.get('SERVER_PORT', '5555'))
    except ValueError:
        PORT = 5555
    app.run(HOST, PORT)