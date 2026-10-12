#!/usr/bin/env python3
import math
import os
from PIL import Image, ImageDraw, ImageFilter

def create_super_image(size, draw_fn, scale=4):
    w, h = size
    sw, sh = w * scale, h * scale
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_fn(draw, sw, sh, scale)
    return img.resize((w, h), Image.Resampling.LANCZOS)

def draw_background(draw, w, h, scale):
    # Radial dark slate gradient
    cx, cy = w / 2, h / 2
    max_r = math.sqrt(cx * cx + cy * cy)
    steps = 40
    for i in range(steps, 0, -1):
        r = max_r * (i / steps)
        t = i / steps
        r_col = int(11 + 15 * t)
        g_col = int(14 + 18 * t)
        b_col = int(24 + 32 * t)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(r_col, g_col, b_col, 255))

def draw_foreground_game(draw, w, h, scale):
    cx, cy = w / 2, h / 2
    arena_r = min(w, h) * 0.35
    
    # Arena ring (cyan neon with alpha glow)
    ring_thick = 4 * scale
    draw.ellipse([cx - arena_r, cy - arena_r, cx + arena_r, cy + arena_r], outline=(0, 240, 255, 120), width=ring_thick)
    
    # Outer subtle dash rings
    draw.ellipse([cx - arena_r * 1.15, cy - arena_r * 1.15, cx + arena_r * 1.15, cy + arena_r * 1.15], outline=(0, 240, 255, 30), width=1 * scale)

    # Paddle Arc (bottom-right neon cyan)
    paddle_start = 25
    paddle_end = 95
    p_thick = 9 * scale
    # Glow pass
    draw.arc([cx - arena_r, cy - arena_r, cx + arena_r, cy + arena_r], start=paddle_start, end=paddle_end, fill=(0, 240, 255, 140), width=p_thick + 4 * scale)
    # Core pass
    draw.arc([cx - arena_r, cy - arena_r, cx + arena_r, cy + arena_r], start=paddle_start, end=paddle_end, fill=(255, 255, 255, 255), width=p_thick)

    # Ball with trail
    ball_pos = (cx + arena_r * 0.32, cy - arena_r * 0.28)
    trail_pos1 = (ball_pos[0] - 22 * scale, ball_pos[1] + 18 * scale)
    trail_pos2 = (ball_pos[0] - 44 * scale, ball_pos[1] + 36 * scale)

    # Trail points
    draw.ellipse([trail_pos2[0] - 4 * scale, trail_pos2[1] - 4 * scale, trail_pos2[0] + 4 * scale, trail_pos2[1] + 4 * scale], fill=(0, 240, 255, 80))
    draw.ellipse([trail_pos1[0] - 6 * scale, trail_pos1[1] - 6 * scale, trail_pos1[0] + 6 * scale, trail_pos1[1] + 6 * scale], fill=(0, 240, 255, 150))

    # Ball glow and core
    b_rad = 10 * scale
    draw.ellipse([ball_pos[0] - b_rad * 1.5, ball_pos[1] - b_rad * 1.5, ball_pos[0] + b_rad * 1.5, ball_pos[1] + b_rad * 1.5], fill=(0, 240, 255, 120))
    draw.ellipse([ball_pos[0] - b_rad, ball_pos[1] - b_rad, ball_pos[0] + b_rad, ball_pos[1] + b_rad], fill=(255, 255, 255, 255))

    # Golden coin at center
    c_rad = 12 * scale
    draw.ellipse([cx - c_rad * 1.4, cy - c_rad * 1.4, cx + c_rad * 1.4, cy + c_rad * 1.4], fill=(255, 215, 0, 100))
    draw.ellipse([cx - c_rad, cy - c_rad, cx + c_rad, cy + c_rad], fill=(255, 215, 0, 255))
    draw.ellipse([cx - c_rad * 0.75, cy - c_rad * 0.75, cx + c_rad * 0.75, cy + c_rad * 0.75], fill=(255, 240, 100, 255))
    # Coin star / inner detail
    draw.line([cx, cy - c_rad * 0.5, cx, cy + c_rad * 0.5], fill=(200, 150, 0, 255), width=2 * scale)
    draw.line([cx - c_rad * 0.5, cy, cx + c_rad * 0.5, cy], fill=(200, 150, 0, 255), width=2 * scale)

def draw_full_icon(draw, w, h, scale):
    draw_background(draw, w, h, scale)
    draw_foreground_game(draw, w, h, scale)

def draw_banner(draw, w, h, scale):
    draw_background(draw, w, h, scale)
    # Place orbit on the left/center
    cx, cy = w * 0.35, h / 2
    arena_r = h * 0.42
    
    # Ring
    draw.ellipse([cx - arena_r, cy - arena_r, cx + arena_r, cy + arena_r], outline=(0, 240, 255, 130), width=4 * scale)
    draw.ellipse([cx - arena_r * 1.12, cy - arena_r * 1.12, cx + arena_r * 1.12, cy + arena_r * 1.12], outline=(0, 240, 255, 40), width=1 * scale)

    # Paddle
    p_thick = 8 * scale
    draw.arc([cx - arena_r, cy - arena_r, cx + arena_r, cy + arena_r], start=20, end=90, fill=(255, 255, 255, 255), width=p_thick)
    
    # Coin
    c_rad = 16 * scale
    draw.ellipse([cx - c_rad, cy - c_rad, cx + c_rad, cy + c_rad], fill=(255, 215, 0, 255))
    draw.ellipse([cx - c_rad * 0.75, cy - c_rad * 0.75, cx + c_rad * 0.75, cy + c_rad * 0.75], fill=(255, 240, 100, 255))

    # Ball
    ball_pos = (cx + arena_r * 0.4, cy - arena_r * 0.35)
    b_rad = 12 * scale
    draw.ellipse([ball_pos[0] - b_rad, ball_pos[1] - b_rad, ball_pos[0] + b_rad, ball_pos[1] + b_rad], fill=(255, 255, 255, 255))

    # Glow dots / sparkles across banner
    import random
    rng = random.Random(42)
    for _ in range(70):
        sx = rng.randint(0, w)
        sy = rng.randint(0, h)
        s_size = rng.randint(1, 3) * scale
        col = rng.choice([(0, 240, 255, 150), (255, 215, 0, 180), (255, 255, 255, 180)])
        draw.ellipse([sx - s_size, sy - s_size, sx + s_size, sy + s_size], fill=col)

def main():
    os.makedirs("assets/icons", exist_ok=True)
    print("Gerando icon_192.png (192x192)...")
    create_super_image((192, 192), draw_full_icon).save("assets/icons/icon_192.png")

    print("Gerando icon_adaptive_background.png (432x432)...")
    create_super_image((432, 432), draw_background).save("assets/icons/icon_adaptive_background.png")

    print("Gerando icon_adaptive_foreground.png (432x432)...")
    create_super_image((432, 432), draw_foreground_game).save("assets/icons/icon_adaptive_foreground.png")

    print("Gerando icon_playstore_512.png (512x512)...")
    create_super_image((512, 512), draw_full_icon).save("assets/icons/icon_playstore_512.png")

    print("Gerando feature_graphic_1024x500.png (1024x500)...")
    create_super_image((1024, 500), draw_banner).save("assets/icons/feature_graphic_1024x500.png")

    print("Gerando splash_screen.png (1080x1920)...")
    create_super_image((1080, 1920), draw_full_icon).save("assets/icons/splash_screen.png")

    print("Todas as artes foram geradas com sucesso em assets/icons/!")

if __name__ == "__main__":
    main()
