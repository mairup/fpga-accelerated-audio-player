//======================================================================
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
        wn_re[   0] = 12'h7FF; wn_im[   0] = 12'h000;
        wn_re[   1] = 12'h7FF; wn_im[   1] = 12'hFF3;
        wn_re[   2] = 12'h7FF; wn_im[   2] = 12'hFE7;
        wn_re[   3] = 12'h7FF; wn_im[   3] = 12'hFDA;
        wn_re[   4] = 12'h7FE; wn_im[   4] = 12'hFCE;
        wn_re[   5] = 12'h7FE; wn_im[   5] = 12'hFC1;
        wn_re[   6] = 12'h7FE; wn_im[   6] = 12'hFB5;
        wn_re[   7] = 12'h7FD; wn_im[   7] = 12'hFA8;
        wn_re[   8] = 12'h7FD; wn_im[   8] = 12'hF9C;
        wn_re[   9] = 12'h7FC; wn_im[   9] = 12'hF8F;
        wn_re[  10] = 12'h7FB; wn_im[  10] = 12'hF82;
        wn_re[  11] = 12'h7FA; wn_im[  11] = 12'hF76;
        wn_re[  12] = 12'h7F9; wn_im[  12] = 12'hF69;
        wn_re[  13] = 12'h7F8; wn_im[  13] = 12'hF5D;
        wn_re[  14] = 12'h7F7; wn_im[  14] = 12'hF50;
        wn_re[  15] = 12'h7F6; wn_im[  15] = 12'hF44;
        wn_re[  16] = 12'h7F5; wn_im[  16] = 12'hF37;
        wn_re[  17] = 12'h7F4; wn_im[  17] = 12'hF2B;
        wn_re[  18] = 12'h7F3; wn_im[  18] = 12'hF1E;
        wn_re[  19] = 12'h7F1; wn_im[  19] = 12'hF12;
        wn_re[  20] = 12'h7F0; wn_im[  20] = 12'hF05;
        wn_re[  21] = 12'h7EE; wn_im[  21] = 12'hEF9;
        wn_re[  22] = 12'h7EC; wn_im[  22] = 12'hEED;
        wn_re[  23] = 12'h7EB; wn_im[  23] = 12'hEE0;
        wn_re[  24] = 12'h7E9; wn_im[  24] = 12'hED4;
        wn_re[  25] = 12'h7E7; wn_im[  25] = 12'hEC7;
        wn_re[  26] = 12'h7E5; wn_im[  26] = 12'hEBB;
        wn_re[  27] = 12'h7E3; wn_im[  27] = 12'hEAE;
        wn_re[  28] = 12'h7E1; wn_im[  28] = 12'hEA2;
        wn_re[  29] = 12'h7DF; wn_im[  29] = 12'hE96;
        wn_re[  30] = 12'h7DC; wn_im[  30] = 12'hE89;
        wn_re[  31] = 12'h7DA; wn_im[  31] = 12'hE7D;
        wn_re[  32] = 12'h7D8; wn_im[  32] = 12'hE71;
        wn_re[  33] = 12'h7D5; wn_im[  33] = 12'hE64;
        wn_re[  34] = 12'h7D3; wn_im[  34] = 12'hE58;
        wn_re[  35] = 12'h7D0; wn_im[  35] = 12'hE4C;
        wn_re[  36] = 12'h7CD; wn_im[  36] = 12'hE3F;
        wn_re[  37] = 12'h7CA; wn_im[  37] = 12'hE33;
        wn_re[  38] = 12'h7C8; wn_im[  38] = 12'hE27;
        wn_re[  39] = 12'h7C5; wn_im[  39] = 12'hE1B;
        wn_re[  40] = 12'h7C2; wn_im[  40] = 12'hE0F;
        wn_re[  41] = 12'h7BF; wn_im[  41] = 12'hE02;
        wn_re[  42] = 12'h7BB; wn_im[  42] = 12'hDF6;
        wn_re[  43] = 12'h7B8; wn_im[  43] = 12'hDEA;
        wn_re[  44] = 12'h7B5; wn_im[  44] = 12'hDDE;
        wn_re[  45] = 12'h7B1; wn_im[  45] = 12'hDD2;
        wn_re[  46] = 12'h7AE; wn_im[  46] = 12'hDC6;
        wn_re[  47] = 12'h7AA; wn_im[  47] = 12'hDBA;
        wn_re[  48] = 12'h7A7; wn_im[  48] = 12'hDAE;
        wn_re[  49] = 12'h7A3; wn_im[  49] = 12'hDA2;
        wn_re[  50] = 12'h79F; wn_im[  50] = 12'hD96;
        wn_re[  51] = 12'h79C; wn_im[  51] = 12'hD8A;
        wn_re[  52] = 12'h798; wn_im[  52] = 12'hD7E;
        wn_re[  53] = 12'h794; wn_im[  53] = 12'hD72;
        wn_re[  54] = 12'h790; wn_im[  54] = 12'hD66;
        wn_re[  55] = 12'h78C; wn_im[  55] = 12'hD5A;
        wn_re[  56] = 12'h787; wn_im[  56] = 12'hD4E;
        wn_re[  57] = 12'h783; wn_im[  57] = 12'hD43;
        wn_re[  58] = 12'h77F; wn_im[  58] = 12'hD37;
        wn_re[  59] = 12'h77A; wn_im[  59] = 12'hD2B;
        wn_re[  60] = 12'h776; wn_im[  60] = 12'hD1F;
        wn_re[  61] = 12'h771; wn_im[  61] = 12'hD14;
        wn_re[  62] = 12'h76D; wn_im[  62] = 12'hD08;
        wn_re[  63] = 12'h768; wn_im[  63] = 12'hCFC;
        wn_re[  64] = 12'h763; wn_im[  64] = 12'hCF1;
        wn_re[  65] = 12'h75E; wn_im[  65] = 12'hCE5;
        wn_re[  66] = 12'h759; wn_im[  66] = 12'hCD9;
        wn_re[  67] = 12'h754; wn_im[  67] = 12'hCCE;
        wn_re[  68] = 12'h74F; wn_im[  68] = 12'hCC2;
        wn_re[  69] = 12'h74A; wn_im[  69] = 12'hCB7;
        wn_re[  70] = 12'h745; wn_im[  70] = 12'hCAC;
        wn_re[  71] = 12'h740; wn_im[  71] = 12'hCA0;
        wn_re[  72] = 12'h73A; wn_im[  72] = 12'hC95;
        wn_re[  73] = 12'h735; wn_im[  73] = 12'hC89;
        wn_re[  74] = 12'h730; wn_im[  74] = 12'hC7E;
        wn_re[  75] = 12'h72A; wn_im[  75] = 12'hC73;
        wn_re[  76] = 12'h724; wn_im[  76] = 12'hC68;
        wn_re[  77] = 12'h71F; wn_im[  77] = 12'hC5C;
        wn_re[  78] = 12'h719; wn_im[  78] = 12'hC51;
        wn_re[  79] = 12'h713; wn_im[  79] = 12'hC46;
        wn_re[  80] = 12'h70D; wn_im[  80] = 12'hC3B;
        wn_re[  81] = 12'h707; wn_im[  81] = 12'hC30;
        wn_re[  82] = 12'h701; wn_im[  82] = 12'hC25;
        wn_re[  83] = 12'h6FB; wn_im[  83] = 12'hC1A;
        wn_re[  84] = 12'h6F5; wn_im[  84] = 12'hC0F;
        wn_re[  85] = 12'h6EF; wn_im[  85] = 12'hC04;
        wn_re[  86] = 12'h6E9; wn_im[  86] = 12'hBF9;
        wn_re[  87] = 12'h6E2; wn_im[  87] = 12'hBEE;
        wn_re[  88] = 12'h6DC; wn_im[  88] = 12'hBE4;
        wn_re[  89] = 12'h6D5; wn_im[  89] = 12'hBD9;
        wn_re[  90] = 12'h6CF; wn_im[  90] = 12'hBCE;
        wn_re[  91] = 12'h6C8; wn_im[  91] = 12'hBC3;
        wn_re[  92] = 12'h6C1; wn_im[  92] = 12'hBB9;
        wn_re[  93] = 12'h6BB; wn_im[  93] = 12'hBAE;
        wn_re[  94] = 12'h6B4; wn_im[  94] = 12'hBA4;
        wn_re[  95] = 12'h6AD; wn_im[  95] = 12'hB99;
        wn_re[  96] = 12'h6A6; wn_im[  96] = 12'hB8F;
        wn_re[  97] = 12'h69F; wn_im[  97] = 12'hB84;
        wn_re[  98] = 12'h698; wn_im[  98] = 12'hB7A;
        wn_re[  99] = 12'h691; wn_im[  99] = 12'hB70;
        wn_re[ 100] = 12'h68A; wn_im[ 100] = 12'hB65;
        wn_re[ 101] = 12'h682; wn_im[ 101] = 12'hB5B;
        wn_re[ 102] = 12'h67B; wn_im[ 102] = 12'hB51;
        wn_re[ 103] = 12'h674; wn_im[ 103] = 12'hB47;
        wn_re[ 104] = 12'h66C; wn_im[ 104] = 12'hB3D;
        wn_re[ 105] = 12'h665; wn_im[ 105] = 12'hB33;
        wn_re[ 106] = 12'h65D; wn_im[ 106] = 12'hB29;
        wn_re[ 107] = 12'h655; wn_im[ 107] = 12'hB1F;
        wn_re[ 108] = 12'h64E; wn_im[ 108] = 12'hB15;
        wn_re[ 109] = 12'h646; wn_im[ 109] = 12'hB0B;
        wn_re[ 110] = 12'h63E; wn_im[ 110] = 12'hB01;
        wn_re[ 111] = 12'h636; wn_im[ 111] = 12'hAF7;
        wn_re[ 112] = 12'h62E; wn_im[ 112] = 12'hAED;
        wn_re[ 113] = 12'h626; wn_im[ 113] = 12'hAE4;
        wn_re[ 114] = 12'h61E; wn_im[ 114] = 12'hADA;
        wn_re[ 115] = 12'h616; wn_im[ 115] = 12'hAD0;
        wn_re[ 116] = 12'h60E; wn_im[ 116] = 12'hAC7;
        wn_re[ 117] = 12'h606; wn_im[ 117] = 12'hABD;
        wn_re[ 118] = 12'h5FD; wn_im[ 118] = 12'hAB4;
        wn_re[ 119] = 12'h5F5; wn_im[ 119] = 12'hAAB;
        wn_re[ 120] = 12'h5ED; wn_im[ 120] = 12'hAA1;
        wn_re[ 121] = 12'h5E4; wn_im[ 121] = 12'hA98;
        wn_re[ 122] = 12'h5DC; wn_im[ 122] = 12'hA8F;
        wn_re[ 123] = 12'h5D3; wn_im[ 123] = 12'hA86;
        wn_re[ 124] = 12'h5CB; wn_im[ 124] = 12'hA7D;
        wn_re[ 125] = 12'h5C2; wn_im[ 125] = 12'hA73;
        wn_re[ 126] = 12'h5B9; wn_im[ 126] = 12'hA6A;
        wn_re[ 127] = 12'h5B0; wn_im[ 127] = 12'hA61;
        wn_re[ 128] = 12'h5A7; wn_im[ 128] = 12'hA59;
        wn_re[ 129] = 12'h59F; wn_im[ 129] = 12'hA50;
        wn_re[ 130] = 12'h596; wn_im[ 130] = 12'hA47;
        wn_re[ 131] = 12'h58D; wn_im[ 131] = 12'hA3E;
        wn_re[ 132] = 12'h583; wn_im[ 132] = 12'hA35;
        wn_re[ 133] = 12'h57A; wn_im[ 133] = 12'hA2D;
        wn_re[ 134] = 12'h571; wn_im[ 134] = 12'hA24;
        wn_re[ 135] = 12'h568; wn_im[ 135] = 12'hA1C;
        wn_re[ 136] = 12'h55F; wn_im[ 136] = 12'hA13;
        wn_re[ 137] = 12'h555; wn_im[ 137] = 12'hA0B;
        wn_re[ 138] = 12'h54C; wn_im[ 138] = 12'hA03;
        wn_re[ 139] = 12'h543; wn_im[ 139] = 12'h9FA;
        wn_re[ 140] = 12'h539; wn_im[ 140] = 12'h9F2;
        wn_re[ 141] = 12'h530; wn_im[ 141] = 12'h9EA;
        wn_re[ 142] = 12'h526; wn_im[ 142] = 12'h9E2;
        wn_re[ 143] = 12'h51C; wn_im[ 143] = 12'h9DA;
        wn_re[ 144] = 12'h513; wn_im[ 144] = 12'h9D2;
        wn_re[ 145] = 12'h509; wn_im[ 145] = 12'h9CA;
        wn_re[ 146] = 12'h4FF; wn_im[ 146] = 12'h9C2;
        wn_re[ 147] = 12'h4F5; wn_im[ 147] = 12'h9BA;
        wn_re[ 148] = 12'h4EB; wn_im[ 148] = 12'h9B2;
        wn_re[ 149] = 12'h4E1; wn_im[ 149] = 12'h9AB;
        wn_re[ 150] = 12'h4D7; wn_im[ 150] = 12'h9A3;
        wn_re[ 151] = 12'h4CD; wn_im[ 151] = 12'h99B;
        wn_re[ 152] = 12'h4C3; wn_im[ 152] = 12'h994;
        wn_re[ 153] = 12'h4B9; wn_im[ 153] = 12'h98C;
        wn_re[ 154] = 12'h4AF; wn_im[ 154] = 12'h985;
        wn_re[ 155] = 12'h4A5; wn_im[ 155] = 12'h97E;
        wn_re[ 156] = 12'h49B; wn_im[ 156] = 12'h976;
        wn_re[ 157] = 12'h490; wn_im[ 157] = 12'h96F;
        wn_re[ 158] = 12'h486; wn_im[ 158] = 12'h968;
        wn_re[ 159] = 12'h47C; wn_im[ 159] = 12'h961;
        wn_re[ 160] = 12'h471; wn_im[ 160] = 12'h95A;
        wn_re[ 161] = 12'h467; wn_im[ 161] = 12'h953;
        wn_re[ 162] = 12'h45C; wn_im[ 162] = 12'h94C;
        wn_re[ 163] = 12'h452; wn_im[ 163] = 12'h945;
        wn_re[ 164] = 12'h447; wn_im[ 164] = 12'h93F;
        wn_re[ 165] = 12'h43D; wn_im[ 165] = 12'h938;
        wn_re[ 166] = 12'h432; wn_im[ 166] = 12'h931;
        wn_re[ 167] = 12'h427; wn_im[ 167] = 12'h92B;
        wn_re[ 168] = 12'h41C; wn_im[ 168] = 12'h924;
        wn_re[ 169] = 12'h412; wn_im[ 169] = 12'h91E;
        wn_re[ 170] = 12'h407; wn_im[ 170] = 12'h917;
        wn_re[ 171] = 12'h3FC; wn_im[ 171] = 12'h911;
        wn_re[ 172] = 12'h3F1; wn_im[ 172] = 12'h90B;
        wn_re[ 173] = 12'h3E6; wn_im[ 173] = 12'h905;
        wn_re[ 174] = 12'h3DB; wn_im[ 174] = 12'h8FF;
        wn_re[ 175] = 12'h3D0; wn_im[ 175] = 12'h8F9;
        wn_re[ 176] = 12'h3C5; wn_im[ 176] = 12'h8F3;
        wn_re[ 177] = 12'h3BA; wn_im[ 177] = 12'h8ED;
        wn_re[ 178] = 12'h3AF; wn_im[ 178] = 12'h8E7;
        wn_re[ 179] = 12'h3A4; wn_im[ 179] = 12'h8E1;
        wn_re[ 180] = 12'h398; wn_im[ 180] = 12'h8DC;
        wn_re[ 181] = 12'h38D; wn_im[ 181] = 12'h8D6;
        wn_re[ 182] = 12'h382; wn_im[ 182] = 12'h8D0;
        wn_re[ 183] = 12'h377; wn_im[ 183] = 12'h8CB;
        wn_re[ 184] = 12'h36B; wn_im[ 184] = 12'h8C6;
        wn_re[ 185] = 12'h360; wn_im[ 185] = 12'h8C0;
        wn_re[ 186] = 12'h354; wn_im[ 186] = 12'h8BB;
        wn_re[ 187] = 12'h349; wn_im[ 187] = 12'h8B6;
        wn_re[ 188] = 12'h33E; wn_im[ 188] = 12'h8B1;
        wn_re[ 189] = 12'h332; wn_im[ 189] = 12'h8AC;
        wn_re[ 190] = 12'h327; wn_im[ 190] = 12'h8A7;
        wn_re[ 191] = 12'h31B; wn_im[ 191] = 12'h8A2;
        wn_re[ 192] = 12'h30F; wn_im[ 192] = 12'h89D;
        wn_re[ 193] = 12'h304; wn_im[ 193] = 12'h898;
        wn_re[ 194] = 12'h2F8; wn_im[ 194] = 12'h893;
        wn_re[ 195] = 12'h2EC; wn_im[ 195] = 12'h88F;
        wn_re[ 196] = 12'h2E1; wn_im[ 196] = 12'h88A;
        wn_re[ 197] = 12'h2D5; wn_im[ 197] = 12'h886;
        wn_re[ 198] = 12'h2C9; wn_im[ 198] = 12'h881;
        wn_re[ 199] = 12'h2BD; wn_im[ 199] = 12'h87D;
        wn_re[ 200] = 12'h2B2; wn_im[ 200] = 12'h879;
        wn_re[ 201] = 12'h2A6; wn_im[ 201] = 12'h874;
        wn_re[ 202] = 12'h29A; wn_im[ 202] = 12'h870;
        wn_re[ 203] = 12'h28E; wn_im[ 203] = 12'h86C;
        wn_re[ 204] = 12'h282; wn_im[ 204] = 12'h868;
        wn_re[ 205] = 12'h276; wn_im[ 205] = 12'h864;
        wn_re[ 206] = 12'h26A; wn_im[ 206] = 12'h861;
        wn_re[ 207] = 12'h25E; wn_im[ 207] = 12'h85D;
        wn_re[ 208] = 12'h252; wn_im[ 208] = 12'h859;
        wn_re[ 209] = 12'h246; wn_im[ 209] = 12'h856;
        wn_re[ 210] = 12'h23A; wn_im[ 210] = 12'h852;
        wn_re[ 211] = 12'h22E; wn_im[ 211] = 12'h84F;
        wn_re[ 212] = 12'h222; wn_im[ 212] = 12'h84B;
        wn_re[ 213] = 12'h216; wn_im[ 213] = 12'h848;
        wn_re[ 214] = 12'h20A; wn_im[ 214] = 12'h845;
        wn_re[ 215] = 12'h1FE; wn_im[ 215] = 12'h841;
        wn_re[ 216] = 12'h1F1; wn_im[ 216] = 12'h83E;
        wn_re[ 217] = 12'h1E5; wn_im[ 217] = 12'h83B;
        wn_re[ 218] = 12'h1D9; wn_im[ 218] = 12'h838;
        wn_re[ 219] = 12'h1CD; wn_im[ 219] = 12'h836;
        wn_re[ 220] = 12'h1C1; wn_im[ 220] = 12'h833;
        wn_re[ 221] = 12'h1B4; wn_im[ 221] = 12'h830;
        wn_re[ 222] = 12'h1A8; wn_im[ 222] = 12'h82D;
        wn_re[ 223] = 12'h19C; wn_im[ 223] = 12'h82B;
        wn_re[ 224] = 12'h18F; wn_im[ 224] = 12'h828;
        wn_re[ 225] = 12'h183; wn_im[ 225] = 12'h826;
        wn_re[ 226] = 12'h177; wn_im[ 226] = 12'h824;
        wn_re[ 227] = 12'h16A; wn_im[ 227] = 12'h821;
        wn_re[ 228] = 12'h15E; wn_im[ 228] = 12'h81F;
        wn_re[ 229] = 12'h152; wn_im[ 229] = 12'h81D;
        wn_re[ 230] = 12'h145; wn_im[ 230] = 12'h81B;
        wn_re[ 231] = 12'h139; wn_im[ 231] = 12'h819;
        wn_re[ 232] = 12'h12C; wn_im[ 232] = 12'h817;
        wn_re[ 233] = 12'h120; wn_im[ 233] = 12'h815;
        wn_re[ 234] = 12'h113; wn_im[ 234] = 12'h814;
        wn_re[ 235] = 12'h107; wn_im[ 235] = 12'h812;
        wn_re[ 236] = 12'h0FB; wn_im[ 236] = 12'h810;
        wn_re[ 237] = 12'h0EE; wn_im[ 237] = 12'h80F;
        wn_re[ 238] = 12'h0E2; wn_im[ 238] = 12'h80D;
        wn_re[ 239] = 12'h0D5; wn_im[ 239] = 12'h80C;
        wn_re[ 240] = 12'h0C9; wn_im[ 240] = 12'h80B;
        wn_re[ 241] = 12'h0BC; wn_im[ 241] = 12'h80A;
        wn_re[ 242] = 12'h0B0; wn_im[ 242] = 12'h809;
        wn_re[ 243] = 12'h0A3; wn_im[ 243] = 12'h808;
        wn_re[ 244] = 12'h097; wn_im[ 244] = 12'h807;
        wn_re[ 245] = 12'h08A; wn_im[ 245] = 12'h806;
        wn_re[ 246] = 12'h07E; wn_im[ 246] = 12'h805;
        wn_re[ 247] = 12'h071; wn_im[ 247] = 12'h804;
        wn_re[ 248] = 12'h064; wn_im[ 248] = 12'h803;
        wn_re[ 249] = 12'h058; wn_im[ 249] = 12'h803;
        wn_re[ 250] = 12'h04B; wn_im[ 250] = 12'h802;
        wn_re[ 251] = 12'h03F; wn_im[ 251] = 12'h802;
        wn_re[ 252] = 12'h032; wn_im[ 252] = 12'h802;
        wn_re[ 253] = 12'h026; wn_im[ 253] = 12'h801;
        wn_re[ 254] = 12'h019; wn_im[ 254] = 12'h801;
        wn_re[ 255] = 12'h00D; wn_im[ 255] = 12'h801;
        wn_re[ 256] = 12'h000; wn_im[ 256] = 12'h801;
        wn_re[ 257] = 12'hFF3; wn_im[ 257] = 12'h801;
        wn_re[ 258] = 12'hFE7; wn_im[ 258] = 12'h801;
        wn_re[ 259] = 12'hFDA; wn_im[ 259] = 12'h801;
        wn_re[ 260] = 12'hFCE; wn_im[ 260] = 12'h802;
        wn_re[ 261] = 12'hFC1; wn_im[ 261] = 12'h802;
        wn_re[ 262] = 12'hFB5; wn_im[ 262] = 12'h802;
        wn_re[ 263] = 12'hFA8; wn_im[ 263] = 12'h803;
        wn_re[ 264] = 12'hF9C; wn_im[ 264] = 12'h803;
        wn_re[ 265] = 12'hF8F; wn_im[ 265] = 12'h804;
        wn_re[ 266] = 12'hF82; wn_im[ 266] = 12'h805;
        wn_re[ 267] = 12'hF76; wn_im[ 267] = 12'h806;
        wn_re[ 268] = 12'hF69; wn_im[ 268] = 12'h807;
        wn_re[ 269] = 12'hF5D; wn_im[ 269] = 12'h808;
        wn_re[ 270] = 12'hF50; wn_im[ 270] = 12'h809;
        wn_re[ 271] = 12'hF44; wn_im[ 271] = 12'h80A;
        wn_re[ 272] = 12'hF37; wn_im[ 272] = 12'h80B;
        wn_re[ 273] = 12'hF2B; wn_im[ 273] = 12'h80C;
        wn_re[ 274] = 12'hF1E; wn_im[ 274] = 12'h80D;
        wn_re[ 275] = 12'hF12; wn_im[ 275] = 12'h80F;
        wn_re[ 276] = 12'hF05; wn_im[ 276] = 12'h810;
        wn_re[ 277] = 12'hEF9; wn_im[ 277] = 12'h812;
        wn_re[ 278] = 12'hEED; wn_im[ 278] = 12'h814;
        wn_re[ 279] = 12'hEE0; wn_im[ 279] = 12'h815;
        wn_re[ 280] = 12'hED4; wn_im[ 280] = 12'h817;
        wn_re[ 281] = 12'hEC7; wn_im[ 281] = 12'h819;
        wn_re[ 282] = 12'hEBB; wn_im[ 282] = 12'h81B;
        wn_re[ 283] = 12'hEAE; wn_im[ 283] = 12'h81D;
        wn_re[ 284] = 12'hEA2; wn_im[ 284] = 12'h81F;
        wn_re[ 285] = 12'hE96; wn_im[ 285] = 12'h821;
        wn_re[ 286] = 12'hE89; wn_im[ 286] = 12'h824;
        wn_re[ 287] = 12'hE7D; wn_im[ 287] = 12'h826;
        wn_re[ 288] = 12'hE71; wn_im[ 288] = 12'h828;
        wn_re[ 289] = 12'hE64; wn_im[ 289] = 12'h82B;
        wn_re[ 290] = 12'hE58; wn_im[ 290] = 12'h82D;
        wn_re[ 291] = 12'hE4C; wn_im[ 291] = 12'h830;
        wn_re[ 292] = 12'hE3F; wn_im[ 292] = 12'h833;
        wn_re[ 293] = 12'hE33; wn_im[ 293] = 12'h836;
        wn_re[ 294] = 12'hE27; wn_im[ 294] = 12'h838;
        wn_re[ 295] = 12'hE1B; wn_im[ 295] = 12'h83B;
        wn_re[ 296] = 12'hE0F; wn_im[ 296] = 12'h83E;
        wn_re[ 297] = 12'hE02; wn_im[ 297] = 12'h841;
        wn_re[ 298] = 12'hDF6; wn_im[ 298] = 12'h845;
        wn_re[ 299] = 12'hDEA; wn_im[ 299] = 12'h848;
        wn_re[ 300] = 12'hDDE; wn_im[ 300] = 12'h84B;
        wn_re[ 301] = 12'hDD2; wn_im[ 301] = 12'h84F;
        wn_re[ 302] = 12'hDC6; wn_im[ 302] = 12'h852;
        wn_re[ 303] = 12'hDBA; wn_im[ 303] = 12'h856;
        wn_re[ 304] = 12'hDAE; wn_im[ 304] = 12'h859;
        wn_re[ 305] = 12'hDA2; wn_im[ 305] = 12'h85D;
        wn_re[ 306] = 12'hD96; wn_im[ 306] = 12'h861;
        wn_re[ 307] = 12'hD8A; wn_im[ 307] = 12'h864;
        wn_re[ 308] = 12'hD7E; wn_im[ 308] = 12'h868;
        wn_re[ 309] = 12'hD72; wn_im[ 309] = 12'h86C;
        wn_re[ 310] = 12'hD66; wn_im[ 310] = 12'h870;
        wn_re[ 311] = 12'hD5A; wn_im[ 311] = 12'h874;
        wn_re[ 312] = 12'hD4E; wn_im[ 312] = 12'h879;
        wn_re[ 313] = 12'hD43; wn_im[ 313] = 12'h87D;
        wn_re[ 314] = 12'hD37; wn_im[ 314] = 12'h881;
        wn_re[ 315] = 12'hD2B; wn_im[ 315] = 12'h886;
        wn_re[ 316] = 12'hD1F; wn_im[ 316] = 12'h88A;
        wn_re[ 317] = 12'hD14; wn_im[ 317] = 12'h88F;
        wn_re[ 318] = 12'hD08; wn_im[ 318] = 12'h893;
        wn_re[ 319] = 12'hCFC; wn_im[ 319] = 12'h898;
        wn_re[ 320] = 12'hCF1; wn_im[ 320] = 12'h89D;
        wn_re[ 321] = 12'hCE5; wn_im[ 321] = 12'h8A2;
        wn_re[ 322] = 12'hCD9; wn_im[ 322] = 12'h8A7;
        wn_re[ 323] = 12'hCCE; wn_im[ 323] = 12'h8AC;
        wn_re[ 324] = 12'hCC2; wn_im[ 324] = 12'h8B1;
        wn_re[ 325] = 12'hCB7; wn_im[ 325] = 12'h8B6;
        wn_re[ 326] = 12'hCAC; wn_im[ 326] = 12'h8BB;
        wn_re[ 327] = 12'hCA0; wn_im[ 327] = 12'h8C0;
        wn_re[ 328] = 12'hC95; wn_im[ 328] = 12'h8C6;
        wn_re[ 329] = 12'hC89; wn_im[ 329] = 12'h8CB;
        wn_re[ 330] = 12'hC7E; wn_im[ 330] = 12'h8D0;
        wn_re[ 331] = 12'hC73; wn_im[ 331] = 12'h8D6;
        wn_re[ 332] = 12'hC68; wn_im[ 332] = 12'h8DC;
        wn_re[ 333] = 12'hC5C; wn_im[ 333] = 12'h8E1;
        wn_re[ 334] = 12'hC51; wn_im[ 334] = 12'h8E7;
        wn_re[ 335] = 12'hC46; wn_im[ 335] = 12'h8ED;
        wn_re[ 336] = 12'hC3B; wn_im[ 336] = 12'h8F3;
        wn_re[ 337] = 12'hC30; wn_im[ 337] = 12'h8F9;
        wn_re[ 338] = 12'hC25; wn_im[ 338] = 12'h8FF;
        wn_re[ 339] = 12'hC1A; wn_im[ 339] = 12'h905;
        wn_re[ 340] = 12'hC0F; wn_im[ 340] = 12'h90B;
        wn_re[ 341] = 12'hC04; wn_im[ 341] = 12'h911;
        wn_re[ 342] = 12'hBF9; wn_im[ 342] = 12'h917;
        wn_re[ 343] = 12'hBEE; wn_im[ 343] = 12'h91E;
        wn_re[ 344] = 12'hBE4; wn_im[ 344] = 12'h924;
        wn_re[ 345] = 12'hBD9; wn_im[ 345] = 12'h92B;
        wn_re[ 346] = 12'hBCE; wn_im[ 346] = 12'h931;
        wn_re[ 347] = 12'hBC3; wn_im[ 347] = 12'h938;
        wn_re[ 348] = 12'hBB9; wn_im[ 348] = 12'h93F;
        wn_re[ 349] = 12'hBAE; wn_im[ 349] = 12'h945;
        wn_re[ 350] = 12'hBA4; wn_im[ 350] = 12'h94C;
        wn_re[ 351] = 12'hB99; wn_im[ 351] = 12'h953;
        wn_re[ 352] = 12'hB8F; wn_im[ 352] = 12'h95A;
        wn_re[ 353] = 12'hB84; wn_im[ 353] = 12'h961;
        wn_re[ 354] = 12'hB7A; wn_im[ 354] = 12'h968;
        wn_re[ 355] = 12'hB70; wn_im[ 355] = 12'h96F;
        wn_re[ 356] = 12'hB65; wn_im[ 356] = 12'h976;
        wn_re[ 357] = 12'hB5B; wn_im[ 357] = 12'h97E;
        wn_re[ 358] = 12'hB51; wn_im[ 358] = 12'h985;
        wn_re[ 359] = 12'hB47; wn_im[ 359] = 12'h98C;
        wn_re[ 360] = 12'hB3D; wn_im[ 360] = 12'h994;
        wn_re[ 361] = 12'hB33; wn_im[ 361] = 12'h99B;
        wn_re[ 362] = 12'hB29; wn_im[ 362] = 12'h9A3;
        wn_re[ 363] = 12'hB1F; wn_im[ 363] = 12'h9AB;
        wn_re[ 364] = 12'hB15; wn_im[ 364] = 12'h9B2;
        wn_re[ 365] = 12'hB0B; wn_im[ 365] = 12'h9BA;
        wn_re[ 366] = 12'hB01; wn_im[ 366] = 12'h9C2;
        wn_re[ 367] = 12'hAF7; wn_im[ 367] = 12'h9CA;
        wn_re[ 368] = 12'hAED; wn_im[ 368] = 12'h9D2;
        wn_re[ 369] = 12'hAE4; wn_im[ 369] = 12'h9DA;
        wn_re[ 370] = 12'hADA; wn_im[ 370] = 12'h9E2;
        wn_re[ 371] = 12'hAD0; wn_im[ 371] = 12'h9EA;
        wn_re[ 372] = 12'hAC7; wn_im[ 372] = 12'h9F2;
        wn_re[ 373] = 12'hABD; wn_im[ 373] = 12'h9FA;
        wn_re[ 374] = 12'hAB4; wn_im[ 374] = 12'hA03;
        wn_re[ 375] = 12'hAAB; wn_im[ 375] = 12'hA0B;
        wn_re[ 376] = 12'hAA1; wn_im[ 376] = 12'hA13;
        wn_re[ 377] = 12'hA98; wn_im[ 377] = 12'hA1C;
        wn_re[ 378] = 12'hA8F; wn_im[ 378] = 12'hA24;
        wn_re[ 379] = 12'hA86; wn_im[ 379] = 12'hA2D;
        wn_re[ 380] = 12'hA7D; wn_im[ 380] = 12'hA35;
        wn_re[ 381] = 12'hA73; wn_im[ 381] = 12'hA3E;
        wn_re[ 382] = 12'hA6A; wn_im[ 382] = 12'hA47;
        wn_re[ 383] = 12'hA61; wn_im[ 383] = 12'hA50;
        wn_re[ 384] = 12'hA59; wn_im[ 384] = 12'hA59;
        wn_re[ 385] = 12'hA50; wn_im[ 385] = 12'hA61;
        wn_re[ 386] = 12'hA47; wn_im[ 386] = 12'hA6A;
        wn_re[ 387] = 12'hA3E; wn_im[ 387] = 12'hA73;
        wn_re[ 388] = 12'hA35; wn_im[ 388] = 12'hA7D;
        wn_re[ 389] = 12'hA2D; wn_im[ 389] = 12'hA86;
        wn_re[ 390] = 12'hA24; wn_im[ 390] = 12'hA8F;
        wn_re[ 391] = 12'hA1C; wn_im[ 391] = 12'hA98;
        wn_re[ 392] = 12'hA13; wn_im[ 392] = 12'hAA1;
        wn_re[ 393] = 12'hA0B; wn_im[ 393] = 12'hAAB;
        wn_re[ 394] = 12'hA03; wn_im[ 394] = 12'hAB4;
        wn_re[ 395] = 12'h9FA; wn_im[ 395] = 12'hABD;
        wn_re[ 396] = 12'h9F2; wn_im[ 396] = 12'hAC7;
        wn_re[ 397] = 12'h9EA; wn_im[ 397] = 12'hAD0;
        wn_re[ 398] = 12'h9E2; wn_im[ 398] = 12'hADA;
        wn_re[ 399] = 12'h9DA; wn_im[ 399] = 12'hAE4;
        wn_re[ 400] = 12'h9D2; wn_im[ 400] = 12'hAED;
        wn_re[ 401] = 12'h9CA; wn_im[ 401] = 12'hAF7;
        wn_re[ 402] = 12'h9C2; wn_im[ 402] = 12'hB01;
        wn_re[ 403] = 12'h9BA; wn_im[ 403] = 12'hB0B;
        wn_re[ 404] = 12'h9B2; wn_im[ 404] = 12'hB15;
        wn_re[ 405] = 12'h9AB; wn_im[ 405] = 12'hB1F;
        wn_re[ 406] = 12'h9A3; wn_im[ 406] = 12'hB29;
        wn_re[ 407] = 12'h99B; wn_im[ 407] = 12'hB33;
        wn_re[ 408] = 12'h994; wn_im[ 408] = 12'hB3D;
        wn_re[ 409] = 12'h98C; wn_im[ 409] = 12'hB47;
        wn_re[ 410] = 12'h985; wn_im[ 410] = 12'hB51;
        wn_re[ 411] = 12'h97E; wn_im[ 411] = 12'hB5B;
        wn_re[ 412] = 12'h976; wn_im[ 412] = 12'hB65;
        wn_re[ 413] = 12'h96F; wn_im[ 413] = 12'hB70;
        wn_re[ 414] = 12'h968; wn_im[ 414] = 12'hB7A;
        wn_re[ 415] = 12'h961; wn_im[ 415] = 12'hB84;
        wn_re[ 416] = 12'h95A; wn_im[ 416] = 12'hB8F;
        wn_re[ 417] = 12'h953; wn_im[ 417] = 12'hB99;
        wn_re[ 418] = 12'h94C; wn_im[ 418] = 12'hBA4;
        wn_re[ 419] = 12'h945; wn_im[ 419] = 12'hBAE;
        wn_re[ 420] = 12'h93F; wn_im[ 420] = 12'hBB9;
        wn_re[ 421] = 12'h938; wn_im[ 421] = 12'hBC3;
        wn_re[ 422] = 12'h931; wn_im[ 422] = 12'hBCE;
        wn_re[ 423] = 12'h92B; wn_im[ 423] = 12'hBD9;
        wn_re[ 424] = 12'h924; wn_im[ 424] = 12'hBE4;
        wn_re[ 425] = 12'h91E; wn_im[ 425] = 12'hBEE;
        wn_re[ 426] = 12'h917; wn_im[ 426] = 12'hBF9;
        wn_re[ 427] = 12'h911; wn_im[ 427] = 12'hC04;
        wn_re[ 428] = 12'h90B; wn_im[ 428] = 12'hC0F;
        wn_re[ 429] = 12'h905; wn_im[ 429] = 12'hC1A;
        wn_re[ 430] = 12'h8FF; wn_im[ 430] = 12'hC25;
        wn_re[ 431] = 12'h8F9; wn_im[ 431] = 12'hC30;
        wn_re[ 432] = 12'h8F3; wn_im[ 432] = 12'hC3B;
        wn_re[ 433] = 12'h8ED; wn_im[ 433] = 12'hC46;
        wn_re[ 434] = 12'h8E7; wn_im[ 434] = 12'hC51;
        wn_re[ 435] = 12'h8E1; wn_im[ 435] = 12'hC5C;
        wn_re[ 436] = 12'h8DC; wn_im[ 436] = 12'hC68;
        wn_re[ 437] = 12'h8D6; wn_im[ 437] = 12'hC73;
        wn_re[ 438] = 12'h8D0; wn_im[ 438] = 12'hC7E;
        wn_re[ 439] = 12'h8CB; wn_im[ 439] = 12'hC89;
        wn_re[ 440] = 12'h8C6; wn_im[ 440] = 12'hC95;
        wn_re[ 441] = 12'h8C0; wn_im[ 441] = 12'hCA0;
        wn_re[ 442] = 12'h8BB; wn_im[ 442] = 12'hCAC;
        wn_re[ 443] = 12'h8B6; wn_im[ 443] = 12'hCB7;
        wn_re[ 444] = 12'h8B1; wn_im[ 444] = 12'hCC2;
        wn_re[ 445] = 12'h8AC; wn_im[ 445] = 12'hCCE;
        wn_re[ 446] = 12'h8A7; wn_im[ 446] = 12'hCD9;
        wn_re[ 447] = 12'h8A2; wn_im[ 447] = 12'hCE5;
        wn_re[ 448] = 12'h89D; wn_im[ 448] = 12'hCF1;
        wn_re[ 449] = 12'h898; wn_im[ 449] = 12'hCFC;
        wn_re[ 450] = 12'h893; wn_im[ 450] = 12'hD08;
        wn_re[ 451] = 12'h88F; wn_im[ 451] = 12'hD14;
        wn_re[ 452] = 12'h88A; wn_im[ 452] = 12'hD1F;
        wn_re[ 453] = 12'h886; wn_im[ 453] = 12'hD2B;
        wn_re[ 454] = 12'h881; wn_im[ 454] = 12'hD37;
        wn_re[ 455] = 12'h87D; wn_im[ 455] = 12'hD43;
        wn_re[ 456] = 12'h879; wn_im[ 456] = 12'hD4E;
        wn_re[ 457] = 12'h874; wn_im[ 457] = 12'hD5A;
        wn_re[ 458] = 12'h870; wn_im[ 458] = 12'hD66;
        wn_re[ 459] = 12'h86C; wn_im[ 459] = 12'hD72;
        wn_re[ 460] = 12'h868; wn_im[ 460] = 12'hD7E;
        wn_re[ 461] = 12'h864; wn_im[ 461] = 12'hD8A;
        wn_re[ 462] = 12'h861; wn_im[ 462] = 12'hD96;
        wn_re[ 463] = 12'h85D; wn_im[ 463] = 12'hDA2;
        wn_re[ 464] = 12'h859; wn_im[ 464] = 12'hDAE;
        wn_re[ 465] = 12'h856; wn_im[ 465] = 12'hDBA;
        wn_re[ 466] = 12'h852; wn_im[ 466] = 12'hDC6;
        wn_re[ 467] = 12'h84F; wn_im[ 467] = 12'hDD2;
        wn_re[ 468] = 12'h84B; wn_im[ 468] = 12'hDDE;
        wn_re[ 469] = 12'h848; wn_im[ 469] = 12'hDEA;
        wn_re[ 470] = 12'h845; wn_im[ 470] = 12'hDF6;
        wn_re[ 471] = 12'h841; wn_im[ 471] = 12'hE02;
        wn_re[ 472] = 12'h83E; wn_im[ 472] = 12'hE0F;
        wn_re[ 473] = 12'h83B; wn_im[ 473] = 12'hE1B;
        wn_re[ 474] = 12'h838; wn_im[ 474] = 12'hE27;
        wn_re[ 475] = 12'h836; wn_im[ 475] = 12'hE33;
        wn_re[ 476] = 12'h833; wn_im[ 476] = 12'hE3F;
        wn_re[ 477] = 12'h830; wn_im[ 477] = 12'hE4C;
        wn_re[ 478] = 12'h82D; wn_im[ 478] = 12'hE58;
        wn_re[ 479] = 12'h82B; wn_im[ 479] = 12'hE64;
        wn_re[ 480] = 12'h828; wn_im[ 480] = 12'hE71;
        wn_re[ 481] = 12'h826; wn_im[ 481] = 12'hE7D;
        wn_re[ 482] = 12'h824; wn_im[ 482] = 12'hE89;
        wn_re[ 483] = 12'h821; wn_im[ 483] = 12'hE96;
        wn_re[ 484] = 12'h81F; wn_im[ 484] = 12'hEA2;
        wn_re[ 485] = 12'h81D; wn_im[ 485] = 12'hEAE;
        wn_re[ 486] = 12'h81B; wn_im[ 486] = 12'hEBB;
        wn_re[ 487] = 12'h819; wn_im[ 487] = 12'hEC7;
        wn_re[ 488] = 12'h817; wn_im[ 488] = 12'hED4;
        wn_re[ 489] = 12'h815; wn_im[ 489] = 12'hEE0;
        wn_re[ 490] = 12'h814; wn_im[ 490] = 12'hEED;
        wn_re[ 491] = 12'h812; wn_im[ 491] = 12'hEF9;
        wn_re[ 492] = 12'h810; wn_im[ 492] = 12'hF05;
        wn_re[ 493] = 12'h80F; wn_im[ 493] = 12'hF12;
        wn_re[ 494] = 12'h80D; wn_im[ 494] = 12'hF1E;
        wn_re[ 495] = 12'h80C; wn_im[ 495] = 12'hF2B;
        wn_re[ 496] = 12'h80B; wn_im[ 496] = 12'hF37;
        wn_re[ 497] = 12'h80A; wn_im[ 497] = 12'hF44;
        wn_re[ 498] = 12'h809; wn_im[ 498] = 12'hF50;
        wn_re[ 499] = 12'h808; wn_im[ 499] = 12'hF5D;
        wn_re[ 500] = 12'h807; wn_im[ 500] = 12'hF69;
        wn_re[ 501] = 12'h806; wn_im[ 501] = 12'hF76;
        wn_re[ 502] = 12'h805; wn_im[ 502] = 12'hF82;
        wn_re[ 503] = 12'h804; wn_im[ 503] = 12'hF8F;
        wn_re[ 504] = 12'h803; wn_im[ 504] = 12'hF9C;
        wn_re[ 505] = 12'h803; wn_im[ 505] = 12'hFA8;
        wn_re[ 506] = 12'h802; wn_im[ 506] = 12'hFB5;
        wn_re[ 507] = 12'h802; wn_im[ 507] = 12'hFC1;
        wn_re[ 508] = 12'h802; wn_im[ 508] = 12'hFCE;
        wn_re[ 509] = 12'h801; wn_im[ 509] = 12'hFDA;
        wn_re[ 510] = 12'h801; wn_im[ 510] = 12'hFE7;
        wn_re[ 511] = 12'h801; wn_im[ 511] = 12'hFF3;
        wn_re[ 512] = 12'h801; wn_im[ 512] = 12'h000;
        wn_re[ 513] = 12'h801; wn_im[ 513] = 12'h00D;
        wn_re[ 514] = 12'h801; wn_im[ 514] = 12'h019;
        wn_re[ 515] = 12'h801; wn_im[ 515] = 12'h026;
        wn_re[ 516] = 12'h802; wn_im[ 516] = 12'h032;
        wn_re[ 517] = 12'h802; wn_im[ 517] = 12'h03F;
        wn_re[ 518] = 12'h802; wn_im[ 518] = 12'h04B;
        wn_re[ 519] = 12'h803; wn_im[ 519] = 12'h058;
        wn_re[ 520] = 12'h803; wn_im[ 520] = 12'h064;
        wn_re[ 521] = 12'h804; wn_im[ 521] = 12'h071;
        wn_re[ 522] = 12'h805; wn_im[ 522] = 12'h07E;
        wn_re[ 523] = 12'h806; wn_im[ 523] = 12'h08A;
        wn_re[ 524] = 12'h807; wn_im[ 524] = 12'h097;
        wn_re[ 525] = 12'h808; wn_im[ 525] = 12'h0A3;
        wn_re[ 526] = 12'h809; wn_im[ 526] = 12'h0B0;
        wn_re[ 527] = 12'h80A; wn_im[ 527] = 12'h0BC;
        wn_re[ 528] = 12'h80B; wn_im[ 528] = 12'h0C9;
        wn_re[ 529] = 12'h80C; wn_im[ 529] = 12'h0D5;
        wn_re[ 530] = 12'h80D; wn_im[ 530] = 12'h0E2;
        wn_re[ 531] = 12'h80F; wn_im[ 531] = 12'h0EE;
        wn_re[ 532] = 12'h810; wn_im[ 532] = 12'h0FB;
        wn_re[ 533] = 12'h812; wn_im[ 533] = 12'h107;
        wn_re[ 534] = 12'h814; wn_im[ 534] = 12'h113;
        wn_re[ 535] = 12'h815; wn_im[ 535] = 12'h120;
        wn_re[ 536] = 12'h817; wn_im[ 536] = 12'h12C;
        wn_re[ 537] = 12'h819; wn_im[ 537] = 12'h139;
        wn_re[ 538] = 12'h81B; wn_im[ 538] = 12'h145;
        wn_re[ 539] = 12'h81D; wn_im[ 539] = 12'h152;
        wn_re[ 540] = 12'h81F; wn_im[ 540] = 12'h15E;
        wn_re[ 541] = 12'h821; wn_im[ 541] = 12'h16A;
        wn_re[ 542] = 12'h824; wn_im[ 542] = 12'h177;
        wn_re[ 543] = 12'h826; wn_im[ 543] = 12'h183;
        wn_re[ 544] = 12'h828; wn_im[ 544] = 12'h18F;
        wn_re[ 545] = 12'h82B; wn_im[ 545] = 12'h19C;
        wn_re[ 546] = 12'h82D; wn_im[ 546] = 12'h1A8;
        wn_re[ 547] = 12'h830; wn_im[ 547] = 12'h1B4;
        wn_re[ 548] = 12'h833; wn_im[ 548] = 12'h1C1;
        wn_re[ 549] = 12'h836; wn_im[ 549] = 12'h1CD;
        wn_re[ 550] = 12'h838; wn_im[ 550] = 12'h1D9;
        wn_re[ 551] = 12'h83B; wn_im[ 551] = 12'h1E5;
        wn_re[ 552] = 12'h83E; wn_im[ 552] = 12'h1F1;
        wn_re[ 553] = 12'h841; wn_im[ 553] = 12'h1FE;
        wn_re[ 554] = 12'h845; wn_im[ 554] = 12'h20A;
        wn_re[ 555] = 12'h848; wn_im[ 555] = 12'h216;
        wn_re[ 556] = 12'h84B; wn_im[ 556] = 12'h222;
        wn_re[ 557] = 12'h84F; wn_im[ 557] = 12'h22E;
        wn_re[ 558] = 12'h852; wn_im[ 558] = 12'h23A;
        wn_re[ 559] = 12'h856; wn_im[ 559] = 12'h246;
        wn_re[ 560] = 12'h859; wn_im[ 560] = 12'h252;
        wn_re[ 561] = 12'h85D; wn_im[ 561] = 12'h25E;
        wn_re[ 562] = 12'h861; wn_im[ 562] = 12'h26A;
        wn_re[ 563] = 12'h864; wn_im[ 563] = 12'h276;
        wn_re[ 564] = 12'h868; wn_im[ 564] = 12'h282;
        wn_re[ 565] = 12'h86C; wn_im[ 565] = 12'h28E;
        wn_re[ 566] = 12'h870; wn_im[ 566] = 12'h29A;
        wn_re[ 567] = 12'h874; wn_im[ 567] = 12'h2A6;
        wn_re[ 568] = 12'h879; wn_im[ 568] = 12'h2B2;
        wn_re[ 569] = 12'h87D; wn_im[ 569] = 12'h2BD;
        wn_re[ 570] = 12'h881; wn_im[ 570] = 12'h2C9;
        wn_re[ 571] = 12'h886; wn_im[ 571] = 12'h2D5;
        wn_re[ 572] = 12'h88A; wn_im[ 572] = 12'h2E1;
        wn_re[ 573] = 12'h88F; wn_im[ 573] = 12'h2EC;
        wn_re[ 574] = 12'h893; wn_im[ 574] = 12'h2F8;
        wn_re[ 575] = 12'h898; wn_im[ 575] = 12'h304;
        wn_re[ 576] = 12'h89D; wn_im[ 576] = 12'h30F;
        wn_re[ 577] = 12'h8A2; wn_im[ 577] = 12'h31B;
        wn_re[ 578] = 12'h8A7; wn_im[ 578] = 12'h327;
        wn_re[ 579] = 12'h8AC; wn_im[ 579] = 12'h332;
        wn_re[ 580] = 12'h8B1; wn_im[ 580] = 12'h33E;
        wn_re[ 581] = 12'h8B6; wn_im[ 581] = 12'h349;
        wn_re[ 582] = 12'h8BB; wn_im[ 582] = 12'h354;
        wn_re[ 583] = 12'h8C0; wn_im[ 583] = 12'h360;
        wn_re[ 584] = 12'h8C6; wn_im[ 584] = 12'h36B;
        wn_re[ 585] = 12'h8CB; wn_im[ 585] = 12'h377;
        wn_re[ 586] = 12'h8D0; wn_im[ 586] = 12'h382;
        wn_re[ 587] = 12'h8D6; wn_im[ 587] = 12'h38D;
        wn_re[ 588] = 12'h8DC; wn_im[ 588] = 12'h398;
        wn_re[ 589] = 12'h8E1; wn_im[ 589] = 12'h3A4;
        wn_re[ 590] = 12'h8E7; wn_im[ 590] = 12'h3AF;
        wn_re[ 591] = 12'h8ED; wn_im[ 591] = 12'h3BA;
        wn_re[ 592] = 12'h8F3; wn_im[ 592] = 12'h3C5;
        wn_re[ 593] = 12'h8F9; wn_im[ 593] = 12'h3D0;
        wn_re[ 594] = 12'h8FF; wn_im[ 594] = 12'h3DB;
        wn_re[ 595] = 12'h905; wn_im[ 595] = 12'h3E6;
        wn_re[ 596] = 12'h90B; wn_im[ 596] = 12'h3F1;
        wn_re[ 597] = 12'h911; wn_im[ 597] = 12'h3FC;
        wn_re[ 598] = 12'h917; wn_im[ 598] = 12'h407;
        wn_re[ 599] = 12'h91E; wn_im[ 599] = 12'h412;
        wn_re[ 600] = 12'h924; wn_im[ 600] = 12'h41C;
        wn_re[ 601] = 12'h92B; wn_im[ 601] = 12'h427;
        wn_re[ 602] = 12'h931; wn_im[ 602] = 12'h432;
        wn_re[ 603] = 12'h938; wn_im[ 603] = 12'h43D;
        wn_re[ 604] = 12'h93F; wn_im[ 604] = 12'h447;
        wn_re[ 605] = 12'h945; wn_im[ 605] = 12'h452;
        wn_re[ 606] = 12'h94C; wn_im[ 606] = 12'h45C;
        wn_re[ 607] = 12'h953; wn_im[ 607] = 12'h467;
        wn_re[ 608] = 12'h95A; wn_im[ 608] = 12'h471;
        wn_re[ 609] = 12'h961; wn_im[ 609] = 12'h47C;
        wn_re[ 610] = 12'h968; wn_im[ 610] = 12'h486;
        wn_re[ 611] = 12'h96F; wn_im[ 611] = 12'h490;
        wn_re[ 612] = 12'h976; wn_im[ 612] = 12'h49B;
        wn_re[ 613] = 12'h97E; wn_im[ 613] = 12'h4A5;
        wn_re[ 614] = 12'h985; wn_im[ 614] = 12'h4AF;
        wn_re[ 615] = 12'h98C; wn_im[ 615] = 12'h4B9;
        wn_re[ 616] = 12'h994; wn_im[ 616] = 12'h4C3;
        wn_re[ 617] = 12'h99B; wn_im[ 617] = 12'h4CD;
        wn_re[ 618] = 12'h9A3; wn_im[ 618] = 12'h4D7;
        wn_re[ 619] = 12'h9AB; wn_im[ 619] = 12'h4E1;
        wn_re[ 620] = 12'h9B2; wn_im[ 620] = 12'h4EB;
        wn_re[ 621] = 12'h9BA; wn_im[ 621] = 12'h4F5;
        wn_re[ 622] = 12'h9C2; wn_im[ 622] = 12'h4FF;
        wn_re[ 623] = 12'h9CA; wn_im[ 623] = 12'h509;
        wn_re[ 624] = 12'h9D2; wn_im[ 624] = 12'h513;
        wn_re[ 625] = 12'h9DA; wn_im[ 625] = 12'h51C;
        wn_re[ 626] = 12'h9E2; wn_im[ 626] = 12'h526;
        wn_re[ 627] = 12'h9EA; wn_im[ 627] = 12'h530;
        wn_re[ 628] = 12'h9F2; wn_im[ 628] = 12'h539;
        wn_re[ 629] = 12'h9FA; wn_im[ 629] = 12'h543;
        wn_re[ 630] = 12'hA03; wn_im[ 630] = 12'h54C;
        wn_re[ 631] = 12'hA0B; wn_im[ 631] = 12'h555;
        wn_re[ 632] = 12'hA13; wn_im[ 632] = 12'h55F;
        wn_re[ 633] = 12'hA1C; wn_im[ 633] = 12'h568;
        wn_re[ 634] = 12'hA24; wn_im[ 634] = 12'h571;
        wn_re[ 635] = 12'hA2D; wn_im[ 635] = 12'h57A;
        wn_re[ 636] = 12'hA35; wn_im[ 636] = 12'h583;
        wn_re[ 637] = 12'hA3E; wn_im[ 637] = 12'h58D;
        wn_re[ 638] = 12'hA47; wn_im[ 638] = 12'h596;
        wn_re[ 639] = 12'hA50; wn_im[ 639] = 12'h59F;
        wn_re[ 640] = 12'hA59; wn_im[ 640] = 12'h5A7;
        wn_re[ 641] = 12'hA61; wn_im[ 641] = 12'h5B0;
        wn_re[ 642] = 12'hA6A; wn_im[ 642] = 12'h5B9;
        wn_re[ 643] = 12'hA73; wn_im[ 643] = 12'h5C2;
        wn_re[ 644] = 12'hA7D; wn_im[ 644] = 12'h5CB;
        wn_re[ 645] = 12'hA86; wn_im[ 645] = 12'h5D3;
        wn_re[ 646] = 12'hA8F; wn_im[ 646] = 12'h5DC;
        wn_re[ 647] = 12'hA98; wn_im[ 647] = 12'h5E4;
        wn_re[ 648] = 12'hAA1; wn_im[ 648] = 12'h5ED;
        wn_re[ 649] = 12'hAAB; wn_im[ 649] = 12'h5F5;
        wn_re[ 650] = 12'hAB4; wn_im[ 650] = 12'h5FD;
        wn_re[ 651] = 12'hABD; wn_im[ 651] = 12'h606;
        wn_re[ 652] = 12'hAC7; wn_im[ 652] = 12'h60E;
        wn_re[ 653] = 12'hAD0; wn_im[ 653] = 12'h616;
        wn_re[ 654] = 12'hADA; wn_im[ 654] = 12'h61E;
        wn_re[ 655] = 12'hAE4; wn_im[ 655] = 12'h626;
        wn_re[ 656] = 12'hAED; wn_im[ 656] = 12'h62E;
        wn_re[ 657] = 12'hAF7; wn_im[ 657] = 12'h636;
        wn_re[ 658] = 12'hB01; wn_im[ 658] = 12'h63E;
        wn_re[ 659] = 12'hB0B; wn_im[ 659] = 12'h646;
        wn_re[ 660] = 12'hB15; wn_im[ 660] = 12'h64E;
        wn_re[ 661] = 12'hB1F; wn_im[ 661] = 12'h655;
        wn_re[ 662] = 12'hB29; wn_im[ 662] = 12'h65D;
        wn_re[ 663] = 12'hB33; wn_im[ 663] = 12'h665;
        wn_re[ 664] = 12'hB3D; wn_im[ 664] = 12'h66C;
        wn_re[ 665] = 12'hB47; wn_im[ 665] = 12'h674;
        wn_re[ 666] = 12'hB51; wn_im[ 666] = 12'h67B;
        wn_re[ 667] = 12'hB5B; wn_im[ 667] = 12'h682;
        wn_re[ 668] = 12'hB65; wn_im[ 668] = 12'h68A;
        wn_re[ 669] = 12'hB70; wn_im[ 669] = 12'h691;
        wn_re[ 670] = 12'hB7A; wn_im[ 670] = 12'h698;
        wn_re[ 671] = 12'hB84; wn_im[ 671] = 12'h69F;
        wn_re[ 672] = 12'hB8F; wn_im[ 672] = 12'h6A6;
        wn_re[ 673] = 12'hB99; wn_im[ 673] = 12'h6AD;
        wn_re[ 674] = 12'hBA4; wn_im[ 674] = 12'h6B4;
        wn_re[ 675] = 12'hBAE; wn_im[ 675] = 12'h6BB;
        wn_re[ 676] = 12'hBB9; wn_im[ 676] = 12'h6C1;
        wn_re[ 677] = 12'hBC3; wn_im[ 677] = 12'h6C8;
        wn_re[ 678] = 12'hBCE; wn_im[ 678] = 12'h6CF;
        wn_re[ 679] = 12'hBD9; wn_im[ 679] = 12'h6D5;
        wn_re[ 680] = 12'hBE4; wn_im[ 680] = 12'h6DC;
        wn_re[ 681] = 12'hBEE; wn_im[ 681] = 12'h6E2;
        wn_re[ 682] = 12'hBF9; wn_im[ 682] = 12'h6E9;
        wn_re[ 683] = 12'hC04; wn_im[ 683] = 12'h6EF;
        wn_re[ 684] = 12'hC0F; wn_im[ 684] = 12'h6F5;
        wn_re[ 685] = 12'hC1A; wn_im[ 685] = 12'h6FB;
        wn_re[ 686] = 12'hC25; wn_im[ 686] = 12'h701;
        wn_re[ 687] = 12'hC30; wn_im[ 687] = 12'h707;
        wn_re[ 688] = 12'hC3B; wn_im[ 688] = 12'h70D;
        wn_re[ 689] = 12'hC46; wn_im[ 689] = 12'h713;
        wn_re[ 690] = 12'hC51; wn_im[ 690] = 12'h719;
        wn_re[ 691] = 12'hC5C; wn_im[ 691] = 12'h71F;
        wn_re[ 692] = 12'hC68; wn_im[ 692] = 12'h724;
        wn_re[ 693] = 12'hC73; wn_im[ 693] = 12'h72A;
        wn_re[ 694] = 12'hC7E; wn_im[ 694] = 12'h730;
        wn_re[ 695] = 12'hC89; wn_im[ 695] = 12'h735;
        wn_re[ 696] = 12'hC95; wn_im[ 696] = 12'h73A;
        wn_re[ 697] = 12'hCA0; wn_im[ 697] = 12'h740;
        wn_re[ 698] = 12'hCAC; wn_im[ 698] = 12'h745;
        wn_re[ 699] = 12'hCB7; wn_im[ 699] = 12'h74A;
        wn_re[ 700] = 12'hCC2; wn_im[ 700] = 12'h74F;
        wn_re[ 701] = 12'hCCE; wn_im[ 701] = 12'h754;
        wn_re[ 702] = 12'hCD9; wn_im[ 702] = 12'h759;
        wn_re[ 703] = 12'hCE5; wn_im[ 703] = 12'h75E;
        wn_re[ 704] = 12'hCF1; wn_im[ 704] = 12'h763;
        wn_re[ 705] = 12'hCFC; wn_im[ 705] = 12'h768;
        wn_re[ 706] = 12'hD08; wn_im[ 706] = 12'h76D;
        wn_re[ 707] = 12'hD14; wn_im[ 707] = 12'h771;
        wn_re[ 708] = 12'hD1F; wn_im[ 708] = 12'h776;
        wn_re[ 709] = 12'hD2B; wn_im[ 709] = 12'h77A;
        wn_re[ 710] = 12'hD37; wn_im[ 710] = 12'h77F;
        wn_re[ 711] = 12'hD43; wn_im[ 711] = 12'h783;
        wn_re[ 712] = 12'hD4E; wn_im[ 712] = 12'h787;
        wn_re[ 713] = 12'hD5A; wn_im[ 713] = 12'h78C;
        wn_re[ 714] = 12'hD66; wn_im[ 714] = 12'h790;
        wn_re[ 715] = 12'hD72; wn_im[ 715] = 12'h794;
        wn_re[ 716] = 12'hD7E; wn_im[ 716] = 12'h798;
        wn_re[ 717] = 12'hD8A; wn_im[ 717] = 12'h79C;
        wn_re[ 718] = 12'hD96; wn_im[ 718] = 12'h79F;
        wn_re[ 719] = 12'hDA2; wn_im[ 719] = 12'h7A3;
        wn_re[ 720] = 12'hDAE; wn_im[ 720] = 12'h7A7;
        wn_re[ 721] = 12'hDBA; wn_im[ 721] = 12'h7AA;
        wn_re[ 722] = 12'hDC6; wn_im[ 722] = 12'h7AE;
        wn_re[ 723] = 12'hDD2; wn_im[ 723] = 12'h7B1;
        wn_re[ 724] = 12'hDDE; wn_im[ 724] = 12'h7B5;
        wn_re[ 725] = 12'hDEA; wn_im[ 725] = 12'h7B8;
        wn_re[ 726] = 12'hDF6; wn_im[ 726] = 12'h7BB;
        wn_re[ 727] = 12'hE02; wn_im[ 727] = 12'h7BF;
        wn_re[ 728] = 12'hE0F; wn_im[ 728] = 12'h7C2;
        wn_re[ 729] = 12'hE1B; wn_im[ 729] = 12'h7C5;
        wn_re[ 730] = 12'hE27; wn_im[ 730] = 12'h7C8;
        wn_re[ 731] = 12'hE33; wn_im[ 731] = 12'h7CA;
        wn_re[ 732] = 12'hE3F; wn_im[ 732] = 12'h7CD;
        wn_re[ 733] = 12'hE4C; wn_im[ 733] = 12'h7D0;
        wn_re[ 734] = 12'hE58; wn_im[ 734] = 12'h7D3;
        wn_re[ 735] = 12'hE64; wn_im[ 735] = 12'h7D5;
        wn_re[ 736] = 12'hE71; wn_im[ 736] = 12'h7D8;
        wn_re[ 737] = 12'hE7D; wn_im[ 737] = 12'h7DA;
        wn_re[ 738] = 12'hE89; wn_im[ 738] = 12'h7DC;
        wn_re[ 739] = 12'hE96; wn_im[ 739] = 12'h7DF;
        wn_re[ 740] = 12'hEA2; wn_im[ 740] = 12'h7E1;
        wn_re[ 741] = 12'hEAE; wn_im[ 741] = 12'h7E3;
        wn_re[ 742] = 12'hEBB; wn_im[ 742] = 12'h7E5;
        wn_re[ 743] = 12'hEC7; wn_im[ 743] = 12'h7E7;
        wn_re[ 744] = 12'hED4; wn_im[ 744] = 12'h7E9;
        wn_re[ 745] = 12'hEE0; wn_im[ 745] = 12'h7EB;
        wn_re[ 746] = 12'hEED; wn_im[ 746] = 12'h7EC;
        wn_re[ 747] = 12'hEF9; wn_im[ 747] = 12'h7EE;
        wn_re[ 748] = 12'hF05; wn_im[ 748] = 12'h7F0;
        wn_re[ 749] = 12'hF12; wn_im[ 749] = 12'h7F1;
        wn_re[ 750] = 12'hF1E; wn_im[ 750] = 12'h7F3;
        wn_re[ 751] = 12'hF2B; wn_im[ 751] = 12'h7F4;
        wn_re[ 752] = 12'hF37; wn_im[ 752] = 12'h7F5;
        wn_re[ 753] = 12'hF44; wn_im[ 753] = 12'h7F6;
        wn_re[ 754] = 12'hF50; wn_im[ 754] = 12'h7F7;
        wn_re[ 755] = 12'hF5D; wn_im[ 755] = 12'h7F8;
        wn_re[ 756] = 12'hF69; wn_im[ 756] = 12'h7F9;
        wn_re[ 757] = 12'hF76; wn_im[ 757] = 12'h7FA;
        wn_re[ 758] = 12'hF82; wn_im[ 758] = 12'h7FB;
        wn_re[ 759] = 12'hF8F; wn_im[ 759] = 12'h7FC;
        wn_re[ 760] = 12'hF9C; wn_im[ 760] = 12'h7FD;
        wn_re[ 761] = 12'hFA8; wn_im[ 761] = 12'h7FD;
        wn_re[ 762] = 12'hFB5; wn_im[ 762] = 12'h7FE;
        wn_re[ 763] = 12'hFC1; wn_im[ 763] = 12'h7FE;
        wn_re[ 764] = 12'hFCE; wn_im[ 764] = 12'h7FE;
        wn_re[ 765] = 12'hFDA; wn_im[ 765] = 12'h7FF;
        wn_re[ 766] = 12'hFE7; wn_im[ 766] = 12'h7FF;
        wn_re[ 767] = 12'hFF3; wn_im[ 767] = 12'h7FF;
        wn_re[ 768] = 12'h000; wn_im[ 768] = 12'h7FF;
        wn_re[ 769] = 12'h00D; wn_im[ 769] = 12'h7FF;
        wn_re[ 770] = 12'h019; wn_im[ 770] = 12'h7FF;
        wn_re[ 771] = 12'h026; wn_im[ 771] = 12'h7FF;
        wn_re[ 772] = 12'h032; wn_im[ 772] = 12'h7FE;
        wn_re[ 773] = 12'h03F; wn_im[ 773] = 12'h7FE;
        wn_re[ 774] = 12'h04B; wn_im[ 774] = 12'h7FE;
        wn_re[ 775] = 12'h058; wn_im[ 775] = 12'h7FD;
        wn_re[ 776] = 12'h064; wn_im[ 776] = 12'h7FD;
        wn_re[ 777] = 12'h071; wn_im[ 777] = 12'h7FC;
        wn_re[ 778] = 12'h07E; wn_im[ 778] = 12'h7FB;
        wn_re[ 779] = 12'h08A; wn_im[ 779] = 12'h7FA;
        wn_re[ 780] = 12'h097; wn_im[ 780] = 12'h7F9;
        wn_re[ 781] = 12'h0A3; wn_im[ 781] = 12'h7F8;
        wn_re[ 782] = 12'h0B0; wn_im[ 782] = 12'h7F7;
        wn_re[ 783] = 12'h0BC; wn_im[ 783] = 12'h7F6;
        wn_re[ 784] = 12'h0C9; wn_im[ 784] = 12'h7F5;
        wn_re[ 785] = 12'h0D5; wn_im[ 785] = 12'h7F4;
        wn_re[ 786] = 12'h0E2; wn_im[ 786] = 12'h7F3;
        wn_re[ 787] = 12'h0EE; wn_im[ 787] = 12'h7F1;
        wn_re[ 788] = 12'h0FB; wn_im[ 788] = 12'h7F0;
        wn_re[ 789] = 12'h107; wn_im[ 789] = 12'h7EE;
        wn_re[ 790] = 12'h113; wn_im[ 790] = 12'h7EC;
        wn_re[ 791] = 12'h120; wn_im[ 791] = 12'h7EB;
        wn_re[ 792] = 12'h12C; wn_im[ 792] = 12'h7E9;
        wn_re[ 793] = 12'h139; wn_im[ 793] = 12'h7E7;
        wn_re[ 794] = 12'h145; wn_im[ 794] = 12'h7E5;
        wn_re[ 795] = 12'h152; wn_im[ 795] = 12'h7E3;
        wn_re[ 796] = 12'h15E; wn_im[ 796] = 12'h7E1;
        wn_re[ 797] = 12'h16A; wn_im[ 797] = 12'h7DF;
        wn_re[ 798] = 12'h177; wn_im[ 798] = 12'h7DC;
        wn_re[ 799] = 12'h183; wn_im[ 799] = 12'h7DA;
        wn_re[ 800] = 12'h18F; wn_im[ 800] = 12'h7D8;
        wn_re[ 801] = 12'h19C; wn_im[ 801] = 12'h7D5;
        wn_re[ 802] = 12'h1A8; wn_im[ 802] = 12'h7D3;
        wn_re[ 803] = 12'h1B4; wn_im[ 803] = 12'h7D0;
        wn_re[ 804] = 12'h1C1; wn_im[ 804] = 12'h7CD;
        wn_re[ 805] = 12'h1CD; wn_im[ 805] = 12'h7CA;
        wn_re[ 806] = 12'h1D9; wn_im[ 806] = 12'h7C8;
        wn_re[ 807] = 12'h1E5; wn_im[ 807] = 12'h7C5;
        wn_re[ 808] = 12'h1F1; wn_im[ 808] = 12'h7C2;
        wn_re[ 809] = 12'h1FE; wn_im[ 809] = 12'h7BF;
        wn_re[ 810] = 12'h20A; wn_im[ 810] = 12'h7BB;
        wn_re[ 811] = 12'h216; wn_im[ 811] = 12'h7B8;
        wn_re[ 812] = 12'h222; wn_im[ 812] = 12'h7B5;
        wn_re[ 813] = 12'h22E; wn_im[ 813] = 12'h7B1;
        wn_re[ 814] = 12'h23A; wn_im[ 814] = 12'h7AE;
        wn_re[ 815] = 12'h246; wn_im[ 815] = 12'h7AA;
        wn_re[ 816] = 12'h252; wn_im[ 816] = 12'h7A7;
        wn_re[ 817] = 12'h25E; wn_im[ 817] = 12'h7A3;
        wn_re[ 818] = 12'h26A; wn_im[ 818] = 12'h79F;
        wn_re[ 819] = 12'h276; wn_im[ 819] = 12'h79C;
        wn_re[ 820] = 12'h282; wn_im[ 820] = 12'h798;
        wn_re[ 821] = 12'h28E; wn_im[ 821] = 12'h794;
        wn_re[ 822] = 12'h29A; wn_im[ 822] = 12'h790;
        wn_re[ 823] = 12'h2A6; wn_im[ 823] = 12'h78C;
        wn_re[ 824] = 12'h2B2; wn_im[ 824] = 12'h787;
        wn_re[ 825] = 12'h2BD; wn_im[ 825] = 12'h783;
        wn_re[ 826] = 12'h2C9; wn_im[ 826] = 12'h77F;
        wn_re[ 827] = 12'h2D5; wn_im[ 827] = 12'h77A;
        wn_re[ 828] = 12'h2E1; wn_im[ 828] = 12'h776;
        wn_re[ 829] = 12'h2EC; wn_im[ 829] = 12'h771;
        wn_re[ 830] = 12'h2F8; wn_im[ 830] = 12'h76D;
        wn_re[ 831] = 12'h304; wn_im[ 831] = 12'h768;
        wn_re[ 832] = 12'h30F; wn_im[ 832] = 12'h763;
        wn_re[ 833] = 12'h31B; wn_im[ 833] = 12'h75E;
        wn_re[ 834] = 12'h327; wn_im[ 834] = 12'h759;
        wn_re[ 835] = 12'h332; wn_im[ 835] = 12'h754;
        wn_re[ 836] = 12'h33E; wn_im[ 836] = 12'h74F;
        wn_re[ 837] = 12'h349; wn_im[ 837] = 12'h74A;
        wn_re[ 838] = 12'h354; wn_im[ 838] = 12'h745;
        wn_re[ 839] = 12'h360; wn_im[ 839] = 12'h740;
        wn_re[ 840] = 12'h36B; wn_im[ 840] = 12'h73A;
        wn_re[ 841] = 12'h377; wn_im[ 841] = 12'h735;
        wn_re[ 842] = 12'h382; wn_im[ 842] = 12'h730;
        wn_re[ 843] = 12'h38D; wn_im[ 843] = 12'h72A;
        wn_re[ 844] = 12'h398; wn_im[ 844] = 12'h724;
        wn_re[ 845] = 12'h3A4; wn_im[ 845] = 12'h71F;
        wn_re[ 846] = 12'h3AF; wn_im[ 846] = 12'h719;
        wn_re[ 847] = 12'h3BA; wn_im[ 847] = 12'h713;
        wn_re[ 848] = 12'h3C5; wn_im[ 848] = 12'h70D;
        wn_re[ 849] = 12'h3D0; wn_im[ 849] = 12'h707;
        wn_re[ 850] = 12'h3DB; wn_im[ 850] = 12'h701;
        wn_re[ 851] = 12'h3E6; wn_im[ 851] = 12'h6FB;
        wn_re[ 852] = 12'h3F1; wn_im[ 852] = 12'h6F5;
        wn_re[ 853] = 12'h3FC; wn_im[ 853] = 12'h6EF;
        wn_re[ 854] = 12'h407; wn_im[ 854] = 12'h6E9;
        wn_re[ 855] = 12'h412; wn_im[ 855] = 12'h6E2;
        wn_re[ 856] = 12'h41C; wn_im[ 856] = 12'h6DC;
        wn_re[ 857] = 12'h427; wn_im[ 857] = 12'h6D5;
        wn_re[ 858] = 12'h432; wn_im[ 858] = 12'h6CF;
        wn_re[ 859] = 12'h43D; wn_im[ 859] = 12'h6C8;
        wn_re[ 860] = 12'h447; wn_im[ 860] = 12'h6C1;
        wn_re[ 861] = 12'h452; wn_im[ 861] = 12'h6BB;
        wn_re[ 862] = 12'h45C; wn_im[ 862] = 12'h6B4;
        wn_re[ 863] = 12'h467; wn_im[ 863] = 12'h6AD;
        wn_re[ 864] = 12'h471; wn_im[ 864] = 12'h6A6;
        wn_re[ 865] = 12'h47C; wn_im[ 865] = 12'h69F;
        wn_re[ 866] = 12'h486; wn_im[ 866] = 12'h698;
        wn_re[ 867] = 12'h490; wn_im[ 867] = 12'h691;
        wn_re[ 868] = 12'h49B; wn_im[ 868] = 12'h68A;
        wn_re[ 869] = 12'h4A5; wn_im[ 869] = 12'h682;
        wn_re[ 870] = 12'h4AF; wn_im[ 870] = 12'h67B;
        wn_re[ 871] = 12'h4B9; wn_im[ 871] = 12'h674;
        wn_re[ 872] = 12'h4C3; wn_im[ 872] = 12'h66C;
        wn_re[ 873] = 12'h4CD; wn_im[ 873] = 12'h665;
        wn_re[ 874] = 12'h4D7; wn_im[ 874] = 12'h65D;
        wn_re[ 875] = 12'h4E1; wn_im[ 875] = 12'h655;
        wn_re[ 876] = 12'h4EB; wn_im[ 876] = 12'h64E;
        wn_re[ 877] = 12'h4F5; wn_im[ 877] = 12'h646;
        wn_re[ 878] = 12'h4FF; wn_im[ 878] = 12'h63E;
        wn_re[ 879] = 12'h509; wn_im[ 879] = 12'h636;
        wn_re[ 880] = 12'h513; wn_im[ 880] = 12'h62E;
        wn_re[ 881] = 12'h51C; wn_im[ 881] = 12'h626;
        wn_re[ 882] = 12'h526; wn_im[ 882] = 12'h61E;
        wn_re[ 883] = 12'h530; wn_im[ 883] = 12'h616;
        wn_re[ 884] = 12'h539; wn_im[ 884] = 12'h60E;
        wn_re[ 885] = 12'h543; wn_im[ 885] = 12'h606;
        wn_re[ 886] = 12'h54C; wn_im[ 886] = 12'h5FD;
        wn_re[ 887] = 12'h555; wn_im[ 887] = 12'h5F5;
        wn_re[ 888] = 12'h55F; wn_im[ 888] = 12'h5ED;
        wn_re[ 889] = 12'h568; wn_im[ 889] = 12'h5E4;
        wn_re[ 890] = 12'h571; wn_im[ 890] = 12'h5DC;
        wn_re[ 891] = 12'h57A; wn_im[ 891] = 12'h5D3;
        wn_re[ 892] = 12'h583; wn_im[ 892] = 12'h5CB;
        wn_re[ 893] = 12'h58D; wn_im[ 893] = 12'h5C2;
        wn_re[ 894] = 12'h596; wn_im[ 894] = 12'h5B9;
        wn_re[ 895] = 12'h59F; wn_im[ 895] = 12'h5B0;
        wn_re[ 896] = 12'h5A7; wn_im[ 896] = 12'h5A7;
        wn_re[ 897] = 12'h5B0; wn_im[ 897] = 12'h59F;
        wn_re[ 898] = 12'h5B9; wn_im[ 898] = 12'h596;
        wn_re[ 899] = 12'h5C2; wn_im[ 899] = 12'h58D;
        wn_re[ 900] = 12'h5CB; wn_im[ 900] = 12'h583;
        wn_re[ 901] = 12'h5D3; wn_im[ 901] = 12'h57A;
        wn_re[ 902] = 12'h5DC; wn_im[ 902] = 12'h571;
        wn_re[ 903] = 12'h5E4; wn_im[ 903] = 12'h568;
        wn_re[ 904] = 12'h5ED; wn_im[ 904] = 12'h55F;
        wn_re[ 905] = 12'h5F5; wn_im[ 905] = 12'h555;
        wn_re[ 906] = 12'h5FD; wn_im[ 906] = 12'h54C;
        wn_re[ 907] = 12'h606; wn_im[ 907] = 12'h543;
        wn_re[ 908] = 12'h60E; wn_im[ 908] = 12'h539;
        wn_re[ 909] = 12'h616; wn_im[ 909] = 12'h530;
        wn_re[ 910] = 12'h61E; wn_im[ 910] = 12'h526;
        wn_re[ 911] = 12'h626; wn_im[ 911] = 12'h51C;
        wn_re[ 912] = 12'h62E; wn_im[ 912] = 12'h513;
        wn_re[ 913] = 12'h636; wn_im[ 913] = 12'h509;
        wn_re[ 914] = 12'h63E; wn_im[ 914] = 12'h4FF;
        wn_re[ 915] = 12'h646; wn_im[ 915] = 12'h4F5;
        wn_re[ 916] = 12'h64E; wn_im[ 916] = 12'h4EB;
        wn_re[ 917] = 12'h655; wn_im[ 917] = 12'h4E1;
        wn_re[ 918] = 12'h65D; wn_im[ 918] = 12'h4D7;
        wn_re[ 919] = 12'h665; wn_im[ 919] = 12'h4CD;
        wn_re[ 920] = 12'h66C; wn_im[ 920] = 12'h4C3;
        wn_re[ 921] = 12'h674; wn_im[ 921] = 12'h4B9;
        wn_re[ 922] = 12'h67B; wn_im[ 922] = 12'h4AF;
        wn_re[ 923] = 12'h682; wn_im[ 923] = 12'h4A5;
        wn_re[ 924] = 12'h68A; wn_im[ 924] = 12'h49B;
        wn_re[ 925] = 12'h691; wn_im[ 925] = 12'h490;
        wn_re[ 926] = 12'h698; wn_im[ 926] = 12'h486;
        wn_re[ 927] = 12'h69F; wn_im[ 927] = 12'h47C;
        wn_re[ 928] = 12'h6A6; wn_im[ 928] = 12'h471;
        wn_re[ 929] = 12'h6AD; wn_im[ 929] = 12'h467;
        wn_re[ 930] = 12'h6B4; wn_im[ 930] = 12'h45C;
        wn_re[ 931] = 12'h6BB; wn_im[ 931] = 12'h452;
        wn_re[ 932] = 12'h6C1; wn_im[ 932] = 12'h447;
        wn_re[ 933] = 12'h6C8; wn_im[ 933] = 12'h43D;
        wn_re[ 934] = 12'h6CF; wn_im[ 934] = 12'h432;
        wn_re[ 935] = 12'h6D5; wn_im[ 935] = 12'h427;
        wn_re[ 936] = 12'h6DC; wn_im[ 936] = 12'h41C;
        wn_re[ 937] = 12'h6E2; wn_im[ 937] = 12'h412;
        wn_re[ 938] = 12'h6E9; wn_im[ 938] = 12'h407;
        wn_re[ 939] = 12'h6EF; wn_im[ 939] = 12'h3FC;
        wn_re[ 940] = 12'h6F5; wn_im[ 940] = 12'h3F1;
        wn_re[ 941] = 12'h6FB; wn_im[ 941] = 12'h3E6;
        wn_re[ 942] = 12'h701; wn_im[ 942] = 12'h3DB;
        wn_re[ 943] = 12'h707; wn_im[ 943] = 12'h3D0;
        wn_re[ 944] = 12'h70D; wn_im[ 944] = 12'h3C5;
        wn_re[ 945] = 12'h713; wn_im[ 945] = 12'h3BA;
        wn_re[ 946] = 12'h719; wn_im[ 946] = 12'h3AF;
        wn_re[ 947] = 12'h71F; wn_im[ 947] = 12'h3A4;
        wn_re[ 948] = 12'h724; wn_im[ 948] = 12'h398;
        wn_re[ 949] = 12'h72A; wn_im[ 949] = 12'h38D;
        wn_re[ 950] = 12'h730; wn_im[ 950] = 12'h382;
        wn_re[ 951] = 12'h735; wn_im[ 951] = 12'h377;
        wn_re[ 952] = 12'h73A; wn_im[ 952] = 12'h36B;
        wn_re[ 953] = 12'h740; wn_im[ 953] = 12'h360;
        wn_re[ 954] = 12'h745; wn_im[ 954] = 12'h354;
        wn_re[ 955] = 12'h74A; wn_im[ 955] = 12'h349;
        wn_re[ 956] = 12'h74F; wn_im[ 956] = 12'h33E;
        wn_re[ 957] = 12'h754; wn_im[ 957] = 12'h332;
        wn_re[ 958] = 12'h759; wn_im[ 958] = 12'h327;
        wn_re[ 959] = 12'h75E; wn_im[ 959] = 12'h31B;
        wn_re[ 960] = 12'h763; wn_im[ 960] = 12'h30F;
        wn_re[ 961] = 12'h768; wn_im[ 961] = 12'h304;
        wn_re[ 962] = 12'h76D; wn_im[ 962] = 12'h2F8;
        wn_re[ 963] = 12'h771; wn_im[ 963] = 12'h2EC;
        wn_re[ 964] = 12'h776; wn_im[ 964] = 12'h2E1;
        wn_re[ 965] = 12'h77A; wn_im[ 965] = 12'h2D5;
        wn_re[ 966] = 12'h77F; wn_im[ 966] = 12'h2C9;
        wn_re[ 967] = 12'h783; wn_im[ 967] = 12'h2BD;
        wn_re[ 968] = 12'h787; wn_im[ 968] = 12'h2B2;
        wn_re[ 969] = 12'h78C; wn_im[ 969] = 12'h2A6;
        wn_re[ 970] = 12'h790; wn_im[ 970] = 12'h29A;
        wn_re[ 971] = 12'h794; wn_im[ 971] = 12'h28E;
        wn_re[ 972] = 12'h798; wn_im[ 972] = 12'h282;
        wn_re[ 973] = 12'h79C; wn_im[ 973] = 12'h276;
        wn_re[ 974] = 12'h79F; wn_im[ 974] = 12'h26A;
        wn_re[ 975] = 12'h7A3; wn_im[ 975] = 12'h25E;
        wn_re[ 976] = 12'h7A7; wn_im[ 976] = 12'h252;
        wn_re[ 977] = 12'h7AA; wn_im[ 977] = 12'h246;
        wn_re[ 978] = 12'h7AE; wn_im[ 978] = 12'h23A;
        wn_re[ 979] = 12'h7B1; wn_im[ 979] = 12'h22E;
        wn_re[ 980] = 12'h7B5; wn_im[ 980] = 12'h222;
        wn_re[ 981] = 12'h7B8; wn_im[ 981] = 12'h216;
        wn_re[ 982] = 12'h7BB; wn_im[ 982] = 12'h20A;
        wn_re[ 983] = 12'h7BF; wn_im[ 983] = 12'h1FE;
        wn_re[ 984] = 12'h7C2; wn_im[ 984] = 12'h1F1;
        wn_re[ 985] = 12'h7C5; wn_im[ 985] = 12'h1E5;
        wn_re[ 986] = 12'h7C8; wn_im[ 986] = 12'h1D9;
        wn_re[ 987] = 12'h7CA; wn_im[ 987] = 12'h1CD;
        wn_re[ 988] = 12'h7CD; wn_im[ 988] = 12'h1C1;
        wn_re[ 989] = 12'h7D0; wn_im[ 989] = 12'h1B4;
        wn_re[ 990] = 12'h7D3; wn_im[ 990] = 12'h1A8;
        wn_re[ 991] = 12'h7D5; wn_im[ 991] = 12'h19C;
        wn_re[ 992] = 12'h7D8; wn_im[ 992] = 12'h18F;
        wn_re[ 993] = 12'h7DA; wn_im[ 993] = 12'h183;
        wn_re[ 994] = 12'h7DC; wn_im[ 994] = 12'h177;
        wn_re[ 995] = 12'h7DF; wn_im[ 995] = 12'h16A;
        wn_re[ 996] = 12'h7E1; wn_im[ 996] = 12'h15E;
        wn_re[ 997] = 12'h7E3; wn_im[ 997] = 12'h152;
        wn_re[ 998] = 12'h7E5; wn_im[ 998] = 12'h145;
        wn_re[ 999] = 12'h7E7; wn_im[ 999] = 12'h139;
        wn_re[1000] = 12'h7E9; wn_im[1000] = 12'h12C;
        wn_re[1001] = 12'h7EB; wn_im[1001] = 12'h120;
        wn_re[1002] = 12'h7EC; wn_im[1002] = 12'h113;
        wn_re[1003] = 12'h7EE; wn_im[1003] = 12'h107;
        wn_re[1004] = 12'h7F0; wn_im[1004] = 12'h0FB;
        wn_re[1005] = 12'h7F1; wn_im[1005] = 12'h0EE;
        wn_re[1006] = 12'h7F3; wn_im[1006] = 12'h0E2;
        wn_re[1007] = 12'h7F4; wn_im[1007] = 12'h0D5;
        wn_re[1008] = 12'h7F5; wn_im[1008] = 12'h0C9;
        wn_re[1009] = 12'h7F6; wn_im[1009] = 12'h0BC;
        wn_re[1010] = 12'h7F7; wn_im[1010] = 12'h0B0;
        wn_re[1011] = 12'h7F8; wn_im[1011] = 12'h0A3;
        wn_re[1012] = 12'h7F9; wn_im[1012] = 12'h097;
        wn_re[1013] = 12'h7FA; wn_im[1013] = 12'h08A;
        wn_re[1014] = 12'h7FB; wn_im[1014] = 12'h07E;
        wn_re[1015] = 12'h7FC; wn_im[1015] = 12'h071;
        wn_re[1016] = 12'h7FD; wn_im[1016] = 12'h064;
        wn_re[1017] = 12'h7FD; wn_im[1017] = 12'h058;
        wn_re[1018] = 12'h7FE; wn_im[1018] = 12'h04B;
        wn_re[1019] = 12'h7FE; wn_im[1019] = 12'h03F;
        wn_re[1020] = 12'h7FE; wn_im[1020] = 12'h032;
        wn_re[1021] = 12'h7FF; wn_im[1021] = 12'h026;
        wn_re[1022] = 12'h7FF; wn_im[1022] = 12'h019;
        wn_re[1023] = 12'h7FF; wn_im[1023] = 12'h00D;
    end

always @(posedge clock) begin
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
