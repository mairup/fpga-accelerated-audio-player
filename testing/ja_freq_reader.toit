import gpio

main:
  p12 := gpio.Pin.in 12
  p13 := gpio.Pin.in 13
  p32 := gpio.Pin.in 32
  p33 := gpio.Pin.in 33

  sample-and-report p12 p13 p32 p33

sample-and-report p12/gpio.Pin p13/gpio.Pin p32/gpio.Pin p33/gpio.Pin:
  while true:
    count-12 := 0
    count-33 := 0
    count-13 := 0
    count-32 := 0

    previous-12 := p12.get
    previous-33 := p33.get
    previous-13 := p13.get
    previous-32 := p32.get

    deadline := Time.monotonic_us + 2_000_000
    while Time.monotonic_us < deadline:
      val-12 := p12.get
      if val-12 == 1 and previous-12 == 0: count-12++
      previous-12 = val-12

      val-33 := p33.get
      if val-33 == 1 and previous-33 == 0: count-33++
      previous-33 = val-33

      val-13 := p13.get
      if val-13 == 1 and previous-13 == 0: count-13++
      previous-13 = val-13

      val-32 := p32.get
      if val-32 == 1 and previous-32 == 0: count-32++
      previous-32 = val-32

      yield

    print "GPIO12: $count-12 counts in 2s (~$(count-12 / 2) Hz) -> JA7  (16 Hz)"
    print "GPIO33: $count-33 counts in 2s (~$(count-33 / 2) Hz) -> JA8  (32 Hz)"
    print "GPIO13: $count-13 counts in 2s (~$(count-13 / 2) Hz) -> JA9  (64 Hz)"
    print "GPIO32: $count-32 counts in 2s (~$(count-32 / 2) Hz) -> JA10 (128 Hz)"
    print "--------------------------------------------------"
