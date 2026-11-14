#!/usr/bin/env python3
"""Device-rebind recovery rehearsal: proves a NEW device takes over only after
the email capability is redeemed, and the OLD device stops receiving JWTs.

Flow (matches the auth directive):
  1 register(phone, deviceA, email)            -> 202
  2 email-verify(phone, email)                 -> 202, capability in the sink
  3 otp/confirm(capability, deviceA)           -> 200  (deviceA bound)
  4 device-login(phone, deviceA)               -> 200
  5 device-login(phone, deviceB)               -> 202  REQUIRE_EMAIL_VERIFICATION
  6 email-verify                               -> 202, second capability
  7 otp/confirm(capability, deviceB)           -> 200  (deviceB now bound)
  8 device-login(phone, deviceB)               -> 200  rebind effective
  9 device-login(phone, deviceA)               -> 202  old device revoked
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = os.environ.get("NEXUS_E2E_API", "http://127.0.0.1:18085")
SINK = os.environ["NEXUS_E2E_MAIL"]
PHONE = os.environ.get("NEXUS_E2E_PHONE", "+959123456789")
EMAIL = os.environ.get("NEXUS_E2E_EMAIL", "recovery@nexus.local")
DEVICE_A = "DEVICEA_0123456789abcd"
DEVICE_B = "DEVICEB_0123456789abcd"

results = []


def call(path, body):
    req = urllib.request.Request(
        BASE + path, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def check(label, want, got, extra=""):
    ok = want == got
    results.append(ok)
    print(f"{'PASS' if ok else 'FAIL'}  {label}: want {want}, got {got} {extra}".rstrip())


def capability(count):
    """Return the (count)th capability written to the mail sink."""
    deadline = time.time() + 10
    while time.time() < deadline:
        if os.path.exists(SINK):
            codes = [ln.split("code=")[1].split()[0]
                     for ln in open(SINK) if "code=" in ln]
            if len(codes) >= count:
                return codes[count - 1]
        time.sleep(0.1)
    raise SystemExit("no verification mail reached the sink")


st, body = call("/api/v1/auth/register",
                {"phone_number": PHONE, "device_id": DEVICE_A, "email": EMAIL})
check("1 register", 202, st, body.get("action", ""))
check("1 register action", "REQUIRE_EMAIL_VERIFICATION", body.get("action"))

st, _ = call("/api/v1/auth/email-verify",
             {"phone_number": PHONE, "email": EMAIL})
check("2 email-verify", 202, st)

st, body = call("/api/v1/auth/otp/confirm",
                {"otp": capability(1), "device_id": DEVICE_A})
check("3 confirm on deviceA", 200, st)
check("3 confirm returns jwt", True, bool(body.get("jwt")))

st, _ = call("/api/v1/auth/device-login",
             {"phone_number": PHONE, "device_id": DEVICE_A})
check("4 deviceA login", 200, st)

st, body = call("/api/v1/auth/device-login",
                {"phone_number": PHONE, "device_id": DEVICE_B})
check("5 deviceB login (unknown)", 202, st, body.get("action", ""))

st, _ = call("/api/v1/auth/email-verify",
             {"phone_number": PHONE, "email": EMAIL})
check("6 email-verify (recovery)", 202, st)

st, _ = call("/api/v1/auth/otp/confirm",
             {"otp": capability(2), "device_id": DEVICE_B})
check("7 confirm on deviceB", 200, st)

st, _ = call("/api/v1/auth/device-login",
             {"phone_number": PHONE, "device_id": DEVICE_B})
check("8 deviceB login after rebind", 200, st)

st, _ = call("/api/v1/auth/device-login",
             {"phone_number": PHONE, "device_id": DEVICE_A})
check("9 deviceA login (revoked)", 202, st)

print(f"\n{sum(results)}/{len(results)} assertions passed")
sys.exit(0 if all(results) else 1)
