module main;
    reg clk;
    reg rst;
    reg rdy;
    wire [7:0] mem_dout;
    wire [31:0] mem_a;
    wire mem_wr;

    cpu dut(
        .clk_in(clk),
        .rst_in(rst),
        .rdy_in(rdy),
        .mem_din(8'b0),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr)
    );

    initial begin
        clk = 0;
        rst = 1;
        rdy = 1;
        #10 rst = 0;
        #2000 $finish;
    end

    always #1 clk = ~clk;

    always @(posedge clk) begin
        if (mem_wr && mem_a == 32'h30000) begin
            $write("%c", mem_dout);
        end
    end
endmodule
