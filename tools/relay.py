#!/usr/bin/env python3
# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Forever Speed online aktarma sunucusu (UDP). İki oyuncu doğrudan bağlanamazsa (ikisinin de NAT'ı zor) aynı oda
# numarasıyla buraya katılır, sunucu birinin paketini öbürüne iletir. Paketin içini okumaz: oyun kendi anahtarıyla
# doğrular. Yalnız standart kütüphane.
#
#   python3 relay.py                  (PORT ortam değişkeni, varsayılan 47812/udp)
#
# Katılma paketi: b"FSR1" + 32 hex oda numarası (iki oyuncunun kod anahtarlarından türer, tahmin edilemez).
# Odada en çok iki adres; 30 sn sesi çıkmayan düşer. Adres başına saniyede en çok 300 paket, paket en çok 700 bayt.
import asyncio
import os
import time

PORT = int(os.environ.get("PORT", "47812"))
MAGIC = b"FSR1"
HEX = set(b"0123456789abcdef")
TTL = 30.0
MAX_ROOMS = 5000
MAX_RATES = MAX_ROOMS * 4 # sınır kaydı: odadaki iki adres ve katılmayı deneyenler
MAX_PACKET = 700
RATE = 300


class Relay(asyncio.DatagramProtocol):
    def __init__(self) -> None:
        self.rooms: dict[bytes, dict[tuple, float]] = {} # oda -> {adres: son görülme}
        self.where: dict[tuple, bytes] = {} # adres -> oda
        self.rate: dict[tuple, list] = {} # adres -> [saniye, paket sayısı]

    def connection_made(self, transport) -> None:
        self.t = transport

    def datagram_received(self, data: bytes, addr: tuple) -> None:
        if len(data) > MAX_PACKET:
            return
        join = data.startswith(MAGIC)
        room = data[4:36]
        if join and (len(room) != 32 or not set(room) <= HEX):
            return
        # odası olmayan adresten yalnız geçerli katılma paketi: UDP'de kaynak adresi taklit edilebilir, her sahte
        # adres sınır kaydı açınca bellek sınırsız büyüyordu
        if not join and addr not in self.where:
            return
        if addr not in self.rate and len(self.rate) >= MAX_RATES:
            return
        now = time.monotonic()
        r = self.rate.setdefault(addr, [int(now), 0])
        if r[0] != int(now):
            r[0], r[1] = int(now), 0
        r[1] += 1
        if r[1] > RATE:
            return
        if join:
            if room not in self.rooms and len(self.rooms) >= MAX_ROOMS:
                return
            members = self.rooms.setdefault(room, {})
            members[addr] = now
            if len(members) > 2: # üçüncü gelirse en eskisi düşer
                old = min(members, key=members.get)
                del members[old]
                self.where.pop(old, None)
            old_room = self.where.get(addr)
            if old_room is not None and old_room != room:
                self.rooms.get(old_room, {}).pop(addr, None)
            self.where[addr] = room
            self.t.sendto(MAGIC + b"ok", addr)
            return
        room = self.where.get(addr)
        if room is None:
            return
        members = self.rooms.get(room, {})
        if addr in members:
            members[addr] = now
        for other in members:
            if other != addr:
                self.t.sendto(data, other)

    def prune(self) -> None:
        now = time.monotonic()
        for room in list(self.rooms):
            members = self.rooms[room]
            for a in [a for a, t in members.items() if now - t > TTL]:
                del members[a]
                self.where.pop(a, None)
            if not members:
                del self.rooms[room]
        self.rate = {a: r for a, r in self.rate.items() if now - r[0] < 5}


async def main() -> None:
    loop = asyncio.get_running_loop()
    relay = Relay()
    await loop.create_datagram_endpoint(lambda: relay, local_addr=("0.0.0.0", PORT))
    print("aktarma sunucusu udp/%d" % PORT, flush=True)
    while True:
        await asyncio.sleep(10)
        relay.prune()


if __name__ == "__main__":
    asyncio.run(main())
