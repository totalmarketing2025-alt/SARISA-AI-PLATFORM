"""Generate SARISA launcher icons for generated Flutter Android/Windows projects.

Requires Pillow. Run after flutter create; only modifies generated platform assets.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import argparse

def draw_logo(size: int) -> Image.Image:
    scale = 4
    n = size * scale
    im = Image.new("RGBA", (n, n), "#09120F")
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, n-1, n-1), radius=n//5, fill="#09120F")
    d.ellipse((n*.20, n*.20, n*.80, n*.80), outline="#67986B", width=max(2,n//40))
    d.ellipse((n*.30, n*.30, n*.70, n*.70), outline="#294E36", width=max(2,n//80))
    d.line((n*.14,n*.84,n*.75,n*.23),fill="#D5B66D",width=max(3,n//19))
    d.polygon([(int(n*.71),int(n*.20)),(int(n*.95),int(n*.05)),
               (int(n*.80),int(n*.29))],fill="#E8CC84")
    d.ellipse((n*.47,n*.47,n*.53,n*.53),fill="#F0D995")
    return im.resize((size,size), Image.Resampling.LANCZOS)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=["android","windows"], required=True)
    args = parser.parse_args()
    if args.platform == "android":
        root = Path("android/app/src/main/res")
        for folder, size in [("mipmap-mdpi",48),("mipmap-hdpi",72),
                             ("mipmap-xhdpi",96),("mipmap-xxhdpi",144),
                             ("mipmap-xxxhdpi",192)]:
            target = root / folder / "ic_launcher.png"
            target.parent.mkdir(parents=True,exist_ok=True)
            draw_logo(size).save(target)
            print(target)
    else:
        target = Path("windows/runner/resources/app_icon.ico")
        target.parent.mkdir(parents=True,exist_ok=True)
        draw_logo(256).save(target,format="ICO",sizes=[(16,16),(24,24),
                              (32,32),(48,48),(64,64),(128,128),(256,256)])
        print(target)

if __name__ == "__main__":
    main()
