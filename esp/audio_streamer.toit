import net
import monitor show Channel
import i2s
import uart

AUDIO-PORT ::= 4440

I2S-CLK-PIN  ::= 32
I2S-WS-PIN   ::= 33
I2S-OUT-PIN  ::= 12

UDP-FRAME-BYTES ::= 960
I2S-FRAME-BYTES ::= 960

MAX-QUEUE-FRAMES ::= 25
PREBUFFER-FRAMES ::= 5

RX-QUEUE ::= Channel MAX-QUEUE-FRAMES

class AudioStreamer:
  network/net.Interface
  i2s-bus/i2s.Bus? := null
  usb-active-until/int := 0

  constructor --.network:

  init-i2s -> none:
    catch:
      i2s-bus = i2s.Bus
        --master=true
        --sck=I2S-CLK-PIN
        --ws=I2S-WS-PIN
        --tx=I2S-OUT-PIN
      i2s-bus.configure
        --sample-rate=48000
        --bits-per-sample=16
        --slots-out=i2s.Bus.SLOTS-MONO-BOTH
        --slots-in=i2s.Bus.SLOTS-MONO-LEFT
      i2s-bus.start

  write-frame buffer/ByteArray -> bool:
    if i2s-bus == null: return false
    err := catch: i2s-bus.write buffer
    return err == null

  run -> none:
    socket := network.udp-open --port=AUDIO-PORT

    init-i2s
    task:: i2s-write-loop
    task:: uart-read-loop

    while true:
      catch:
        datagram := socket.receive
        if datagram.data.size == UDP-FRAME-BYTES:
          // Ignore UDP packets if USB is actively streaming
          if Time.monotonic_us < usb-active-until: continue

          if RX-QUEUE.size < MAX-QUEUE-FRAMES:
            RX-QUEUE.send datagram.data

  uart-read-loop -> none:
    port/uart.Port? := null
    err := catch:
      port = uart.Port --rx=3 --tx=1 --baud_rate=2000000
    
    if err != null or not port:
      print "UART0 init failed with error: $err"
      return
    
    print "UART0 listening at 2000000 baud on pins rx=3 tx=1"
    reader := port.in
    synchronizer := PacketSynchronizer
    rx-count := 0
    
    while true:
      err2 := catch:
        frame := synchronizer.read-frame reader
        if RX-QUEUE.size < MAX-QUEUE-FRAMES:
          RX-QUEUE.send frame
        usb-active-until = Time.monotonic_us + 1_000_000
        rx-count++
        if rx-count % 100 == 0:
          print "UART received $rx-count frames"
      if err2 != null:
        print "UART frame read error: $err2"

  i2s-write-loop -> none:
    silence-buf := ByteArray I2S-FRAME-BYTES
    buffered := false

    while true:
      if not buffered:
        if RX-QUEUE.size < PREBUFFER-FRAMES:
          write-frame silence-buf
          sleep --ms=0
          continue
        buffered = true

      if RX-QUEUE.size > 0:
        write-frame RX-QUEUE.receive
      else:
        buffered = false
        write-frame silence-buf

      sleep --ms=0

main:
  network := net.open
  streamer := AudioStreamer --network=network
  streamer.run

class PacketSynchronizer:
  read-frame reader -> ByteArray:
    align-to-next-frame reader
    return reader.read-bytes UDP-FRAME-BYTES

  align-to-next-frame reader -> none:
    while true:
      reader.skip-up-to 0x5a
      peek := reader.peek-bytes 3
      if peek[0] == 0xa5 and peek[1] == 0x5a and peek[2] == 0xa5:
        reader.skip 3
        return
