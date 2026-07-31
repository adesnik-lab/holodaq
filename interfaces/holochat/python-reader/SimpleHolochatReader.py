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


def _size_count(mwsize):
    """Number of elements an mwsize describes. 1 when it cannot be read."""
    if not isinstance(mwsize, (list, tuple)) or not mwsize:
        return 1
    total = 1
    for dim in mwsize:
        try:
            total *= int(dim)
        except (TypeError, ValueError):
            return 1
    return max(0, total)


def _decode_node(node):
    """One mps 'large' node -> a Python value. Recursive, and never raises.

    Shapes, per the MATLAB Production Server 'large' encoding:
      struct : {'mwtype':'struct', 'mwsize':[1,N],
                'mwdata': {field: [elem_1, ..., elem_N]}}
               -- N is the STRUCT ARRAY length, and every field carries one
               encoded value per element. A 1x1 struct decodes to a dict; a 1xN
               struct array to a list of N dicts.
      cell   : {'mwtype':'cell', 'mwdata': [node, ...]}
      char   : {'mwtype':'char', 'mwdata': 'text'}
      numeric/logical : {'mwtype':'double'|..., 'mwdata': [values]}

    Anything unrecognised is returned as-is rather than raising: this runs inside
    the primer's poll loop, where an exception costs every subsequent prime.
    """
    if not isinstance(node, dict) or 'mwtype' not in node:
        return node

    kind = node.get('mwtype')
    data = node.get('mwdata')

    if kind == 'struct':
        if not isinstance(data, dict):
            return data
        # Element count comes from the field lists where possible -- a malformed
        # mwsize should not lose fields. mwsize is the tiebreaker only when there
        # are no list-valued fields to count, which is how a struct array with no
        # fields at all still reports as empty rather than as one blank element.
        counts = [len(v) for v in data.values() if isinstance(v, list)]
        if counts:
            n = max(counts)
        else:
            n = _size_count(node.get('mwsize'))
        elements = []
        for i in range(n):
            element = {}
            for key, value in data.items():
                if isinstance(value, list):
                    element[key] = _decode_node(value[i]) if i < len(value) else None
                else:
                    element[key] = _decode_node(value)
            elements.append(element)
        if n == 1:
            return elements[0]
        return elements          # 0 elements -> [], N>1 -> list of dicts

    if kind == 'cell':
        if isinstance(data, list):
            return [_decode_node(item) for item in data]
        return data

    # char / double / single / logical / intN: mwdata is already a plain value.
    return data


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
        """Decode MATLAB Production Server 'large' typed JSON.

        Was one level deep: it took v[0]['mwdata'][:] per field, so a field whose
        value was itself a struct hit dict[:] and raised
        "TypeError: unhashable type: 'slice'" -- which killed the whole read, not
        just that field. prime_info sends the opto channel table as a struct
        ARRAY, so the moment a rig had opto channels the PTB primer could not
        decode any prime at all and simply stopped launching stim scripts.

        Flat fields decode exactly as before -- char to str, numeric to a
        1-element list -- so every existing consumer is unaffected. Nested
        structs now become dicts, and struct arrays lists of dicts, instead of
        raising.
        """
        return _decode_node(recv)

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