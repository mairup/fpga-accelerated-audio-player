module XadcVolume (
  input  wire        clock,
  input  wire        reset,
  input  wire        vauxp0,
  input  wire        vauxn0,
  output reg  [15:0] volumeGain
);

  // NextPNR-Xilinx open-source flow lacks hard XADC Bel placement support.
  // We implement a smooth digital integration filter on the pin.
  // When High (or full range), volume is maximum (16'h7FFF = 1.0 in Q15/Q31 scaling).
  reg [15:0] integrator;

  always @(posedge clock) begin
    if (reset) begin
      volumeGain <= 16'h7FFF;
      integrator <= 16'h7FFF;
    end else begin
      if (vauxp0) begin
        if (integrator < 16'h7FFF)
          integrator <= integrator + 16'd1;
      end else begin
        if (integrator > 16'h0000)
          integrator <= integrator - 16'd1;
      end
      volumeGain <= integrator;
    end
  end
endmodule
