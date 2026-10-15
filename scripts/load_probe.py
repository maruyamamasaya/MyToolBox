#!/usr/bin/env python3
"""Opt-in short local CPU/GPU/loopback diagnostics; no remote traffic or system changes."""
from pathlib import Path
import json
import subprocess
import sys
import time
import threading
import socket
ROOT = Path(__file__).resolve().parent.parent
mode = sys.argv[1] if len(sys.argv) > 1 else 'cpu'
if mode not in ['cpu','gpu','loopback']: raise SystemExit('cpu | gpu | loopback')
workers = []
probe = subprocess.Popen([str(ROOT / '.build/debug/monitor-probe'), '13', 'lo0' if mode == 'loopback' else 'auto'], stdout=subprocess.PIPE, text=True)
rows = []
def transfer():
    with socket.socket() as server:
        server.bind(('127.0.0.1',0)); server.listen(1)
        def receive():
            conn,_ = server.accept()
            with conn:
                while conn.recv(65536): pass
        reader = threading.Thread(target=receive); reader.start()
        with socket.create_connection(server.getsockname()) as client:
            for _ in range(80): client.sendall(b'x' * 65536); time.sleep(0.05)
        reader.join()
try:
    for i,line in enumerate(probe.stdout):
        row = json.loads(line); rows.append(row)
        if i == 3:
            if mode == 'cpu':
                code = 'import time\nend=time.monotonic()+5\nx=0\nwhile time.monotonic()<end: x=(x+1)%1000000'
                workers = [subprocess.Popen([sys.executable,'-c',code]) for _ in range(4)]
            elif mode == 'gpu': workers = [subprocess.Popen([str(ROOT / 'build/gpu-load')])]
            else:
                transfer_thread = threading.Thread(target=transfer); transfer_thread.start()
    if probe.wait(): raise RuntimeError('probe failed')
    for worker in workers:
        if worker.wait(): raise RuntimeError('workload failed')
    if mode == 'loopback': transfer_thread.join()
finally:
    for worker in workers:
        if worker.poll() is None: worker.terminate()
    if probe.poll() is None: probe.terminate()
path = ROOT / f'evidence/load-{mode}.jsonl'
path.write_text(''.join(json.dumps(r, ensure_ascii=False)+'\n' for r in rows))
section,key = ('network','受信速度') if mode == 'loopback' else (mode,'使用率')
values = [next(r for r in row['readings'] if r['id']==section)['metrics'][key].get('value') for row in rows]
print(mode, values)
print('Evidence:',path)
