"""Sample Roku's documented recent graphics FPS; never infer per-frame/input timing.

https://github.com/rokudev/dev-doc/blob/v2.0/docs/DEVELOPER/dev-tools/external-control-api.md
This is read-only. Establish the intended screen/workload separately; idle screens
need not redraw at60fps. Keep output private because screen/workload labels may
contain user data. Never overwrite previous measurements.
"""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import time
import xml.etree.ElementTree as ET
import requests

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--host', required=True)
parser.add_argument('--samples', type=int, default=30)
parser.add_argument('--interval', type=float, default=1)
parser.add_argument('--state', required=True)
parser.add_argument('--runtime', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
if args.samples < 2 or args.interval < .5:
    parser.error('Use at least2 samples and interval>=0.5seconds')
if args.output.exists():
    parser.error('Refusing to overwrite evidence')
runtime_hash = hashlib.sha256(args.runtime.read_bytes()).hexdigest()
base = 'http://' + args.host + ':8060'
def query(path):
    response = requests.get(base + path, timeout=5)
    response.raise_for_status()
    return ET.fromstring(response.text)
info = query('/query/device-info')
record = {
    'state': args.state,
    'runtime': str(args.runtime),
    'runtime_sha256': runtime_hash,
    'runtime_note': 'Caller identifies the installed package; this endpoint does not attest its hash.',
    'device': {key: info.findtext(key) for key in ('model-name', 'model-number', 'software-version', 'software-build')},
    'metric': 'recent rendered graphics FPS, separate from video FPS',
    'not_measured': ['individual frame times', 'input-to-visible-focus latency'],
    'samples': [],
    'complete': False,
}
args.output.parent.mkdir(parents=True, exist_ok=True)
# Reserve the artifact before sampling, then retain partial evidence on failure.
with args.output.open('x') as handle:
    json.dump(record, handle, indent=2)
start = time.monotonic()
try:
    for i in range(args.samples):
        time.sleep(max(0, start + i * args.interval - time.monotonic()))
        data = query('/query/graphics-frame-rate')
        if data.findtext('status') != 'OK':
            raise RuntimeError('Graphics FPS status: ' + str(data.findtext('status')))
        record['samples'].append({'elapsed_seconds': time.monotonic() - start,
                                  'fps': float(data.findtext('fps')),
                                  'device_timestamp': data.findtext('timestamp')})
    values = sorted(sample['fps'] for sample in record['samples'])
    record['statistics'] = {'min_recent_fps': values[0], 'p05_recent_fps': values[int((len(values)-1)*.05)],
                            'median_recent_fps': statistics.median(values), 'max_recent_fps': values[-1],
                            'unique_device_timestamps': len({sample['device_timestamp'] for sample in record['samples']})}
    record['complete'] = True
    print(json.dumps(record['statistics']))
finally:
    args.output.write_text(json.dumps(record, indent=2) + '\n')
