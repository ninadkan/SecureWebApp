"""
This script runs the application using a development server.
It contains the definition of routes and views for the application.
"""
from flask import Flask, jsonify, abort, make_response
from flask import url_for
from flask import request, Response
from flask_cors import CORS
import json
#import jwtValidate
import validateJWT
import appSecrets
import storageBlobService 

app = Flask(__name__)


app.config['Instance'] = appSecrets.InstanceName
app.config['Domain'] = appSecrets.DomainName
app.config['TenantId'] = appSecrets.TenantId
app.config['ClientId'] = appSecrets.ClientId
app.config['account_name'] = appSecrets.AccountName
app.config['account_key'] = appSecrets.AccountKey
app.config['sas_token'] = appSecrets.SAS_Token

CORS(app)
jwtValidator = validateJWT.validateJWT(app)
storageBlobWrapper = storageBlobService.StorageBlobServiceWrapper(app)

# Make the WSGI interface available at the top level so wfastcgi can get it.
wsgi_app = app.wsgi_app

@app.errorhandler(401)
def custom_401(error):
    return Response('Unauthorized', 401, {'Content-Type': 'text/html', 'WWW-Authenticate':'Basic realm="Login Required"'})

@app.errorhandler(404)
def not_found(error):
     return make_response(jsonify({'error': 'Not found'}), 404)

@app.route('/')
def hello():
    """Renders a sample page."""
    return "Hello World!"


def readContentIntoTasks():
    global storageBlobWrapper
    content = storageBlobWrapper.get_blob_content()
    tasks = None
    if (content and len(content)>0):
        tasks = json.loads(content)
    return tasks

@app.route('/todo/api/v1.0/tasks', methods=['GET'])
def get_tasks():
    global jwtValidator
    if not(jwtValidator.validate_request(request)):
        abort(401)
    tasks = readContentIntoTasks()
    return jsonify({'tasks': tasks})

@app.route('/todo/api/v1.0/tasks/<int:task_id>', methods=['GET'])
def get_task(task_id):
    global jwtValidator
    if not(jwtValidator.validate_request(request)):
        abort(401)

    tasks = readContentIntoTasks()
    if (tasks == None or len(tasks) == 0):
        abort(404)

    task = [task for task in tasks if task['id'] == task_id]
    if len(task) == 0:
        abort(404)
    return jsonify({'task': task[0]})


@app.route('/todo/api/v1.0/tasks', methods=['POST'])
def create_task():
    global jwtValidator
    if not(jwtValidator.validate_request(request)):
        abort(401)

    if not request.json or not 'title' in request.json:
        abort(400)

    tasks = readContentIntoTasks()

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

@app.route('/todo/api/v1.0/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    global jwtValidator
    if not(jwtValidator.validate_request(request)):
        abort(401)

    tasks = readContentIntoTasks()

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

@app.route('/todo/api/v1.0/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    global jwtValidator
    if not(jwtValidator.validate_request(request)):
        abort(401)

    tasks = readContentIntoTasks()
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