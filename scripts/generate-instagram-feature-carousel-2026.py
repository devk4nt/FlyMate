from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Deliverables/Marketing/InstagramFeatureCarousel-2026-08-v3"
PROFILE_OUTPUT = ROOT / "Deliverables/Marketing/InstagramProfileRefresh-2026-08"
CURRENT_SOURCE = PROFILE_OUTPUT / "sources"
BACKGROUND = OUTPUT / "background-generated.png"
SOURCE = ROOT / "Deliverables/AppStoreScreenshots-2026/ko-KR/iPhone-6.9-inch/final"
APP_ICON = ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/FlyMateAppIcon.png"
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

WIDTH = 1080
HEIGHT = 1350
NAVY = "#081D69"
BLUE = "#159BDA"
MUTED = "#56627A"


SLIDES = [
    {
        "source": "quick-feedback-current.jpg",
        "kicker": "QUICK FEEDBACK",
        "title": ("스터디 없이도,", "바로 피드백"),
        "subtitle": "1분 영상으로 지금 필요한 조언을 받아보세요",
        "crop_y": 0,
        "raw_source": True,
        "output_name": "quick-feedback",
    },
    {
        "source": "02-request-in-one-minute.png",
        "kicker": "60-SECOND PRACTICE",
        "title": ("1분이면", "요청 완료"),
        "subtitle": "궁금한 항목을 고르고 영상만 올리면 끝",
        "crop_y": 600,
    },
    {
        "source": "03-two-perspectives.png",
        "kicker": "TWO PERSPECTIVES",
        "title": ("서로 다른 두 명의", "구체적인 조언"),
        "subtitle": "잘한 점과 개선점을 한 화면에서 확인해요",
        "crop_y": 690,
    },
    {
        "source": "04-grow-together.png",
        "kicker": "GROW TOGETHER",
        "title": ("혼자보다 꾸준하게,", "스터디와 함께"),
        "subtitle": "영상 연습과 피드백을 한곳에서 이어가요",
        "crop_y": 600,
    },
    {
        "source": "05-timestamp-feedback.png",
        "kicker": "TIMESTAMP FEEDBACK",
        "title": ("영상의 그 순간에", "정확한 피드백"),
        "subtitle": "표정과 말투, 놓치지 않고 바로 짚어줘요",
        "crop_y": 720,
    },
    {
        "source": "06-find-your-crew.png",
        "kicker": "FIND YOUR CREW",
        "title": ("나와 맞는 스터디를", "지금 찾아보세요"),
        "subtitle": "직무와 목표가 맞는 사람들과 함께 준비해요",
        "crop_y": 600,
    },
    {
        "source": "06-find-your-crew.png",
        "kicker": "NEW STUDY ALERT",
        "title": ("새 모집글,", "알림으로 바로 확인"),
        "subtitle": "오픈채팅방을 계속 확인하던 번거로움을 줄여보세요",
        "crop_y": 600,
        "notification": True,
        "output_name": "recruit-notification",
    },
]


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    indices = {"regular": 0, "medium": 2, "semibold": 4, "bold": 6, "extrabold": 14}
    return ImageFont.truetype(FONT, size=size, index=indices[weight])


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    ratio = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((round(image.width * ratio), round(image.height * ratio)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def fit_font(text: str, max_size: int, max_width: int) -> ImageFont.FreeTypeFont:
    size = max_size
    while size > 48:
        candidate = font(size, "extrabold")
        if candidate.getlength(text) <= max_width:
            return candidate
        size -= 2
    return font(size, "extrabold")


def rounded_phone(source: Path, crop_y: int) -> Image.Image:
    image = Image.open(source).convert("RGB")
    crop = image.crop((120, crop_y, 1200, image.height))
    max_width = 650
    max_height = 875
    scale = min(max_width / crop.width, max_height / crop.height)
    target_width = round(crop.width * scale)
    target_height = round(crop.height * scale)
    crop = crop.resize((target_width, target_height), Image.Resampling.LANCZOS)

    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, crop.width - 1, crop.height - 1), radius=42, fill=255)
    result = Image.new("RGBA", crop.size)
    result.paste(crop, (0, 0), mask)
    return result


def rounded_current_screenshot(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGB")
    max_width = 650
    max_height = 875
    scale = min(max_width / image.width, max_height / image.height)
    image = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )

    border = 8
    framed = Image.new("RGBA", (image.width + border * 2, image.height + border * 2), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(framed)
    frame_draw.rounded_rectangle(
        (0, 0, framed.width - 1, framed.height - 1),
        radius=46,
        fill="#151A24",
    )
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width - 1, image.height - 1), radius=38, fill=255)
    framed.paste(image, (border, border), mask)
    return framed


def draw_notification_banner(canvas: Image.Image, phone_y: int) -> Image.Image:
    banner_x = 176
    banner_y = phone_y + 46
    banner_width = 728
    banner_height = 178

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (banner_x + 5, banner_y + 10, banner_x + banner_width + 5, banner_y + banner_height + 10),
        radius=34,
        fill=(24, 46, 87, 65),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas = Image.alpha_composite(canvas, shadow)

    banner = Image.new("RGBA", (banner_width, banner_height), (250, 251, 255, 246))
    banner_mask = Image.new("L", banner.size, 0)
    ImageDraw.Draw(banner_mask).rounded_rectangle((0, 0, banner_width - 1, banner_height - 1), radius=34, fill=255)

    icon = Image.open(APP_ICON).convert("RGBA").resize((74, 74), Image.Resampling.LANCZOS)
    icon_mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(icon_mask).rounded_rectangle((0, 0, 73, 73), radius=17, fill=255)
    banner.paste(icon, (24, 25), icon_mask)

    banner_draw = ImageDraw.Draw(banner)
    banner_draw.text((118, 20), "FlyMate", font=font(22, "bold"), fill="#20232A")
    banner_draw.text((650, 22), "지금", font=font(18, "regular"), fill="#7C8492")
    banner_draw.text((118, 57), "새 스터디 모집글", font=font(24, "bold"), fill=NAVY)
    banner_draw.text(
        (118, 95),
        "김하늘님이 '국내 항공사 영상면접 스터디원 모집'을",
        font=font(18, "medium"),
        fill="#404756",
    )
    banner_draw.text((118, 124), "시작했어요", font=font(18, "medium"), fill="#404756")

    canvas.paste(banner, (banner_x, banner_y), banner_mask)
    return canvas


def draw_slide(index: int, slide: dict[str, object]) -> None:
    background = cover(Image.open(BACKGROUND).convert("RGB"), (WIDTH, HEIGHT)).convert("RGBA")
    draw = ImageDraw.Draw(background)

    # Soft white veil keeps copy highly legible while retaining the generated texture.
    veil = Image.new("RGBA", (WIDTH, HEIGHT), (255, 255, 255, 0))
    ImageDraw.Draw(veil).rounded_rectangle((38, 34, WIDTH - 38, HEIGHT + 80), radius=52, fill=(255, 255, 255, 52))
    background = Image.alpha_composite(background, veil)
    draw = ImageDraw.Draw(background)

    draw.text((78, 68), str(slide["kicker"]), font=font(23, "bold"), fill=BLUE, tracking=1)

    pill_box = (908, 54, 1005, 111)
    draw.rounded_rectangle(pill_box, radius=29, fill=(255, 255, 255, 220), outline=(255, 255, 255, 245), width=2)
    page_text = f"{index}/{len(SLIDES)}"
    page_font = font(23, "bold")
    page_box = draw.textbbox((0, 0), page_text, font=page_font)
    draw.text(
        ((pill_box[0] + pill_box[2] - (page_box[2] - page_box[0])) / 2, 70),
        page_text,
        font=page_font,
        fill=NAVY,
    )

    title_y = 128
    first, second = slide["title"]
    first_font = fit_font(str(first), 72, 920)
    second_font = fit_font(str(second), 76, 920)
    draw.text((76, title_y), str(first), font=first_font, fill=NAVY)
    draw.text((76, title_y + 82), str(second), font=second_font, fill=BLUE)

    subtitle_y = title_y + 184
    draw.text((78, subtitle_y), str(slide["subtitle"]), font=font(29, "semibold"), fill=MUTED)

    if slide.get("raw_source"):
        phone = rounded_current_screenshot(CURRENT_SOURCE / str(slide["source"]))
    else:
        phone = rounded_phone(SOURCE / str(slide["source"]), int(slide["crop_y"]))
    phone_x = (WIDTH - phone.width) // 2
    phone_y = 430

    shadow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (phone_x + 10, phone_y + 18, phone_x + phone.width + 10, phone_y + phone.height + 18),
        radius=48,
        fill=(19, 52, 101, 58),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    background = Image.alpha_composite(background, shadow)
    background.alpha_composite(phone, (phone_x, phone_y))

    if slide.get("notification"):
        background = draw_notification_banner(background, phone_y)

    output_name = str(slide.get("output_name", Path(str(slide["source"])).stem))
    output_path = OUTPUT / f"{index:02d}-{output_name}.png"
    background.convert("RGB").save(output_path, quality=96)


def draw_profile_card(
    filename: str,
    kicker: str,
    title: tuple[str, str],
    subtitle: str,
    source_name: str,
    crop_y: int,
    notification: bool = False,
    raw_source: bool = False,
) -> None:
    background = cover(Image.open(BACKGROUND).convert("RGB"), (WIDTH, HEIGHT)).convert("RGBA")
    veil = Image.new("RGBA", (WIDTH, HEIGHT), (255, 255, 255, 0))
    ImageDraw.Draw(veil).rounded_rectangle((38, 34, WIDTH - 38, HEIGHT + 80), radius=52, fill=(255, 255, 255, 52))
    background = Image.alpha_composite(background, veil)
    draw = ImageDraw.Draw(background)

    draw.text((78, 68), kicker, font=font(23, "bold"), fill=BLUE, tracking=1)
    first, second = title
    draw.text((76, 128), first, font=fit_font(first, 72, 920), fill=NAVY)
    draw.text((76, 210), second, font=fit_font(second, 76, 920), fill=BLUE)
    draw.text((78, 312), subtitle, font=font(29, "semibold"), fill=MUTED)

    if raw_source:
        phone = rounded_current_screenshot(CURRENT_SOURCE / source_name)
    else:
        phone = rounded_phone(SOURCE / source_name, crop_y)
    phone_x = (WIDTH - phone.width) // 2
    phone_y = 430
    shadow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (phone_x + 10, phone_y + 18, phone_x + phone.width + 10, phone_y + phone.height + 18),
        radius=48,
        fill=(19, 52, 101, 58),
    )
    background = Image.alpha_composite(background, shadow.filter(ImageFilter.GaussianBlur(24)))
    background.alpha_composite(phone, (phone_x, phone_y))
    if notification:
        background = draw_notification_banner(background, phone_y)
    background.convert("RGB").save(PROFILE_OUTPUT / filename, quality=96)


def generate_profile_refresh() -> None:
    PROFILE_OUTPUT.mkdir(parents=True, exist_ok=True)
    draw_profile_card(
        "01-brand-intro.png",
        "MEET FLYMATE",
        ("영상면접 준비,", "FlyMate 하나로"),
        "스터디 모집부터 영상 피드백까지 한곳에서",
        "04-grow-together.png",
        600,
    )
    draw_profile_card(
        "03-free-start.png",
        "START FREE",
        ("혼자 고민하지 말고,", "바로 피드백"),
        "1분 영상으로 지금 필요한 조언을 받아보세요",
        "quick-feedback-current.jpg",
        0,
        raw_source=True,
    )
    draw_profile_card(
        "04-recruit-notification.png",
        "NEW STUDY ALERT",
        ("새 모집글,", "알림으로 바로 확인"),
        "오픈채팅방을 계속 확인하던 번거로움을 줄여보세요",
        "06-find-your-crew.png",
        600,
        notification=True,
    )

def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for index, slide in enumerate(SLIDES, start=1):
        draw_slide(index, slide)
    generate_profile_refresh()


if __name__ == "__main__":
    main()
