# Virtual Printer Script

Use this to validate TCP print payloads without a physical printer.

## Run

```bash
python3 /Users/geek/MY OWN PROJECTs/test_print/scripts/virtual_printer.py
```

## App config

- Simulator: printer IP `127.0.0.1`, port `9100`
- Physical iPad: printer IP = your Mac LAN IP, port `9100`

The script prints connection events and payload previews so you can verify TSPL commands.
