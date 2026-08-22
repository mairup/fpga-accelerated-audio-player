#!/usr/bin/env python3
import math
import os

def generate_twiddles(N=1024, width=12):
    max_val = (1 << (width - 1)) - 1  # 2047 for 12-bit
    min_val = -(1 << (width - 1))     # -2048 for 12-bit
    mask = (1 << width) - 1

    lines = []
    for k in range(N):
        theta = 2.0 * math.pi * k / N
        cos_val = math.cos(theta)
        sin_val = -math.sin(theta)  # W_N^k = e^(-j 2 pi k / N) = cos - j sin

        re_int = round(cos_val * max_val)
        im_int = round(sin_val * max_val)

        re_int = max(min_val, min(max_val, re_int))
        im_int = max(min_val, min(max_val, im_int))

        re_hex = f"{re_int & mask:03X}"
        im_hex = f"{im_int & mask:03X}"

        lines.append(f"        wn_re[{k:4d}] = 12'h{re_hex}; wn_im[{k:4d}] = 12'h{im_hex};")
    return "\n".join(lines)

def build_verilog():
    twiddles_code = generate_twiddles(1024, 12)
    
    header = """//======================================================================
//  1024-Point Streaming Radix-2^2 SDF FFT Core (12-bit Optimized)
//  Vendor-neutral synthesizable Verilog-2001 (Yosys / F4PGA compatible)
//======================================================================

//----------------------------------------------------------------------
//  Butterfly: Add/Sub and Scaling
//----------------------------------------------------------------------
module R22Sdf_Butterfly #(
    parameter   WIDTH = 12,
    parameter   RH = 0  //  Round Half Up
)(
    input   signed  [WIDTH-1:0] x0_re,  //  Input Data #0 (Real)
    input   signed  [WIDTH-1:0] x0_im,  //  Input Data #0 (Imag)
    input   signed  [WIDTH-1:0] x1_re,  //  Input Data #1 (Real)
    input   signed  [WIDTH-1:0] x1_im,  //  Input Data #1 (Imag)
    output  signed  [WIDTH-1:0] y0_re,  //  Output Data #0 (Real)
    output  signed  [WIDTH-1:0] y0_im,  //  Output Data #0 (Imag)
    output  signed  [WIDTH-1:0] y1_re,  //  Output Data #1 (Real)
    output  signed  [WIDTH-1:0] y1_im   //  Output Data #1 (Imag)
);

wire signed [WIDTH:0]   add_re, add_im, sub_re, sub_im;

//  Add/Sub
assign  add_re = x0_re + x1_re;
assign  add_im = x0_im + x1_im;
assign  sub_re = x0_re - x1_re;
assign  sub_im = x0_im - x1_im;

//  Scaling
assign  y0_re = (add_re + RH) >>> 1;
assign  y0_im = (add_im + RH) >>> 1;
assign  y1_re = (sub_re + RH) >>> 1;
assign  y1_im = (sub_im + RH) >>> 1;

endmodule


//----------------------------------------------------------------------
//  DelayBuffer: Hybrid SRL (DEPTH < 16) / Circular BRAM (DEPTH >= 16)
//----------------------------------------------------------------------
module R22Sdf_DelayBuffer #(
    parameter   DEPTH = 32,
    parameter   WIDTH = 12
)(
    input               clock,  //  Master Clock
    input               reset,  //  Active High Reset
    input               en,     //  Enable
    input   [WIDTH-1:0] di_re,  //  Data Input (Real)
    input   [WIDTH-1:0] di_im,  //  Data Input (Imag)
    output  [WIDTH-1:0] do_re,  //  Data Output (Real)
    output  [WIDTH-1:0] do_im   //  Data Output (Imag)
);

generate
if (DEPTH < 16) begin : gen_srl
    reg [WIDTH-1:0] buf_re[0:DEPTH-1];
    reg [WIDTH-1:0] buf_im[0:DEPTH-1];
    integer n;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            for (n = 0; n < DEPTH; n = n + 1) begin
                buf_re[n] <= {WIDTH{1'b0}};
                buf_im[n] <= {WIDTH{1'b0}};
            end
        end else if (en) begin
            for (n = DEPTH-1; n > 0; n = n - 1) begin
                buf_re[n] <= buf_re[n-1];
                buf_im[n] <= buf_im[n-1];
            end
            buf_re[0] <= di_re;
            buf_im[0] <= di_im;
        end
    end

    assign do_re = buf_re[DEPTH-1];
    assign do_im = buf_im[DEPTH-1];
end else begin : gen_bram
    localparam AW = (DEPTH <= 2) ? 1 :
                    (DEPTH <= 4) ? 2 :
                    (DEPTH <= 8) ? 3 :
                    (DEPTH <= 16) ? 4 :
                    (DEPTH <= 32) ? 5 :
                    (DEPTH <= 64) ? 6 :
                    (DEPTH <= 128) ? 7 :
                    (DEPTH <= 256) ? 8 :
                    (DEPTH <= 512) ? 9 : 10;

    reg [WIDTH-1:0] mem_re [0:DEPTH-1];
    reg [WIDTH-1:0] mem_im [0:DEPTH-1];
    reg [AW-1:0] wr_ptr = {AW{1'b0}};
    reg [AW-1:0] rd_ptr = {{AW-1{1'b0}}, 1'b1};
    reg [WIDTH-1:0] reg_do_re = {WIDTH{1'b0}};
    reg [WIDTH-1:0] reg_do_im = {WIDTH{1'b0}};

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            wr_ptr <= {AW{1'b0}};
            rd_ptr <= {{AW-1{1'b0}}, 1'b1};
            reg_do_re <= {WIDTH{1'b0}};
            reg_do_im <= {WIDTH{1'b0}};
        end else if (en) begin
            mem_re[wr_ptr] <= di_re;
            mem_im[wr_ptr] <= di_im;
            reg_do_re <= mem_re[rd_ptr];
            reg_do_im <= mem_im[rd_ptr];
            wr_ptr <= (wr_ptr == DEPTH-1) ? {AW{1'b0}} : (wr_ptr + 1'b1);
            rd_ptr <= (rd_ptr == DEPTH-1) ? {AW{1'b0}} : (rd_ptr + 1'b1);
        end
    end

    assign do_re = reg_do_re;
    assign do_im = reg_do_im;
end
endgenerate

endmodule


//----------------------------------------------------------------------
//  Multiply: Complex Multiplier
//----------------------------------------------------------------------
module R22Sdf_Multiply #(
    parameter   WIDTH = 12
)(
    input   signed  [WIDTH-1:0] a_re,
    input   signed  [WIDTH-1:0] a_im,
    input   signed  [WIDTH-1:0] b_re,
    input   signed  [WIDTH-1:0] b_im,
    output  signed  [WIDTH-1:0] m_re,
    output  signed  [WIDTH-1:0] m_im
);

wire signed [WIDTH*2-1:0]   arbr, arbi, aibr, aibi;
wire signed [WIDTH-1:0]     sc_arbr, sc_arbi, sc_aibr, sc_aibi;

//  Signed Multiplication
assign  arbr = a_re * b_re;
assign  arbi = a_re * b_im;
assign  aibr = a_im * b_re;
assign  aibi = a_im * b_im;

//  Scaling
assign  sc_arbr = arbr >>> (WIDTH-1);
assign  sc_arbi = arbi >>> (WIDTH-1);
assign  sc_aibr = aibr >>> (WIDTH-1);
assign  sc_aibi = aibi >>> (WIDTH-1);

//  Sub/Add
assign  m_re = sc_arbr - sc_aibi;
assign  m_im = sc_arbi + sc_aibr;

endmodule


//----------------------------------------------------------------------
//  Twiddle: 1024-Point Twiddle Table (BRAM ROM Inferred)
//----------------------------------------------------------------------
module R22Sdf_Twiddle1024 #(
    parameter   WIDTH = 12,
    parameter   TW_FF = 1   //  Use Output Register
)(
    input               clock,  //  Master Clock
    input   [9:0]       addr,   //  Twiddle Factor Number
    output  [WIDTH-1:0] tw_re,  //  Twiddle Factor (Real)
    output  [WIDTH-1:0] tw_im   //  Twiddle Factor (Imag)
);

reg [WIDTH-1:0] wn_re [0:1023];
reg [WIDTH-1:0] wn_im [0:1023];
reg [WIDTH-1:0] ff_re;
reg [WIDTH-1:0] ff_im;

    initial begin
"""
    middle = twiddles_code + "\n    end\n\n"
    footer = """always @(posedge clock) begin
    ff_re <= wn_re[addr];
    ff_im <= wn_im[addr];
end

assign tw_re = TW_FF ? ff_re : wn_re[addr];
assign tw_im = TW_FF ? ff_im : wn_im[addr];

endmodule


//----------------------------------------------------------------------
//  SdfUnit: Radix-2^2 Single-Path Delay Feedback Unit for N-Point FFT
//----------------------------------------------------------------------
module R22Sdf_SdfUnit #(
    parameter   N = 64,     //  Number of FFT Point
    parameter   M = 64,     //  Twiddle Resolution
    parameter   WIDTH = 12  //  Data Bit Length
)(
    input               clock,  //  Master Clock
    input               reset,  //  Active High Asynchronous Reset
    input               di_en,  //  Input Data Enable
    input   [WIDTH-1:0] di_re,  //  Input Data (Real)
    input   [WIDTH-1:0] di_im,  //  Input Data (Imag)
    output              do_en,  //  Output Data Enable
    output  [WIDTH-1:0] do_re,  //  Output Data (Real)
    output  [WIDTH-1:0] do_im   //  Output Data (Imag)
);

//  log2 constant function
function integer log2;
    input integer x;
    integer value;
    begin
        value = x-1;
        for (log2=0; value>0; log2=log2+1)
            value = value>>1;
    end
endfunction

localparam  LOG_N = log2(N);    //  Bit Length of N
localparam  LOG_M = log2(M);    //  Bit Length of M

//----------------------------------------------------------------------
//  Internal Regs and Nets
//----------------------------------------------------------------------
//  1st Butterfly
reg [LOG_N-1:0] di_count;   //  Input Data Count
wire            bf1_bf;     //  Butterfly Add/Sub Enable
wire[WIDTH-1:0] bf1_x0_re;  //  Data #0 to Butterfly (Real)
wire[WIDTH-1:0] bf1_x0_im;  //  Data #0 to Butterfly (Imag)
wire[WIDTH-1:0] bf1_x1_re;  //  Data #1 to Butterfly (Real)
wire[WIDTH-1:0] bf1_x1_im;  //  Data #1 to Butterfly (Imag)
wire[WIDTH-1:0] bf1_y0_re;  //  Data #0 from Butterfly (Real)
wire[WIDTH-1:0] bf1_y0_im;  //  Data #0 from Butterfly (Imag)
wire[WIDTH-1:0] bf1_y1_re;  //  Data #1 from Butterfly (Real)
wire[WIDTH-1:0] bf1_y1_im;  //  Data #1 from Butterfly (Imag)
wire[WIDTH-1:0] db1_di_re;  //  Data to DelayBuffer (Real)
wire[WIDTH-1:0] db1_di_im;  //  Data to DelayBuffer (Imag)
wire[WIDTH-1:0] db1_do_re;  //  Data from DelayBuffer (Real)
wire[WIDTH-1:0] db1_do_im;  //  Data from DelayBuffer (Imag)
wire[WIDTH-1:0] bf1_sp_re;  //  Single-Path Data Output (Real)
wire[WIDTH-1:0] bf1_sp_im;  //  Single-Path Data Output (Imag)
reg             bf1_sp_en;  //  Single-Path Data Enable
reg [LOG_N-1:0] bf1_count;  //  Single-Path Data Count
wire            bf1_start;  //  Single-Path Output Trigger
wire            bf1_end;    //  End of Single-Path Data
wire            bf1_mj;     //  Twiddle (-j) Enable
reg [WIDTH-1:0] bf1_do_re;  //  1st Butterfly Output Data (Real)
reg [WIDTH-1:0] bf1_do_im;  //  1st Butterfly Output Data (Imag)

//  2nd Butterfly
reg             bf2_bf;     //  Butterfly Add/Sub Enable
wire[WIDTH-1:0] bf2_x0_re;  //  Data #0 to Butterfly (Real)
wire[WIDTH-1:0] bf2_x0_im;  //  Data #0 to Butterfly (Imag)
wire[WIDTH-1:0] bf2_x1_re;  //  Data #1 to Butterfly (Real)
wire[WIDTH-1:0] bf2_x1_im;  //  Data #1 to Butterfly (Imag)
wire[WIDTH-1:0] bf2_y0_re;  //  Data #0 from Butterfly (Real)
wire[WIDTH-1:0] bf2_y0_im;  //  Data #0 from Butterfly (Imag)
wire[WIDTH-1:0] bf2_y1_re;  //  Data #1 from Butterfly (Real)
wire[WIDTH-1:0] bf2_y1_im;  //  Data #1 from Butterfly (Imag)
wire[WIDTH-1:0] db2_di_re;  //  Data to DelayBuffer (Real)
wire[WIDTH-1:0] db2_di_im;  //  Data to DelayBuffer (Imag)
wire[WIDTH-1:0] db2_do_re;  //  Data from DelayBuffer (Real)
wire[WIDTH-1:0] db2_do_im;  //  Data from DelayBuffer (Imag)
wire[WIDTH-1:0] bf2_sp_re;  //  Single-Path Data Output (Real)
wire[WIDTH-1:0] bf2_sp_im;  //  Single-Path Data Output (Imag)
reg             bf2_sp_en;  //  Single-Path Data Enable
reg [LOG_N-1:0] bf2_count;  //  Single-Path Data Count
reg             bf2_start;  //  Single-Path Output Trigger
wire            bf2_end;    //  End of Single-Path Data
reg [WIDTH-1:0] bf2_do_re;  //  2nd Butterfly Output Data (Real)
reg [WIDTH-1:0] bf2_do_im;  //  2nd Butterfly Output Data (Imag)
reg             bf2_do_en;  //  2nd Butterfly Output Data Enable

//  Multiplication
wire[1:0]       tw_sel;     //  Twiddle Select (2n/n/3n)
wire[LOG_N-3:0] tw_num;     //  Twiddle Number (n)
wire[LOG_N-1:0] tw_addr;    //  Twiddle Table Address
wire[WIDTH-1:0] tw_re;      //  Twiddle Factor (Real)
wire[WIDTH-1:0] tw_im;      //  Twiddle Factor (Imag)
reg             mu_en;      //  Multiplication Enable
wire[WIDTH-1:0] mu_a_re;    //  Multiplier Input (Real)
wire[WIDTH-1:0] mu_a_im;    //  Multiplier Input (Imag)
wire[WIDTH-1:0] mu_m_re;    //  Multiplier Output (Real)
wire[WIDTH-1:0] mu_m_im;    //  Multiplier Output (Imag)
reg [WIDTH-1:0] mu_do_re;   //  Multiplication Output Data (Real)
reg [WIDTH-1:0] mu_do_im;   //  Multiplication Output Data (Imag)
reg             mu_do_en;   //  Multiplication Output Data Enable

//----------------------------------------------------------------------
//  1st Butterfly
//----------------------------------------------------------------------
always @(posedge clock or posedge reset) begin
    if (reset) begin
        di_count <= {LOG_N{1'b0}};
    end else begin
        di_count <= di_en ? (di_count + 1'b1) : {LOG_N{1'b0}};
    end
end
assign  bf1_bf = di_count[LOG_M-1];

assign  bf1_x0_re = bf1_bf ? db1_do_re : {WIDTH{1'bx}};
assign  bf1_x0_im = bf1_bf ? db1_do_im : {WIDTH{1'bx}};
assign  bf1_x1_re = bf1_bf ? di_re : {WIDTH{1'bx}};
assign  bf1_x1_im = bf1_bf ? di_im : {WIDTH{1'bx}};

R22Sdf_Butterfly #(.WIDTH(WIDTH),.RH(0)) BF1 (
    .x0_re  (bf1_x0_re  ),
    .x0_im  (bf1_x0_im  ),
    .x1_re  (bf1_x1_re  ),
    .x1_im  (bf1_x1_im  ),
    .y0_re  (bf1_y0_re  ),
    .y0_im  (bf1_y0_im  ),
    .y1_re  (bf1_y1_re  ),
    .y1_im  (bf1_y1_im  )
);

R22Sdf_DelayBuffer #(.DEPTH(2**(LOG_M-1)),.WIDTH(WIDTH)) DB1 (
    .clock  (clock      ),
    .reset  (reset      ),
    .en     (di_en      ),
    .di_re  (db1_di_re  ),
    .di_im  (db1_di_im  ),
    .do_re  (db1_do_re  ),
    .do_im  (db1_do_im  )
);

assign  db1_di_re = bf1_bf ? bf1_y1_re : di_re;
assign  db1_di_im = bf1_bf ? bf1_y1_im : di_im;
assign  bf1_sp_re = bf1_bf ? bf1_y0_re : bf1_mj ?  db1_do_im : db1_do_re;
assign  bf1_sp_im = bf1_bf ? bf1_y0_im : bf1_mj ? -db1_do_re : db1_do_im;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        bf1_sp_en <= 1'b0;
        bf1_count <= {LOG_N{1'b0}};
    end else begin
        bf1_sp_en <= bf1_start ? 1'b1 : bf1_end ? 1'b0 : bf1_sp_en;
        bf1_count <= bf1_sp_en ? (bf1_count + 1'b1) : {LOG_N{1'b0}};
    end
end
assign  bf1_start = (di_count == (2**(LOG_M-1)-1));
assign  bf1_end = (bf1_count == (2**LOG_N-1));
assign  bf1_mj = (bf1_count[LOG_M-1:LOG_M-2] == 2'd3);

always @(posedge clock) begin
    bf1_do_re <= bf1_sp_re;
    bf1_do_im <= bf1_sp_im;
end

//----------------------------------------------------------------------
//  2nd Butterfly
//----------------------------------------------------------------------
always @(posedge clock) begin
    bf2_bf <= bf1_count[LOG_M-2];
end

assign  bf2_x0_re = bf2_bf ? db2_do_re : {WIDTH{1'bx}};
assign  bf2_x0_im = bf2_bf ? db2_do_im : {WIDTH{1'bx}};
assign  bf2_x1_re = bf2_bf ? bf1_do_re : {WIDTH{1'bx}};
assign  bf2_x1_im = bf2_bf ? bf1_do_im : {WIDTH{1'bx}};

R22Sdf_Butterfly #(.WIDTH(WIDTH),.RH(1)) BF2 (
    .x0_re  (bf2_x0_re  ),
    .x0_im  (bf2_x0_im  ),
    .x1_re  (bf2_x1_re  ),
    .x1_im  (bf2_x1_im  ),
    .y0_re  (bf2_y0_re  ),
    .y0_im  (bf2_y0_im  ),
    .y1_re  (bf2_y1_re  ),
    .y1_im  (bf2_y1_im  )
);

R22Sdf_DelayBuffer #(.DEPTH(2**(LOG_M-2)),.WIDTH(WIDTH)) DB2 (
    .clock  (clock      ),
    .reset  (reset      ),
    .en     (bf1_sp_en  ),
    .di_re  (db2_di_re  ),
    .di_im  (db2_di_im  ),
    .do_re  (db2_do_re  ),
    .do_im  (db2_do_im  )
);

assign  db2_di_re = bf2_bf ? bf2_y1_re : bf1_do_re;
assign  db2_di_im = bf2_bf ? bf2_y1_im : bf1_do_im;
assign  bf2_sp_re = bf2_bf ? bf2_y0_re : db2_do_re;
assign  bf2_sp_im = bf2_bf ? bf2_y0_im : db2_do_im;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        bf2_sp_en <= 1'b0;
        bf2_count <= {LOG_N{1'b0}};
    end else begin
        bf2_sp_en <= bf2_start ? 1'b1 : bf2_end ? 1'b0 : bf2_sp_en;
        bf2_count <= bf2_sp_en ? (bf2_count + 1'b1) : {LOG_N{1'b0}};
    end
end

always @(posedge clock) begin
    bf2_start <= (bf1_count == (2**(LOG_M-2)-1)) & bf1_sp_en;
end
assign  bf2_end = (bf2_count == (2**LOG_N-1));

always @(posedge clock) begin
    bf2_do_re <= bf2_sp_re;
    bf2_do_im <= bf2_sp_im;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        bf2_do_en <= 1'b0;
    end else begin
        bf2_do_en <= bf2_sp_en;
    end
end

//----------------------------------------------------------------------
//  Multiplication
//----------------------------------------------------------------------
assign  tw_sel[1] = bf2_count[LOG_M-2];
assign  tw_sel[0] = bf2_count[LOG_M-1];
assign  tw_num = bf2_count << (LOG_N-LOG_M);
assign  tw_addr = tw_num * tw_sel;

R22Sdf_Twiddle1024 #(.WIDTH(WIDTH), .TW_FF(1)) TW (
    .clock  (clock  ),
    .addr   (tw_addr),
    .tw_re  (tw_re  ),
    .tw_im  (tw_im  )
);

always @(posedge clock) begin
    mu_en <= (tw_addr != {LOG_N{1'b0}});
end
assign  mu_a_re = mu_en ? bf2_do_re : {WIDTH{1'bx}};
assign  mu_a_im = mu_en ? bf2_do_im : {WIDTH{1'bx}};

R22Sdf_Multiply #(.WIDTH(WIDTH)) MU (
    .a_re   (mu_a_re),
    .a_im   (mu_a_im),
    .b_re   (tw_re  ),
    .b_im   (tw_im  ),
    .m_re   (mu_m_re),
    .m_im   (mu_m_im)
);

always @(posedge clock) begin
    mu_do_re <= mu_en ? mu_m_re : bf2_do_re;
    mu_do_im <= mu_en ? mu_m_im : bf2_do_im;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        mu_do_en <= 1'b0;
    end else begin
        mu_do_en <= bf2_do_en;
    end
end

//  No multiplication required at final stage
assign  do_en = (LOG_M == 2) ? bf2_do_en : mu_do_en;
assign  do_re = (LOG_M == 2) ? bf2_do_re : mu_do_re;
assign  do_im = (LOG_M == 2) ? bf2_do_im : mu_do_im;

endmodule


//----------------------------------------------------------------------
//  FFT: 1024-Point FFT Using Radix-2^2 Single-Path Delay Feedback
//----------------------------------------------------------------------
module R22SdfFFT1024 #(
    parameter   WIDTH = 12
)(
    input               clock,  //  Master Clock
    input               reset,  //  Active High Asynchronous Reset
    input               di_en,  //  Input Data Enable
    input   [WIDTH-1:0] di_re,  //  Input Data (Real)
    input   [WIDTH-1:0] di_im,  //  Input Data (Imag)
    output              do_en,  //  Output Data Enable
    output  [WIDTH-1:0] do_re,  //  Output Data (Real)
    output  [WIDTH-1:0] do_im   //  Output Data (Imag)
);

wire            su1_do_en;
wire[WIDTH-1:0] su1_do_re;
wire[WIDTH-1:0] su1_do_im;
wire            su2_do_en;
wire[WIDTH-1:0] su2_do_re;
wire[WIDTH-1:0] su2_do_im;
wire            su3_do_en;
wire[WIDTH-1:0] su3_do_re;
wire[WIDTH-1:0] su3_do_im;
wire            su4_do_en;
wire[WIDTH-1:0] su4_do_re;
wire[WIDTH-1:0] su4_do_im;

R22Sdf_SdfUnit #(.N(1024),.M(1024),.WIDTH(WIDTH)) SU1 (
    .clock  (clock      ),
    .reset  (reset      ),
    .di_en  (di_en      ),
    .di_re  (di_re      ),
    .di_im  (di_im      ),
    .do_en  (su1_do_en  ),
    .do_re  (su1_do_re  ),
    .do_im  (su1_do_im  )
);

R22Sdf_SdfUnit #(.N(1024),.M(256),.WIDTH(WIDTH)) SU2 (
    .clock  (clock      ),
    .reset  (reset      ),
    .di_en  (su1_do_en  ),
    .di_re  (su1_do_re  ),
    .di_im  (su1_do_im  ),
    .do_en  (su2_do_en  ),
    .do_re  (su2_do_re  ),
    .do_im  (su2_do_im  )
);

R22Sdf_SdfUnit #(.N(1024),.M(64),.WIDTH(WIDTH)) SU3 (
    .clock  (clock      ),
    .reset  (reset      ),
    .di_en  (su2_do_en  ),
    .di_re  (su2_do_re  ),
    .di_im  (su2_do_im  ),
    .do_en  (su3_do_en  ),
    .do_re  (su3_do_re  ),
    .do_im  (su3_do_im  )
);

R22Sdf_SdfUnit #(.N(1024),.M(16),.WIDTH(WIDTH)) SU4 (
    .clock  (clock      ),
    .reset  (reset      ),
    .di_en  (su3_do_en  ),
    .di_re  (su3_do_re  ),
    .di_im  (su3_do_im  ),
    .do_en  (su4_do_en  ),
    .do_re  (su4_do_re  ),
    .do_im  (su4_do_im  )
);

R22Sdf_SdfUnit #(.N(1024),.M(4),.WIDTH(WIDTH)) SU5 (
    .clock  (clock      ),
    .reset  (reset      ),
    .di_en  (su4_do_en  ),
    .di_re  (su4_do_re  ),
    .di_im  (su4_do_im  ),
    .do_en  (do_en      ),
    .do_re  (do_re      ),
    .do_im  (do_im      )
);

endmodule
"""
    return header + middle + footer

if __name__ == "__main__":
    v_content = build_verilog()
    target_paths = [
        "/home/mai/Documents/FRI/L2/NDN/fpga-accelerated-audio-player/fpga/src/main/resources/vsrc/r22sdf/R22SdfFFT1024.v",
        "/home/mai/Documents/FRI/L2/NDN/fpga-accelerated-audio-player/fpga/R22SdfFFT1024.v"
    ]
    for p in target_paths:
        if os.path.exists(os.path.dirname(p)):
            with open(p, "w") as f:
                f.write(v_content)
            print(f"Updated {p}")
