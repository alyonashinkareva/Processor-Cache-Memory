`include "cache.sv"
module testbench #(
    parameter MEM_SIZE = 2**18,
    parameter CACHE_SIZE = 2**11,
    parameter CACHE_LINE_SIZE = 16,
    parameter CACHE_LINE_COUNT = 2**7,
    parameter CACHE_WAY = 2,
    parameter CACHE_SETS_COUNT = 64,
    parameter CACHE_TAG_SIZE = 8,
    parameter CACHE_SET_SIZE = 6,
    parameter CACHE_OFFSET_SIZE = 4,
    parameter CACHE_ADDR_SIZE = 18,
    parameter ADDR1_BUS_SIZE = 14,
    parameter ADDR2_BUS_SIZE = 14,
    parameter DATA1_BUS_SIZE = 16,
    parameter DATA2_BUS_SIZE = 16,
    parameter CTR1_BUS_SIZE = 3,
    parameter CTR2_BUS_SIZE = 2
);
int hits;
int requests;
reg [ADDR1_BUS_SIZE - 1 : 0] A1_reg;
reg [DATA1_BUS_SIZE - 1 : 0] D1_reg;
reg [CTR1_BUS_SIZE - 1 : 0] C1_reg;
reg clk;
inout wire [CTR1_BUS_SIZE - 1 : 0] C1;
inout wire [DATA1_BUS_SIZE - 1 : 0] D1;
integer M;
integer N;
integer K;
integer x;
integer y;
integer k;
integer s;
integer pa;
integer pb;
integer pc;
integer requests_count;
reg [17 : 0] addr;
reg [7 : 0] a;
reg [15 : 0] b;
reg [31 : 0] c;
reg l_C1;
reg writeD1;
cache cache(clk, A1_reg, D1, C1, hits, requests);
assign C1 = l_C1 ? C1_reg : 'hz;
assign D1 = writeD1 ? D1_reg : 'hz;

always #1 clk = ~clk;

initial 
begin
    clk = 1;
    M = 64;
    #2;
    N = 60;
    #2;
    K = 32;
    #2;
    pa = 0;
    #2;
    pc = 0;
    #2;

    requests_count = 0;
    for (y = 0; y < M; y += 1)
    begin
        for (x = 0; x < N; x += 1) 
        begin
            pb = 0;
            #2;
            s = 0;
            #2;
            for (k = 0; k < K; k += 1)
            begin
                requests_count += 2;
                C1_reg = 1;
                l_C1 = 1;
                A1_reg = (pa * K + k) >> CACHE_OFFSET_SIZE;
                #2;
                A1_reg = (pa * K + k) % CACHE_LINE_SIZE;
                #2;
                l_C1 = 0;
                #1
                //wait(C1 == 7);
                #7;
                a = D1[7 : 0];
                C1_reg = 2;
                l_C1 = 1;
                A1_reg = (M * K + (pb * N + x) * 2) >> CACHE_OFFSET_SIZE;
                #2;
                A1_reg = (M * K + (pb * N + x) * 2) % CACHE_LINE_SIZE;
                #2;
                l_C1 = 0;
                #1;
                //wait(C1 == 7);
                #50;
                b = D1[7 : 0];
                s += a * b;
                #10;
                pb += 1;
                #2;
                #2;
            end
            requests_count += 1;
            C1_reg = 7;
            l_C1 = 1;
            A1_reg = (M * K + K * N * 2 + (pc * N + x) * 4) >> CACHE_OFFSET_SIZE;
            #2;
            A1_reg = (M * K + K * N * 2 + (pc * N + x) * 4) % CACHE_LINE_SIZE;
            #2;
            l_C1 = 0;
            #2;
            //wait(C1 == 7);
            #3;
            #2;
        end
        pa += 1;
        #2;
        pc += 1;
        #2;
        #2;
    end

    #2;
    $display("Cache hits: %0d", hits);
    $display("Cache requests: %0d", requests_count);
    $display("Tacts: ", $time);
    #1;
    $finish;

end
endmodule