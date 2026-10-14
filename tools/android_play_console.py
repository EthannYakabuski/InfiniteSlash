"""Control only the isolated InfiniteSlash_PGS emulator console.

Allows screenshots and local test key events before guest ADB is authorized.
The console token is consumed in memory and is never logged or exported.
"""
import argparse
import socket
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", nargs="+")
    args = parser.parse_args()
    command = " ".join(args.command)
    if not (command.startswith("screenrecord screenshot ") or command.startswith("event send ")):
        parser.error("Only a screenshot or test key event is permitted.")
    if command.startswith("screenrecord screenshot "):
        destination = Path(command.removeprefix("screenrecord screenshot ")).resolve()
        root = Path(__file__).resolve().parents[1]
        if not destination.is_relative_to(root):
            parser.error("Screenshots must stay inside this checkout.")
        destination.mkdir(parents=True, exist_ok=True)
    with socket.create_connection(("127.0.0.1", 5582), timeout=10) as connection:
        connection.settimeout(10)

        def receive() -> str:
            data = b""
            while not data.endswith((b"OK\r\n", b"OK\n")) and b"KO:" not in data:
                chunk = connection.recv(4096)
                if not chunk:
                    raise RuntimeError("Emulator console closed")
                data += chunk
            return data.decode("utf-8", errors="replace")

        greeting = receive()
        if "Authentication required" in greeting:
            token_path = Path.home() / ".emulator_console_auth_token"
            connection.sendall(b"auth " + token_path.read_bytes().strip() + b"\n")
            if "KO:" in receive():
                raise RuntimeError("Emulator console authentication failed")
        connection.sendall(b"avd name\n")
        if "InfiniteSlash_PGS" not in receive().splitlines():
            raise RuntimeError("Console does not belong to the isolated PGS emulator")
        connection.sendall(command.encode("utf-8") + b"\n")
        response = receive()
        if "KO:" in response:
            raise RuntimeError(response)
        print(response.strip())


if __name__ == "__main__":
    main()
