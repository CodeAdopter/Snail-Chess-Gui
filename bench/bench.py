"""A rough GPU benchmark: the app's 2D and 3D boards in set scenes, measured with nvidia-smi.

    python bench/bench.py                       # run every scene here, with build/snail_chess_gui.exe
    python bench/bench.py --only library        # only scenes whose name has "library" in it
    python bench/bench.py --host snail-2700x    # run them on another PC over ssh, in its desktop session

Each scene runs the app for --seconds in a fixed window with a quality preset, 3D or not, a room,
and one of: idle (nothing asked of it), orbit (the camera turning, as when someone drags the view),
uncapped (orbit with vertical sync off, so frames come as fast as the GPU draws them) or analysis
(Snail Chess analysing, so the arrows and lines keep changing). nvidia-smi samples the
GPU's load four times a second; the first --settle seconds, while the scene loads, are left out.
The app's --stats gives the frames it drew.

The columns: fps, frames presented a second; gpu %, the GPU's average load, with its power and
clock (a lightly loaded GPU clocks down, which makes its load read high); and cpu ms, the app's CPU
time a second. An uncapped scene's ms is what one frame costs, 1000 / fps, and holds across
refresh rates, so a 32 Hz Remote Desktop and a 144 Hz monitor compare.

The app must be a console build (build/snail_chess_gui.exe from `snailc build -c release`), as
--stats prints. On another PC the app runs from a scheduled task in the logged-on user's session,
since a program started over ssh has no desktop to draw on. Results are kept in build/bench/.
"""

import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
APP_FILES = ["snail_chess_gui.exe", "SDL3.dll", "snailchess.exe", "snailfast.exe"]
REMOTE_DIR = r"C:\analysis\bench"
WIDTH, HEIGHT = 1000, 680
QUALITIES = {
    "ultra": {"msaa": 8, "render_scale": 1.5, "shadow_size": 4096, "anisotropy": 16},
    "high": {"msaa": 4, "render_scale": 1.0, "shadow_size": 2048, "anisotropy": 8},
}
TRIALS = {
    "u-msaa4": {"msaa": 4, "render_scale": 1.5, "shadow_size": 4096, "anisotropy": 16},
    "u-msaa2": {"msaa": 2, "render_scale": 1.5, "shadow_size": 4096, "anisotropy": 16},
    "u-scale1": {"msaa": 8, "render_scale": 1.0, "shadow_size": 4096, "anisotropy": 16},
    "u-shadow2k": {"msaa": 8, "render_scale": 1.5, "shadow_size": 2048, "anisotropy": 16},
}
ROOMS = ["none", "library", "park", "mars", "bedroom"]


def scenes(trials=False):
    if trials:
        out = []
        for quality in ["ultra", *TRIALS, "high"]:
            for room in ["none", "library"]:
                out.append((f"3d {quality} {room} orbit", quality, room, "orbit"))
                out.append((f"3d {quality} {room} idle", quality, room, "idle"))
        return out
    out = [("2d idle", "high", None, "idle"), ("2d analysis", "high", None, "analysis"),
           ("2d charcoal animated", "high", None, "animated charcoal"), ("2d paper animated", "high", None, "animated paper")]
    for quality in QUALITIES:
        for room in ROOMS:
            out.append((f"3d {quality} {room} idle", quality, room, "idle"))
            if room != "bedroom":
                out.append((f"3d {quality} {room} orbit", quality, room, "orbit"))
                out.append((f"3d {quality} {room} uncapped", quality, room, "uncapped"))
        out.append((f"3d {quality} library analysis", quality, "library", "analysis"))
    return out


def arguments(room, mode, seconds, settle):
    args = ["--width", str(WIDTH), "--height", str(HEIGHT), "--stats", "--gpu-times", "--quit-after-ms", str(int(seconds * 1000)), "--bench-from-ms", str(int(settle * 1000))]
    if room:
        args += ["--board3d", "--room", room]
    if mode in ("orbit", "uncapped"):
        args += ["--orbit", "20"]
    if mode == "analysis":
        args += ["--analyse"]
    return args


def sample_gpu(into, stop):
    smi = subprocess.Popen(["nvidia-smi", "--query-gpu=timestamp,utilization.gpu,power.draw,clocks.gr", "--format=csv,noheader,nounits", "-lms", "250"],
                           stdout=subprocess.PIPE, text=True)
    while not stop.is_set():
        line = smi.stdout.readline()
        if not line:
            break
        into.append((time.time(), line.strip()))
    smi.kill()


EXTRA = []


def run_scene(app, data, name, quality, room, mode, seconds, settle):
    home = data / "app"
    home.mkdir(parents=True, exist_ok=True)
    settings = home / "settings.json"
    graphics = {"vsync": mode != "uncapped", **{**QUALITIES, **TRIALS}[quality]}
    wanted = {"graphics": graphics, "settings": {"start_with": "analysis"}}
    if mode.startswith("animated"):
        wanted["appearance"] = {"theme": mode.split()[1]}
        wanted["board"] = {"pieces": "blunder"}
    settings.write_text(json.dumps(wanted), encoding="utf-8")
    samples, stop = [], threading.Event()
    sampler = threading.Thread(target=sample_gpu, args=(samples, stop))
    sampler.start()
    began = time.time()
    result = subprocess.run([str(app), "--data", str(home), *arguments(room, mode, seconds, settle), *EXTRA], capture_output=True, text=True, timeout=seconds + 60)
    ended = time.time()
    stop.set()
    sampler.join(timeout=5)
    loads, watts, clocks = [], [], []
    for at, line in samples:
        if began + settle <= at <= ended - 0.5:
            parts = [p.strip() for p in line.split(",")]
            try:
                loads.append(float(parts[1]))
                watts.append(float(parts[2]))
                clocks.append(float(parts[3]))
            except (IndexError, ValueError):
                pass
    measured = re.search(r"^bench seconds ([\d.]+) presented (\d+)", result.stdout, re.M)
    total = re.search(r"^stats seconds ([\d.]+) .* cpu_ms (\d+)", result.stdout, re.M)
    size = re.search(r"size (\d+)x(\d+)", result.stdout)
    fps = int(measured[2]) / float(measured[1]) if measured and float(measured[1]) > 0 else 0.0
    timed = re.search(r"^gpu times over (\d+) frames, ([\d.]+) ms a frame", result.stdout, re.M)
    laps = {m[1].strip(): float(m[2]) for m in re.finditer(r"^  (\S.{0,21}?)\s+([\d.]+) ms\s+[\d.]+%", result.stdout, re.M)}
    shown = int(total[0].split("presented ")[1].split()[0]) if total else 0
    gpu_frame = float(timed[2]) * int(timed[1]) / shown if timed and shown else None
    load = sum(loads) / len(loads) if loads else 0.0
    return {
        "scene": name, "quality": quality, "room": room or "2d", "mode": mode,
        "fps": round(fps, 1), "gpu_pct": round(load, 1), "gpu_ms_frame": round(gpu_frame, 2) if gpu_frame else None,
        "laps": {k: round(v * int(timed[1]) / shown, 3) for k, v in laps.items()} if timed and shown else {}, "frame_ms": round(1000.0 / fps, 2) if mode == "uncapped" and fps > 0 else None,
        "watts": round(sum(watts) / len(watts), 1) if watts else None, "clock_mhz": round(sum(clocks) / len(clocks)) if clocks else None,
        "cpu_ms_per_s": round(int(total[2]) / float(total[1])) if total else None,
        "size": f"{size[1]}x{size[2]}" if size else "?", "samples": len(loads), "exit": result.returncode,
    }


def run_here(app, seconds, settle, only, out, trials=False):
    gpu = subprocess.run(["nvidia-smi", "--query-gpu=name,driver_version", "--format=csv,noheader"], capture_output=True, text=True).stdout.strip()
    rows = []
    with tempfile.TemporaryDirectory(prefix="snail-bench-") as temp:
        data = Path(temp)
        for warm in [s for s in scenes() if s[0] in ("3d high library idle", "3d ultra park idle", "3d ultra mars idle", "3d ultra bedroom idle")]:
            run_scene(app, data, *warm, seconds=8, settle=0)
        for scene in scenes(trials):
            if only and only not in scene[0]:
                continue
            row = run_scene(app, data, *scene, seconds=seconds, settle=settle)
            rows.append(row)
            print(line_of(row), flush=True)
    report = {"machine": os.environ.get("COMPUTERNAME", "?"), "gpu": gpu, "when": datetime.datetime.now().isoformat(timespec="seconds"), "rows": rows}
    out.write_text(json.dumps(report, indent=1), encoding="utf-8")
    return report


def line_of(row):
    gpu = f"{row['gpu_ms_frame']:6.2f}" if row.get("gpu_ms_frame") is not None else "     -"
    return f"  {row['scene']:31} {row['fps']:6.1f} fps  {gpu} gpu ms/frame  {row['gpu_pct']:5.1f} % gpu {row['watts'] or 0:6.1f} W {row['clock_mhz'] or 0:5} MHz  {row['cpu_ms_per_s'] or 0:4} cpu ms/s"


def ssh(host, command, check=True):
    result = subprocess.run(["ssh", "-o", "BatchMode=yes", host, command], capture_output=True, text=True)
    if check and result.returncode:
        sys.exit(f"bench: {host}: {command[:120]}\n{result.stdout}{result.stderr}")
    return result.stdout


def run_there(host, app, seconds, settle, only, out, trials=False):
    remote = REMOTE_DIR
    ssh(host, f'cmd /c "if not exist {remote}\\app mkdir {remote}\\app"')
    files = [str(app.parent / f) for f in APP_FILES] + [str(Path(__file__))]
    subprocess.run(["scp", "-q", *files[:-1], f"{host}:{remote}\\app\\".replace("\\", "/")], check=True)
    subprocess.run(["scp", "-q", files[-1], f"{host}:{remote}/bench.py"], check=True)
    python = ssh(host, "where python").splitlines()
    python = next((p.strip() for p in python if "WindowsApps" not in p), python[0].strip())
    flags = f"--seconds {seconds} --settle {settle}" + (f" --only \"{only}\"" if only else "") + (" --trials" if trials else "") + (f" --extra=\"{' '.join(EXTRA)}\"" if EXTRA else "")
    script = f'@echo off\r\ncd /d {remote}\r\ndel results.json done.txt 2>nul\r\n"{python}" bench.py --app {remote}\\app\\snail_chess_gui.exe --out {remote}\\results.json {flags} > log.txt 2>&1\r\necho done > done.txt\r\n'
    local_script = out.parent / "remote_run.cmd"
    local_script.write_bytes(script.encode("utf-8"))
    subprocess.run(["scp", "-q", str(local_script), f"{host}:{remote}/run.cmd"], check=True)
    ssh(host, f'schtasks /create /tn SnailBench /tr "{remote}\\run.cmd" /sc once /st 23:59 /it /f')
    ssh(host, "schtasks /run /tn SnailBench")
    print(f"running on {host}, in its desktop session", flush=True)
    shown = 0
    while True:
        time.sleep(10)
        log = ssh(host, f'cmd /c "type {remote}\\log.txt 2>nul"', check=False).splitlines()
        for line in log[shown:]:
            print(line, flush=True)
        shown = max(shown, len(log))
        if "done" in ssh(host, f'cmd /c "type {remote}\\done.txt 2>nul"', check=False):
            break
    subprocess.run(["scp", "-q", f"{host}:{remote}/results.json".replace("\\", "/"), str(out)], check=True)
    ssh(host, "schtasks /delete /tn SnailBench /f", check=False)
    return json.loads(out.read_text(encoding="utf-8"))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", help="run on this ssh host instead of here")
    parser.add_argument("--app", default=str(REPO / "build" / "snail_chess_gui.exe"))
    parser.add_argument("--seconds", type=float, default=15.0)
    parser.add_argument("--settle", type=float, default=5.0)
    parser.add_argument("--only", default="")
    parser.add_argument("--out")
    parser.add_argument("--trials", action="store_true", help="the quality trials instead of the usual scenes")
    parser.add_argument("--extra", default="", help="more arguments for the app, such as --no-shadow-keep")
    args = parser.parse_args()
    EXTRA.extend(args.extra.split())
    app = Path(args.app)
    if not app.exists():
        sys.exit(f"bench: {app} is missing; build it with snailc build -c release")
    out_dir = REPO / "build" / "bench"
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M")
    out = Path(args.out) if args.out else out_dir / f"{args.host or os.environ.get('COMPUTERNAME', 'here')}-{stamp}.json"
    if args.host:
        report = run_there(args.host, app, args.seconds, args.settle, args.only, out, args.trials)
        print(f"\n{report['machine']}, {report['gpu']}")
        for row in report["rows"]:
            print(line_of(row))
    else:
        print(f"{os.environ.get('COMPUTERNAME', '?')}, {WIDTH}x{HEIGHT} window, {args.seconds:.0f} s a scene", flush=True)
        run_here(app, args.seconds, args.settle, args.only, out, args.trials)
    print(f"\nsaved {out}")


if __name__ == "__main__":
    main()
