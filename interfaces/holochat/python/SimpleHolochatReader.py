import requests
import json
import time

class SimpleReader:
    def __init__(self, name, url='http://136.152.58.120:8000'):
        self.name = name
        self.url = url

        # delete and clear up stuff
        requests.delete(f'{self.url}/db/{self.name}')
        self.flush()
    def read(self, timeout=2):
        t = time.time()
        recv = None
        while (recv is None) and (time.time() - t) < timeout:
            recv = self.scan()
        return self.decode(recv)

    def scan(self):
        response = requests.get(f'{self.url}/msg/{self.name}')
        if (response.status_code == 404) or (response.json()['message_status'] == 'read'):
            return None
        return json.loads(response.json()['message'])

    def decode(self, recv):
        return recv['mwdata'][0]
    
    def flush(self):
        requests.delete(f'{self.url}/msg/{self.name}')