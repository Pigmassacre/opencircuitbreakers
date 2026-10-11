import socket, struct, time

class Gdb:
    def __init__(self, port=2345):
        self.s = socket.create_connection(("127.0.0.1", port))
        self.s.settimeout(30)
        self.buf = b""

    def send(self, data):
        if isinstance(data, str):
            data = data.encode()
        pkt = b"$" + data + b"#" + b"%02x" % (sum(data) & 0xff)
        self.s.sendall(pkt)

    def recv(self, timeout=30):
        self.s.settimeout(timeout)
        while True:
            a = self.buf.find(b"$")
            b = self.buf.find(b"#", a + 1) if a >= 0 else -1
            if a >= 0 and b >= 0 and len(self.buf) >= b + 3:
                body = self.buf[a + 1:b]
                self.buf = self.buf[b + 3:]
                self.s.sendall(b"+")
                return body
            d = self.s.recv(65536)
            if not d:
                raise EOFError
            self.buf += d

    def cmd(self, data, timeout=30):
        self.send(data)
        return self.recv(timeout)

    def read(self, addr, n):
        out = b""
        while n:
            k = min(n, 0x400)
            r = self.cmd("m%x,%x" % (addr, k))
            out += bytes.fromhex(r.decode())
            addr += k
            n -= k
        return out

    def write(self, addr, data):
        r = self.cmd("M%x,%x:%s" % (addr, len(data), data.hex()))
        assert r == b"OK", r

    def r32(self, a): return struct.unpack("<I", self.read(a, 4))[0]
    def s32(self, a): return struct.unpack("<i", self.read(a, 4))[0]
    def r16(self, a): return struct.unpack("<H", self.read(a, 2))[0]
    def w32(self, a, v): self.write(a, struct.pack("<I", v & 0xffffffff))
    def w16(self, a, v): self.write(a, struct.pack("<H", v & 0xffff))

    def regs(self):
        r = bytes.fromhex(self.cmd("g").decode().replace("x", "0"))
        return struct.unpack("<%dI" % (len(r) // 4), r)

    def bp(self, addr): return self.cmd("Z0,%x,4" % addr)
    def unbp(self, addr): return self.cmd("z0,%x,4" % addr)

    def cont(self, timeout=60):
        return self.cmd("c", timeout)

    def interrupt(self):
        self.s.sendall(b"\x03")
        return self.recv()
