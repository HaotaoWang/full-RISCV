import fitz

def search_pdf(pdf_path, keywords):
    print(f'Searching {pdf_path}...')
    try:
        doc = fitz.open(pdf_path)
    except Exception as e:
        print(f'Error opening {pdf_path}: {e}')
        return
        
    for i in range(len(doc)):
        page = doc.load_page(i)
        text = page.get_text()
        lines = text.split('\n')
        for j, line in enumerate(lines):
            line_lower = line.lower()
            if any(k in line_lower for k in keywords):
                start = max(0, j - 2)
                end = min(len(lines), j + 3)
                context = ' | '.join([l.strip() for l in lines[start:end]])
                print(f'Page {i+1}: {context}')

search_pdf('MK7XCORE676_20220110.pdf', ['clk', 'clock', 'rst', 'reset', 'uart', 'tx', 'rx', '50m'])
search_pdf('MK7160FA20190818.pdf', ['clk', 'clock', 'rst', 'reset', 'uart', 'tx', 'rx', '50m'])
