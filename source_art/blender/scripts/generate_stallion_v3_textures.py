import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures", "vehicles", "stallion_v3")
RNG = np.random.default_rng(3112026)


def smooth_noise(size, coarse):
    small = (RNG.random((coarse, coarse)) * 255).astype(np.uint8)
    image = Image.fromarray(small, "L").resize((size, size), Image.Resampling.BICUBIC)
    return np.asarray(image, dtype=np.float32) / 255.0


def save_rgb(name, array):
    Image.fromarray(np.clip(array, 0, 255).astype(np.uint8), "RGB").save(
        os.path.join(OUT, name), optimize=True
    )


def build():
    os.makedirs(OUT, exist_ok=True)
    size = 2048
    y, x = np.mgrid[0:size, 0:size]
    macro = smooth_noise(size, 48)
    micro = smooth_noise(size, 256)
    dust = np.clip(0.62 * macro + 0.38 * micro, 0.0, 1.0)

    base = np.zeros((size, size, 3), dtype=np.float32)
    sand = np.array([184.0, 164.0, 126.0])
    base[:] = sand + (dust[..., None] - 0.5) * np.array([18.0, 14.0, 10.0])
    # Controlled diagonal competition accents; no logo or real-world branding.
    stripe = ((x + y * 0.42) % 690 < 76) & (y > 170) & (y < 1880)
    secondary = ((x - y * 0.23) % 940 < 38)
    base[stripe] = np.array([163.0, 58.0, 31.0]) + (micro[stripe, None] - 0.5) * 10.0
    base[secondary] = np.array([43.0, 48.0, 51.0])
    lower_dust = np.clip((y / size - 0.58) * 2.0, 0.0, 1.0)[..., None]
    base = base * (1.0 - lower_dust * 0.12) + np.array([155.0, 125.0, 87.0]) * lower_dust * 0.12
    save_rgb("stallion_v3_base_color.png", base)

    height = 0.55 * smooth_noise(size, 180) + 0.30 * smooth_noise(size, 420)
    # Fine directional grooves support tire/metal read without replacing macro geometry.
    grooves = np.sin((x * 0.075 + y * 0.021)) * 0.08
    height += grooves
    gy, gx = np.gradient(height)
    strength = 2.1
    nx = -gx * strength
    ny = -gy * strength
    nz = np.ones_like(nx)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack(((nx / norm * 0.5 + 0.5) * 255.0, (ny / norm * 0.5 + 0.5) * 255.0, (nz / norm * 0.5 + 0.5) * 255.0), axis=-1)
    save_rgb("stallion_v3_normal.png", normal)

    ao = np.clip(235.0 - (1.0 - macro) * 34.0 - lower_dust[..., 0] * 18.0, 170.0, 245.0)
    roughness = np.clip(156.0 + dust * 58.0 + lower_dust[..., 0] * 22.0, 135.0, 238.0)
    metallic = np.where(secondary, 180.0, 12.0)
    orm = np.stack((ao, roughness, metallic), axis=-1)
    save_rgb("stallion_v3_orm.png", orm)

    mask_size = 1024
    my, mx = np.mgrid[0:mask_size, 0:mask_size]
    dirt = smooth_noise(mask_size, 72)
    dust_mask = np.clip((my / mask_size - 0.42) * 1.6 + dirt * 0.55, 0.0, 1.0)
    scratch_lines = ((mx * 3 + my * 7) % 401 < 3).astype(np.float32)
    damage = np.clip(scratch_lines * (smooth_noise(mask_size, 140) > 0.67), 0.0, 1.0)
    cavity = np.clip((1.0 - smooth_noise(mask_size, 92)) * 0.65, 0.0, 1.0)
    dirt_damage = np.stack((dust_mask, damage, cavity), axis=-1) * 255.0
    save_rgb("stallion_v3_dirt_damage_mask.png", dirt_damage)

    emissive = np.zeros((mask_size, mask_size, 3), dtype=np.uint8)
    amber = ((mx % 320) > 92) & ((mx % 320) < 228) & ((my % 300) > 105) & ((my % 300) < 190)
    red = ((mx % 510) > 180) & ((mx % 510) < 340) & ((my % 430) > 285) & ((my % 430) < 350)
    emissive[amber] = np.array([255, 184, 74], dtype=np.uint8)
    emissive[red] = np.array([255, 42, 18], dtype=np.uint8)
    image = Image.fromarray(emissive, "RGB").filter(ImageFilter.GaussianBlur(radius=1.2))
    image.save(os.path.join(OUT, "stallion_v3_emissive.png"), optimize=True)

    print("STALLION_V3_TEXTURES_OK", OUT)
    print("TEXTURES=2048x2048:base_color,normal,orm 1024x1024:dirt_damage_mask,emissive")


if __name__ == "__main__":
    build()
