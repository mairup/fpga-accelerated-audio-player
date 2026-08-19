import net
import monitor show Channel
import log
import i2s
import gpio.adc show Adc

AUDIO-PORT ::= 4440

BCLK-PIN  ::= 32
WS-PIN    ::= 33
SDOUT-PIN ::= 12
ADC-PIN   ::= 34

VOL-POT-MIN ::= 0.1420
VOL-POT-MAX ::= 3.1390
ADC-POLL-MS ::= 50

UDP-FRAME-BYTES ::= 960
I2S-FRAME-BYTES ::= 960

MAX-QUEUE-FRAMES ::= 25
PREBUFFER-FRAMES ::= 5

RX-QUEUE ::= Channel MAX-QUEUE-FRAMES

class AudioStreamer:
  network/net.Interface
  i2s-bus/i2s.Bus? := null
  adc/Adc?         := null

  volume-gain/float    := 1.0
  volume-voltage/float := 3.14

  rx-count/int       := 0
  write-count/int    := 0
  underrun-count/int := 0
  drop-count/int     := 0

  constructor --.network:

  init-adc -> none:
    err := catch:
      adc = Adc ADC-PIN --max-voltage=3.3
      log.info "ADC Volume Initialized on GPIO $ADC-PIN"
    if err != null:
      log.error "ADC init failed on GPIO $ADC-PIN: $err"

  init-i2s -> none:
    log.info "Initializing I2S Master Bus (BCLK=$BCLK-PIN WS=$WS-PIN SDOUT=$SDOUT-PIN)"
    err := catch:
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
      log.info "I2S Master Bus started at 48kHz 16-bit Mono"
    if err != null:
      log.error "I2S init failed: $err"

  calculate-gain v/float -> float:
    if v <= VOL-POT-MIN: return 0.0
    if v >= VOL-POT-MAX: return 1.0
    return (v - VOL-POT-MIN) / (VOL-POT-MAX - VOL-POT-MIN)

  write-frame buf/ByteArray -> bool:
    if i2s-bus == null: return false
    err := catch: i2s-bus.write buf
    if err != null:
      log.error "I2S write error: $err"
      return false
    return true

  volume-poll-loop -> none:
    while true:
      if adc != null:
        err := catch:
          v := adc.get --samples=1
          volume-voltage = v
          volume-gain = calculate-gain v
        if err != null:
          log.error "ADC read error: $err"
      sleep --ms=ADC-POLL-MS

  run -> none:
    socket := network.udp-open --port=AUDIO-PORT
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
      if err != null:
        log.error "UDP RX error: $err"
        sleep --ms=1

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
        if write-frame RX-QUEUE.receive:
          write-count++
      else:
        underrun-count++
        buffered = false
        write-frame silence-buf

      sleep --ms=0

  stats-loop -> none:
    while true:
      sleep (Duration --s=2)
      vol-pct := (volume-gain * 100.0).to-int
      log.info "TELEM -> VOL: $(vol-pct)% ($(%.2f volume-voltage)V) | UDP RX:$rx-count | I2S TX:$write-count | Underruns:$underrun-count | Drops:$drop-count | Q:$RX-QUEUE.size"

main:
  network := net.open
  log.info "Starting Mono-16bit Audio Streamer"
  streamer := AudioStreamer --network=network
  streamer.run
