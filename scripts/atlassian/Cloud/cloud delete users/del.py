import sys, argparse
import browser_cookie3
import requests
cookies = browser_cookie3.chrome()
parser = argparse.ArgumentParser(description='Bulk remove Atlassian accounts')
parser.add_argument('aaid_file', type=str, help='File of Atlassian account IDs, one on each line')
args = parser.parse_args()
try:
        with open(args.aaid_file, 'r') as fp:
            for line in iter(fp.readline, ''):
                url = 'https://admin.atlassian.com/gateway/api/adminhub/um/site/6jdk33a5-8622-143d-kd2k-ba4d5959cb36/users/{}'.format(line.strip())
                    print('removing user {}'.format(line))
                    response = requests.delete(url, cookies = cookies)
                    print(response)
except EnvironmentError: # parent of IOError, OSError *and* WindowsError where available
print('Error opening input file; does it exist or corrupted?')
print('')