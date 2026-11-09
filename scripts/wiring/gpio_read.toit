// GPIO wiring reader: reports per-pin steady levels + edge counts over UDP.
// Usage: make wiring-test (rewrites PC-IP), or edit PC-IP and: jag run scripts/wiring/gpio_read.toit
import net
import net.udp
import net.ip_address show IpAddress
import net.socket_address show SocketAddress
import gpio

PC-IP ::= "192.168.5.100"
PC-PORT ::= 9998
DURATION-S ::= 4
CANDIDATES ::= [4, 5, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 25, 26, 27, 32, 33, 34, 35, 36, 39]

main:
  network := net.open
  socket := network.udp-open
  address := SocketAddress (IpAddress.parse PC-IP) PC-PORT

  socket.send (udp.Datagram ("reader-start".to-byte-array) address)

  pins := List
  nums := List
  for j := 0; j < CANDIDATES.size; j++:
    p := CANDIDATES[j]
    err := catch:
      pins.add (gpio.Pin.in p)
      nums.add p
    if err != null:
      socket.send (udp.Datagram ("open-fail:$p".to-byte-array) address)

  counts := List
  firsts := List
  lasts := List
  for i := 0; i < pins.size; i++:
    counts.add 0
    firsts.add (pins[i].get)
    lasts.add (pins[i].get)

  start := Time.monotonic-us
  deadline := DURATION-S * 1000000
  while (Time.monotonic-us - start) < deadline:
    for i := 0; i < pins.size; i++:
      v := pins[i].get
      if v != lasts[i]:
        lasts[i] = v
        counts[i] = counts[i] + 1
    sleep --ms=1

  level-parts := List
  for i := 0; i < pins.size; i++:
    level-parts.add "$(nums[i])=$(firsts[i])->$(lasts[i])"
  socket.send (udp.Datagram ("LEVELS:$(level-parts.join ",")".to-byte-array) address)

  parts := List
  for i := 0; i < pins.size; i++:
    if counts[i] >= 5:
      parts.add "$(nums[i]):$(counts[i])"
  socket.send (udp.Datagram ("EDGE-MAP:$(parts.join ",")".to-byte-array) address)
  sleep --ms=2000
