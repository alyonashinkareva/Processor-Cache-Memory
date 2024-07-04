module memory #(
    parameter MEM_SIZE = 2**18,
    parameter ADDR2_BUS_SIZE = 14,
    parameter DATA2_BUS_SIZE = 16,
    parameter CTR2_BUS_SIZE = 2
)
(
    input wire clk,
    input wire [ADDR2_BUS_SIZE - 1 : 0] A2,
    inout wire [DATA2_BUS_SIZE - 1 : 0] D2,
    inout wire [CTR2_BUS_SIZE - 1 : 0] C2
);
reg [DATA2_BUS_SIZE - 1 : 0] D2_reg;
reg [CTR2_BUS_SIZE - 1 : 0] C2_reg;
reg write;
reg l_C2;
reg [7 : 0] memory [MEM_SIZE - 1 : 0];
integer SEED = 225526;
integer i;

assign D2 = write ? D2_reg : 'hz;
assign C2 = l_C2 ? C2 : 'hz;

initial begin
    $dumpfile("dump3.vcd");
    //$dumpvars(0, clk, l_C2, wire);
    l_C2 = 0;
    write = 0;
    for (i = 0; i < MEM_SIZE; i++) 
    begin
        memory[i] = $random(SEED)>>16;
    end
    for (i = 0; i < 8; i += 1) 
    begin
        //$display("[%h] %h", i, memory[i]);
    end
end

always @(posedge clk)
begin
    #2
    case(C2)
        2'b00 : // NOP
        begin
            $display("nop");
        end
        2'b01 : // RESPONSE
        begin
            $display("response");
        end
        2'b10 : // READ_LINE
        begin
            //reading c.line
            #198;
            // wire = 1;
            l_C2 = 1;
            C2_reg = 1;
            for (i = A2 * 8; i < A2 * 8 + 16; i += 2)
            begin
                D2_reg = {memory[i + 1], memory[i]};
                #2;
            end
            C2_reg = 0;
            l_C2 = 0;
            write = 0;
        end
        2'b11 : // WRITE_LINE
        begin
            //writing c.line
            #198 write = 1;
            l_C2 = 1;
            C2_reg = 1;
            for (i = A2 * 8; i < A2 * 8 + 16; i += 2) 
            begin
                memory[i] = D2[7 : 0];
                memory[i + 1] = D2[15 : 8];
                #2;
            end
            l_C2 = 0;
            C2_reg = 0;
        end
    endcase
end
endmodule