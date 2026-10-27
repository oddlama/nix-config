"""Generate Antirion v0.1.x virtual keys for agenix-rekey.

Format from crates/antirion-identity/src/keyfmt.rs: 12-character lowercase/digit
ID, 43-character base62 secret, then a 6-character base62 CRC-32/IEEE checksum.
The checksum is only a format check; secrecy comes from the OS-backed RNG.
"""

import secrets
import string
import zlib

BASE62 = string.digits + string.ascii_uppercase + string.ascii_lowercase


def checksum(body: str) -> str:
    value = zlib.crc32(body.encode("ascii"))
    result = ""
    for _ in range(6):
        result = BASE62[value % 62] + result
        value //= 62
    return result


def generate() -> str:
    kid = "".join(secrets.choice(string.ascii_lowercase + string.digits) for _ in range(12))
    secret = "".join(secrets.choice(BASE62) for _ in range(43))
    body = f"sk-antirion-{kid}-{secret}"
    return body + checksum(body)


if __name__ == "__main__":
    print(generate())
