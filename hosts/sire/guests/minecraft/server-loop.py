import os
import signal
import subprocess
import sys
import time
from pathlib import Path

def exit_usage():
    print(f"usage: {sys.argv[0]} [--block blockfile] COMMAND... [:POST: POST_SCRIPT...]")
    sys.exit(1)

def main():
    if len(sys.argv) < 2:
        exit_usage()

    blockfile = None
    if sys.argv[1] == "--block":
        if len(sys.argv) < 4:
            exit_usage()

        blockfile = Path(sys.argv[2])
        cmd = sys.argv[3:]
    else:
        cmd = sys.argv[1:]

    # Split cmd and post-cmd
    post = None
    try:
        separator = cmd.index(":POST:")
        post = cmd[separator + 1:]
        cmd = cmd[:separator]
    except ValueError:
        pass

    # Global state
    shared_data = {
        "stop": False,
        "process": None,
    }

    def block_start():
        if not blockfile:
            return
        print(f"Blocking on {blockfile}")
        blockfile.touch()
        while blockfile.exists() and not shared_data["stop"]:
            time.sleep(.5)

    def run_server():
        if shared_data["stop"]:
            return

        print(f"Starting process {cmd} ...")
        start_time = time.time()
        shared_data["process"] = subprocess.Popen(cmd, preexec_fn=os.setsid)
        shared_data["process"].wait()

        end_time = time.time()
        if end_time - start_time < 2:
            print("Server exited abnormally fast, aborting!")
            shared_data["stop"] = True
            return

        shared_data["process"] = None

        # Launch post script
        if post:
            print(f"Starting post process {post} ...")
            subprocess.run(post, preexec_fn=os.setsid)

    def signal_forward(sig, _):
        if shared_data["process"]:
            print(f"Passing signal {sig} to child ...")
            try:
                shared_data["process"].send_signal(sig)
            except OSError:
                pass

    def signal_forward_and_stop(sig, frame):
        shared_data["stop"] = True
        signal_forward(sig, frame)

    signal.signal(signal.SIGINT, signal_forward)
    signal.signal(signal.SIGTERM, signal_forward_and_stop)
    signal.signal(signal.SIGHUP, signal_forward_and_stop)

    # Run until killed
    try:
        while not shared_data["stop"]:
            block_start()
            run_server()
        print("Exiting.")
    finally:
        if blockfile and blockfile.exists():
            blockfile.unlink()

if __name__ == '__main__':
    main()
