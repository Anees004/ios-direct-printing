#!/usr/bin/env python3
"""
Virtual printer: TCP server that mimics a Rollo/label printer on port 9100.
Accepts raw print jobs (TSPL/ZPL/etc.), logs them, and optionally saves to a file.
Use this to test the app without a physical printer — run on your Mac, point the app
to this machine's IP and port 9100.

Usage:
  python3 virtual_printer.py [--port 9100] [--save-dir ./jobs]
  # Or: ./virtual_printer.py

Then on iPad: Settings → Printer IP = <this Mac's IP>, Port 9100. Connect & Print.
"""

import argparse
import socket
import sys
import time
from pathlib import Path


def get_local_ip():
    """Prefer the IP used for default route (often Wi‑Fi)."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0)
        s.connect(("10.255.255.255", 1))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "0.0.0.0"


def main():
    parser = argparse.ArgumentParser(description="Virtual printer for testing (TCP port 9100)")
    parser.add_argument("--port", type=int, default=9100, help="Port to listen on (default 9100)")
    parser.add_argument(
        "--save-dir",
        type=str,
        default=None,
        help="Directory to save each job (e.g. ./jobs). Last job also as last_print_job.txt",
    )
    parser.add_argument("--bind", type=str, default="0.0.0.0", help="Bind address (default 0.0.0.0)")
    args = parser.parse_args()

    save_dir = Path(args.save_dir) if args.save_dir else None
    if save_dir:
        save_dir.mkdir(parents=True, exist_ok=True)

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((args.bind, args.port))
    server.listen(1)
    server.settimeout(1.0)

    local_ip = get_local_ip()
    print("=" * 60)
    print("Virtual Printer (mimics Rollo on port 9100)")
    print("=" * 60)
    print(f"Listening on {args.bind}:{args.port}")
    print(f"On this machine, try IP: {local_ip}")
    print()
    print("Simulator on this Mac: set Printer IP to 127.0.0.1, Port %d" % args.port)
    print("Physical iPad (same Wi‑Fi): set Printer IP to %s, Port %d" % (local_ip, args.port))
    print("Then Connect and Print. Real jobs show TSPL/ZPL; HTTP = browser, not the app.")
    print("Ctrl+C to stop.")
    print("=" * 60)
    sys.stdout.flush()

    job_index = 0
    try:
        while True:
            try:
                conn, addr = server.accept()
            except socket.timeout:
                continue
            job_index += 1
            peer = "%s:%s" % (addr[0], addr[1])
            print("\n[%s] Connection from %s (job #%d)" % (time.strftime("%H:%M:%S"), peer, job_index))
            conn.settimeout(30.0)
            chunks = []
            try:
                while True:
                    data = conn.recv(65536)
                    if not data:
                        break
                    chunks.append(data)
            except socket.timeout:
                pass
            conn.close()

            payload = b"".join(chunks)
            size = len(payload)
            print("  Received %d bytes" % size)

            is_http = payload.startswith(b"GET ") or payload.startswith(b"POST ") or payload.startswith(b"HTTP/")
            if is_http:
                print("  >>> Looks like HTTP (browser), not a print job. In the app set Printer IP to 127.0.0.1 for simulator.")

            try:
                text = payload.decode("utf-8", errors="replace")
                if text.strip():
                    preview = text[:500].replace("\r", "\n")
                    if len(text) > 500:
                        preview += "\n... (truncated)"
                    print("  Preview (first 500 chars):")
                    for line in preview.splitlines():
                        print("    %s" % line)
            except Exception:
                print("  (binary data, no preview)")

            if save_dir and payload:
                last_file = save_dir / "last_print_job.txt"
                last_file.write_bytes(payload)
                named = save_dir / ("job_%04d.txt" % job_index)
                named.write_bytes(payload)
                print("  Saved: %s and %s" % (last_file.name, named.name))

    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        server.close()
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
