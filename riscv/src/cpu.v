module cpu(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,
    input wire [7:0] mem_din,
    output reg [7:0] mem_dout,
    output reg [31:0] mem_a,
    output reg mem_wr
);
    localparam IO_ADDR = 32'h30000;
    localparam IO_CYCLE = 32'h30004;

    reg [31:0] cycle_counter;
    reg [31:0] pc;
    reg [31:0] regs[0:31];
    reg [7:0] mem[0:131071];

    integer i;

    function [31:0] load_word;
        input [31:0] addr;
        begin
            load_word = {mem[addr + 3], mem[addr + 2], mem[addr + 1], mem[addr]};
        end
    endfunction

    function [31:0] load_half_signed;
        input [31:0] addr;
        reg [15:0] data;
        begin
            data = {mem[addr + 1], mem[addr]};
            load_half_signed = {{16{data[15]}}, data};
        end
    endfunction

    function [31:0] load_half_unsigned;
        input [31:0] addr;
        reg [15:0] data;
        begin
            data = {mem[addr + 1], mem[addr]};
            load_half_unsigned = {16'b0, data};
        end
    endfunction

    function [31:0] load_byte_signed;
        input [31:0] addr;
        begin
            load_byte_signed = {{24{mem[addr][7]}}, mem[addr]};
        end
    endfunction

    function [31:0] load_byte_unsigned;
        input [31:0] addr;
        begin
            load_byte_unsigned = {24'b0, mem[addr]};
        end
    endfunction

    function [31:0] sign_extend12;
        input [11:0] imm;
        begin
            sign_extend12 = {{20{imm[11]}}, imm};
        end
    endfunction

    function [31:0] sign_extend13;
        input [12:0] imm;
        begin
            sign_extend13 = {{19{imm[12]}}, imm};
        end
    endfunction

    function [31:0] sign_extend21;
        input [20:0] imm;
        begin
            sign_extend21 = {{11{imm[20]}}, imm};
        end
    endfunction

    reg [31:0] inst;
    reg [31:0] next_pc;
    reg [31:0] rd_value;
    reg [31:0] rs1_val;
    reg [31:0] rs2_val;
    reg [31:0] addr;
    reg [31:0] imm_i;
    reg [31:0] imm_s;
    reg [31:0] imm_b;
    reg [31:0] imm_u;
    reg [31:0] imm_j;
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;
    reg [6:0] opcode;
    reg [2:0] funct3;
    reg [6:0] funct7;

    initial begin
        pc = 0;
        cycle_counter = 0;
        mem_a = 0;
        mem_dout = 0;
        mem_wr = 0;
        for (i = 0; i < 32; i = i + 1) regs[i] = 0;
        for (i = 0; i < 131072; i = i + 1) mem[i] = 0;
        $readmemh("testcase.hex", mem);
    end

    always @(posedge clk_in) begin
        if (rst_in) begin
            pc <= 0;
            cycle_counter <= 0;
            mem_a <= 0;
            mem_dout <= 0;
            mem_wr <= 0;
            for (i = 0; i < 32; i = i + 1) regs[i] <= 0;
        end else if (rdy_in) begin
            inst = load_word(pc);
            next_pc = pc + 4;
            rd_value = 0;
            rs1 = inst[19:15];
            rs2 = inst[24:20];
            rd = inst[11:7];
            opcode = inst[6:0];
            funct3 = inst[14:12];
            funct7 = inst[31:25];
            rs1_val = regs[rs1];
            rs2_val = regs[rs2];
            imm_i = sign_extend12(inst[31:20]);
            imm_s = sign_extend12({inst[31:25], inst[11:7]});
            imm_b = sign_extend13({inst[31], inst[7], inst[30:25], inst[11:8], 1'b0});
            imm_u = {inst[31:12], 12'b0};
            imm_j = sign_extend21({inst[31], inst[19:12], inst[20], inst[30:21], 1'b0});
            mem_wr <= 0;
            cycle_counter <= cycle_counter + 1;

            case (opcode)
                7'b0110111: rd_value = imm_u;
                7'b0010111: rd_value = pc + imm_u;
                7'b1101111: begin
                    rd_value = next_pc;
                    next_pc = pc + imm_j;
                end
                7'b1100111: begin
                    rd_value = next_pc;
                    next_pc = (rs1_val + imm_i) & 32'hfffffffe;
                end
                7'b1100011: begin
                    case (funct3)
                        3'b000: if (rs1_val == rs2_val) next_pc = pc + imm_b;
                        3'b001: if (rs1_val != rs2_val) next_pc = pc + imm_b;
                        3'b100: if ($signed(rs1_val) < $signed(rs2_val)) next_pc = pc + imm_b;
                        3'b101: if ($signed(rs1_val) >= $signed(rs2_val)) next_pc = pc + imm_b;
                        3'b110: if (rs1_val < rs2_val) next_pc = pc + imm_b;
                        3'b111: if (rs1_val >= rs2_val) next_pc = pc + imm_b;
                    endcase
                end
                7'b0000011: begin
                    addr = rs1_val + imm_i;
                    if (addr == IO_CYCLE) begin
                        rd_value = cycle_counter;
                    end else begin
                        case (funct3)
                            3'b000: rd_value = load_byte_signed(addr);
                            3'b001: rd_value = load_half_signed(addr);
                            3'b010: rd_value = load_word(addr);
                            3'b100: rd_value = load_byte_unsigned(addr);
                            3'b101: rd_value = load_half_unsigned(addr);
                        endcase
                    end
                end
                7'b0100011: begin
                    addr = rs1_val + imm_s;
                    case (funct3)
                        3'b000: begin
                            mem[addr] <= rs2_val[7:0];
                            if (addr == IO_ADDR) mem_dout <= rs2_val[7:0];
                        end
                        3'b001: begin
                            mem[addr] <= rs2_val[7:0];
                            mem[addr + 1] <= rs2_val[15:8];
                            if (addr == IO_ADDR) mem_dout <= rs2_val[7:0];
                        end
                        3'b010: begin
                            mem[addr] <= rs2_val[7:0];
                            mem[addr + 1] <= rs2_val[15:8];
                            mem[addr + 2] <= rs2_val[23:16];
                            mem[addr + 3] <= rs2_val[31:24];
                            if (addr == IO_ADDR) mem_dout <= rs2_val[7:0];
                        end
                    endcase
                    mem_a <= addr;
                    mem_wr <= 1;
                end
                7'b0010011: begin
                    case (funct3)
                        3'b000: rd_value = rs1_val + imm_i;
                        3'b001: rd_value = rs1_val << inst[24:20];
                        3'b010: rd_value = ($signed(rs1_val) < $signed(imm_i)) ? 32'd1 : 32'd0;
                        3'b011: rd_value = (rs1_val < imm_i) ? 32'd1 : 32'd0;
                        3'b100: rd_value = rs1_val ^ imm_i;
                        3'b101: rd_value = funct7[5] ? ($signed(rs1_val) >>> inst[24:20]) : (rs1_val >> inst[24:20]);
                        3'b110: rd_value = rs1_val | imm_i;
                        3'b111: rd_value = rs1_val & imm_i;
                    endcase
                end
                7'b0110011: begin
                    case (funct3)
                        3'b000: rd_value = funct7[5] ? (rs1_val - rs2_val) : (rs1_val + rs2_val);
                        3'b001: rd_value = rs1_val << rs2_val[4:0];
                        3'b010: rd_value = ($signed(rs1_val) < $signed(rs2_val)) ? 32'd1 : 32'd0;
                        3'b011: rd_value = (rs1_val < rs2_val) ? 32'd1 : 32'd0;
                        3'b100: rd_value = rs1_val ^ rs2_val;
                        3'b101: rd_value = funct7[5] ? ($signed(rs1_val) >>> rs2_val[4:0]) : (rs1_val >> rs2_val[4:0]);
                        3'b110: rd_value = rs1_val | rs2_val;
                        3'b111: rd_value = rs1_val & rs2_val;
                    endcase
                end
            endcase

            if (rd != 0 && opcode != 7'b0100011 && opcode != 7'b1100011) regs[rd] <= rd_value;
            regs[0] <= 0;
            pc <= next_pc;
            if (!(opcode == 7'b0100011)) mem_a <= pc;
        end
    end
endmodule
