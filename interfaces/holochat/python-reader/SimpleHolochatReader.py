import os
import requests
import json
import time

# Scope2K's broker. Only used when neither the caller nor the environment says
# otherwise -- see holochat_server() on the MATLAB side for why the environment
# is authoritative for this one value (it is the bootstrap: you need the broker
# URL before you can read any published config from it).
DEFAULT_URL = 'http://136.152.58.120:8000'


def default_url():
    """Broker URL for this machine: $HOLOCHAT_SERVER, else the Scope2K default.

    One `export HOLOCHAT_SERVER=http://host:8000` covers every Python entry point
    on the box (this reader, ptb_primer, psychopy_defaults) and matches what the
    MATLAB side resolves, so a lab points all four machines at their own broker
    without editing code.
    """
    return os.environ.get('HOLOCHAT_SERVER', '').strip() or DEFAULT_URL


class SimpleReader:
    def __init__(self, name, url=None, reset=True):
        self.name = name
        # url=None (the default) resolves from the environment. Callers that pass
        # an explicit url still win, so nothing that already passes one changes.
        self.url = url or default_url()

        # delete and clear up stuff. reset=False for read-only consumers (e.g.
        # the PTB primer) that must NOT wipe config the DAQ already posted.
        if reset:
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
                output[k] = v[0]['mwdata'][:]
        else:
            output = recv['mwdata']
        return output

    def read_config(self, topic=None):
        """Read a persistent `config` topic (default: this box's own) with no
        consume-once gate. `topic='abort'` reads the shared abort signal.

        Returns a dict (or None if unset). Handles both MATLAB Production
        Server "large" typed JSON (mwtype/mwdata, from the DAQ) and plain JSON.
        """
        if topic is None:
            topic = self.name
        response = requests.get(f'{self.url}/config/{topic}')
        if response.status_code == 404:
            return None
        raw = response.json().get('message')
        if raw is None:
            return None
        try:
            msg = json.loads(raw)
        except (TypeError, ValueError):
            return None
        if isinstance(msg, dict) and 'mwtype' in msg:
            return self.decode(msg)
        return msg

    def set_config(self, data, target=None):
        """Post a plain-JSON payload to a `config` topic (default: self).

        Used for prime acks (config/<name>_status). The DAQ-side reader tolerates
        plain JSON, so we don't need to emit the MATLAB typed format here.
        """
        if target is None:
            target = self.name
        payload = {'sender': self.name, 'message': json.dumps(data)}
        requests.post(f'{self.url}/config/{target}', json=payload)

    def flush(self):
        requests.delete(f'{self.url}/msg/{self.name}')