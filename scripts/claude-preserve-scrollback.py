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
from typing import Optional
from fcntl import ioctl


CLEAR_SCROLLBACK = b"\x1b[3J"
STARTUP_BUFFER_WINDOW = 1.5
STARTUP_BUFFER_LIMIT = 262144
CLEARISH_RE = re.compile(rb"\x1b\[(?:2J|H|[0-9;]*H)")
PRINTABLE_RE = re.compile(rb"[^\x00-\x1f\x7f]|\n")
PROMPT_MARKERS = (
    b"? for shortcuts",
    b"/buddy",
)


def winsize_from_fd(fd: int):
    try:
        return struct.unpack("HHHH", ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8))
    except OSError:
        return None


def set_winsize(fd: int, source_fd: Optional[int] = None) -> None:
    try:
        size = winsize_from_fd(source_fd) if source_fd is not None else None
        if size is None:
            fallback = shutil.get_terminal_size()
            size = (fallback.lines, fallback.columns, 0, 0)
        buf = struct.pack("HHHH", *size)
        ioctl(fd, termios.TIOCSWINSZ, buf)
    except OSError:
        pass


def filter_output(data: bytes) -> bytes:
    return data.replace(CLEAR_SCROLLBACK, b"")


def best_startup_frame(data: bytes) -> bytes:
    matches = list(CLEARISH_RE.finditer(data))
    candidates = []
    if matches:
        candidates.extend(data[m.start():] for m in matches)
    candidates.append(data)

    for frame in reversed(candidates):
        if PRINTABLE_RE.search(frame):
            return frame
    return candidates[-1]


def has_prompt_marker(data: bytes) -> bool:
    return any(marker in data for marker in PROMPT_MARKERS)


def main() -> int:
    argv = ["claude", *sys.argv[1:]]
    stdin_fd = sys.stdin.fileno()
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
    startup_deadline = time.monotonic() + STARTUP_BUFFER_WINDOW
    startup_buffer = bytearray()
    startup_flushed = False
    post_flush_deadline = 0.0
    last_startup_frame = b""

    try:
        while True:
          read_fds = [master_fd, stdin_fd]
          timeout = None
          if not startup_flushed:
              timeout = max(0.0, startup_deadline - time.monotonic())
          ready, _, _ = select.select(read_fds, [], [], timeout)
          if not startup_flushed and time.monotonic() >= startup_deadline:
              last_startup_frame = best_startup_frame(bytes(startup_buffer))
              os.write(sys.stdout.fileno(), last_startup_frame)
              startup_buffer.clear()
              startup_flushed = True
              post_flush_deadline = time.monotonic() + 1.0
              continue
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
                  if has_prompt_marker(startup_buffer):
                      last_startup_frame = best_startup_frame(bytes(startup_buffer))
                      os.write(sys.stdout.fileno(), last_startup_frame)
                      startup_buffer.clear()
                      startup_flushed = True
                      post_flush_deadline = time.monotonic() + 1.0
              else:
                  if time.monotonic() < post_flush_deadline and last_startup_frame:
                      if best_startup_frame(data) == last_startup_frame:
                          continue
                  os.write(sys.stdout.fileno(), data)
        if not startup_flushed and startup_buffer:
            os.write(sys.stdout.fileno(), best_startup_frame(bytes(startup_buffer)))
        return proc.wait()
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass
        termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty)


if __name__ == "__main__":
    raise SystemExit(main())
