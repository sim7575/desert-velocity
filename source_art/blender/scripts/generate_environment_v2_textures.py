import os
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "assets" / "textures" / "environment" / "environment_v2"


def resized_noise(width, height, cells_x, cells_y, seed):
    rng = np.random.default_rng(seed)
    grid = (rng.random((cells_y, cells_x)) * 255.0).astype(np.uint8)
    image = Image.fromarray(grid, "L").resize((width, height), Image.Resampling.BICUBIC)
    return np.asarray(image, dtype=np.float32) / 255.0


def fractal_noise(width, height, seed):
    result = np.zeros((height, width), dtype=np.float32)
    weight = 0.0
    for octave, cells in enumerate((6, 12, 24, 48, 96)):
        amplitude = 0.55 ** octave
        result += resized_noise(width, height, cells, cells, seed + octave * 97) * amplitude
        weight += amplitude
    return result / weight


def fracture_mask(width, height, seed, count=10):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:height, 0:width]
    x = xx.astype(np.float32) / width
    y = yy.astype(np.float32) / height
    mask = np.zeros((height, width), dtype=np.float32)
    for _ in range(count):
        x0, y0 = rng.random(2)
        angle = rng.uniform(-1.25, 1.25)
        dx, dy = np.cos(angle), np.sin(angle)
        distance = np.abs((x - x0) * dy - (y - y0) * dx)
        along = (x - x0) * dx + (y - y0) * dy
        length = rng.uniform(0.18, 0.65)
        width_value = rng.uniform(0.0015, 0.005)
        line = np.exp(-(distance / width_value) ** 2) * np.clip(1.0 - np.abs(along) / length, 0.0, 1.0)
        mask = np.maximum(mask, line)
    return mask


def normal_from_height(height, strength):
    grad_y, grad_x = np.gradient(height)
    nx = -grad_x * strength
    ny = -grad_y * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / length, ny / length, nz / length), axis=-1)
    return np.clip((normal * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)


def save_maps(prefix, base, height, ao, roughness, metallic):
    normal = normal_from_height(height, 3.2)
    orm = np.stack((ao, roughness, metallic), axis=-1)
    Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").save(OUTPUT / f"{prefix}_base_color.png", optimize=True)
    Image.fromarray(normal, "RGB").save(OUTPUT / f"{prefix}_normal.png", optimize=True)
    Image.fromarray(np.clip(orm, 0, 255).astype(np.uint8), "RGB").save(OUTPUT / f"{prefix}_orm.png", optimize=True)


def natural_atlas(size=2048):
    width = height = size
    base = np.zeros((height, width, 3), dtype=np.float32)
    height_map = np.zeros((height, width), dtype=np.float32)
    ao = np.zeros((height, width), dtype=np.float32)
    rough = np.zeros((height, width), dtype=np.float32)
    metallic = np.zeros((height, width), dtype=np.float32)
    palettes = [
        (132, 72, 50), (181, 119, 62), (92, 68, 60), (213, 154, 85), (145, 100, 62),
    ]
    for zone, palette in enumerate(palettes):
        x0 = zone * width // len(palettes)
        x1 = (zone + 1) * width // len(palettes)
        zone_w = x1 - x0
        macro = fractal_noise(zone_w, height, 1100 + zone * 71)
        micro = fractal_noise(zone_w, height, 2100 + zone * 83)
        fractures = fracture_mask(zone_w, height, 3100 + zone * 43, 8 if zone < 3 else 5)
        yy = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None]
        warped = yy + (macro - 0.5) * (0.14 if zone < 3 else 0.04)
        strata = 0.5 + 0.5 * np.sin(warped * (46.0 + zone * 5.0) + macro * 7.0)
        strata = strata * 0.55 + fractal_noise(zone_w, height, 4100 + zone * 59) * 0.45
        if zone >= 3:
            strata *= 0.22
        local_height = np.clip(macro * 0.48 + micro * 0.22 + strata * 0.30 - fractures * 0.16, 0.0, 1.0)
        cavity = np.clip(fractures * 0.38 + (0.48 - local_height) * 0.22, 0.0, 1.0)
        sand_dust = np.clip((macro - 0.58) * 1.8, 0.0, 0.35)
        color = np.asarray(palette, dtype=np.float32)[None, None, :] * (0.76 + local_height[..., None] * 0.28 + (micro[..., None] - 0.5) * 0.14)
        color *= (1.0 - cavity[..., None] * 0.20)
        color = color * (1.0 - sand_dust[..., None] * 0.12) + np.asarray((218, 158, 91), dtype=np.float32) * sand_dust[..., None] * 0.12
        base[:, x0:x1] = color
        height_map[:, x0:x1] = local_height
        ao[:, x0:x1] = 255.0 * np.clip(0.97 - cavity * 0.32, 0.58, 1.0)
        base_roughness = 0.78 if zone < 3 else 0.92
        rough[:, x0:x1] = 255.0 * np.clip(base_roughness + (micro - 0.5) * 0.16 + sand_dust * 0.12, 0.55, 0.99)
    save_maps("natural", base, height_map, ao, rough, metallic)


def road_atlas(size=2048):
    width = height = size
    base = np.zeros((height, width, 3), dtype=np.float32)
    height_map = np.zeros((height, width), dtype=np.float32)
    ao = np.zeros((height, width), dtype=np.float32)
    rough = np.zeros((height, width), dtype=np.float32)
    metallic = np.zeros((height, width), dtype=np.float32)
    palettes = [(55, 52, 47), (128, 88, 53), (162, 113, 68), (194, 137, 77)]
    for zone, palette in enumerate(palettes):
        x0 = zone * width // 4
        x1 = (zone + 1) * width // 4
        zone_w = x1 - x0
        macro = fractal_noise(zone_w, height, 5100 + zone * 73)
        gravel = fractal_noise(zone_w, height, 6100 + zone * 41)
        cracks = fracture_mask(zone_w, height, 7100 + zone * 47, 16 if zone == 0 else 8)
        xx = np.linspace(0.0, 1.0, zone_w, dtype=np.float32)[None, :]
        tracks = np.exp(-((xx - 0.27) / 0.055) ** 2) + np.exp(-((xx - 0.73) / 0.055) ** 2)
        tracks = tracks * (0.11 if zone == 0 else 0.04)
        local_height = np.clip(macro * 0.56 + gravel * 0.30 - cracks * 0.14 - tracks, 0.0, 1.0)
        dust = np.clip((macro - 0.50) * (0.55 if zone == 0 else 0.24), 0.0, 0.28)
        color = np.asarray(palette, dtype=np.float32)[None, None, :] * (0.82 + local_height[..., None] * 0.24)
        color = color * (1.0 - cracks[..., None] * 0.22) + np.asarray((190, 133, 76), dtype=np.float32) * dust[..., None]
        base[:, x0:x1] = color
        height_map[:, x0:x1] = local_height
        ao[:, x0:x1] = 255.0 * np.clip(0.98 - cracks * 0.28 - (0.45 - local_height) * 0.16, 0.58, 1.0)
        rough[:, x0:x1] = 255.0 * np.clip((0.76 + zone * 0.055) + (gravel - 0.5) * 0.14 + dust * 0.18, 0.58, 0.99)
    save_maps("road", base, height_map, ao, rough, metallic)


def props_atlas(size=1024):
    width = height = size
    base = np.zeros((height, width, 3), dtype=np.float32)
    height_map = np.zeros((height, width), dtype=np.float32)
    ao = np.zeros((height, width), dtype=np.float32)
    rough = np.zeros((height, width), dtype=np.float32)
    metallic = np.zeros((height, width), dtype=np.float32)
    palettes = [(202, 77, 25), (75, 83, 84), (116, 62, 37), (64, 83, 88)]
    for zone, palette in enumerate(palettes):
        x0, x1 = zone * width // 4, (zone + 1) * width // 4
        zone_w = x1 - x0
        wear = fractal_noise(zone_w, height, 8100 + zone * 37)
        scratches = fracture_mask(zone_w, height, 9100 + zone * 53, 18)
        rust = np.clip((wear - 0.58) * 2.4, 0.0, 1.0)
        local_height = np.clip(wear * 0.62 - scratches * 0.12, 0.0, 1.0)
        color = np.asarray(palette, dtype=np.float32)[None, None, :] * (0.76 + local_height[..., None] * 0.32)
        color = color * (1.0 - scratches[..., None] * 0.20) + np.asarray((132, 65, 34), dtype=np.float32) * rust[..., None] * 0.28
        base[:, x0:x1] = color
        height_map[:, x0:x1] = local_height
        ao[:, x0:x1] = 255.0 * np.clip(0.96 - scratches * 0.26, 0.58, 1.0)
        rough[:, x0:x1] = 255.0 * np.clip((0.58 if zone == 0 else 0.74) + rust * 0.20 + (wear - 0.5) * 0.12, 0.42, 0.98)
        metallic[:, x0:x1] = 255.0 * (0.60 if zone != 3 else 0.18)
    save_maps("props", base, height_map, ao, rough, metallic)


def vegetation_atlas(size=1024):
    width = height = size
    base = np.zeros((height, width, 3), dtype=np.float32)
    height_map = np.zeros((height, width), dtype=np.float32)
    ao = np.zeros((height, width), dtype=np.float32)
    rough = np.zeros((height, width), dtype=np.float32)
    metallic = np.zeros((height, width), dtype=np.float32)
    palettes = [(64, 91, 59), (79, 104, 66), (102, 91, 57), (92, 70, 43)]
    for zone, palette in enumerate(palettes):
        x0, x1 = zone * width // 4, (zone + 1) * width // 4
        zone_w = x1 - x0
        macro = fractal_noise(zone_w, height, 10100 + zone * 31)
        fibers = 0.5 + 0.5 * np.sin(np.linspace(0.0, 90.0, zone_w, dtype=np.float32)[None, :] + macro * 5.0)
        local_height = np.clip(macro * 0.60 + fibers * 0.22, 0.0, 1.0)
        dry = np.clip((macro - 0.62) * 1.6, 0.0, 0.35)
        color = np.asarray(palette, dtype=np.float32)[None, None, :] * (0.76 + local_height[..., None] * 0.32)
        color += np.asarray((176, 126, 67), dtype=np.float32) * dry[..., None] * 0.18
        base[:, x0:x1] = color
        height_map[:, x0:x1] = local_height
        ao[:, x0:x1] = 255.0 * np.clip(0.88 + local_height * 0.10, 0.62, 0.98)
        rough[:, x0:x1] = 255.0 * np.clip(0.82 + (macro - 0.5) * 0.16, 0.66, 0.98)
    save_maps("vegetation", base, height_map, ao, rough, metallic)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    natural_atlas()
    road_atlas()
    props_atlas()
    vegetation_atlas()
    for path in sorted(OUTPUT.glob("*.png")):
        with Image.open(path) as image:
            print(f"ENVIRONMENT_V2_TEXTURE {path.name} {image.size[0]}x{image.size[1]} RGB")
    print("ENVIRONMENT_V2_TEXTURE_GENERATION PASS count=12")


if __name__ == "__main__":
    main()
