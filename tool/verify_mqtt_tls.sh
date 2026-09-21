#!/usr/bin/env bash
set -euo pipefail

# The CA, credentials and broker exist only for this test invocation. The Dart
# test adds the CA to its own isolate's SecurityContext, never to the OS store.
resolve_tool() {
  local override="$1" name="$2" fallback="$3"
  if [ -n "$override" ]; then
    command -v "$override" || {
      echo "Cannot execute configured $name: $override" >&2
      return 1
    }
  elif command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
  elif [ -x "$fallback" ]; then
    printf '%s\n' "$fallback"
  else
    echo "Missing $name; install it or configure its executable override." >&2
    return 1
  fi
}

openssl_bin="$(resolve_tool "${OPENSSL_BIN:-}" openssl /opt/homebrew/bin/openssl)"
mosquitto_bin="$(resolve_tool "${MOSQUITTO_BIN:-}" mosquitto /opt/homebrew/sbin/mosquitto)"
passwd_bin="$(resolve_tool "${MOSQUITTO_PASSWD_BIN:-}" mosquitto_passwd /opt/homebrew/bin/mosquitto_passwd)"
pub_bin="$(resolve_tool "${MOSQUITTO_PUB_BIN:-}" mosquitto_pub /opt/homebrew/bin/mosquitto_pub)"
python_bin="$(resolve_tool "${PYTHON_BIN:-}" python3 /opt/homebrew/bin/python3)"
flutter_bin="$(resolve_tool "${FLUTTER_BIN:-}" flutter '')"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
port="${MQTT_TLS_TEST_PORT:-28885}"
port="$("$python_bin" - "$port" <<'PY'
import sys
port = int(sys.argv[1])
if not 1024 <= port <= 65535:
    raise SystemExit('MQTT_TLS_TEST_PORT must be between 1024 and 65535')
print(port)
PY
)"

umask 077
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/owntrack-mqtt-tls.XXXXXX")"
broker_pid=""
runner_pid=""
cleanup() {
  result=$?
  trap - EXIT INT TERM
  if [ -n "$runner_pid" ]; then
    kill -TERM "$runner_pid" 2>/dev/null || true
    wait "$runner_pid" 2>/dev/null || true
  fi
  if [ -n "$broker_pid" ]; then
    kill "$broker_pid" 2>/dev/null || true
    wait "$broker_pid" 2>/dev/null || true
  fi
  if [ "$result" -ne 0 ]; then
    for log in "$fixture_dir/certificates.log" "$fixture_dir/broker.log"; do
      if [ -f "$log" ]; then
        cat "$log" >&2
      fi
    done
  fi
  rm -rf "$fixture_dir"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

cat > "$fixture_dir/ca.cnf" <<'CONFIG'
[req]
distinguished_name = subject
[subject]
[ca_extensions]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
CONFIG
"$openssl_bin" req -x509 -newkey rsa:2048 -nodes -sha256 -days 1 \
  -subj '/CN=OwnTrack isolated test CA' -config "$fixture_dir/ca.cnf" \
  -extensions ca_extensions -keyout "$fixture_dir/ca.key" \
  -out "$fixture_dir/ca.crt" > "$fixture_dir/certificates.log" 2>&1
"$openssl_bin" req -new -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=localhost' -keyout "$fixture_dir/server.key" \
  -out "$fixture_dir/server.csr" >> "$fixture_dir/certificates.log" 2>&1
cat > "$fixture_dir/server.ext" <<'CONFIG'
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:localhost
CONFIG
"$openssl_bin" x509 -req -sha256 -days 1 -in "$fixture_dir/server.csr" \
  -CA "$fixture_dir/ca.crt" -CAkey "$fixture_dir/ca.key" -CAcreateserial \
  -extfile "$fixture_dir/server.ext" -out "$fixture_dir/server.crt" \
  >> "$fixture_dir/certificates.log" 2>&1

test_user='owntrack-native-tls'
test_password="$("$openssl_bin" rand -hex 24)"
"$passwd_bin" -b -c "$fixture_dir/passwords" "$test_user" "$test_password"
cat > "$fixture_dir/mosquitto.conf" <<CONFIG
listener $port 127.0.0.1
protocol mqtt
allow_anonymous false
password_file $fixture_dir/passwords
cafile $fixture_dir/ca.crt
certfile $fixture_dir/server.crt
keyfile $fixture_dir/server.key
require_certificate false
persistence false
CONFIG

"$python_bin" - "$fixture_dir" "$port" "$test_user" "$test_password" <<'PY'
import json
import pathlib
import socket
import sys
directory, port, username, password = sys.argv[1:]
with socket.socket() as probe:
    probe.bind(('127.0.0.1', int(port)))
pathlib.Path(directory, 'defines.json').write_text(json.dumps({
    'MQTT_TLS_TEST_PORT': int(port),
    'MQTT_TLS_TEST_CA_FILE': str(pathlib.Path(directory, 'ca.crt')),
    'MQTT_TLS_TEST_SERVER_CERT_FILE': str(pathlib.Path(directory, 'server.crt')),
    'MQTT_TLS_TEST_SERVER_KEY_FILE': str(pathlib.Path(directory, 'server.key')),
    'MQTT_TLS_TEST_USERNAME': username,
    'MQTT_TLS_TEST_PASSWORD': password,
}))
PY

"$mosquitto_bin" -c "$fixture_dir/mosquitto.conf" > "$fixture_dir/broker.log" 2>&1 &
broker_pid=$!
"$python_bin" - "$broker_pid" "$pub_bin" "$fixture_dir/defines.json" <<'PY'
import json
import os
import pathlib
import subprocess
import sys
import time
pid, executable, definitions = sys.argv[1:]
config = json.loads(pathlib.Path(definitions).read_text())
command = [
    executable, '-h', 'localhost', '-p', str(config['MQTT_TLS_TEST_PORT']),
    '--cafile', config['MQTT_TLS_TEST_CA_FILE'],
    '-u', config['MQTT_TLS_TEST_USERNAME'], '-P', config['MQTT_TLS_TEST_PASSWORD'],
    '-q', '1', '-t', 'owntracks/integration/tls-readiness', '-n',
]
deadline = time.monotonic() + 15
while time.monotonic() < deadline:
    os.kill(int(pid), 0)
    try:
        result = subprocess.run(command, capture_output=True, timeout=2)
        if result.returncode == 0:
            break
    except subprocess.TimeoutExpired:
        pass
    time.sleep(0.1)
else:
    raise SystemExit('Loopback TLS broker did not acknowledge its readiness probe')
PY

cd "$project_root"
# Bound compilation as well as test execution. The runner owns a fresh process
# group so interruption can terminate only this invocation's Flutter children.
"$python_bin" - "$flutter_bin" "$fixture_dir/defines.json" <<'PY' &
import os
import signal
import subprocess
import sys
import time

command = [sys.argv[1], 'test', '--reporter', 'expanded',
           '--dart-define-from-file=' + sys.argv[2],
           'test/integration/mqtt_tls_test.dart']
process = subprocess.Popen(command, start_new_session=True)

def live_group_members():
    # macOS can reject a group signal after its leader exits. Inspect only
    # identifiers/status, and never assume a permission error means it is empty.
    rows = subprocess.check_output(
        ['ps', '-axo', 'pid=,pgid=,stat='], text=True, timeout=3)
    return [int(pid) for pid, group, status in
            (row.split() for row in rows.splitlines() if row.strip())
            if int(group) == process.pid and not status.startswith('Z')]

def signal_group(signum):
    try:
        os.killpg(process.pid, signum)
    except ProcessLookupError:
        pass
    except PermissionError:
        for pid in live_group_members():
            try:
                if os.getpgid(pid) == process.pid:
                    os.kill(pid, signum)
            except (ProcessLookupError, PermissionError):
                pass
        # Cleanup below verifies that all live members actually exit. A denied
        # individual signal is not silently treated as successful cleanup.

def interrupted(signum, frame):
    raise SystemExit(128 + signum)

signal.signal(signal.SIGTERM, interrupted)
try:
    result = process.wait(timeout=420)
except subprocess.TimeoutExpired:
    print('Native TLS verification exceeded its 420 second bound.', file=sys.stderr)
    result = 124
except KeyboardInterrupt:
    result = 130
finally:
    signal_group(signal.SIGTERM)
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        pass
    signal_group(signal.SIGKILL)
    process.wait(timeout=3)
    deadline = time.monotonic() + 3
    while members := live_group_members():
        if time.monotonic() >= deadline:
            raise RuntimeError(f'Runner cleanup left live process group members: {members}')
        time.sleep(0.05)
sys.exit(result)
PY
runner_pid=$!
set +e
wait "$runner_pid"
result=$?
set -e
runner_pid=""
exit "$result"
