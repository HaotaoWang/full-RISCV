import fitz
import re

def extract_all_text(pdf_path):
    """提取 PDF 全部文本并搜索关键管脚信息"""
    doc = fitz.open(pdf_path)
    results = {}
    
    for i in range(len(doc)):
        page = doc.load_page(i)
        text = page.get_text()
        
        # 搜索 LED 相关
        if re.search(r'LED', text, re.IGNORECASE):
            lines = text.split('\n')
            for j, line in enumerate(lines):
                if re.search(r'LED', line, re.IGNORECASE):
                    # 在前后5行中搜索 FPGA 管脚号模式
                    context = lines[max(0,j-3):min(len(lines),j+4)]
                    for ctx_line in context:
                        pins = re.findall(r'\b([A-Z]{1,2}\d{1,2})\b', ctx_line)
                        if pins and 'LED' in ctx_line.upper():
                            results.setdefault('LED', []).append(f'Page {i+1}: {ctx_line.strip()} -> pins: {pins}')

        # 搜索系统时钟
        if re.search(r'(sys_clk|SYS_CLK|50M|200M|CLK_IN|GCLK|clk_p|clk_n)', text):
            lines = text.split('\n')
            for j, line in enumerate(lines):
                if re.search(r'(sys_clk|SYS_CLK|50M|200M|CLK_IN|GCLK|clk_p|clk_n|PL_CLK)', line, re.IGNORECASE):
                    pins = re.findall(r'\b([A-Z]{1,2}\d{1,2})\b', line)
                    if pins:
                        results.setdefault('CLK', []).append(f'Page {i+1}: {line.strip()} -> pins: {pins}')

        # 搜索复位
        if re.search(r'(RESET|RST|CPU_RST)', text, re.IGNORECASE):
            lines = text.split('\n')
            for j, line in enumerate(lines):
                if re.search(r'(FPGA.*RST|RST.*FPGA|CPU_RST|SYS_RST|PL_RST)', line, re.IGNORECASE):
                    pins = re.findall(r'\b([A-Z]{1,2}\d{1,2})\b', line)
                    if pins:
                        results.setdefault('RESET', []).append(f'Page {i+1}: {line.strip()} -> pins: {pins}')

        # 搜索 UART
        if re.search(r'(UART|CP2104|USB_UART)', text, re.IGNORECASE):
            lines = text.split('\n')
            for j, line in enumerate(lines):
                if re.search(r'(UART.*FPGA|FPGA.*UART|CP2104.*TXD|CP2104.*RXD|USB_UART)', line, re.IGNORECASE):
                    pins = re.findall(r'\b([A-Z]{1,2}\d{1,2})\b', line)
                    if pins:
                        results.setdefault('UART', []).append(f'Page {i+1}: {line.strip()} -> pins: {pins}')

    return results

print("=" * 60)
print("核心板原理图 (MK7XCORE676_20220110.pdf)")
print("=" * 60)
r1 = extract_all_text('MK7XCORE676_20220110.pdf')
for k, v in r1.items():
    print(f"\n--- {k} ---")
    for item in v:
        print(f"  {item}")

print("\n" + "=" * 60)
print("底板原理图 (MK7160FA20190818.pdf)")  
print("=" * 60)
r2 = extract_all_text('MK7160FA20190818.pdf')
for k, v in r2.items():
    print(f"\n--- {k} ---")
    for item in v:
        print(f"  {item}")
