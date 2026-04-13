#!/usr/bin/env python3
import os
import pty
import select
import signal
import struct
import subprocess
import sys
import termios
import tty
from fcntl import ioctl
from typing import Optional


CLEAR_SCROLLBACK = b"\x1b[3J"


def winsize_from_fd(fd: int):
    try:
        return struct.unpack("HHHH", ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8))
    except OSError:
        return None


def set_winsize(fd: int, source_fd: Optional[int] = None) -> None:
    try:
        size = winsize_from_fd(source_fd)
        if size is None:
            return
        buf = struct.pack("HHHH", *size)
        ioctl(fd, termios.TIOCSWINSZ, buf)
    except OSError:
        pass


def filter_output(data: bytes) -> bytes:
    return data.replace(CLEAR_SCROLLBACK, b"")


def main() -> int:
    argv = ["claude", *sys.argv[1:]]
    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    master_fd, slave_fd = pty.openpty()
    set_winsize(slave_fd, stdin_fd)

    proc = subprocess.Popen(argv, stdin=slave_fd, stdout=slave_fd, stderr=slave_fd, close_fds=True)
    os.close(slave_fd)

    def on_winch(signum, frame):
        del signum, frame
        set_winsize(master_fd, stdin_fd)

    signal.signal(signal.SIGWINCH, on_winch)

    old_tty = termios.tcgetattr(stdin_fd)
    tty.setraw(stdin_fd)

    try:
        while True:
            ready, _, _ = select.select([master_fd, stdin_fd], [], [])
            if stdin_fd in ready:
                data = os.read(stdin_fd, 8192)
                if not data:
                    break
                os.write(master_fd, data)
            if master_fd in ready:
                try:
                    data = os.read(master_fd, 8192)
                except OSError:
                    data = b""
                if not data:
                    break
                filtered = filter_output(data)
                if filtered:
                    os.write(stdout_fd, filtered)
        return proc.wait()
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass
        termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty)


if __name__ == "__main__":
    raise SystemExit(main())
