import sys

def parse_vcd(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()
        
    id_map = {}
    for line in lines:
        if line.startswith('$var'):
            parts = line.split()
            if 'timer_interrupt_pending' in parts:
                id_map['timer'] = parts[3]
            elif 'MIE' in parts and 'csr_registers' not in line:
                id_map['MIE'] = parts[3]
            elif 'trap_status' in parts and 'EX' not in line and 'ID' not in line and 'MEM' not in line:
                if 'trap_status_combinatorial' not in line:
                    id_map['trap_status'] = parts[3]
            elif 'alu_result' in parts and 'EX' not in line and 'MEM' not in line:
                if 'branch' not in line:
                    id_map['alu_result'] = parts[3]
            elif 'registers' in line and '[2]' in line:
                id_map['sp'] = parts[3]
        elif line.startswith('$enddefinitions'):
            break

    print("ID Map:", id_map)
    
    current_time = 0
    for line in lines:
        if line.startswith('#'):
            current_time = int(line[1:].strip())
        elif 'sp' in id_map and id_map['sp'] in line:
            if line.endswith(id_map['sp'] + '\n'):
                val = line.split()[0]
                if 'x' not in val:
                    print(f"Time {current_time}: sp = {val}")
        elif 'alu_result' in id_map and id_map['alu_result'] in line:
            if line.endswith(id_map['alu_result'] + '\n'):
                val = line.split()[0]
                if 'x' not in val:
                    #print(f"Time {current_time}: alu_result = {val}")
                    if val == 'b11':
                        print(f"FIRST MISALIGNED STORE at Time {current_time}")
                        sys.exit(0)

parse_vcd('soc_axi_test.vcd')
