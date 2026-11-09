module UartTransmitter(
  input        clock,
  input        reset,
  input  [7:0] io_inputDataByte, // @[src/main/scala/fpga/UartTransmitter.scala 7:14]
  input        io_transmitValid, // @[src/main/scala/fpga/UartTransmitter.scala 7:14]
  output       io_transmitterReady, // @[src/main/scala/fpga/UartTransmitter.scala 7:14]
  output       io_serialTxPin // @[src/main/scala/fpga/UartTransmitter.scala 7:14]
);
`ifdef RANDOMIZE_REG_INIT
  reg [31:0] _RAND_0;
  reg [31:0] _RAND_1;
  reg [31:0] _RAND_2;
  reg [31:0] _RAND_3;
`endif // RANDOMIZE_REG_INIT
  reg [9:0] cycleCounter; // @[src/main/scala/fpga/UartTransmitter.scala 15:29]
  reg [3:0] bitIndexCounter; // @[src/main/scala/fpga/UartTransmitter.scala 16:32]
  reg [9:0] shiftRegister; // @[src/main/scala/fpga/UartTransmitter.scala 18:30]
  reg  isTransmittingState; // @[src/main/scala/fpga/UartTransmitter.scala 19:36]
  wire [9:0] _shiftRegister_T_1 = {1'h1,shiftRegister[9:1]}; // @[src/main/scala/fpga/UartTransmitter.scala 27:27]
  wire [3:0] _bitIndexCounter_T_1 = bitIndexCounter + 4'h1; // @[src/main/scala/fpga/UartTransmitter.scala 33:44]
  wire [9:0] _cycleCounter_T_1 = cycleCounter + 10'h1; // @[src/main/scala/fpga/UartTransmitter.scala 36:36]
  wire [9:0] _shiftRegister_T_2 = {1'h1,io_inputDataByte,1'h0}; // @[src/main/scala/fpga/UartTransmitter.scala 40:27]
  wire  _GEN_7 = io_transmitValid | isTransmittingState; // @[src/main/scala/fpga/UartTransmitter.scala 39:28 41:27 19:36]
  assign io_transmitterReady = ~isTransmittingState; // @[src/main/scala/fpga/UartTransmitter.scala 21:26]
  assign io_serialTxPin = shiftRegister[0]; // @[src/main/scala/fpga/UartTransmitter.scala 22:34]
  always @(posedge clock or posedge reset) begin
    if (reset) begin // @[src/main/scala/fpga/UartTransmitter.scala 24:29]
      cycleCounter <= 10'h0; // @[src/main/scala/fpga/UartTransmitter.scala 25:54 26:20 36:20]
    end else if (isTransmittingState) begin // @[src/main/scala/fpga/UartTransmitter.scala 39:28]
      if (cycleCounter == 10'h363) begin // @[src/main/scala/fpga/UartTransmitter.scala 42:20]
        cycleCounter <= 10'h0;
      end else begin
        cycleCounter <= _cycleCounter_T_1;
      end
    end else if (io_transmitValid) begin // @[src/main/scala/fpga/UartTransmitter.scala 15:29]
      cycleCounter <= 10'h0;
    end
  end
  always @(posedge clock or posedge reset) begin
    if (reset) begin // @[src/main/scala/fpga/UartTransmitter.scala 24:29]
      bitIndexCounter <= 4'h0; // @[src/main/scala/fpga/UartTransmitter.scala 25:54 29:37 31:25 33:25 16:32]
    end else if (isTransmittingState) begin // @[src/main/scala/fpga/UartTransmitter.scala 39:28]
      if (cycleCounter == 10'h363) begin // @[src/main/scala/fpga/UartTransmitter.scala 43:23]
        if (bitIndexCounter == 4'h9) begin
          bitIndexCounter <= 4'h0;
        end else begin
          bitIndexCounter <= _bitIndexCounter_T_1;
        end
      end
    end else if (io_transmitValid) begin // @[src/main/scala/fpga/UartTransmitter.scala 16:32]
      bitIndexCounter <= 4'h0;
    end
  end
  always @(posedge clock or posedge reset) begin
    if (reset) begin // @[src/main/scala/fpga/UartTransmitter.scala 24:29]
      shiftRegister <= 10'h1; // @[src/main/scala/fpga/UartTransmitter.scala 25:54 27:21 18:30]
    end else if (isTransmittingState) begin // @[src/main/scala/fpga/UartTransmitter.scala 39:28]
      if (cycleCounter == 10'h363) begin // @[src/main/scala/fpga/UartTransmitter.scala 40:21]
        shiftRegister <= _shiftRegister_T_1;
      end
    end else if (io_transmitValid) begin // @[src/main/scala/fpga/UartTransmitter.scala 18:30]
      shiftRegister <= _shiftRegister_T_2;
    end
  end
  always @(posedge clock or posedge reset) begin
    if (reset) begin // @[src/main/scala/fpga/UartTransmitter.scala 24:29]
      isTransmittingState <= 1'h0; // @[src/main/scala/fpga/UartTransmitter.scala 25:54 29:37 30:29 19:{36,36}]
    end else if (isTransmittingState) begin
      if (cycleCounter == 10'h363) begin
        if (bitIndexCounter == 4'h9) begin
          isTransmittingState <= 1'h0;
        end
      end
    end else begin
      isTransmittingState <= _GEN_7;
    end
  end
// Register and memory initialization
`ifdef RANDOMIZE_GARBAGE_ASSIGN
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_INVALID_ASSIGN
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_REG_INIT
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_MEM_INIT
`define RANDOMIZE
`endif
`ifndef RANDOM
`define RANDOM $random
`endif
`ifdef RANDOMIZE_MEM_INIT
  integer initvar;
`endif
`ifndef SYNTHESIS
`ifdef FIRRTL_BEFORE_INITIAL
`FIRRTL_BEFORE_INITIAL
`endif
initial begin
  `ifdef RANDOMIZE
    `ifdef INIT_RANDOM
      `INIT_RANDOM
    `endif
    `ifndef VERILATOR
      `ifdef RANDOMIZE_DELAY
        #`RANDOMIZE_DELAY begin end
      `else
        #0.002 begin end
      `endif
    `endif
`ifdef RANDOMIZE_REG_INIT
  _RAND_0 = {1{`RANDOM}};
  cycleCounter = _RAND_0[9:0];
  _RAND_1 = {1{`RANDOM}};
  bitIndexCounter = _RAND_1[3:0];
  _RAND_2 = {1{`RANDOM}};
  shiftRegister = _RAND_2[9:0];
  _RAND_3 = {1{`RANDOM}};
  isTransmittingState = _RAND_3[0:0];
`endif // RANDOMIZE_REG_INIT
  if (reset) begin
    cycleCounter = 10'h0;
  end
  if (reset) begin
    bitIndexCounter = 4'h0;
  end
  if (reset) begin
    shiftRegister = 10'h1;
  end
  if (reset) begin
    isTransmittingState = 1'h0;
  end
  `endif // RANDOMIZE
end // initial
`ifdef FIRRTL_AFTER_INITIAL
`FIRRTL_AFTER_INITIAL
`endif
`endif // SYNTHESIS
endmodule
module JaDriveTop(
  input   clock,
  input   reset,
  output  io_jaPins_0, // @[src/main/scala/fpga/JaDriveTop.scala 7:14]
  output  io_jaPins_1, // @[src/main/scala/fpga/JaDriveTop.scala 7:14]
  output  io_jaPins_2, // @[src/main/scala/fpga/JaDriveTop.scala 7:14]
  output  io_jaPins_3, // @[src/main/scala/fpga/JaDriveTop.scala 7:14]
  output  io_jaPins_4, // @[src/main/scala/fpga/JaDriveTop.scala 7:14]
  output  io_jaPins_5, // @[src/main/scala/fpga/JaDriveTop.scala 7:14]
  output  io_jaPins_6, // @[src/main/scala/fpga/JaDriveTop.scala 7:14]
  output  io_jaPins_7, // @[src/main/scala/fpga/JaDriveTop.scala 7:14]
  output  io_txSerialPin // @[src/main/scala/fpga/JaDriveTop.scala 7:14]
);
`ifdef RANDOMIZE_REG_INIT
  reg [31:0] _RAND_0;
  reg [31:0] _RAND_1;
  reg [31:0] _RAND_2;
  reg [31:0] _RAND_3;
  reg [31:0] _RAND_4;
  reg [31:0] _RAND_5;
  reg [31:0] _RAND_6;
  reg [31:0] _RAND_7;
  reg [31:0] _RAND_8;
  reg [31:0] _RAND_9;
  reg [31:0] _RAND_10;
  reg [31:0] _RAND_11;
  reg [31:0] _RAND_12;
  reg [31:0] _RAND_13;
  reg [31:0] _RAND_14;
  reg [31:0] _RAND_15;
  reg [31:0] _RAND_16;
  reg [31:0] _RAND_17;
  reg [31:0] _RAND_18;
`endif // RANDOMIZE_REG_INIT
  wire  uart_clock; // @[src/main/scala/fpga/JaDriveTop.scala 13:22]
  wire  uart_reset; // @[src/main/scala/fpga/JaDriveTop.scala 13:22]
  wire [7:0] uart_io_inputDataByte; // @[src/main/scala/fpga/JaDriveTop.scala 13:22]
  wire  uart_io_transmitValid; // @[src/main/scala/fpga/JaDriveTop.scala 13:22]
  wire  uart_io_transmitterReady; // @[src/main/scala/fpga/JaDriveTop.scala 13:22]
  wire  uart_io_serialTxPin; // @[src/main/scala/fpga/JaDriveTop.scala 13:22]
  wire  _GEN_0 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  reg [25:0] cnt; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  wire  _GEN_1 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  reg  outReg; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  wire [25:0] _cnt_T_1 = cnt + 26'h1; // @[src/main/scala/fpga/JaDriveTop.scala 22:18]
  wire  _GEN_2 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  reg [25:0] cnt_1; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  wire  _GEN_3 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  reg  outReg_1; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  wire [25:0] _cnt_T_3 = cnt_1 + 26'h1; // @[src/main/scala/fpga/JaDriveTop.scala 22:18]
  wire  _GEN_4 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  reg [25:0] cnt_2; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  wire  _GEN_5 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  reg  outReg_2; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  wire [25:0] _cnt_T_5 = cnt_2 + 26'h1; // @[src/main/scala/fpga/JaDriveTop.scala 22:18]
  wire  _GEN_6 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  reg [25:0] cnt_3; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  wire  _GEN_7 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  reg  outReg_3; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  wire [25:0] _cnt_T_7 = cnt_3 + 26'h1; // @[src/main/scala/fpga/JaDriveTop.scala 22:18]
  wire  _GEN_8 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  reg [25:0] cnt_4; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  wire  _GEN_9 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  reg  outReg_4; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  wire [25:0] _cnt_T_9 = cnt_4 + 26'h1; // @[src/main/scala/fpga/JaDriveTop.scala 22:18]
  wire  _GEN_10 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  reg [25:0] cnt_5; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  wire  _GEN_11 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  reg  outReg_5; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  wire [25:0] _cnt_T_11 = cnt_5 + 26'h1; // @[src/main/scala/fpga/JaDriveTop.scala 22:18]
  wire  _GEN_12 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  reg [25:0] cnt_6; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  wire  _GEN_13 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  reg  outReg_6; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  wire [25:0] _cnt_T_13 = cnt_6 + 26'h1; // @[src/main/scala/fpga/JaDriveTop.scala 22:18]
  wire  _GEN_14 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  reg [25:0] cnt_7; // @[src/main/scala/fpga/JaDriveTop.scala 20:24]
  wire  _GEN_15 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  reg  outReg_7; // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
  wire [25:0] _cnt_T_15 = cnt_7 + 26'h1; // @[src/main/scala/fpga/JaDriveTop.scala 22:18]
  wire  _GEN_16 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 30:30]
  reg [26:0] windowTimer; // @[src/main/scala/fpga/JaDriveTop.scala 30:30]
  wire [26:0] _windowTimer_T_1 = windowTimer + 27'h1; // @[src/main/scala/fpga/JaDriveTop.scala 32:32]
  wire  windowClear = windowTimer == 27'h5f5e0ff; // @[src/main/scala/fpga/JaDriveTop.scala 33:22]
  wire  _GEN_17 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 41:27]
  reg [3:0] msgIndex; // @[src/main/scala/fpga/JaDriveTop.scala 41:27]
  wire  _GEN_24 = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 42:34]
  reg  msgTransmitting; // @[src/main/scala/fpga/JaDriveTop.scala 42:34]
  wire  _GEN_18 = windowClear & ~msgTransmitting & uart_io_transmitterReady | msgTransmitting; // @[src/main/scala/fpga/JaDriveTop.scala 44:71 45:23 42:34]
  wire [3:0] _GEN_19 = windowClear & ~msgTransmitting & uart_io_transmitterReady ? 4'h0 : msgIndex; // @[src/main/scala/fpga/JaDriveTop.scala 44:71 46:16 41:27]
  wire [3:0] _msgIndex_T_1 = msgIndex + 4'h1; // @[src/main/scala/fpga/JaDriveTop.scala 54:32]
  wire [7:0] _GEN_27 = 3'h1 == msgIndex[2:0] ? 8'h4c : 8'h41; // @[src/main/scala/fpga/JaDriveTop.scala 59:{27,27}]
  wire [7:0] _GEN_28 = 3'h2 == msgIndex[2:0] ? 8'h49 : _GEN_27; // @[src/main/scala/fpga/JaDriveTop.scala 59:{27,27}]
  wire [7:0] _GEN_29 = 3'h3 == msgIndex[2:0] ? 8'h56 : _GEN_28; // @[src/main/scala/fpga/JaDriveTop.scala 59:{27,27}]
  wire [7:0] _GEN_30 = 3'h4 == msgIndex[2:0] ? 8'h45 : _GEN_29; // @[src/main/scala/fpga/JaDriveTop.scala 59:{27,27}]
  wire [7:0] _GEN_31 = 3'h5 == msgIndex[2:0] ? 8'hd : _GEN_30; // @[src/main/scala/fpga/JaDriveTop.scala 59:{27,27}]
  UartTransmitter uart ( // @[src/main/scala/fpga/JaDriveTop.scala 13:22]
    .clock(uart_clock),
    .reset(uart_reset),
    .io_inputDataByte(uart_io_inputDataByte),
    .io_transmitValid(uart_io_transmitValid),
    .io_transmitterReady(uart_io_transmitterReady),
    .io_serialTxPin(uart_io_serialTxPin)
  );
  assign io_jaPins_0 = outReg; // @[src/main/scala/fpga/JaDriveTop.scala 27:20]
  assign io_jaPins_1 = outReg_1; // @[src/main/scala/fpga/JaDriveTop.scala 27:20]
  assign io_jaPins_2 = outReg_2; // @[src/main/scala/fpga/JaDriveTop.scala 27:20]
  assign io_jaPins_3 = outReg_3; // @[src/main/scala/fpga/JaDriveTop.scala 27:20]
  assign io_jaPins_4 = outReg_4; // @[src/main/scala/fpga/JaDriveTop.scala 27:20]
  assign io_jaPins_5 = outReg_5; // @[src/main/scala/fpga/JaDriveTop.scala 27:20]
  assign io_jaPins_6 = outReg_6; // @[src/main/scala/fpga/JaDriveTop.scala 27:20]
  assign io_jaPins_7 = outReg_7; // @[src/main/scala/fpga/JaDriveTop.scala 27:20]
  assign io_txSerialPin = uart_io_serialTxPin; // @[src/main/scala/fpga/JaDriveTop.scala 14:20]
  assign uart_clock = clock;
  assign uart_reset = 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 12:21]
  assign uart_io_inputDataByte = 3'h6 == msgIndex[2:0] ? 8'ha : _GEN_31; // @[src/main/scala/fpga/JaDriveTop.scala 59:{27,27}]
  assign uart_io_transmitValid = msgTransmitting; // @[src/main/scala/fpga/JaDriveTop.scala 60:27]
  always @(posedge clock or posedge _GEN_0) begin
    if (_GEN_0) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      cnt <= 26'h0; // @[src/main/scala/fpga/JaDriveTop.scala 24:13]
    end else if (cnt == 26'h1e847f) begin // @[src/main/scala/fpga/JaDriveTop.scala 22:11]
      cnt <= 26'h0;
    end else begin
      cnt <= _cnt_T_1;
    end
  end
  always @(posedge clock or posedge _GEN_1) begin
    if (_GEN_1) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      outReg <= 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 25:16]
    end else if (cnt == 26'h1e847f) begin // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
      outReg <= ~outReg;
    end
  end
  always @(posedge clock or posedge _GEN_2) begin
    if (_GEN_2) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      cnt_1 <= 26'h0; // @[src/main/scala/fpga/JaDriveTop.scala 24:13]
    end else if (cnt_1 == 26'h2dc6bf) begin // @[src/main/scala/fpga/JaDriveTop.scala 22:11]
      cnt_1 <= 26'h0;
    end else begin
      cnt_1 <= _cnt_T_3;
    end
  end
  always @(posedge clock or posedge _GEN_3) begin
    if (_GEN_3) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      outReg_1 <= 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 25:16]
    end else if (cnt_1 == 26'h2dc6bf) begin // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
      outReg_1 <= ~outReg_1;
    end
  end
  always @(posedge clock or posedge _GEN_4) begin
    if (_GEN_4) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      cnt_2 <= 26'h0; // @[src/main/scala/fpga/JaDriveTop.scala 24:13]
    end else if (cnt_2 == 26'h4c4b3f) begin // @[src/main/scala/fpga/JaDriveTop.scala 22:11]
      cnt_2 <= 26'h0;
    end else begin
      cnt_2 <= _cnt_T_5;
    end
  end
  always @(posedge clock or posedge _GEN_5) begin
    if (_GEN_5) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      outReg_2 <= 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 25:16]
    end else if (cnt_2 == 26'h4c4b3f) begin // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
      outReg_2 <= ~outReg_2;
    end
  end
  always @(posedge clock or posedge _GEN_6) begin
    if (_GEN_6) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      cnt_3 <= 26'h0; // @[src/main/scala/fpga/JaDriveTop.scala 24:13]
    end else if (cnt_3 == 26'h6acfbf) begin // @[src/main/scala/fpga/JaDriveTop.scala 22:11]
      cnt_3 <= 26'h0;
    end else begin
      cnt_3 <= _cnt_T_7;
    end
  end
  always @(posedge clock or posedge _GEN_7) begin
    if (_GEN_7) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      outReg_3 <= 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 25:16]
    end else if (cnt_3 == 26'h6acfbf) begin // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
      outReg_3 <= ~outReg_3;
    end
  end
  always @(posedge clock or posedge _GEN_8) begin
    if (_GEN_8) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      cnt_4 <= 26'h0; // @[src/main/scala/fpga/JaDriveTop.scala 24:13]
    end else if (cnt_4 == 26'ha7d8bf) begin // @[src/main/scala/fpga/JaDriveTop.scala 22:11]
      cnt_4 <= 26'h0;
    end else begin
      cnt_4 <= _cnt_T_9;
    end
  end
  always @(posedge clock or posedge _GEN_9) begin
    if (_GEN_9) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      outReg_4 <= 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 25:16]
    end else if (cnt_4 == 26'ha7d8bf) begin // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
      outReg_4 <= ~outReg_4;
    end
  end
  always @(posedge clock or posedge _GEN_10) begin
    if (_GEN_10) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      cnt_5 <= 26'h0; // @[src/main/scala/fpga/JaDriveTop.scala 24:13]
    end else if (cnt_5 == 26'he4e1bf) begin // @[src/main/scala/fpga/JaDriveTop.scala 22:11]
      cnt_5 <= 26'h0;
    end else begin
      cnt_5 <= _cnt_T_11;
    end
  end
  always @(posedge clock or posedge _GEN_11) begin
    if (_GEN_11) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      outReg_5 <= 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 25:16]
    end else if (cnt_5 == 26'he4e1bf) begin // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
      outReg_5 <= ~outReg_5;
    end
  end
  always @(posedge clock or posedge _GEN_12) begin
    if (_GEN_12) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      cnt_6 <= 26'h0; // @[src/main/scala/fpga/JaDriveTop.scala 24:13]
    end else if (cnt_6 == 26'h1406f3f) begin // @[src/main/scala/fpga/JaDriveTop.scala 22:11]
      cnt_6 <= 26'h0;
    end else begin
      cnt_6 <= _cnt_T_13;
    end
  end
  always @(posedge clock or posedge _GEN_13) begin
    if (_GEN_13) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      outReg_6 <= 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 25:16]
    end else if (cnt_6 == 26'h1406f3f) begin // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
      outReg_6 <= ~outReg_6;
    end
  end
  always @(posedge clock or posedge _GEN_14) begin
    if (_GEN_14) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      cnt_7 <= 26'h0; // @[src/main/scala/fpga/JaDriveTop.scala 24:13]
    end else if (cnt_7 == 26'h19bfcbf) begin // @[src/main/scala/fpga/JaDriveTop.scala 22:11]
      cnt_7 <= 26'h0;
    end else begin
      cnt_7 <= _cnt_T_15;
    end
  end
  always @(posedge clock or posedge _GEN_15) begin
    if (_GEN_15) begin // @[src/main/scala/fpga/JaDriveTop.scala 23:40]
      outReg_7 <= 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 25:16]
    end else if (cnt_7 == 26'h19bfcbf) begin // @[src/main/scala/fpga/JaDriveTop.scala 21:27]
      outReg_7 <= ~outReg_7;
    end
  end
  always @(posedge clock or posedge _GEN_16) begin
    if (_GEN_16) begin // @[src/main/scala/fpga/JaDriveTop.scala 33:47]
      windowTimer <= 27'h0; // @[src/main/scala/fpga/JaDriveTop.scala 34:19]
    end else if (windowClear) begin // @[src/main/scala/fpga/JaDriveTop.scala 32:17]
      windowTimer <= 27'h0;
    end else begin
      windowTimer <= _windowTimer_T_1;
    end
  end
  always @(posedge clock or posedge _GEN_17) begin
    if (_GEN_17) begin // @[src/main/scala/fpga/JaDriveTop.scala 49:27]
      msgIndex <= 4'h0; // @[src/main/scala/fpga/JaDriveTop.scala 50:38 51:43 54:20]
    end else if (msgTransmitting) begin
      if (uart_io_transmitterReady) begin
        if (msgIndex == 4'h6) begin
          msgIndex <= _GEN_19;
        end else begin
          msgIndex <= _msgIndex_T_1;
        end
      end else begin
        msgIndex <= _GEN_19;
      end
    end else begin
      msgIndex <= _GEN_19;
    end
  end
  always @(posedge clock or posedge _GEN_24) begin
    if (_GEN_24) begin // @[src/main/scala/fpga/JaDriveTop.scala 49:27]
      msgTransmitting <= 1'h0; // @[src/main/scala/fpga/JaDriveTop.scala 50:38 51:43 52:27]
    end else if (msgTransmitting) begin
      if (uart_io_transmitterReady) begin
        if (msgIndex == 4'h6) begin
          msgTransmitting <= 1'h0;
        end else begin
          msgTransmitting <= _GEN_18;
        end
      end else begin
        msgTransmitting <= _GEN_18;
      end
    end else begin
      msgTransmitting <= _GEN_18;
    end
  end
// Register and memory initialization
`ifdef RANDOMIZE_GARBAGE_ASSIGN
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_INVALID_ASSIGN
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_REG_INIT
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_MEM_INIT
`define RANDOMIZE
`endif
`ifndef RANDOM
`define RANDOM $random
`endif
`ifdef RANDOMIZE_MEM_INIT
  integer initvar;
`endif
`ifndef SYNTHESIS
`ifdef FIRRTL_BEFORE_INITIAL
`FIRRTL_BEFORE_INITIAL
`endif
initial begin
  `ifdef RANDOMIZE
    `ifdef INIT_RANDOM
      `INIT_RANDOM
    `endif
    `ifndef VERILATOR
      `ifdef RANDOMIZE_DELAY
        #`RANDOMIZE_DELAY begin end
      `else
        #0.002 begin end
      `endif
    `endif
`ifdef RANDOMIZE_REG_INIT
  _RAND_0 = {1{`RANDOM}};
  cnt = _RAND_0[25:0];
  _RAND_1 = {1{`RANDOM}};
  outReg = _RAND_1[0:0];
  _RAND_2 = {1{`RANDOM}};
  cnt_1 = _RAND_2[25:0];
  _RAND_3 = {1{`RANDOM}};
  outReg_1 = _RAND_3[0:0];
  _RAND_4 = {1{`RANDOM}};
  cnt_2 = _RAND_4[25:0];
  _RAND_5 = {1{`RANDOM}};
  outReg_2 = _RAND_5[0:0];
  _RAND_6 = {1{`RANDOM}};
  cnt_3 = _RAND_6[25:0];
  _RAND_7 = {1{`RANDOM}};
  outReg_3 = _RAND_7[0:0];
  _RAND_8 = {1{`RANDOM}};
  cnt_4 = _RAND_8[25:0];
  _RAND_9 = {1{`RANDOM}};
  outReg_4 = _RAND_9[0:0];
  _RAND_10 = {1{`RANDOM}};
  cnt_5 = _RAND_10[25:0];
  _RAND_11 = {1{`RANDOM}};
  outReg_5 = _RAND_11[0:0];
  _RAND_12 = {1{`RANDOM}};
  cnt_6 = _RAND_12[25:0];
  _RAND_13 = {1{`RANDOM}};
  outReg_6 = _RAND_13[0:0];
  _RAND_14 = {1{`RANDOM}};
  cnt_7 = _RAND_14[25:0];
  _RAND_15 = {1{`RANDOM}};
  outReg_7 = _RAND_15[0:0];
  _RAND_16 = {1{`RANDOM}};
  windowTimer = _RAND_16[26:0];
  _RAND_17 = {1{`RANDOM}};
  msgIndex = _RAND_17[3:0];
  _RAND_18 = {1{`RANDOM}};
  msgTransmitting = _RAND_18[0:0];
`endif // RANDOMIZE_REG_INIT
  if (_GEN_0) begin
    cnt = 26'h0;
  end
  if (_GEN_1) begin
    outReg = 1'h0;
  end
  if (_GEN_2) begin
    cnt_1 = 26'h0;
  end
  if (_GEN_3) begin
    outReg_1 = 1'h0;
  end
  if (_GEN_4) begin
    cnt_2 = 26'h0;
  end
  if (_GEN_5) begin
    outReg_2 = 1'h0;
  end
  if (_GEN_6) begin
    cnt_3 = 26'h0;
  end
  if (_GEN_7) begin
    outReg_3 = 1'h0;
  end
  if (_GEN_8) begin
    cnt_4 = 26'h0;
  end
  if (_GEN_9) begin
    outReg_4 = 1'h0;
  end
  if (_GEN_10) begin
    cnt_5 = 26'h0;
  end
  if (_GEN_11) begin
    outReg_5 = 1'h0;
  end
  if (_GEN_12) begin
    cnt_6 = 26'h0;
  end
  if (_GEN_13) begin
    outReg_6 = 1'h0;
  end
  if (_GEN_14) begin
    cnt_7 = 26'h0;
  end
  if (_GEN_15) begin
    outReg_7 = 1'h0;
  end
  if (_GEN_16) begin
    windowTimer = 27'h0;
  end
  if (_GEN_17) begin
    msgIndex = 4'h0;
  end
  if (_GEN_24) begin
    msgTransmitting = 1'h0;
  end
  `endif // RANDOMIZE
end // initial
`ifdef FIRRTL_AFTER_INITIAL
`FIRRTL_AFTER_INITIAL
`endif
`endif // SYNTHESIS
endmodule
