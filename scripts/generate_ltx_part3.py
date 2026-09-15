import json
import time
import urllib.request
import os

COMFY_URL = "http://127.0.0.1:8189"

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
                    print("LTX Scene 3 generation finished successfully!")
                    return history[prompt_id]
        except Exception as e:
            pass
        time.sleep(3)
    raise TimeoutError(f"Prompt {prompt_id} timed out after {timeout} seconds.")

def main():
    with open(r"C:\Users\AbhishekRazy\Downloads\LTX Image to Video.json", "r", encoding="utf-8") as f:
        workflow = json.load(f)

    # 1. First frame image
    workflow["395"]["inputs"]["image"] = "scene3_input.png"

    # 2. Duration (10 seconds)
    workflow["413"]["inputs"]["value"] = 10

    # 3. Prompt (Voiceover script + motion, strictly NO music)
    prompt_text = (
        "Cinematic smooth push-in camera movement towards the glowing 3D crystalline Exalere prism logo with "
        "sparkling ambient particles and orbital light rings. "
        "The narrator delivers the final closing call to action: "
        "'Exalere: Personal Media Catalog and Universal Stream Player. "
        "Your entertainment, your way. Download now on Google Play.' "
        "Clear professional voiceover only, spoken cleanly, warmly and powerfully. "
        "Strictly no music, no background music, no soundtrack, no instrumental sounds."
    )
    workflow["409"]["inputs"]["value"] = prompt_text

    # 4. Negative prompt
    workflow["419"]["inputs"]["text"] = (
        "music, background music, soundtrack, song, singing, musical instruments, synth, guitar, beats, "
        "audio noise, distorted voice, stuttering, ugly, blurry, jerky camera, fast abrupt motion"
    )

    # 5. Output prefix in Node 75
    workflow["75"]["inputs"]["filename_prefix"] = "video/exalere_scene3"

    print("Submitting LTX Scene 3 generation prompt...")
    res = queue_prompt(workflow)
    prompt_id = res["prompt_id"]
    print(f"Prompt ID: {prompt_id}")

    history = wait_for_completion(prompt_id, timeout=900)
    outputs = history.get("outputs", {})
    print("Outputs:", json.dumps(outputs, indent=2))

if __name__ == "__main__":
    main()
