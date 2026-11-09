"""Windows release: builds HEAD, packs it as a zip and publishes it on GitHub.

    python release/release.py             # build, check and publish, asking first
    python release/release.py --dry-run   # build and check only, publish nothing
    python release/release.py --yes       # publish without asking

The version is snail.toml's `version`. The release is tagged v<version> and its notes are
docs/releases/<version>.md. A version with a hyphen, such as 0.1.0-alpha, is a pre-release.

HEAD must be clean, and pushed to origin/main before publishing. The commit is built in a fresh
worktree: snailfast first, then the app with snailc's release build. The app is marked a Windows
GUI program, so no console opens beside it, its imports are checked to be SDL3.dll and Windows'
own, and it is run once against an empty data folder. The bundled engine must answer UCI.

The zip holds one folder, "Snail Chess GUI", with the app, SDL3.dll, snailchess.exe,
snailfast.exe, release/README.txt, the license and the licenses of what the app includes. The
zip and the PDB, for reading crash reports, are kept in build/release/<version>/.
"""

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SNAILC = Path(os.environ["LOCALAPPDATA"]) / "Programs" / "Snail" / "bin" / "snailc.exe"
LLVM = Path(r"C:\Program Files\LLVM\bin")
SYSTEM32 = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32"
FOLDER = "Snail Chess GUI"
APP = "Snail Chess GUI.exe"
REPO_URL = "https://github.com/CodeAdopter/Snail-Chess-Gui"

# What goes in licenses\ beside the app's own LICENSE.txt, from the tree being released.
LICENSES = {
    "Inter (OFL-1.1).txt": "assets/fonts/inter/OFL.txt",
    "Gluten (OFL-1.1).txt": "assets/fonts/gluten/OFL.txt",
    "Pixelify Sans (OFL-1.1).txt": "assets/fonts/pixelify-sans/OFL.txt",
    "Chewy (Apache-2.0).txt": "assets/fonts/chewy/LICENSE.txt",
    "Classic pieces, Cburnett (BSD).txt": "assets/pieces/classic/LICENSE.txt",
}
OUTSIDE_LICENSES = {
    "SDL3 (zlib).txt": Path(r"C:\Snail\Snail Engine\vendor\SDL3\LICENSE.txt"),
    "Snail Db (MPL-2.0).txt": Path(r"C:\Snail Db\LICENSE"),
}
NOTICE = """Snail Chess GUI is free software under the GNU General Public License, version 3 or (at your
option) any later version: see LICENSE.txt. Its source is at {url}.

It includes parts that keep their own licenses:

- Snail Chess (snailchess.exe), github.com/CodeAdopter/Snail-Chess: GPL-3.0, as LICENSE.txt.
- Snail Db, built into the app, github.com/CodeAdopter/Snail-Db: MPL-2.0, see Snail Db (MPL-2.0).txt.
- SDL3 (SDL3.dll), libsdl.org: zlib license, see SDL3 (zlib).txt.
- The fonts Inter, Gluten and Pixelify Sans: SIL Open Font License 1.1; Chewy: Apache License 2.0.
- The Classic pieces, by Cburnett: BSD license.
- Opening names, from Lichess's chess-openings, the other piece sets and the sounds: CC0.
"""


def fail(message):
    sys.exit(f"release: {message}")


def run(*command, cwd=REPO, check=True, **kwargs):
    result = subprocess.run([str(c) for c in command], cwd=cwd, capture_output=True, encoding="utf-8", errors="replace", **kwargs)
    if check and result.returncode:
        fail(f"{Path(str(command[0])).name} {' '.join(map(str, command[1:]))[:300]}\n{result.stdout}{result.stderr}")
    return result.stdout.strip()


def version_of_tree(tree):
    found = re.search(r'^version\s*=\s*"([^"]+)"', (tree / "snail.toml").read_text(encoding="utf-8"), re.M)
    if not found:
        fail("snail.toml has no version")
    return found[1]


def head_checked(publishing):
    if run("git", "status", "--porcelain", "--untracked-files=no"):
        fail("the work tree has uncommitted changes; commit them first")
    sha = run("git", "rev-parse", "HEAD")
    if publishing:
        run("git", "fetch", "--quiet", "origin")
        if subprocess.run(["git", "merge-base", "--is-ancestor", sha, "origin/main"], cwd=REPO).returncode:
            fail(f"HEAD {sha[:7]} is not on origin/main yet; push it first")
    return sha


def build(sha, work):
    tree = work / "tree"
    run("git", "worktree", "add", "--detach", tree, sha)
    try:
        run(SNAILC, "build", "-c", "release", cwd=tree / "snailfast")
        run(SNAILC, "build", "-c", "release", cwd=tree)
        built = work / "built"
        shutil.copytree(tree / "build", built)
        for name, inside in LICENSES.items():
            (built / "licenses").mkdir(exist_ok=True)
            shutil.copyfile(tree / inside, built / "licenses" / name)
        shutil.copyfile(tree / "LICENSE", built / "LICENSE.txt")
        shutil.copyfile(tree / "release" / "README.txt", built / "README.txt")
        return built, version_of_tree(tree)
    finally:
        run("git", "worktree", "remove", "--force", tree)


def imports_of(exe):
    dump = run(LLVM / "llvm-objdump.exe", "-p", exe)
    subsystem = re.search(r"^Subsystem\s+([0-9a-f]+)", dump, re.M)
    return int(subsystem[1], 16) if subsystem else -1, sorted(set(re.findall(r"DLL Name: (\S+)", dump)))


def pack(built, version, out):
    stage = out / FOLDER
    if stage.exists():
        shutil.rmtree(stage)
    (stage / "licenses").mkdir(parents=True)
    shutil.copyfile(built / "snail_chess_gui.exe", stage / APP)
    for name in ["SDL3.dll", "snailchess.exe", "snailfast.exe", "LICENSE.txt"]:
        shutil.copyfile(built / name, stage / name)
    text = (built / "README.txt").read_text(encoding="utf-8").replace("{version}", version)
    (stage / "README.txt").write_text(text, encoding="utf-8", newline="\r\n")
    for name in (built / "licenses").iterdir():
        shutil.copyfile(name, stage / "licenses" / name.name)
    for name, path in OUTSIDE_LICENSES.items():
        if not path.exists():
            fail(f"{path} is missing")
        shutil.copyfile(path, stage / "licenses" / name)
    (stage / "licenses" / "NOTICE.txt").write_text(NOTICE.format(url=REPO_URL), encoding="utf-8", newline="\r\n")
    shutil.copyfile(built / "snail_chess_gui.pdb", out / "snail_chess_gui.pdb")
    run(LLVM / "llvm-objcopy.exe", "--subsystem", "windows", stage / APP)
    return stage


def check(stage, version):
    report = []
    for exe, gui in [(APP, True), ("snailchess.exe", False), ("snailfast.exe", False)]:
        subsystem, dlls = imports_of(stage / exe)
        if subsystem != (2 if gui else 3):
            fail(f"{exe}: subsystem {subsystem}, expected {'Windows GUI (2)' if gui else 'console (3)'}")
        foreign = [d for d in dlls if d.lower() != "sdl3.dll" and not (SYSTEM32 / d).exists()]
        if foreign:
            fail(f"{exe} needs {', '.join(foreign)}, which Windows does not have")
        report.append(f"  {exe:22} {(stage / exe).stat().st_size:>10,} B   imports {', '.join(dlls)}")
    engine = subprocess.run([str(stage / "snailchess.exe")], input="uci\nquit\n", capture_output=True, text=True, timeout=30).stdout
    name = re.search(r"^id name (.+?)\s*$", engine, re.M)
    if not name:
        fail(f"snailchess.exe did not answer uci: {engine[:200]!r}")
    report.append(f"  bundled engine         {name[1]}")
    with tempfile.TemporaryDirectory(prefix="snail-gui-first-") as temp:
        data, shot = Path(temp) / "data", Path(temp) / "first.png"
        result = subprocess.run([str(stage / APP), "--data", str(data), "--screenshot", str(shot), "--quit-after-ms", "8000"], timeout=120)
        if result.returncode or not shot.exists() or not (data / "settings.json").exists():
            fail(f"the app did not start cleanly on an empty data folder (exit {result.returncode})")
        report.append(f"  first start            ok, on an empty data folder")
    return report


def zipped(stage, version, out):
    path = out / f"snail-chess-gui-{version}-windows.zip"
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for file in sorted(stage.rglob("*")):
            if file.is_file():
                z.write(file, file.relative_to(stage.parent).as_posix())
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return path, digest


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="build and check, publish nothing")
    parser.add_argument("--yes", action="store_true", help="publish without asking")
    args = parser.parse_args()

    sha = head_checked(not args.dry_run)
    version = version_of_tree(REPO)
    tag = f"v{version}"
    notes = REPO / "docs" / "releases" / f"{version}.md"
    if not notes.exists():
        fail(f"{notes.relative_to(REPO)} is missing; write the release notes first")
    if subprocess.run(["gh", "release", "view", tag], cwd=REPO, capture_output=True).returncode == 0:
        fail(f"{tag} is already released")

    print(f"{version}  {sha[:7]}  {run('git', 'log', '-1', '--format=%s', sha)}", flush=True)
    out = REPO / "build" / "release" / version
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="snail-gui-release-", ignore_cleanup_errors=True) as temp:
        built, built_version = build(sha, Path(temp))
        if built_version != version:
            fail(f"HEAD's snail.toml says {built_version}, the work tree's {version}")
        stage = pack(built, version, out)
    report = check(stage, version)
    path, digest = zipped(stage, version, out)
    print("\n".join(report))
    print(f"  {path.name:22} {path.stat().st_size:>10,} B   sha256 {digest}")

    if args.dry_run:
        print(f"\nDry run: nothing published. The zip is in {out}.")
        return
    prerelease = "-" in version
    if not args.yes and input(f"\nOn GitHub: tag {tag} at {sha[:7]} and publish {path.name} as a {'pre-release' if prerelease else 'release'}? [y/N] ").strip().lower() != "y":
        print("Nothing published.")
        return
    run("gh", "release", "create", tag, path, "--target", sha, "--title", f"Snail Chess GUI {version}",
        "--notes-file", notes, *(["--prerelease"] if prerelease else []))
    run("git", "fetch", "--quiet", "--tags", "origin")
    print(f"Released {version}: {run('gh', 'release', 'view', tag, '--json', 'url', '--jq', '.url')}")


if __name__ == "__main__":
    main()
