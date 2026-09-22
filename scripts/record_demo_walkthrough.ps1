# Automated demo recording script for Exalere Walkthrough
$ErrorActionPreference = "Stop"

Write-Host "1. Resetting Exalere to clean Home state..."
adb shell am start -S -n com.abhishekrazy.exalere/.MainActivity
Start-Sleep -Seconds 3

# Dismiss any potential update dialog
adb shell input keyevent 4
Start-Sleep -Seconds 1

Write-Host "2. Starting screen recording on device..."
# Clean old recording
adb shell rm -f /sdcard/demo_walkthrough.mp4

# Start screenrecord in background
$proc = Start-Process adb -ArgumentList "shell screenrecord --size 720x1600 --bit-rate 4000000 /sdcard/demo_walkthrough.mp4" -PassThru
Start-Sleep -Seconds 2

Write-Host "3. Showcasing Home Screen catalog..."
Start-Sleep -Seconds 3

Write-Host "4. Navigating to Settings -> Community Add-ons..."
# Tap Settings tab on bottom nav (Tab index 5, x=1230, y=2850 on 1344x2992 screen)
adb shell input tap 1230 2850
Start-Sleep -Seconds 2

# Scroll down to reveal Community Add-ons
adb shell input swipe 672 2000 672 1200 400
Start-Sleep -Seconds 2

# Tap Install on MediaFusion or featured Add-on (x=1150, y=1750)
adb shell input tap 1150 1750
Start-Sleep -Seconds 3

Write-Host "5. Navigating to Search Tab & querying..."
# Tap Search tab (Tab index 1, x=336, y=2850)
adb shell input tap 336 2850
Start-Sleep -Seconds 2

# Tap Search input field (x=500, y=270)
adb shell input tap 500 270
Start-Sleep -Milliseconds 600

# Type "Spider"
adb shell input text "Spider"
Start-Sleep -Milliseconds 800

# Tap Search execute button (x=1200, y=270)
adb shell input tap 1200 270
Start-Sleep -Seconds 3

Write-Host "6. Selecting movie card to open Details Screen..."
# Hide soft keyboard if visible
adb shell input keyevent 111
Start-Sleep -Milliseconds 500

# Tap first search result card (x=300, y=800)
adb shell input tap 300 800
Start-Sleep -Seconds 4

Write-Host "7. Showcasing Details view and stream playback..."
# Tap Play button (x=200, y=1420)
adb shell input tap 200 1420
Start-Sleep -Seconds 5

Write-Host "8. Stopping screen recording..."
adb shell pkill -2 screenrecord
adb shell pkill -INT screenrecord
if ($proc -and -not $proc.HasExited) {
    Wait-Process -Id $proc.Id -Timeout 6 -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 3

Write-Host "9. Pulling demo video from device..."
New-Item -ItemType Directory -Force -Path ".github\assets" | Out-Null
adb pull /sdcard/demo_walkthrough.mp4 .github\assets\demo_raw.mp4

Write-Host "10. Optimizing video and generating animated GIF..."
ffmpeg -y -i .github\assets\demo_raw.mp4 -vf "scale=720:-1:flags=lanczos" -c:v libx264 -crf 23 -preset medium -pix_fmt yuv420p .github\assets\demo_walkthrough.mp4
ffmpeg -y -i .github\assets\demo_raw.mp4 -vf "fps=12,scale=400:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" .github\assets\demo_walkthrough.gif

Remove-Item .github\assets\demo_raw.mp4 -Force -ErrorAction SilentlyContinue
Write-Host "Demo recording and GIF generation completed successfully!"
