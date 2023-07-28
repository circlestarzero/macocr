import subprocess
import time
import tempfile
import json

OCR_EXCUATBLE = "/Users/cc/work/macocr/.build/arm64-apple-macosx/debug/macocr"
def ocr(img):
    t1 = time.time()
    with tempfile.NamedTemporaryFile(delete=True, suffix=".jpg") as f:
        img_path = f.name
        img.convert("RGB").save(img_path, "JPEG")
        command = f"{OCR_EXCUATBLE} {img_path}"
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        # Parse the JSON result into a Python dict
        parsed_result = json.loads(result.stdout)
        t2 = time.time()
        print(f"Time: {t2 - t1}")
        return parsed_result
    
if __name__ == "__main__":
    from PIL import Image
    img = Image.open("test.png")
    print(ocr(img))
