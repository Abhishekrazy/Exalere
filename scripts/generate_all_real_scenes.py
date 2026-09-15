import json
import time
import urllib.request
import os
import shutil

COMFY_URL = "http://127.0.0.1:8189"
RELEASE_DIR = r"i:\Personal\Flutter\Exalere\release_assets"
OUTPUT_DIR = r"K:\ComfyUI\ComfyUI_Output"

def queue_prompt(prompt_workflow):
    data = json.dumps({"prompt": prompt_workflow}).encode("utf-8")
    req = urllib.request.Request(f"{COMFY_URL}/prompt", data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode("utf-8"))

def wait_for_completion(prompt_id, timeout=900):
    print(f"Monitoring LTX prompt {prompt_id}...")
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            req = urllib.request.Request(f"{COMFY_URL}/history/{prompt_id}")
            with urllib.request.urlopen(req) as resp:
                history = json.loads(resp.read().decode("utf-8"))
                if prompt_id in history:
                    return history[prompt_id]
        except Exception:
            pass
        time.sleep(3)
    raise TimeoutError(f"Prompt {prompt_id} timed out after {timeout} seconds.")

def render_scene(scene_num, input_image, prompt_text, out_prefix):
    with open(r"C:\Users\AbhishekRazy\Downloads\LTX Image to Video.json", "r", encoding="utf-8") as f:
        workflow = json.load(f)

    workflow["395"]["inputs"]["image"] = input_image
    workflow["413"]["inputs"]["value"] = 10
    workflow["409"]["inputs"]["value"] = prompt_text
    workflow["419"]["inputs"]["text"] = (
        "music, background music, soundtrack, song, singing, musical instruments, synth, guitar, beats, "
        "audio noise, distorted voice, stuttering, ugly, blurry, jerky camera, fast abrupt motion"
    )
    workflow["75"]["inputs"]["filename_prefix"] = out_prefix

    print(f"\n==========================================")
    print(f"Submitting Scene {scene_num}: {out_prefix}")
    print(f"Input image: {input_image}")
    print(f"==========================================")

    res = queue_prompt(workflow)
    prompt_id = res["prompt_id"]
    print(f"Prompt ID: {prompt_id}")

    hist = wait_for_completion(prompt_id)
    outputs = hist.get("outputs", {})
    images = outputs.get("75", {}).get("images", [])
    if not images:
        raise RuntimeError(f"Scene {scene_num} failed: No output video returned!")

    filename = images[0]["filename"]
    subfolder = images[0].get("subfolder", "video")
    src_video = os.path.join(OUTPUT_DIR, subfolder, filename)
    dest_video = os.path.join(RELEASE_DIR, f"scene{scene_num}.mp4")

    shutil.copy2(src_video, dest_video)
    print(f"[SUCCESS] Scene {scene_num} rendered & saved to: {dest_video}")
    return dest_video

def main():
    scenes = [
        (
            1,
            "scene1_real_input.png",
            (
                "A cinematic slow, smooth push-in camera movement towards the sleek television in the modern ambient room. "
                "The TV screen displays the Exalere logo and catalog with vibrant movie posters. "
                "The narrator speaks with a confident, clear, warm tone: "
                "'Meet Exalere — your personal media catalog and universal stream player. "
                "Organize your movies, discover trending titles, and enjoy an effortless TV Leanback experience.' "
                "Clear professional voiceover only, spoken cleanly and naturally. "
                "Strictly no music, no background music, no soundtrack, no instrumental sounds."
            ),
            "video/exalere_real_scene1"
        ),
        (
            2,
            "scene2_real_input.png",
            (
                "Cinematic smooth camera movement gliding across the 4K HDR video playback interface on the television. "
                "The screen radiates vibrant cinematic colors with sci-fi action and glowing audio spectrum bars. "
                "The narrator speaks with a confident, clear, articulate voice: "
                "'Powered by the ultra-fast libmpv engine for crystal-clear 4K HDR streaming. "
                "Easily extend your catalog with custom stream plugins and personal playlists — putting you in complete control.' "
                "Clear professional voiceover only, spoken cleanly and naturally. "
                "Strictly no music, no background music, no soundtrack, no instrumental sounds."
            ),
            "video/exalere_real_scene2"
        ),
        (
            3,
            "scene3_real_input.png",
            (
                "Cinematic smooth push-in camera movement towards the glowing red Exalere logo with sparkling ambient particles and atmospheric lighting. "
                "The narrator delivers the final closing call to action: "
                "'Exalere: Personal Media Catalog and Universal Stream Player. "
                "Your entertainment, your way. Download now on Google Play.' "
                "Clear professional voiceover only, spoken cleanly, warmly and powerfully. "
                "Strictly no music, no background music, no soundtrack, no instrumental sounds."
            ),
            "video/exalere_real_scene3"
        )
    ]

    for num, inp, prompt, prefix in scenes:
        render_scene(num, inp, prompt, prefix)

    print("\nAll 3 scenes rendered with real Exalere logo! Now compositing videos...")
    import subprocess
    subprocess.run(["python", "scripts/composite_promo_video.py"], check=True)
    print("\n[COMPLETE] Both promotional video formats composited with real logo!")

if __name__ == "__main__":
    main()
