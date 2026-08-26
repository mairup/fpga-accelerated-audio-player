package dsp

import chisel3._
import chisel3.util._

class DualPortBramRom(val entries: Int, val dataWidth: Int, val initData: Seq[BigInt])
    extends BlackBox with HasBlackBoxInline {

  val addrWidth = log2Ceil(entries)

  val io = IO(new Bundle {
    val clk = Input(Clock())
    val addrA = Input(UInt(addrWidth.W))
    val addrB = Input(UInt(addrWidth.W))
    val dataA = Output(SInt(dataWidth.W))
    val dataB = Output(SInt(dataWidth.W))
  })

  private val hexLines = initData.zipWithIndex.map { case (value, idx) =>
    val hexStr = f"${value & 0xFFFFFFFFL}%08x"
    s"      mem[$idx] = 32'h$hexStr;"
  }.mkString("\n")

  private val modName = s"DualPortBramRom_${entries}_${dataWidth}_${Math.abs(initData.hashCode())}"
  override val desiredName = modName

  setInline(
    s"$modName.v",
    s"""module $modName (
       |  input  wire clk,
       |  input  wire [${addrWidth - 1}:0] addrA,
       |  input  wire [${addrWidth - 1}:0] addrB,
       |  output reg  [${dataWidth - 1}:0] dataA,
       |  output reg  [${dataWidth - 1}:0] dataB
       |);
       |  (* ram_style = "block" *) reg [${dataWidth - 1}:0] mem [0:${entries - 1}];
       |
       |  initial begin
       |$hexLines
       |  end
       |
       |  always @(posedge clk) begin
       |    dataA <= mem[addrA];
       |    dataB <= mem[addrB];
       |  end
       |endmodule
       |""".stripMargin
  )
}

class DualPortBramRam(val entries: Int, val dataWidth: Int)
    extends BlackBox with HasBlackBoxInline {

  val addrWidth = log2Ceil(entries)

  val io = IO(new Bundle {
    val clk   = Input(Clock())
    val weA   = Input(Bool())
    val addrA = Input(UInt(addrWidth.W))
    val dinA  = Input(SInt(dataWidth.W))
    val addrB = Input(UInt(addrWidth.W))
    val doutB = Output(SInt(dataWidth.W))
  })

  private val modName = s"DualPortBramRam_${entries}_${dataWidth}"
  override val desiredName = modName

  setInline(
    s"$modName.v",
    s"""module $modName (
       |  input  wire clk,
       |  input  wire weA,
       |  input  wire [${addrWidth - 1}:0] addrA,
       |  input  wire [${dataWidth - 1}:0] dinA,
       |  input  wire [${addrWidth - 1}:0] addrB,
       |  output reg  [${dataWidth - 1}:0] doutB
       |);
       |  (* ram_style = "block" *) reg [${dataWidth - 1}:0] mem [0:${entries - 1}];
       |
       |  always @(posedge clk) begin
       |    if (weA)
       |      mem[addrA] <= dinA;
       |    doutB <= mem[addrB];
       |  end
       |endmodule
       |""".stripMargin
  )
}
