import requests
from requests.auth import HTTPBasicAuth
import csv
import os
import json

username = input('Enter Username: ')
password = input('Enter API token: ')
basedir = os.path.abspath(os.path.dirname(__file__))
csv_file = os.path.join(basedir, 'userlist.csv')
cloud_url = input('Enter the cloud url: ')

auth = HTTPBasicAuth(username, password)
headers = {'Content-Type': 'application/json'}

with open(csv_file, 'r') as file:
    userlist = csv.DictReader(file, delimiter=',')

    for user in userlist:
        id = user['account_id']
        url = 'https://' + cloud_url + '/rest/api/3/user'
        print(url)
        print(id)

        query= {'accountId': id}

        response = requests.request("DELETE",url,params=query,auth=auth)
        print(response.text)

