import net
import net.udp as udp
import monitor show Channel
import log
import i2s
import uart
import gpio.adc show Adc

AUDIO-PORT ::= 4440

BCLK-PIN  ::= 32
WS-PIN    ::= 33
SDOUT-PIN ::= 12
ADC-PIN   ::= 34
UART-TX-PIN ::= 13

VOLT-MIN ::= 0.1420
VOLT-MAX ::= 3.1390
ADC-POLL-MS ::= 50

FRAME-BYTES ::= 960

MAX-QUEUE-FRAMES ::= 10

RX-QUEUE ::= Channel MAX-QUEUE-FRAMES

class AudioStreamer:
  network/net.Interface
  socket/udp.Socket? := null
  i2s-bus/i2s.Bus?   := null
  adc/Adc?           := null
  uart-bus/uart.Port? := null

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
        --slots-in=i2s.Bus.SLOTS-MONO-LEFT
        --slots-out=i2s.Bus.SLOTS-MONO-BOTH
      i2s-bus.start
      log.info "I2S Master Bus started at 48kHz 16-bit Mono (no SDIN — GPIO 13 repurposed for UART TX)"
    if err:
      log.error "I2S init failed: $err"

  init-uart -> none:
    err := catch:
      uart-bus = uart.Port --tx=UART-TX-PIN --baud-rate=115200
      log.info "UART TX initialized on GPIO $UART-TX-PIN @ 115200 baud"
    if err:
      log.error "UART init failed on GPIO $UART-TX-PIN: $err"

  calculate-gain v/float -> float:
    if v <= VOLT-MIN: return 0.0
    if v >= VOLT-MAX: return 1.0
    return (v - VOLT-MIN) / (VOLT-MAX - VOLT-MIN)

  volume-poll-loop -> none:
    cfg-buf := ByteArray 5
    cfg-buf[0] = 0xAA
    cfg-buf[1] = 0x01
    cfg-buf[2] = 0x01
    while true:
      if adc:
        err := catch:
          v := adc.get --samples=1
          volume-voltage = v
          volume-gain = calculate-gain v
        if err:
          log.error "ADC read error: $err"
      if uart-bus:
        vol := (volume-gain * 0x7FFF).to-int
        cfg-buf[3] = (vol >> 8) & 0xFF
        cfg-buf[4] = vol & 0xFF
        uart-bus.out.write cfg-buf
      sleep --ms=ADC-POLL-MS

  run -> none:
    socket = network.udp-open --port=AUDIO-PORT
    log.info "UDP audio receiver active on port $AUDIO-PORT"

    init-i2s
    init-adc
    init-uart
    task:: volume-poll-loop
    task:: i2s-write-loop
    task:: stats-loop

    while true:
      err := catch:
        gram := socket.receive
        if gram.data.size == FRAME-BYTES:
          rx-count++
          if RX-QUEUE.size < MAX-QUEUE-FRAMES:
            RX-QUEUE.send gram.data
          else:
            drop-count++
      if err:
        log.error "UDP RX error: $err"
      sleep --ms=1

  i2s-write-loop -> none:
    silence-buf := ByteArray FRAME-BYTES

    while true:
      buf := null
      if RX-QUEUE.size == 0:
        buf = silence-buf
      else:
        buf = RX-QUEUE.receive

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
