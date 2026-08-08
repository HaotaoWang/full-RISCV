import re

def analyze_vcd():
    with open("soc_axi_test.vcd", "r") as f:
        content = f.read()
    
    # We want to find the symbol for timer_irq, pc, x3, mstatus, trap_done, trap_status
    symbols = {}
    lines = content.split('\n')
    for line in lines:
        if line.startswith("$var"):
            parts = line.split()
            # $var wire 1 % timer_irq $end
            if len(parts) >= 5:
                name = parts[4]
                if name in ["timer_irq", "pc", "trap_status", "trap_done", "current_mode", "registers[3]", "MIE"]:
                    symbols[name] = parts[3]
    
    print("Found symbols:", symbols)
    
    # Now scan values
    for name, sym in symbols.items():
        pattern = re.compile(r'^([bB]?\d+)' + re.escape(sym) + r'$')
        # This is a bit too much regex, let's just do a simple pass
    
    # Simple pass:
    time = 0
    state = {sym: "X" for sym in symbols.values()}
    
    events = []
    for line in lines:
        if line.startswith("#"):
            time = int(line[1:])
        elif len(line) > 1 and line[-1] in symbols.values() and line[0] in "01": # single bit
            sym = line[-1]
            state[sym] = line[0]
            if sym == symbols.get("timer_irq"):
                events.append((time, "timer_irq", line[0]))
        elif len(line) > 1 and line.startswith("b"): # multi bit
            parts = line.split()
            if len(parts) == 2 and parts[1] in symbols.values():
                sym = parts[1]
                val = parts[0][1:]
                state[sym] = val
                if sym == symbols.get("pc"):
                    events.append((time, "pc", val))
                if sym == symbols.get("trap_status"):
                    events.append((time, "trap_status", val))
                    
    for e in events:
        if e[1] == "timer_irq":
            print(f"Time {e[0]}: {e[1]} = {e[2]}")
            
    for e in events[-50:]:
        print(f"Time {e[0]}: {e[1]} = {e[2]}")

analyze_vcd()
