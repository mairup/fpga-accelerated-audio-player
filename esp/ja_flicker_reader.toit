import gpio

// Flash FPGA with TopJaFlicker.bit first.
// JA pin frequencies: JA1=1 JA2=2 JA3=4 JA4=8 JA7=16 JA8=32 JA9=64 JA10=128
// Correct wiring: GPIO13->JA4(8) GPIO32->JA7(16) GPIO33->JA8(32) GPIO12->JA9(64)

main:
  p12 := gpio.Pin.in 12
  p13 := gpio.Pin.in 13
  p32 := gpio.Pin.in 32
  p33 := gpio.Pin.in 33
  a := 0
  b := 0
  c := 0
  d := 0
  ca := 0
  cb := 0
  cc := 0
  cd := 0
  ms := 0
  while ms < 2000:
    v := p12.get
    if v == 1 and a == 0: ca += 1
    a = v
    v = p13.get
    if v == 1 and b == 0: cb += 1
    b = v
    v = p32.get
    if v == 1 and c == 0: cc += 1
    c = v
    v = p33.get
    if v == 1 and d == 0: cd += 1
    d = v
    sleep --ms=1
    ms += 1
  print "GPIO12: ~$(ca / 2) Hz (want 64 = JA9)"
  print "GPIO13: ~$(cb / 2) Hz (want 8  = JA4)"
  print "GPIO32: ~$(cc / 2) Hz (want 16 = JA7)"
  print "GPIO33: ~$(cd / 2) Hz (want 32 = JA8)"
