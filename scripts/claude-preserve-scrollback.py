#!/usr/bin/env python3
import os
import pty
import select
import shutil
import signal
import struct
import subprocess
import sys
import termios
import tty
from fcntl import ioctl


CLEAR_SCROLLBACK = b"\x1b[3J"


def set_winsize(fd: int) -> None:
    try:
        size = shutil.get_terminal_size()
        buf = struct.pack("HHHH", size.lines, size.columns, 0, 0)
        ioctl(fd, termios.TIOCSWINSZ, buf)
    except OSError:
        pass


def filter_output(data: bytes) -> bytes:
    return data.replace(CLEAR_SCROLLBACK, b"")


def main() -> int:
    argv = ["claude", *sys.argv[1:]]
    master_fd, slave_fd = pty.openpty()
    set_winsize(slave_fd)

    proc = subprocess.Popen(argv, stdin=slave_fd, stdout=slave_fd, stderr=slave_fd, close_fds=True)
    os.close(slave_fd)

    def on_winch(signum, frame):
        del signum, frame
        set_winsize(master_fd)

    signal.signal(signal.SIGWINCH, on_winch)

    stdin_fd = sys.stdin.fileno()
    old_tty = termios.tcgetattr(stdin_fd)
    tty.setraw(stdin_fd)

    try:
        while True:
          read_fds = [master_fd, stdin_fd]
          ready, _, _ = select.select(read_fds, [], [])
          if stdin_fd in ready:
              data = os.read(stdin_fd, 8192)
              if not data:
                  os.close(master_fd)
                  break
              os.write(master_fd, data)
          if master_fd in ready:
              try:
                  data = os.read(master_fd, 8192)
              except OSError:
                  data = b""
              if not data:
                  break
              os.write(sys.stdout.fileno(), filter_output(data))
        return proc.wait()
    finally:
        termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty)


if __name__ == "__main__":
    raise SystemExit(main())
