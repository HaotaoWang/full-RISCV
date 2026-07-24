import sys

def rewrite():
    with open('d:/riscv/verilog-axi/rtl/axi_ram.v', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    out = []
    for line in lines:
        if line.startswith('module axi_ram #'):
            out.append('module axi_ram_init #\n')
        elif line.strip() == 'parameter PIPELINE_OUTPUT = 0':
            out.append('    parameter PIPELINE_OUTPUT = 0,\n')
            out.append('    parameter INIT_FILE = ""\n')
        elif line.strip() == 'for (j = i; j < i + 2**(VALID_ADDR_WIDTH/2); j = j + 1) begin':
            out.append(line)
        elif line.strip() == 'end' and len(out) > 3 and out[-2].strip() == 'end' and 'mem[j] = 0;' in out[-3]:
            out.append(line)
            out.append('    if (INIT_FILE != "") begin\n')
            out.append('        $readmemh(INIT_FILE, mem);\n')
            out.append('        $display("[axi_ram_init] Loaded %s", INIT_FILE);\n')
            out.append('    end\n')
        else:
            out.append(line)
            
    with open('d:/riscv/basic_rv32s/modules/axi_ram_init.v', 'w', encoding='utf-8') as f:
        f.writelines(out)
    print('Done.')

rewrite()
