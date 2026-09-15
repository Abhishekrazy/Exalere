import os
import subprocess

ASSETS_DIR = r"i:\Personal\Flutter\Exalere\release_assets"

def run_cmd(cmd, desc):
    print(f"\n[EXEC] {desc}")
    print(" ".join(cmd))
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[ERROR] {res.stderr}")
        raise RuntimeError(f"FFmpeg failed with code {res.returncode}")
    print(f"[SUCCESS] {desc}")

def main():
    s1 = os.path.join(ASSETS_DIR, "scene1.mp4")
    s2 = os.path.join(ASSETS_DIR, "scene2.mp4")
    s3 = os.path.join(ASSETS_DIR, "scene3.mp4")
    bgm = os.path.join(ASSETS_DIR, "exalere_promo_bgm.mp3")

    # Step 1: Create a concat file for the 3 scenes
    concat_txt = os.path.join(ASSETS_DIR, "concat_list.txt")
    with open(concat_txt, "w", encoding="utf-8") as f:
        f.write(f"file '{s1}'\n")
        f.write(f"file '{s2}'\n")
        f.write(f"file '{s3}'\n")

    # Temp merged raw video + narration
    merged_raw = os.path.join(ASSETS_DIR, "temp_merged_raw.mp4")
    cmd_concat = [
        "ffmpeg", "-y", "-f", "concat", "-safe", "0",
        "-i", concat_txt,
        "-c:v", "libx264", "-preset", "fast", "-crf", "18",
        "-c:a", "aac", "-b:a", "192k",
        merged_raw
    ]
    run_cmd(cmd_concat, "Concatenating 3 video scenes")

    # Step 2: Render 16:9 Landscape for Google Play Store with audio ducking and BGM
    out_landscape = os.path.join(ASSETS_DIR, "exalere_promo_playstore_landscape_16x9.mp4")
    # Total duration is approx 30.12s
    # Audio filter:
    # 1. Take voice from merged_raw [0:a] and normalize volume
    # 2. Take bgm [1:a], apply volume reduction (0.28) and fade out at 28s
    # 3. Mix both together with amix
    cmd_landscape = [
        "ffmpeg", "-y",
        "-i", merged_raw,
        "-i", bgm,
        "-filter_complex",
        "[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30[v];"
        "[1:a]volume=0.28,afade=t=out:st=28.5:d=1.5[bgm_ducked];"
        "[0:a]volume=1.4[voice_boosted];"
        "[voice_boosted][bgm_ducked]amix=inputs=2:duration=first:dropout_transition=2[a]",
        "-map", "[v]",
        "-map", "[a]",
        "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "320k",
        out_landscape
    ]
    run_cmd(cmd_landscape, "Compositing 16:9 Play Store Landscape video")

    # Step 3: Render 9:16 Portrait for Instagram Reels / Stories
    # Uses blurred background + centered crisp video layout with clean branding
    out_portrait = os.path.join(ASSETS_DIR, "exalere_promo_instagram_portrait_9x16.mp4")
    cmd_portrait = [
        "ffmpeg", "-y",
        "-i", merged_raw,
        "-i", bgm,
        "-filter_complex",
        "[0:v]split=2[bg_src][fg_src];"
        "[bg_src]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,gblur=sigma=28[bg];"
        "[fg_src]scale=1080:-1[fg];"
        "[bg][fg]overlay=0:(H-h)/2,fps=30[v];"
        "[1:a]volume=0.28,afade=t=out:st=28.5:d=1.5[bgm_ducked];"
        "[0:a]volume=1.4[voice_boosted];"
        "[voice_boosted][bgm_ducked]amix=inputs=2:duration=first:dropout_transition=2[a]",
        "-map", "[v]",
        "-map", "[a]",
        "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "320k",
        out_portrait
    ]
    run_cmd(cmd_portrait, "Compositing 9:16 Instagram Portrait video")

    # Clean up temp files
    if os.path.exists(concat_txt): os.remove(concat_txt)
    if os.path.exists(merged_raw): os.remove(merged_raw)

    print("\n[ALL COMPLETED]")
    print(f"Play Store Landscape (16:9): {out_landscape}")
    print(f"Instagram Portrait (9:16):    {out_portrait}")

if __name__ == "__main__":
    main()
