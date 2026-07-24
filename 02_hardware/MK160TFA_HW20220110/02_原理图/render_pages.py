import fitz

def extract_pages(pdf_path, pages, output_prefix):
    """将指定页面渲染为图片"""
    doc = fitz.open(pdf_path)
    for p in pages:
        if p < len(doc):
            page = doc.load_page(p)
            pix = page.get_pixmap(dpi=200)
            fname = f"{output_prefix}_page{p+1}.png"
            pix.save(fname)
            print(f"已保存: {fname}")

# 核心板: 第1页(总览), 第3页(有 sys_clk_i), 第7页(LED/按键?)
extract_pages('MK7XCORE676_20220110.pdf', [0, 2, 6, 7], 'core')

# 底板: 第1页(总览), 第3页(UART), 第11页(PL_CLK)  
extract_pages('MK7160FA20190818.pdf', [0, 2, 10], 'baseboard')
