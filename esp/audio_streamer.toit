import net
import net.udp as udp
import monitor show Channel
import log
import i2s
import io show LITTLE-ENDIAN
import gpio.adc show Adc

AUDIO-PORT ::= 4440

BCLK-PIN  ::= 32
WS-PIN    ::= 33
SDOUT-PIN ::= 12
SDIN-PIN  ::= 13
ADC-PIN   ::= 34

VOLT-MIN ::= 0.1420
VOLT-MAX ::= 3.1390
ADC-POLL-MS ::= 50

UDP-FRAME-BYTES ::= 960
I2S-FRAME-BYTES ::= 960

MAX-QUEUE-FRAMES ::= 10

RX-QUEUE ::= Channel MAX-QUEUE-FRAMES

class AudioStreamer:
  network/net.Interface
  socket/udp.Socket? := null
  i2s-bus/i2s.Bus?   := null
  adc/Adc?           := null

  volume-gain/float    := 1.0
  volume-voltage/float := 3.14

  rx-count/int       := 0
  write-count/int    := 0
  drop-count/int     := 0

  constructor --.network:

  init-adc -> none:
    err := catch:
      adc = Adc ADC-PIN --max-voltage=3.3
      log.info "ADC Volume Initialized on GPIO $ADC-PIN"
    if err:
      log.error "ADC init failed on GPIO $ADC-PIN: $err"

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
      log.info "I2S Master Bus started at 48kHz 16-bit Mono"
    if err:
      log.error "I2S init failed: $err"

  calculate-gain v/float -> float:
    if v <= VOLT-MIN: return 0.0
    if v >= VOLT-MAX: return 1.0
    return (v - VOLT-MIN) / (VOLT-MAX - VOLT-MIN)

  volume-poll-loop -> none:
    while true:
      if adc:
        err := catch:
          v := adc.get --samples=1
          volume-voltage = v
          volume-gain = calculate-gain v
        if err:
          log.error "ADC read error: $err"
      sleep --ms=ADC-POLL-MS

  /**
  Scales 16-bit little-endian PCM samples in-place using 4x loop unrolling.
  Processing in-place avoids heap allocations and GC pauses, while unrolling
  reduces bytecode loop overhead to prevent UDP receive packet drops.
  */
  apply-pcm-gain buf/ByteArray mult/int -> none:
    size := buf.size
    i := 0
    while i < size:
      s0 := LITTLE-ENDIAN.int16 buf i
      s1 := LITTLE-ENDIAN.int16 buf i + 2
      s2 := LITTLE-ENDIAN.int16 buf i + 4
      s3 := LITTLE-ENDIAN.int16 buf i + 6
      LITTLE-ENDIAN.put-int16 buf i ((s0 * mult) >> 15)
      LITTLE-ENDIAN.put-int16 buf i + 2 ((s1 * mult) >> 15)
      LITTLE-ENDIAN.put-int16 buf i + 4 ((s2 * mult) >> 15)
      LITTLE-ENDIAN.put-int16 buf i + 6 ((s3 * mult) >> 15)
      i += 8

  scale-samples buf/ByteArray -> none:
    gain := volume-gain
    if gain >= 0.999: return
    if gain <= 0.001:
      buf.fill 0
      return
    mult := (gain * 32768.0).to-int
    apply-pcm-gain buf mult

  run -> none:
    socket = network.udp-open --port=AUDIO-PORT
    log.info "UDP audio receiver active on port $AUDIO-PORT"

    init-i2s
    init-adc
    task:: volume-poll-loop
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
        log.error "UDP RX error: $err"
        sleep --ms=1

  i2s-write-loop -> none:
    silence-buf := ByteArray I2S-FRAME-BYTES

    while true:
      buf := null
      if RX-QUEUE.size == 0:
        buf = silence-buf
      else:
        buf = RX-QUEUE.receive
        scale-samples buf

      if i2s-bus:
        i2s-bus.write buf
        write-count++

      sleep --ms=0

  stats-loop -> none:
    while true:
      sleep (Duration --s=2)
      vol-pct := (volume-gain * 100.0).to-int
      log.info "TELEM -> VOL: $(vol-pct)% ($(%.2f volume-voltage)V) | UDP RX:$rx-count | I2S TX:$write-count | Drops:$drop-count | Q:$RX-QUEUE.size"

main:
  network := net.open
  log.info "Starting Mono-16bit Audio Streamer"
  streamer := AudioStreamer --network=network
  streamer.run
