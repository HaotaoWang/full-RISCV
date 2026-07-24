import fitz
import re
import sys

def extract_pins(pdf_path):
    print(f'--- Extracting from {pdf_path} ---')
    try:
        doc = fitz.open(pdf_path)
    except Exception as e:
        print(f'Error opening {pdf_path}: {e}')
        return
        
    text_lines = []
    for i in range(len(doc)):
        page = doc.load_page(i)
        # Extract blocks to keep text structure better
        blocks = page.get_text("blocks")
        for b in blocks:
            text = b[4].replace('\n', ' ')
            text_lines.append(text)

    # Keywords to look for
    keywords = ['clk', 'clock', 'rst', 'reset', 'uart', 'tx', 'rx', '50m']
    
    # regex for FPGA pins, usually 1-2 uppercase letters followed by 1-2 digits, e.g. Y9, AA10, A1
    pin_pattern = re.compile(r'\b[A-Z]{1,2}[0-9]{1,2}\b')
    
    found = []
    for line in text_lines:
        line_lower = line.lower()
        if any(k in line_lower for k in keywords):
            pins = pin_pattern.findall(line)
            if pins:
                found.append((line.strip(), pins))
                
    for line, pins in found:
        print(f"Found {pins} in: {line}")
    print("\n")

extract_pins('MK7XCORE676_20220110.pdf')
extract_pins('MK7160FA20190818.pdf')
