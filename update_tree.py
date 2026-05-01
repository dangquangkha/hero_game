import os
from pathlib import Path

# Các thư mục hoặc file bạn KHÔNG muốn in ra README (tránh rác)
IGNORE_ITEMS = {'.git', '__pycache__', '.vscode', 'update_tree.py'}

def generate_tree(dir_path, prefix=""):
    tree_str = ""
    path = Path(dir_path)
    
    try:
        items = list(path.iterdir())
    except PermissionError:
        return ""

    # Lọc bỏ các thư mục ẩn/rác và sắp xếp: Thư mục xếp trước, file xếp sau
    items = [i for i in items if i.name not in IGNORE_ITEMS and not i.name.startswith('.')]
    items.sort(key=lambda x: (x.is_file(), x.name.lower()))
    
    count = len(items)
    for i, item in enumerate(items):
        is_last = (i == count - 1)
        connector = "└── " if is_last else "├── "
        
        # Thêm slash / vào sau tên nếu nó là thư mục cho dễ nhìn
        display_name = f"{item.name}/" if item.is_dir() else item.name
        tree_str += f"{prefix}{connector}{display_name}\n"
        
        if item.is_dir():
            extension = "    " if is_last else "│   "
            tree_str += generate_tree(item, prefix + extension)
            
    return tree_str

def update_readme(readme_path, tree_content):
    # ĐÂY LÀ 2 DÒNG ĐÃ ĐƯỢC SỬA LẠI
    # Dùng mẹo cộng chuỗi để giao diện chat không thể xóa code
    start_marker = "<" + "!-- START_TREE --" + ">"
    end_marker = "<" + "!-- END_TREE --" + ">"
    
    try:
        # Đọc nội dung hiện tại của README
        with open(readme_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Kiểm tra xem có 2 thẻ đánh dấu không
        if start_marker in content and end_marker in content:
            # Cắt chuỗi để giữ nguyên phần đầu và phần cuối, chỉ thay thế phần giữa
            before = content.split(start_marker)[0]
            after = content.split(end_marker)[1]
            
            # Ghép lại với cây thư mục mới
            new_content = f"{before}{start_marker}\n```text\nyour-game/\n{tree_content}```\n{end_marker}{after}"
            
            # Ghi đè lại vào file
            with open(readme_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print("✅ Đã cập nhật cấu trúc thư mục mới vào README.md thành công!")
        else:
            print(f"⚠️ Không tìm thấy thẻ {start_marker} và {end_marker} trong README.md.")
            print("Vui lòng thêm hai thẻ này vào file README.md của bạn trước.")
            
    except FileNotFoundError:
        print("❌ Không tìm thấy file README.md!")

if __name__ == "__main__":
    print("Đang quét cấu trúc thư mục...")
    # Quét thư mục hiện tại (".")
    tree_output = generate_tree(".")
    
    # Cập nhật vào README
    update_readme("README.md", tree_output)