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
import time
import tty
import re
from fcntl import ioctl


CLEAR_SCROLLBACK = b"\x1b[3J"
STARTUP_BUFFER_WINDOW = 1.5
STARTUP_BUFFER_LIMIT = 262144
CLEARISH_RE = re.compile(rb"\x1b\[(?:2J|H|[0-9;]*H)")


def set_winsize(fd: int) -> None:
    try:
        size = shutil.get_terminal_size()
        buf = struct.pack("HHHH", size.lines, size.columns, 0, 0)
        ioctl(fd, termios.TIOCSWINSZ, buf)
    except OSError:
        pass


def filter_output(data: bytes) -> bytes:
    return data.replace(CLEAR_SCROLLBACK, b"")


def latest_frame(data: bytes) -> bytes:
    matches = list(CLEARISH_RE.finditer(data))
    if matches:
        return data[matches[-1].start():]
    return data


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
    startup_deadline = time.monotonic() + STARTUP_BUFFER_WINDOW
    startup_buffer = bytearray()
    startup_flushed = False

    try:
        while True:
          read_fds = [master_fd, stdin_fd]
          ready, _, _ = select.select(read_fds, [], [])
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
              data = filter_output(data)
              if not startup_flushed:
                  startup_buffer.extend(data)
                  if len(startup_buffer) > STARTUP_BUFFER_LIMIT:
                      del startup_buffer[:-STARTUP_BUFFER_LIMIT]
                  if time.monotonic() >= startup_deadline:
                      os.write(sys.stdout.fileno(), latest_frame(bytes(startup_buffer)))
                      startup_buffer.clear()
                      startup_flushed = True
              else:
                  os.write(sys.stdout.fileno(), data)
        if not startup_flushed and startup_buffer:
            os.write(sys.stdout.fileno(), latest_frame(bytes(startup_buffer)))
        return proc.wait()
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass
        termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty)


if __name__ == "__main__":
    raise SystemExit(main())
