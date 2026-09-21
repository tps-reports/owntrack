#!/usr/bin/env bash
# Run the production browser MQTT adapter against a temporary authenticated
# loopback broker. Requires Mosquitto with WebSocket support, OpenSSL, Python 3,
# Flutter and Chrome. Configuration uses Mosquitto 2.0-compatible options.
# Optional executable overrides: MOSQUITTO_BIN, MOSQUITTO_PASSWD_BIN,
# OPENSSL_BIN, PYTHON_BIN, FLUTTER_BIN, CHROME_BIN.
set -euo pipefail
umask 077

if [[ $# -ne 0 ]]; then
  printf 'Usage: bash tool/verify_mqtt_wss.sh\n' >&2
  exit 64
fi

resolve_tool() {
  if command -v "$1" >/dev/null 2>&1; then
    command -v "$1"
  elif [[ -x "$2" ]]; then
    printf '%s\n' "$2"
  else
    printf 'Required executable not found: %s\n' "$1" >&2
    return 1
  fi
}

MOSQUITTO_BIN=${MOSQUITTO_BIN:-$(resolve_tool mosquitto /opt/homebrew/sbin/mosquitto)}
MOSQUITTO_PASSWD_BIN=${MOSQUITTO_PASSWD_BIN:-$(resolve_tool mosquitto_passwd /opt/homebrew/bin/mosquitto_passwd)}
OPENSSL_BIN=${OPENSSL_BIN:-$(resolve_tool openssl /opt/homebrew/bin/openssl)}
PYTHON_BIN=${PYTHON_BIN:-$(resolve_tool python3 /usr/bin/python3)}
FLUTTER_BIN=${FLUTTER_BIN:-$(resolve_tool flutter /opt/homebrew/bin/flutter)}
CHROME_BIN=${CHROME_BIN:-${CHROME_EXECUTABLE:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}}
if [[ ! -x "$CHROME_BIN" ]]; then
  CHROME_BIN=$(resolve_tool google-chrome /usr/bin/chromium)
fi

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d "${TMPDIR:-/tmp}/owntrack-wss.XXXXXX")
broker_pid=''
runner_pid=''

cleanup() {
  local result=$?
  trap - EXIT INT TERM
  if [[ -n "$runner_pid" ]]; then
    kill -TERM "$runner_pid" 2>/dev/null || true
    wait "$runner_pid" 2>/dev/null || true
  fi
  if [[ -n "$broker_pid" ]]; then
    kill -TERM "$broker_pid" 2>/dev/null || true
    wait "$broker_pid" 2>/dev/null || true
  fi
  rm -rf -- "$fixture_dir"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Refuse occupied fixture ports instead of touching an existing broker.
"$PYTHON_BIN" - <<'PY'
import socket
for port in (28886, 28887):
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', port))
PY

crypto() {
  if ! "$OPENSSL_BIN" "$@" >>"$fixture_dir/setup.log" 2>&1; then
    cat "$fixture_dir/setup.log" >&2
    return 1
  fi
}

crypto req -x509 -newkey rsa:2048 -nodes -days 1 \
  -subj '/CN=OwnTrack ephemeral WSS fixture CA' \
  -addext 'basicConstraints=critical,CA:TRUE' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign' \
  -keyout "$fixture_dir/ca.key" -out "$fixture_dir/ca.crt"
cat >"$fixture_dir/server.ext" <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=IP:127.0.0.1,DNS:localhost
EOF

serial=1
for name in trusted untrusted; do
  crypto req -new -newkey rsa:2048 -nodes -subj '/CN=localhost' \
    -keyout "$fixture_dir/$name.key" -out "$fixture_dir/$name.csr"
  crypto x509 -req -in "$fixture_dir/$name.csr" \
    -CA "$fixture_dir/ca.crt" -CAkey "$fixture_dir/ca.key" \
    -set_serial "$serial" -days 1 -extfile "$fixture_dir/server.ext" \
    -out "$fixture_dir/$name.crt"
  serial=$((serial + 1))
done

fixture_username=owntrack-wss-test
fixture_password=$("$OPENSSL_BIN" rand -hex 24)
"$MOSQUITTO_PASSWD_BIN" -b -c "$fixture_dir/passwords" \
  "$fixture_username" "$fixture_password"
cat >"$fixture_dir/acl" <<EOF
user $fixture_username
topic readwrite owntracks/wss-test/#
EOF
cat >"$fixture_dir/mosquitto.conf" <<EOF
persistence false
allow_anonymous false
password_file $fixture_dir/passwords
acl_file $fixture_dir/acl
log_dest stdout
log_type error
log_type warning
log_type notice
listener 28886 127.0.0.1
socket_domain ipv4
protocol websockets
certfile $fixture_dir/trusted.crt
keyfile $fixture_dir/trusted.key
listener 28887 127.0.0.1
socket_domain ipv4
protocol websockets
certfile $fixture_dir/untrusted.crt
keyfile $fixture_dir/untrusted.key
EOF
"$MOSQUITTO_BIN" -c "$fixture_dir/mosquitto.conf" >"$fixture_dir/broker.log" 2>&1 &
broker_pid=$!

# Validate both live endpoints with the fixture CA before the negative browser
# test. This prevents an unreachable listener from masquerading as TLS rejection.
if ! "$PYTHON_BIN" - "$fixture_dir/ca.crt" <<'PY'
import socket
import ssl
import sys
import time
context = ssl.create_default_context(cafile=sys.argv[1])
for port in (28886, 28887):
    deadline = time.monotonic() + 10
    while True:
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=2) as connection:
                with context.wrap_socket(connection, server_hostname='127.0.0.1'):
                    pass
            break
        except OSError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.1)
PY
then
  cat "$fixture_dir/broker.log" >&2
  exit 1
fi

fixture_spki=$("$OPENSSL_BIN" x509 -in "$fixture_dir/trusted.crt" -pubkey -noout |
  "$OPENSSL_BIN" pkey -pubin -outform DER |
  "$OPENSSL_BIN" dgst -sha256 -binary |
  "$OPENSSL_BIN" base64 -A)

# Chromium applies this exception only to a matching public key and only in a
# browser with --user-data-dir. Flutter supplies an isolated temporary profile.
# https://chromium.googlesource.com/chromium/src/+/main/services/network/public/cpp/network_switches.cc
cat >"$fixture_dir/chrome-wrapper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for argument in "$@"; do
  case "$argument" in
    --ignore-certificate-errors|--allow-insecure-localhost|--ignore-certificate-errors-spki-list=*)
      printf 'Unexpected broad or pre-existing certificate override.\n' >&2
      exit 64
      ;;
  esac
done
exec "$OWNTRACK_WSS_CHROME_REAL" \
  "--ignore-certificate-errors-spki-list=$OWNTRACK_WSS_SPKI" "$@"
EOF
chmod 700 "$fixture_dir/chrome-wrapper"

OWNTRACK_WSS_PASSWORD="$fixture_password" "$PYTHON_BIN" - "$fixture_dir/defines.json" <<'PY'
import json
import os
import sys
with open(sys.argv[1], 'w', encoding='utf-8') as destination:
    json.dump({
        'OWNTRACK_WSS_PORT': 28886,
        'OWNTRACK_WSS_UNTRUSTED_PORT': 28887,
        'OWNTRACK_WSS_USERNAME': 'owntrack-wss-test',
        'OWNTRACK_WSS_PASSWORD': os.environ['OWNTRACK_WSS_PASSWORD'],
    }, destination)
PY
unset fixture_password
printf 'WSS fixture ready: authenticated loopback 28886; unlisted certificate 28887.\n'
printf 'Ephemeral trusted leaf SPKI: %s\n' "$fixture_spki"
cd -- "$project_root"

# The bound also covers compilation/browser startup. Signal cleanup kills only
# the process group created here, then the shell removes the broker and fixtures.
CHROME_EXECUTABLE="$fixture_dir/chrome-wrapper" \
OWNTRACK_WSS_CHROME_REAL="$CHROME_BIN" OWNTRACK_WSS_SPKI="$fixture_spki" \
"$PYTHON_BIN" - "$FLUTTER_BIN" "$fixture_dir/defines.json" <<'PY' &
import os
import signal
import subprocess
import sys
import time

command = [sys.argv[1], 'test', '--platform', 'chrome', '--timeout', '45s',
           '--dart-define-from-file=' + sys.argv[2], 'test/browser/mqtt_wss_test.dart']
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
    print('WSS browser verification exceeded its 420 second bound.', file=sys.stderr)
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
runner_pid=''
if [[ $result -ne 0 ]]; then
  cat "$fixture_dir/broker.log" >&2
fi
exit "$result"
