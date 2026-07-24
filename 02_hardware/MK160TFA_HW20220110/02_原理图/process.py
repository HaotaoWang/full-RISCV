import os
import glob
import fitz  # PyMuPDF

def process_pdf(pdf_path, output_dir):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    print(f"开始处理: {pdf_path}")
    doc = fitz.open(pdf_path)
    
    # 将每一页渲染为图片
    for i in range(len(doc)):
        page = doc.load_page(i)
        pix = page.get_pixmap(dpi=200) # 设置合理的DPI提高清晰度
        img_name = f"page_{i + 1}.png"
        img_path = os.path.join(output_dir, img_name)
        pix.save(img_path)
        print(f"已保存: {img_path}")
        
    print(f"\n全部转换完成，共 {len(doc)} 页！")
    
    # 遍历文件夹中的图片
    print(f"开始遍历 {output_dir} 中的图片...")
    image_files = glob.glob(os.path.join(output_dir, "page_*.png"))
    # 按数字排序
    image_files.sort(key=lambda x: int(os.path.basename(x).replace("page_", "").replace(".png", "")))
    
    for img_path in image_files:
        print(f"正在读取并处理: {img_path}")
        # 这里可以加入后续处理逻辑

if __name__ == "__main__":
    process_pdf("第6章-湿度传感器.pdf", "output_images")
