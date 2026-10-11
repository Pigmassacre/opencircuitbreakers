"""Press buttons in the original through DuckStation's GDB server.

    python3 menu.py run:14 start:3 run:6 cross:45 select:3 --shot /tmp/now.png

name:n holds the buttons (joined with +) for n pad reads. run:s lets the game
run free for s seconds. --shot saves the DuckStation window when it is done.
"""
import subprocess, sys, time
from rsp import Gdb

BUTTONS = dict(l2=1, r2=2, l1=4, r1=8, tri=0x10, cross=0x20, square=0x40, circle=0x80, up=0x100, down=0x200, left=0x400, right=0x800, select=0x1000, start=0x2000, wait=0)
# The game's button bits, as FUN_00031a58 makes them from the pad's own.
RAW = {1: 0x100, 2: 0x200, 4: 0x400, 8: 0x800, 0x10: 0x1000, 0x20: 0x4000, 0x40: 0x8000, 0x80: 0x2000, 0x100: 0x10, 0x200: 0x40, 0x400: 0x80, 0x800: 0x20, 0x1000: 1, 0x2000: 8}
PAD_READ = 0x80031a58
PAD_ONE = 0xbf734


def put(g, word):
    if g.regs()[4] & 0xffffff != PAD_ONE:
        return False
    raw = 0xffff
    for bit, mask in RAW.items():
        if word & bit:
            raw &= ~mask
    g.w16(0x80000000 + PAD_ONE + 2, raw)
    return True


def main():
    args = sys.argv[1:]
    shot = None
    if "--shot" in args:
        shot = args[args.index("--shot") + 1]
        del args[args.index("--shot"):args.index("--shot") + 2]
    g = Gdb()
    g.cmd("?")
    g.bp(PAD_READ)
    for token in args:
        name, _, count = token.partition(":")
        if name == "run":
            g.unbp(PAD_READ)
            g.send("c")
            time.sleep(float(count))
            g.interrupt()
            g.bp(PAD_READ)
            continue
        word = 0
        for button in name.split("+"):
            word |= BUTTONS[button]
        done = 0
        while done < int(count or 3):
            g.cont()
            done += put(g, word)
    for _ in range(4):
        g.cont()
        put(g, 0)
    g.unbp(PAD_READ)
    if shot:
        g.send("c")
        time.sleep(0.3)
        window = subprocess.check_output("wmctrl -lx | grep -i duckstation | head -1 | cut -d' ' -f1", shell=True).decode().strip()
        subprocess.run("xwd -id %s -silent | ffmpeg -loglevel error -y -i - %s" % (window, shot), shell=True)
        g.interrupt()


if __name__ == "__main__":
    main()
