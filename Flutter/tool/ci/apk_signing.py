"""Read a single verified APK signing identity from apksigner output."""
import re


def certificate_sha256(output):
    certificates = re.findall(r'^Signer (?:#\d+|\(minSdkVersion=[^\r\n]+\)) certificate SHA-256 digest: ([0-9a-fA-F]{64})\r?$', output, re.M)
    identities = {value.lower() for value in certificates}
    if len(identities) != 1:
        raise ValueError('Expected exactly one APK signing identity')
    return identities.pop()
