"""Export Android UI goldens, icon and feature graphic for the Play listing.

Run after screenshots_test.dart with SONARPAD_SCREENSHOT_DEVICE=android.
These are Flutter-rendered demo screens, using the same approach as iOS.
"""

from pathlib import Path
from shutil import copyfile

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SCREENSHOTS = (
    "01_home_screen",
    "02_settings_screen",
    "03_documents_screen",
    "04_wikipedia_screen",
    "05_news_screen",
    "06_podcast_screen",
    "07_radio_screen",
    "08_route_screen",
)


def export_feature_graphic(destination):
    source = ROOT / "store/google-play/it/feature-graphic.png"
    with Image.open(source) as banner:
        if banner.size != (1024, 500) or banner.mode != "RGB":
            raise RuntimeError("Feature graphic must be a 1024x500 RGB image")
    destination.mkdir(parents=True, exist_ok=True)
    copyfile(source, destination / "feature-graphic-1024x500.png")


def main():
    destination = ROOT / "build/google_play_images"
    phones = destination / "phone"
    phones.mkdir(parents=True, exist_ok=True)
    for name in SCREENSHOTS:
        matches = list((ROOT / "test/goldens").rglob(f"{name}.png"))
        if len(matches) != 1:
            raise RuntimeError(f"Expected one screenshot for {name}, found {len(matches)}")
        with Image.open(matches[0]) as image:
            if image.size != (360, 640):
                raise RuntimeError(f"Not an Android golden: {name}, {image.size}")
            image.convert("RGB").resize(
                (1080, 1920), Image.Resampling.LANCZOS
            ).save(phones / f"{name}.png")
    with Image.open(ROOT / "assets/icon/app_icon.png") as icon:
        background = Image.new("RGBA", icon.size, "white")
        background.alpha_composite(icon.convert("RGBA"))
        background.convert("RGB").resize(
            (512, 512), Image.Resampling.LANCZOS
        ).save(destination / "icon-512.png")
    export_feature_graphic(destination)
    print(f"Exported eight phone screenshots, icon and feature graphic to {destination}")


if __name__ == "__main__":
    main()
