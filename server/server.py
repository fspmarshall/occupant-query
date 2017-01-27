#!/usr/bin/env python3
from flask import Flask
from flask import request
from flask import Response
from flask import render_template
from flask_cors import cross_origin
import os.path as path
import src.psql as psql
import json


app = Flask(__name__)
app.debug = True

# Because its rude not to say hello.
@app.route('/')
def landing():
    return 'hello world'

# Primary data-logging route.
@app.route('/log_responses/<query>', methods = ['GET','POST'])
@cross_origin()
def log_responses(query):
    if request.method == 'POST':
        jdata = request.get_json(force=True)
        store_values(query,jdata)
        rsp = Response( response = json.dumps({"hello": "world"}),
                        mimetype = 'application/json',
                        status   = 200
                        )
        return rsp
    elif request.method == 'GET':
        data = get_deployment(query)
        rsp = Response(response=data, status=200,
                mimetype='application/json')
        return rsp

# Primary query-serving route.
@app.route('/queries/<query>', methods = ['GET'])
def queries(query):
    qfile = 'tmp/queries/{}.json'.format(query)
    if not path.isfile(qfile) or query == 'config':
        raise Exception('no query named {}.'.format(query))
    with open(qfile) as fp:
        seed = json.load(fp)
    return render_template('main.html',seed=seed)

# Storage function -- overwrite as appropriate.
def store_values(query,data):
    print('Values Recieved For {}'.format(query))
    print(json.dumps(data,indent=2))
    #with open('tmp/config/psql_config.json') as fp:
    #    config = json.load(fp)['psql']
    #psql.push(query,data,config['dbname'],config['tblname'])

# Placeholder deployment update function -- feature not yet implimented.
def get_deployment(deployment):
    return json.dumps({"test":"someTest"})
