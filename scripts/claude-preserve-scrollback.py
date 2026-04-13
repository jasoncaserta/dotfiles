#!/usr/bin/env python3
import os
import pty
import select
import signal
import struct
import subprocess
import sys
import termios
import time
import tty
from fcntl import ioctl
from typing import Optional
from datetime import datetime


CLEAR_SCROLLBACK = b"\x1b[3J"
DEBUG_LOG = "/tmp/claude-preserve-scrollback.log"


def log_debug(message: str) -> None:
    if os.environ.get("CLAUDE_SCROLLBACK_DEBUG") != "1":
        return
    try:
        with open(DEBUG_LOG, "a", encoding="utf-8") as fh:
            fh.write(f"{datetime.now().isoformat(timespec='milliseconds')} {message}\n")
    except OSError:
        pass


def winsize_from_fd(fd: int):
    try:
        return struct.unpack("HHHH", ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8))
    except OSError:
        return None


def winsize_from_tmux_pane():
    pane = os.environ.get("TMUX_PANE", "")
    if not pane:
        return None
    try:
        out = subprocess.check_output(
            ["tmux", "display-message", "-p", "-t", pane, "#{pane_height} #{pane_width}"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        if not out:
            return None
        rows_s, cols_s = out.split()
        rows = int(rows_s)
        cols = int(cols_s)
        if rows > 0 and cols > 0:
            return (rows, cols, 0, 0)
    except Exception:
        return None
    return None


def stable_tmux_winsize(
    max_wait_s: float = 3.0,
    settle_s: float = 0.35,
    min_wait_s: float = 1.0,
):
    deadline = time.monotonic() + max_wait_s
    started_at = time.monotonic()
    last = None
    last_change_at = started_at
    while time.monotonic() < deadline:
        size = winsize_from_tmux_pane()
        if size is not None:
            if size != last:
                last = size
                last_change_at = time.monotonic()
            elif (
                (time.monotonic() - last_change_at) >= settle_s
                and (time.monotonic() - started_at) >= min_wait_s
            ):
                return size
        time.sleep(0.05)
    return last


def set_winsize(fd: int, source_fd: Optional[int] = None) -> None:
    try:
        size = stable_tmux_winsize() if source_fd is not None else winsize_from_tmux_pane()
        if size is None:
            size = winsize_from_fd(source_fd)
        if size is None:
            log_debug(f"set_winsize target_fd={fd} source_fd={source_fd} size=none")
            return
        buf = struct.pack("HHHH", *size)
        ioctl(fd, termios.TIOCSWINSZ, buf)
        log_debug(
            f"set_winsize target_fd={fd} source_fd={source_fd} rows={size[0]} cols={size[1]}"
        )
    except OSError:
        pass


def filter_output(data: bytes) -> bytes:
    return data.replace(CLEAR_SCROLLBACK, b"")


def main() -> int:
    argv = ["claude", *sys.argv[1:]]
    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    master_fd, slave_fd = pty.openpty()
    log_debug(
        f"start pane={os.environ.get('TMUX_PANE','')} argv={argv!r} stdin_fd={stdin_fd} stdout_fd={stdout_fd}"
    )
    set_winsize(slave_fd, stdin_fd)

    proc = subprocess.Popen(argv, stdin=slave_fd, stdout=slave_fd, stderr=slave_fd, close_fds=True)
    log_debug(f"spawn pid={proc.pid}")
    os.close(slave_fd)

    def on_winch(signum, frame):
        del signum, frame
        log_debug("sigwinch")
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
                    log_debug("stdin eof")
                    break
                os.write(master_fd, data)
            if master_fd in ready:
                try:
                    data = os.read(master_fd, 8192)
                except OSError:
                    data = b""
                if not data:
                    log_debug("master eof")
                    break
                filtered = filter_output(data)
                preview = (
                    filtered[:120]
                    .decode("utf-8", errors="replace")
                    .replace("\n", "\\n")
                    .replace("\r", "\\r")
                )
                log_debug(
                    f"read bytes={len(data)} filtered={len(filtered)} contains_3J={CLEAR_SCROLLBACK in data} preview={preview!r}"
                )
                if filtered:
                    os.write(stdout_fd, filtered)
        rc = proc.wait()
        log_debug(f"proc exit rc={rc}")
        return rc
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass
        termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty)
        log_debug("cleanup")


if __name__ == "__main__":
    raise SystemExit(main())
