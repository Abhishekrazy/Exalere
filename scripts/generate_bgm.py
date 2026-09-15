import json
import time
import urllib.request
import urllib.parse
import os

COMFY_URL = "http://127.0.0.1:8189"

def queue_prompt(prompt_workflow):
    data = json.dumps({"prompt": prompt_workflow}).encode("utf-8")
    req = urllib.request.Request(f"{COMFY_URL}/prompt", data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode("utf-8"))

def wait_for_completion(prompt_id, timeout=300):
    print(f"Monitoring prompt {prompt_id}...")
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            req = urllib.request.Request(f"{COMFY_URL}/history/{prompt_id}")
            with urllib.request.urlopen(req) as resp:
                history = json.loads(resp.read().decode("utf-8"))
                if prompt_id in history:
                    print("Prompt execution finished successfully!")
                    return history[prompt_id]
        except Exception as e:
            pass
        time.sleep(2)
    raise TimeoutError(f"Prompt {prompt_id} timed out after {timeout} seconds.")

def main():
    with open(r"C:\Users\AbhishekRazy\Downloads\audio_minimax_music_3.json", "r", encoding="utf-8") as f:
        workflow = json.load(f)

    # Customize prompt for Exalere promotional background music
    caption = (
        "Global Metadata: Modern cinematic electronic, sleek tech ambient, futuristic synthwave, 115 BPM, C minor. "
        "Inspiring, energetic, high-tech, crystal clear production, punchy deep electronic kick, crisp hi-hats, "
        "warm analog synth pads, polished commercial tech promo soundtrack.\n\n"
        "Arrangement: Pure instrumental with uplifting arpeggios, sleek sub-bass pulse, atmospheric risers, modern polished tech broadcast mix."
    )
    lyrics = "[Instrumental]\n(driving electronic tech pulse)\n[Instrumental]\n[Outro]\n(clean fade)"

    # Update node 37:13
    workflow["37:13"]["inputs"]["caption"] = caption
    workflow["37:13"]["inputs"]["lyrics"] = lyrics
    workflow["37:13"]["inputs"]["max_duration"] = 35

    # Update node 35 (save audio)
    workflow["35"]["inputs"]["filename_prefix"] = "audio/exalere_promo_bgm"

    print("Submitting Minimax Music generation prompt...")
    res = queue_prompt(workflow)
    prompt_id = res["prompt_id"]
    print(f"Prompt ID: {prompt_id}")

    history = wait_for_completion(prompt_id, timeout=300)
    outputs = history.get("outputs", {})
    print("Outputs:", json.dumps(outputs, indent=2))

if __name__ == "__main__":
    main()
