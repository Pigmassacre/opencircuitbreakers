"""Drive car 0 of the original and save its record every game frame.

    python3 record.py tape.json 1500 ../../data/tracks/jungle4/track.json [mix]

Start it with the race under way. The car follows the track's nodes, weaving
from wall to wall; with mix it also brakes, reverses, coasts and steers at
random. The tape is what simtest.gd and replay.gd take.
"""
import json, math, random, struct, sys
from rsp import Gdb

CAR = 0x801f75c0
SIZE = 0x210
# jal FUN_00039a6c for car 0 in the race loop: the pad word is in the car by now.
CALL = 0x80027214
NODES = 0x800a6e88


def word(car, offset):
    return struct.unpack_from("<i", car, offset)[0]


def short(car, offset):
    return struct.unpack_from("<h", car, offset)[0]


def state(car):
    return {"p": [word(car, 0x14) / 4096, word(car, 0x18) / 4096, word(car, 0x1c) / 4096], "v": [word(car, 0x84), word(car, 0x88), word(car, 0x8c)],
            "h": short(car, 0x9e) & 0xfff, "g": word(car, 0x74), "spd": word(car, 0x94), "wreck": word(car, 0), "wall": word(car, 0xc)}


def main():
    out, frames, track = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    mix = len(sys.argv) > 4 and sys.argv[4] == "mix"
    count = len(json.load(open(track))["nodes"])
    g = Gdb()
    g.cmd("?")
    table = g.r32(NODES)
    nodes = [struct.unpack("<18h", g.read(table + i * 0x24, 0x24)) for i in range(count)]
    random.seed(7)
    mode = {"kind": 0, "until": 0}

    def pad(frame, car):
        if frame < 5:
            return 0
        x, y = struct.unpack_from("<2i", car, 0x24)
        heading = struct.unpack_from("<H", car, 0x9e)[0]
        node = word(car, 0xd8)
        a = nodes[(node + 3) % count]
        b = nodes[(node + 4) % count]
        tx, ty = b[10], b[11]
        if not mix:
            dx, dy = b[10] - a[10], b[11] - a[11]
            length = math.hypot(dx, dy) or 1.0
            off = 330.0 * math.sin(frame / 37.0)
            tx += -dy / length * off
            ty += dx / length * off
        want = math.atan2(tx - x, -(ty - y)) / math.tau * 4096
        turn = (int(want) - heading + 0x800) % 0x1000 - 0x800
        buttons = 0x20
        if mix:
            if frame >= mode["until"]:
                mode["kind"] = random.choice([0, 0, 0, 1, 2, 3, 4, 5])
                mode["until"] = frame + random.randint(8, 45)
            kind = mode["kind"]
            buttons = {0: 0x20, 1: 0, 2: 0x40, 3: 0x60, 4: 0x40, 5: 0x20}[kind]
            if kind == 5:
                return buttons | random.choice([0x400, 0x800])
            if kind == 4:
                return buttons | (0x800 if (frame // 10) % 2 else 0x400)
        elif frame % 500 >= 460:
            return buttons | 0x800
        if turn > 0x30:
            buttons |= 0x800
        elif turn < -0x30:
            buttons |= 0x400
        return buttons

    g.bp(CALL)
    tape = []
    for frame in range(frames):
        g.cont()
        car = g.read(CAR, SIZE)
        buttons = pad(frame, car)
        g.w32(CAR + 0xc4, buttons)
        tape.append({"w": buttons, "r": car.hex(), "s": state(car)})
    g.unbp(CALL)
    first = bytes.fromhex(tape[0]["r"])
    json.dump({"start": [word(first, 0x14) / 4096, word(first, 0x18) / 4096, word(first, 0x1c) / 4096, short(first, 0x9e)], "frames": tape}, open(out, "w"))
    print("saved", frames, "frames to", out)


if __name__ == "__main__":
    main()
