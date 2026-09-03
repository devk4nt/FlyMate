"""Staging 전용 앱 아이콘 생성 — prod 아이콘의 비행기 실루엣은 유지하고 배경만 주황으로 바꾼 뒤
하단에 STAGING 띠를 얹는다. 홈 화면 축소 크기(60pt)에서도 색으로 즉시 구분되는 것이 목적."""
from PIL import Image, ImageDraw, ImageFont

SRC = "Resources/Assets.xcassets/AppIcon.appiconset/FlyMateAppIcon.png"
DST = "Resources/Assets.xcassets/AppIcon-Staging.appiconset/FlyMateAppIcon-Staging.png"
SIZE = 1024
BAND_H = 190
# prod 파랑(#4EA8F0 계열)과 명확히 대비되는 주황. 흰 비행기·흰 글자와 대비 4.5:1 이상 확보
TOP = (247, 148, 30)
BOTTOM = (233, 106, 22)
BAND = (30, 30, 34, 235)

src = Image.open(SRC).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)

# 1. 비행기 마스크 추출 — 원본은 흰 실루엣 + 파란 그라데이션이므로 밝기로 분리한다
gray = src.convert("L")
mask = gray.point(lambda v: 255 if v > 225 else 0).convert("L")

# 2. 주황 그라데이션 배경
bg = Image.new("RGBA", (SIZE, SIZE))
draw = ImageDraw.Draw(bg)
for y in range(SIZE):
    t = y / (SIZE - 1)
    draw.line(
        [(0, y), (SIZE, y)],
        fill=tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)) + (255,),
    )

# 3. 비행기를 흰색으로 합성
plane = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
bg.paste(plane, (0, 0), mask)

# 4. 하단 STAGING 띠
band = Image.new("RGBA", (SIZE, BAND_H), BAND)
bg.alpha_composite(band, (0, SIZE - BAND_H))

font = None
for path in [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/Library/Fonts/Arial Bold.ttf",
]:
    try:
        font = ImageFont.truetype(path, 118)
        break
    except OSError:
        continue
if font is None:
    raise SystemExit("굵은 시스템 폰트를 찾지 못했습니다 — 폰트 경로를 확인하세요")

draw = ImageDraw.Draw(bg)
text = "STAGING"
box = draw.textbbox((0, 0), text, font=font, stroke_width=0)
tw, th = box[2] - box[0], box[3] - box[1]
draw.text(
    ((SIZE - tw) / 2 - box[0], SIZE - BAND_H + (BAND_H - th) / 2 - box[1]),
    text,
    font=font,
    fill=(255, 255, 255, 255),
)

bg.convert("RGB").save(DST, "PNG")

out = Image.open(DST)
assert out.size == (SIZE, SIZE), out.size
assert out.mode == "RGB", out.mode  # 앱 아이콘은 알파 채널 금지 (App Store 거부 사유)
print(f"생성: {DST} {out.size} {out.mode}")
