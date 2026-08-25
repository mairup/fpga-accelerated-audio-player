import net
import monitor show Channel
import i2s
import uart

AUDIO-PORT ::= 4440

BCLK-PIN  ::= 32
WS-PIN    ::= 33
SDOUT-PIN ::= 12

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
        --sck=BCLK-PIN
        --ws=WS-PIN
        --tx=SDOUT-PIN
      i2s-bus.configure
        --sample-rate=48000
        --bits-per-sample=16
        --slots-out=i2s.Bus.SLOTS-MONO-BOTH
        --slots-in=i2s.Bus.SLOTS-MONO-LEFT
      i2s-bus.start

  write-frame buf/ByteArray -> bool:
    if i2s-bus == null: return false
    err := catch: i2s-bus.write buf
    return err == null

  run -> none:
    socket := network.udp-open --port=AUDIO-PORT

    init-i2s
    task:: i2s-write-loop
    task:: uart-read-loop

    while true:
      catch:
        gram := socket.receive
        if gram.data.size == UDP-FRAME-BYTES:
          // Ignore UDP packets if USB is actively streaming
          if Time.monotonic_us < usb-active-until: continue

          if RX-QUEUE.size < MAX-QUEUE-FRAMES:
            RX-QUEUE.send gram.data

  uart-read-loop -> none:
    // We catch exceptions here because claiming Pins 1/3 (UART0)
    // might disrupt Jaguar's monitor.
    catch:
      port := uart.Port --rx=3 --tx=1 --baud_rate=2000000
      reader := port.in
      buf := ByteArray UDP-FRAME-BYTES
      idx := 0
      while true:
        chunk := reader.read
        for i := 0; i < chunk.size; i++:
          buf[idx++] = chunk[i]
          if idx == UDP-FRAME-BYTES:
            if RX-QUEUE.size < MAX-QUEUE-FRAMES:
              RX-QUEUE.send buf.copy
            usb-active-until = Time.monotonic_us + 1_000_000
            idx = 0

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
