#!/usr/bin/env python3
"""Record a smooth demo video of the Godot MCP Demos by screen-capturing the game window."""

import configparser
import json
import os
import re
import signal
import socket
import subprocess
import sys
import time

GAME_PORT = 9501
TIMEOUT = 10.0
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

_config_path = os.path.join(SCRIPT_DIR, "..", "mcp_ports.cfg")
if os.path.exists(_config_path):
    _cfg = configparser.ConfigParser()
    _cfg.read(_config_path)
    GAME_PORT = _cfg.getint("mcp", "game_port", fallback=GAME_PORT)
VIDEO_OUTPUT = os.path.join(SCRIPT_DIR, "..", "demo.mp4")


def send(cmd: dict) -> dict:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(TIMEOUT)
        s.connect(("127.0.0.1", GAME_PORT))
        s.sendall((json.dumps(cmd) + "\n").encode())
        data = b""
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            data += chunk
            if b"\n" in data:
                break
        return json.loads(data.decode().strip())


def click(x: float, y: float) -> None:
    send({"cmd": "click", "x": x, "y": y})
    print(f"  Click ({x}, {y})")


def wait(seconds: float) -> None:
    time.sleep(seconds)


def find_game_window() -> dict | None:
    """Find the Godot game window geometry using xwininfo."""
    # List windows and find the Godot game
    result = subprocess.run(
        ["xwininfo", "-root", "-tree"],
        capture_output=True, text=True, timeout=5,
    )
    for line in result.stdout.splitlines():
        # Look for the game window by title
        if "Godot MCP Demos" in line or "Godot" in line:
            # Found it — get its window ID
            match = re.search(r"(0x[0-9a-fA-F]+)", line)
            if match:
                wid = match.group(1)
                # Get geometry for this window
                geo = subprocess.run(
                    ["xwininfo", "-id", wid],
                    capture_output=True, text=True, timeout=5,
                )
                info = {}
                for gline in geo.stdout.splitlines():
                    if "Absolute upper-left X:" in gline:
                        info["x"] = int(gline.split(":")[-1].strip())
                    elif "Absolute upper-left Y:" in gline:
                        info["y"] = int(gline.split(":")[-1].strip())
                    elif "Width:" in gline:
                        info["w"] = int(gline.split(":")[-1].strip())
                    elif "Height:" in gline:
                        info["h"] = int(gline.split(":")[-1].strip())
                if all(k in info for k in ("x", "y", "w", "h")):
                    return info
    return None


def main():
    print("Waiting for game to be ready...")
    for _ in range(20):
        try:
            send({"cmd": "get_runtime_tree"})
            break
        except (ConnectionRefusedError, socket.timeout):
            time.sleep(0.5)
    else:
        print("Could not connect to game on port 9501. Is it running?")
        sys.exit(1)

    wait(1.0)

    # Find game window
    print("Finding game window...")
    geo = find_game_window()
    if not geo:
        print("Could not find the Godot game window.")
        print("Falling back to display :0 offset. You may need to adjust.")
        geo = {"x": 0, "y": 0, "w": 900, "h": 600}

    # Make dimensions even (required by libx264)
    geo["w"] = geo["w"] & ~1
    geo["h"] = geo["h"] & ~1

    print(f"Recording window at {geo['x']},{geo['y']} size {geo['w']}x{geo['h']}")

    # Start ffmpeg screen recording
    display = os.environ.get("DISPLAY", ":0")
    ffmpeg_cmd = [
        "ffmpeg", "-y",
        "-f", "x11grab",
        "-framerate", "30",
        "-video_size", f"{geo['w']}x{geo['h']}",
        "-i", f"{display}+{geo['x']},{geo['y']}",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "20",
        "-preset", "fast",
        VIDEO_OUTPUT,
    ]
    print(f"Starting recording...")
    ffmpeg_proc = subprocess.Popen(
        ffmpeg_cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    wait(0.5)  # Let ffmpeg settle

    try:
        # ── Launcher ──
        print("\n=== Launcher ===")
        wait(2.0)

        # ── Kanban Board ──
        print("\n=== Kanban Board ===")
        click(448, 330)  # "Kanban Board" button
        wait(2.5)

        # ── Spinning Cube (via nav bar) ──
        print("\n=== Spinning Cube ===")
        click(485, 17)  # "Cube" in nav bar
        wait(3.0)  # Let the cube spin a bit

        # ── Cookie Clicker (via nav bar) ──
        print("\n=== Cookie Clicker ===")
        click(541, 17)  # "Cookie" in nav bar
        wait(1.5)

        # Click the cookie a bunch
        print("  Clicking cookie...")
        for i in range(12):
            click(448, 350)  # Cookie button
            wait(0.25)
        wait(1.0)

        # ── Back to Menu ──
        print("\n=== Back to Menu ===")
        click(353, 17)  # "Menu" in nav bar
        wait(2.0)

    finally:
        # Stop ffmpeg gracefully
        print("\n=== Stopping recording ===")
        ffmpeg_proc.stdin.write(b"q")
        ffmpeg_proc.stdin.flush()
        ffmpeg_proc.wait(timeout=10)

    size_kb = os.path.getsize(VIDEO_OUTPUT) / 1024
    print(f"\nVideo saved: {VIDEO_OUTPUT} ({size_kb:.0f} KB)")
    print("Done!")


if __name__ == "__main__":
    main()
