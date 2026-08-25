import uart
import gpio

main:
  print "trying uart0"
  rx_pin := gpio.Pin 3
  tx_pin := gpio.Pin 1
  port := uart.Port --tx=tx_pin --rx=rx_pin --baud_rate=2000000
  print "uart0 opened"
