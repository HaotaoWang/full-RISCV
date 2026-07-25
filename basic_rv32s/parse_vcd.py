import sys

def parse_vcd(vcd_file):
    with open(vcd_file, 'r') as f:
        lines = f.readlines()
        
    pc_ids = []
    
    # Find variables named pc
    for line in lines:
        if "$var" in line and " pc [" in line:
            parts = line.split()
            if len(parts) >= 4:
                pc_ids.append(parts[3])
        if "$enddefinitions" in line:
            break
            
    print(f"PC IDs found: {pc_ids}")
    
    # Trace PC
    time = 0
    history = {}
    for pid in pc_ids:
        history[pid] = []
        
    for line in lines:
        line = line.strip()
        if line.startswith('#'):
            time = int(line[1:])
        else:
            for pid in pc_ids:
                if line.endswith(pid):
                    val = line[:-len(pid)].strip()
                    if val.startswith('b'):
                        val = val[1:]
                        if 'x' not in val and 'z' not in val:
                            pc = int(val, 2)
                            if not history[pid] or history[pid][-1][1] != pc:
                                history[pid].append((time, pc))
                                
    # Find the one that looks like a real PC (starts at 0, goes up)
    best_id = None
    best_len = 0
    for pid in pc_ids:
        if len(history[pid]) > best_len:
            best_len = len(history[pid])
            best_id = pid
            
    if best_id:
        print(f"Tracing PC (ID {best_id}) with {best_len} transitions:")
        for t, p in history[best_id][:30]:
            print(f"Time {t}: PC = {hex(p)}")
        print("...")
        for t, p in history[best_id][-30:]:
            print(f"Time {t}: PC = {hex(p)}")

if __name__ == "__main__":
    parse_vcd("benchmark.vcd")
