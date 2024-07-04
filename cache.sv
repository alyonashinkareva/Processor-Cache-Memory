`include "memory.sv"
module cache #(
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
)
(
    input wire clk,
    input wire [ADDR1_BUS_SIZE - 1 : 0] A1,
    inout wire [DATA1_BUS_SIZE - 1 : 0] D1,
    inout wire [CTR1_BUS_SIZE - 1 : 0] C1,
    output int hits,
    output int requests
);
    reg [CACHE_TAG_SIZE - 1 : 0] cache_line_tag [CACHE_LINE_COUNT - 1 : 0];
    byte cache_line_data [CACHE_LINE_COUNT - 1 : 0][CACHE_LINE_SIZE - 1 : 0];
    reg cache_line_old [CACHE_LINE_COUNT - 1 : 0];
    reg cache_line_valid [CACHE_LINE_COUNT - 1 : 0];
    reg cache_line_dirty [CACHE_LINE_COUNT - 1 : 0];
    reg writeD1;
    reg l_C1;
    reg writeD2;
    reg l_C2;
    reg [ADDR2_BUS_SIZE - 1 : 0] A2_reg;
    reg [DATA2_BUS_SIZE - 1 : 0] D2_reg;
    reg [CTR2_BUS_SIZE - 1 : 0] C2_reg;
    wire [DATA2_BUS_SIZE - 1 : 0] D2;
    wire [CTR2_BUS_SIZE - 1 : 0] C2;
    reg [CTR1_BUS_SIZE - 1 : 0] C1_reg;
    reg [DATA1_BUS_SIZE - 1 : 0] D1_reg;
    reg [CACHE_OFFSET_SIZE - 1 : 0] addr_offset;
    reg [CACHE_SET_SIZE - 1 : 0] addr_set;
    reg [CACHE_TAG_SIZE - 1 : 0] addr_tag;
    reg [7:0] byte_byte;
    assign D1 = writeD1 ? D1_reg : 'hz;
    assign C1 = l_C1 ? C1_reg : 'hz;
    assign D2 = writeD2 ? D2_reg : 'hz;
    assign C2 = l_C2 ? C2_reg : 'hz;
    assign byte_byte = cache_line_data[0][0];
    memory memory(.clk(clk), .A2(A2_reg), .D2(D2), .C2(C2));
    integer i;
    integer hits_count;
    integer requests_count;

    initial 
    begin
      //  $dumpfile("dump2.vcd");
       // $dumpvars(0, clk, D1, C1, l_C2, C2, D2, writeD1, writeD2, addr_set, addr_tag, addr_offset, A2_reg, byte_byte, D1_reg);
        writeD1 = 0;
        l_C1 = 0;
        writeD2 = 0;
        l_C2 = 0;
        for (i = 0; i < CACHE_LINE_COUNT; i++)
        begin
            cache_line_valid[i] = 0;
        end
    end

    task byte_to_cpu(input firstSecond, input [2 : 0] number_bytes);
    begin
        l_C1 = 1;
        C1_reg = 7;
        writeD1 = 1;
        for (i = 0; i < number_bytes; i += 2) 
        begin
            #1;
            D1_reg[7 : 0] = cache_line_data[addr_set * 2 + firstSecond][addr_offset + i];
            if (number_bytes > 1) 
            begin
                D1_reg[15 : 8] = cache_line_data[addr_set * 2 + firstSecond][addr_offset + i + 1];
            end
            #1;
        end
        C1_reg = 0;
        l_C1 = 0;
        writeD1 = 0;
    end
    endtask

    task byte_from_cpu(input firstSecond, input [2 : 0] number_bytes);
    begin
        l_C1 = 1;
        C1_reg = 7;
        for (i = 0; i < number_bytes; i += 2) 
        begin
            #1;
            cache_line_data[addr_set * 2 + firstSecond][addr_offset + i] = D1[7 : 0];
            if (number_bytes > 1)
            begin
                cache_line_data[addr_set * 2 + firstSecond][addr_offset + i + 1] = D1[15 : 8];
            end
            #1;
        end
        C1_reg = 0;
        l_C1 = 0;
    end
    endtask

    task read_line_mem(input firstSecond);
    begin
        l_C2 = 1;
        C2_reg = 2;
        #200 l_C2 = 0;
        for (i = 0; i < 8; i++)
        begin
            #1 cache_line_data[addr_set * 2 + firstSecond][i * 2] = D2[7 : 0];
            cache_line_data[addr_set * 2 + firstSecond][i * 2 + 1] = D2[15 : 8];
            #1;
        end
        cache_line_tag[addr_set * 2 + firstSecond] = addr_tag;
        cache_line_dirty[addr_set * 2 + firstSecond] = 0;
    end
    endtask

    task write_line_mem(input firstSecond);
    begin
        l_C2 = 1;
        C2_reg = 3;
        #200 l_C2 = 0;
        for (i = 0; i < 16; i += 2) 
        begin
            #1 D2_reg[7 : 0] = cache_line_data[addr_set * 2 + firstSecond][i];
            D2_reg[15 : 8] = cache_line_data[addr_set * 2 + firstSecond][i + 1];
            #1;
        end
    end
    endtask

    task read_addr;
    begin
        addr_set = A1[CACHE_SET_SIZE - 1 : 0];
        addr_tag = A1[CACHE_TAG_SIZE + CACHE_SET_SIZE - 1 : CACHE_SET_SIZE];
        #2;
        addr_offset = A1[CACHE_OFFSET_SIZE - 1 : 0];
        requests += 1;
    end
    endtask

    task read_bytes(input [2 : 0] number_bytes);
    begin
        read_addr();
        if (cache_line_tag[addr_set * 2] == addr_tag && cache_line_valid[addr_set * 2] == 1)
        begin
            // кэш-попадание первая кэш-линия
            #8;
            byte_to_cpu(0, number_bytes);
            hits += 1;
        end
        else if (cache_line_tag[addr_set * 2 + 1] == addr_tag && cache_line_valid[addr_set * 2 + 1] == 1)
        begin
            // кэш-попадание вторая кэш-линия
            #8;
            byte_to_cpu(1, number_bytes);
            hits += 1;
        end
        else
        begin
            // кэш-промах
            #4;
            if (cache_line_valid[addr_set * 2] == 1 && cache_line_valid[addr_set * 2 + 1] == 1) 
            begin
                // линия1 и линия2 заняты
                if (cache_line_old[addr_set * 2] == 1) 
                begin
                    // линия1 old
                    A2_reg = {addr_tag, addr_set};
                    if (cache_line_dirty[addr_set * 2] == 1)
                    begin
                        write_line_mem(0);
                    end
                    read_line_mem(0);
                    cache_line_old[addr_set * 2] = 0;
                    cache_line_old[addr_set * 2 + 1] = 1;
                    l_C2 = 0;
                    byte_to_cpu(0, number_bytes);
                end
                else 
                begin
                    // линия2 old
                    A2_reg = {addr_tag, addr_set};
                    if (cache_line_dirty[addr_set * 2 + 1] == 1)
                    begin
                        write_line_mem(1);
                    end
                    read_line_mem(1);
                    cache_line_old[addr_set * 2 + 1] = 0;
                    cache_line_old[addr_set * 2] = 1;
                    byte_to_cpu(1, number_bytes);
                end
            end
            else if (cache_line_valid[addr_set * 2] == 0 && cache_line_valid[addr_set * 2 + 1] == 1)
            begin
                A2_reg = {addr_tag, addr_set};
                if (cache_line_dirty[addr_set * 2] == 1)
                begin
                    write_line_mem(0);
                end
                read_line_mem(0);
                cache_line_valid[addr_set * 2] = 1;
                cache_line_old[addr_set * 2] = 0;
                cache_line_old[addr_set * 2 + 1] = 1;
                byte_to_cpu(0, number_bytes);
            end
            else if (cache_line_valid[addr_set * 2] == 1 && cache_line_valid[addr_set * 2 + 1] == 0)
            begin
                A2_reg = {addr_tag, addr_set};
                if (cache_line_dirty[addr_set * 2 + 1] == 1) 
                begin
                    write_line_mem(1);
                end
                read_line_mem(1);
                cache_line_valid[addr_set * 2 + 1] = 1;
                cache_line_old[addr_set * 2 + 1] = 0;
                cache_line_old[addr_set * 2] = 1;
                byte_to_cpu(1, number_bytes);
            end
            else if (cache_line_valid[addr_set * 2] == 0 && cache_line_valid[addr_set * 2 + 1] == 0)
            begin
                A2_reg = {addr_tag, addr_set};
                if (cache_line_dirty[addr_set * 2 + 1] == 1) 
                begin
                    write_line_mem(0);
                end
                read_line_mem(0);
                cache_line_valid[addr_set * 2] = 1;
                cache_line_old[addr_set * 2] = 0;
                cache_line_old[addr_set * 2 + 1] = 1;
                byte_to_cpu(0, number_bytes);
            end
        end
    end
    endtask

    task write_bytes(input [1 : 0] number_bytes);
    begin
        if (cache_line_tag[addr_set * 2] == addr_tag && cache_line_valid[addr_set * 2] == 1)
        begin
            // кэш-попадание первая кэш-линия
            #8;
            byte_from_cpu(0, number_bytes);
        end
        else if (cache_line_tag[addr_set * 2 + 1] == addr_tag && cache_line_valid[addr_set * 2 + 1] == 1)
        begin
            // кэш-попадание вторая кэш-линия
            #8;
            byte_from_cpu(1, number_bytes);
        end
        else
        begin
            // кэш-промах
            #4;
            if (cache_line_valid[addr_set * 2] == 1 && cache_line_valid[addr_set * 2 + 1] == 1) 
            begin
                // линия1 и линия2 заняты
                if (cache_line_old[addr_set * 2] == 1) 
                begin
                    // линия1 old
                    l_C2 = 1;
                    A2_reg = {addr_tag, addr_set};
                    if (cache_line_dirty[addr_set * 2] == 1)
                    begin
                        C2_reg = 3;
                        write_line_mem(0);
                    end
                    C2_reg = 2;
                    read_line_mem(0);
                    cache_line_old[addr_set * 2] = 0;
                    cache_line_old[addr_set * 2 + 1] = 1;
                    l_C2 = 0;
                    byte_from_cpu(0, number_bytes);
                end
                else 
                begin
                    // линия2 old
                    l_C2 = 1;
                    A2_reg = {addr_tag, addr_set};
                    if (cache_line_dirty[addr_set * 2 + 1] == 1)
                    begin
                        C2_reg = 3;
                        write_line_mem(1);
                    end
                    C2_reg = 2;
                    read_line_mem(1);
                    cache_line_old[addr_set * 2 + 1] = 0;
                    cache_line_old[addr_set * 2] = 1;
                    l_C2 = 0;
                    byte_from_cpu(1, number_bytes);
                end
            end
            else if (cache_line_valid[addr_set * 2] == 0 && cache_line_valid[addr_set * 2 + 1] == 1)
            begin
                l_C2 = 1;
                A2_reg = {addr_tag, addr_set};
                if (cache_line_dirty[addr_set * 2] == 1)
                begin
                    C2_reg = 3;
                    write_line_mem(0);
                end
                C2_reg = 2;
                read_line_mem(0);
                cache_line_valid[addr_set * 2] = 1;
                cache_line_old[addr_set * 2] = 0;
                cache_line_old[addr_set * 2 + 1] = 1;
                l_C2 = 0;
                byte_from_cpu(0, number_bytes);
            end
            else if (cache_line_valid[addr_set * 2] == 1 && cache_line_valid[addr_set * 2 + 1] == 0)
            begin
                l_C2 = 1;
                A2_reg = {addr_tag, addr_set};
                C2_reg = 2;
                if (cache_line_dirty[addr_set * 2 + 1] == 1) 
                begin
                    C2_reg = 3;
                    write_line_mem(1);
                end
                read_line_mem(1);
                cache_line_valid[addr_set * 2 + 1] = 1;
                cache_line_old[addr_set * 2 + 1] = 0;
                cache_line_old[addr_set * 2] = 1;
                l_C2 = 0;
                byte_from_cpu(1, number_bytes);
            end
            else if (cache_line_valid[addr_set * 2] == 0 && cache_line_valid[addr_set * 2 + 1] == 0)
            begin
                l_C2 = 1;
                A2_reg = {addr_tag, addr_set};
                C2_reg = 2;
                if (cache_line_dirty[addr_set * 2 + 1] == 1) 
                begin
                    C2_reg = 3;
                    write_line_mem(0);
                end
                read_line_mem(0);
                cache_line_valid[addr_set * 2] = 1;
                cache_line_old[addr_set * 2] = 0;
                cache_line_old[addr_set * 2 + 1] = 1;
                l_C2 = 0;
                byte_from_cpu(0, number_bytes);
            end
        end
    end
    endtask

    always @(negedge clk) 
    begin
        #1;
    end

    always @(posedge clk)
    begin
        #1;
        case (C1)
        3'b000 :  // NOP
        begin
            $display("nothing");
        end
        3'b001 : // READ8
        begin
            read_bytes(1);
        end
        3'b010 : // READ16
        begin
            read_bytes(2);
        end
        3'b011 : //READ32
        begin
            read_bytes(4); //READ32
        end
        3'b100 : // INVALIDATE_LINE
        begin
            addr_set = A1[5 : 0];
            write_line_mem(A1[6]);
        end
        3'b101 : // WRITE8
        begin
            write_bytes(1);
        end
        3'b110 : // WRITE16
        begin
            write_bytes(2);
        end
        3'b111 : // WRITE32
        begin
            write_bytes(4);
        end
        endcase
    end
endmodule