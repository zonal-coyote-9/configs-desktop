#!/usr/bin/env python3
import argparse
import subprocess

DATA_TYPES = [
    "SPHardwareDataType",
    "SPSoftwareDataType",
    "SPStorageDataType",
    "SPPowerDataType",
    "SPDisplaysDataType",
]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Prints hardware, software, storage, power and display "
                                                 "info via system_profiler. Run with no options to show this help.")
    parser.add_argument("--run", "--Run", action="store_true", help="Print the system information.")
    if not parser.parse_args().run:
        parser.print_help()
        raise SystemExit(0)

    for data_type in DATA_TYPES:
        subprocess.run(["system_profiler", data_type])
