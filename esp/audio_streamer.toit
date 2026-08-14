import net
import net.udp as udp
import monitor show Channel
import log
import i2s
import io show LITTLE-ENDIAN

AUDIO-PORT ::= 4440

BCLK-PIN ::= 32
WS-PIN ::= 33
SDOUT-PIN ::= 12
SDIN-PIN ::= 13

// 480 mono 16-bit frames = 960 bytes UDP (10 ms), played directly via 16-bit I2S
UDP-FRAME-BYTES ::= 960
I2S-FRAME-BYTES ::= 960

MAX-QUEUE-FRAMES ::= 10   // 100 ms max buffer (heap under 10KB)
PREBUFFER-FRAMES ::= 4    // 40 ms cushion

RX-QUEUE ::= Channel MAX-QUEUE-FRAMES

class AudioStreamer:
  network/net.Interface
  socket/udp.Socket? := null
  i2s-bus/i2s.Bus? := null

  rx-count/int := 0
  write-count/int := 0
  underrun-count/int := 0
  drop-count/int := 0

  constructor --.network:

  init-i2s -> none:
    log.info "Initializing I2S Master Bus (BCLK=$BCLK-PIN WS=$WS-PIN SDOUT=$SDOUT-PIN SDIN=$SDIN-PIN)"
    err := catch:
      i2s-bus = i2s.Bus
        --master=true
        --sck=BCLK-PIN
        --ws=WS-PIN
        --tx=SDOUT-PIN
        --rx=SDIN-PIN
      i2s-bus.configure
        --sample-rate=48000
        --bits-per-sample=16
        --slots-out=i2s.Bus.SLOTS-MONO-BOTH
        --slots-in=i2s.Bus.SLOTS-MONO-LEFT
      i2s-bus.start
      log.info "I2S Master Bus successfully started at 48kHz 16-bit Mono"
    if err:
      log.error "I2S init failed: $err"

  run -> none:
    socket = network.udp-open --port=AUDIO-PORT
    log.info "Proto-13 Mono-to-Stereo Streamer active on UDP port $AUDIO-PORT (100 pkts/s)"
    
    init-i2s
    task:: i2s-write-loop
    task:: stats-loop

    while true:
      err := catch:
        gram := socket.receive
        if gram.data.size == UDP-FRAME-BYTES:
          rx-count++
          if RX-QUEUE.size < MAX-QUEUE-FRAMES:
            RX-QUEUE.send gram.data
          else:
            drop-count++
      if err:
        log.error "UDP packet error: $err"

  i2s-write-loop -> none:
    silence-buf := ByteArray I2S-FRAME-BYTES
    is-prebuffering := true

    while true:
      if is-prebuffering:
        if RX-QUEUE.size < PREBUFFER-FRAMES:
          if i2s-bus:
            catch: i2s-bus.write silence-buf
          continue
        else:
          is-prebuffering = false
          log.info "Pre-buffering complete, starting playback (Cushion: $RX-QUEUE.size packets)"

      buf := null
      is-silence := false
      if RX-QUEUE.size == 0:
        underrun-count++
        is-prebuffering = true
        buf = silence-buf
        is-silence = true
      else:
        buf = RX-QUEUE.receive

      if i2s-bus:
        err := catch:
          i2s-bus.write buf
          if not is-silence:
            write-count++
        if err:
          log.error "I2S write error: $err"

  stats-loop -> none:
    while true:
      sleep (Duration --s=2)
      log.info "STREAM TELEM -> UDP RX:$rx-count | I2S TX:$write-count | Underruns:$underrun-count | Drops:$drop-count | Q:$RX-QUEUE.size"



main:
  network := net.open
  log.info "Starting Proto-13 Clean Blocking Audio Streamer"
  streamer := AudioStreamer --network=network
  streamer.run
