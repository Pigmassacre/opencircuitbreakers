"""Set the port's replay beside the original's tape.

    python3 compare.py tape.json replay.json [every]
"""
import json, math, sys

tape = json.load(open(sys.argv[1]))["frames"]
port = json.load(open(sys.argv[2]))
every = int(sys.argv[3]) if len(sys.argv) > 3 else 20
frames = min(len(tape), len(port))
same = 0
near = 0
first = None
for k in range(frames):
    o = tape[k]["s"]
    p = port[k]
    apart = math.dist(o["p"], p["p"])
    if apart < 0.01 and o["h"] == p["h"] and (o["wreck"] or o["v"] == [round(v) for v in p["v"]]):
        same += 1
    if apart < 20:
        near += 1
    elif first is None:
        first = k
    if k % every == 0:
        print("%5d  original %-28s port %-28s apart %7.1f  speed %5d %5d  heading %4d %4d  wall %d %d" % (k, [round(v, 1) for v in o["p"]], [round(v, 1) for v in p["p"]], apart, o["spd"], p["spd"], o["h"], p["h"], o["wall"], p["wall"]))
print("%d frames: %d the same, %d within 20 units, first frame further apart: %s" % (frames, same, near, first))
print("A scripted mover such as a conveyor shows as one frame's worth apart while the car is on it: the tape is taken after the track script has run and the replay before.")
