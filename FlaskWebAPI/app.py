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

app = Flask(__name__)


app.config['Instance'] = appSecrets.InstanceName
app.config['Domain'] = appSecrets.DomainName
app.config['TenantId'] = appSecrets.TenantId
app.config['ClientId'] = appSecrets.ClientId

CORS(app)
jwtValidator = validateJWT.validateJWT(app)

# Make the WSGI interface available at the top level so wfastcgi can get it.
wsgi_app = app.wsgi_app



@app.errorhandler(401)
def custom_401(error):
    return Response('Unauthorized', 401, {'Content-Type': 'text/html', 'WWW-Authenticate':'Basic realm="Login Required"'})

@app.route('/')
def hello():
    """Renders a sample page."""
    return "Hello World!"

tasks = [
     {
         'id': 1,
         'title': u'House Clean',
         'description': u'Garage, Lounge, Porch, Bathroooms', 
         'done': False
     },
     {
         'id': 2,
         'title': u'Exercise',
         'description': u'Threadmill or Walk or weights', 
         'done': False
     },
     {
         'id': 3,
         'title': u'Write up Blog',
         'description': u'Three entries till end of April', 
         'done': False
     }
 ]

@app.route('/todo/api/v1.0/tasks', methods=['GET'])
def get_tasks():
    global jwtValidator
    if not(jwtValidator.validate_request(request)):
        abort(401)
    global tasks
    
    return jsonify({'tasks': [task for task in tasks]})

@app.route('/todo/api/v1.0/tasks/<int:task_id>', methods=['GET'])
def get_task(task_id):
    global jwtValidator
    if not(jwtValidator.validate_request(request)):
        abort(401)
    global tasks
    task = [task for task in tasks if task['id'] == task_id]
    if len(task) == 0:
        abort(404)
    return jsonify({'task': task[0]})
    
@app.errorhandler(404)
def not_found(error):
     return make_response(jsonify({'error': 'Not found'}), 404)

@app.route('/todo/api/v1.0/tasks', methods=['POST'])
def create_task():
    global jwtValidator
    if not(jwtValidator.validate_request(request)):
        abort(401)

    if not request.json or not 'title' in request.json:
        abort(400)

    global tasks
    if len(tasks) == 0:
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
    return jsonify({'task': task}), 201

@app.route('/todo/api/v1.0/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    global jwtValidator
    if not(jwtValidator.validate_request(request)):
        abort(401)
    global tasks
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
    return jsonify({'task': task[0]})

@app.route('/todo/api/v1.0/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    global jwtValidator
    if not(jwtValidator.validate_request(request)):
        abort(401)
    global tasks
    task = [task for task in tasks if task['id'] == task_id]
    if len(task) == 0:
        abort(404)
    tasks.remove(task[0])
    return jsonify({'result': True})



if __name__ == '__main__':
    import os
    HOST = os.environ.get('SERVER_HOST', 'localhost')
    try:
        PORT = int(os.environ.get('SERVER_PORT', '5555'))
    except ValueError:
        PORT = 5555
    app.run(HOST, PORT)