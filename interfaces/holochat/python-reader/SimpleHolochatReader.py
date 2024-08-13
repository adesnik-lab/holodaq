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
        if recv is not None:
            return self.decode(recv)

    def scan(self):
        response = requests.get(f'{self.url}/msg/{self.name}')
        if (response.status_code == 404) or (response.json()['message_status'] == 'read'):
            return None
        else:
            return json.loads(response.json()['message'])

    def decode(self, recv):
        if recv['mwtype'] == 'struct':
            # now we need to turn this into a dict...
            output = dict()
            tmp = recv['mwdata']
            for k, v in tmp.items():
                output[k] = v[0]['mwdata']
        else:
            output = recv['mwdata']
        return output

    
    def flush(self):
        requests.delete(f'{self.url}/msg/{self.name}')