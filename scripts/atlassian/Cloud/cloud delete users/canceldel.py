import sys, argparse
import browser_cookie3
import requests

cookies = browser_cookie3.chrome()

parser = argparse.ArgumentParser(description='Bulk delete drafts')
parser.add_argument('aaid_file', type=str, help='Draft IDs, one on each line')

args = parser.parse_args()

try:
	  with open(args.aaid_file, 'r') as fp:
	    for line in iter(fp.readline, ''):
		    url = 'https://admin.atlassian.com/gateway/api/users/{}/cancel-deletion'.format(line.strip())
		    print('cancel deletion {}'.format(line))
		    response = requests.post(url, cookies = cookies)
		    print(response)
except EnvironmentError: # parent of IOError, OSError *and* WindowsError where available
    print('Error opening input file; does it exist or corrupted?')
    print('')
