# Automated demo recording script for Exalere Android TV Walkthrough (24 Seconds)
$ErrorActionPreference = "Stop"

Write-Host "1. Resetting Exalere to clean state on Android TV..."
adb shell pm clear com.abhishekrazy.exalere
adb shell am start -S -n com.abhishekrazy.exalere/.MainActivity
Start-Sleep -Seconds 4

# Dismiss any potential update dialog
adb shell input keyevent 4
Start-Sleep -Seconds 1

Write-Host "2. Starting screen recording on Android TV..."
# Clean old recording
adb shell rm -f /sdcard/tv_walkthrough.mp4

# Start screenrecord at 1280x720 16:9 widescreen TV format
$proc = Start-Process adb -ArgumentList "shell screenrecord --size 1280x720 --bit-rate 4000000 /sdcard/tv_walkthrough.mp4" -PassThru
Start-Sleep -Seconds 1

Write-Host "3. Showcasing TV Home Screen with D-Pad focus (2.5s)..."
adb shell input keyevent 22 # D-Pad Right on movie cards
Start-Sleep -Milliseconds 1200
adb shell input keyevent 21 # D-Pad Left
Start-Sleep -Milliseconds 1300

Write-Host "4. Navigating to Settings -> Add-ons..."
adb shell input keyevent 4 # Back to sidebar
Start-Sleep -Milliseconds 400
# D-Pad Down 5 times to Settings (index 5)
1..5 | ForEach-Object {
    adb shell input keyevent 20
    Start-Sleep -Milliseconds 150
}
Start-Sleep -Milliseconds 200
adb shell input keyevent 23 # Select Settings
Start-Sleep -Milliseconds 800

# Scroll down to Add-ons in Settings (6 down, 1 right)
1..6 | ForEach-Object {
    adb shell input keyevent 20
    Start-Sleep -Milliseconds 150
}
Start-Sleep -Milliseconds 200
adb shell input keyevent 22 # Right to Add-ons
Start-Sleep -Milliseconds 200
adb shell input keyevent 23 # Enter Add-ons
Start-Sleep -Milliseconds 800

Write-Host "5. Installing 4K Torrentio Plugin (1-Click Install)..."
adb shell input keyevent 20 # Down to + Add Add-on
Start-Sleep -Milliseconds 200
adb shell input keyevent 20 # Down to TPB+
Start-Sleep -Milliseconds 200
adb shell input keyevent 22 # Right to Torrentio (4K HDR)
Start-Sleep -Milliseconds 300
adb shell input keyevent 23 # Click Install!
Start-Sleep -Milliseconds 1800 # Let green 'Installed' toast show

Write-Host "6. Navigating to Search Tab..."
adb shell input keyevent 4 # Back from Add-ons
Start-Sleep -Milliseconds 400
adb shell input keyevent 4 # Back to Sidebar
Start-Sleep -Milliseconds 400
# Up 4 times to Search (index 1)
1..4 | ForEach-Object {
    adb shell input keyevent 19
    Start-Sleep -Milliseconds 150
}
Start-Sleep -Milliseconds 200
adb shell input keyevent 23 # Enter Search tab
Start-Sleep -Milliseconds 800

Write-Host "7. Opening TV Search Keyboard and Querying 'Spider'..."
adb shell input keyevent 19 # Up to 'All' filter pill
Start-Sleep -Milliseconds 250
adb shell input keyevent 19 # Up to Search Bar
Start-Sleep -Milliseconds 300
adb shell input keyevent 23 # Open Leanback TV keyboard
Start-Sleep -Milliseconds 800

adb shell input text "Spider"
Start-Sleep -Milliseconds 600
adb shell input keyevent 66 # Press Enter to search
Start-Sleep -Milliseconds 2000 # Let search results load

Write-Host "8. Selecting movie and opening Cinematic TV Details Screen..."
adb shell input keyevent 20 # Down into results
Start-Sleep -Milliseconds 300
adb shell input keyevent 20 # Down to Spider-Man 2
Start-Sleep -Milliseconds 500
adb shell input keyevent 23 # Open Details Screen
Start-Sleep -Milliseconds 2000 # Let backdrop and Play button appear

Write-Host "9. Triggering 4K Video Playback Resolver..."
adb shell input keyevent 23 # Press Play
Start-Sleep -Milliseconds 3500 # Show 4K stream sources from Torrentio

Write-Host "10. Stopping screen recording..."
adb shell pkill -2 screenrecord
adb shell pkill -INT screenrecord
if ($proc -and -not $proc.HasExited) {
    Wait-Process -Id $proc.Id -Timeout 6 -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

Write-Host "11. Pulling demo video from device..."
New-Item -ItemType Directory -Force -Path ".github\assets" | Out-Null
adb pull /sdcard/tv_walkthrough.mp4 .github\assets\tv_raw.mp4

Write-Host "12. Trimming to exactly 24.000 seconds and optimizing..."
# Transcode & trim to exact 24 seconds at 1280x720 16:9
ffmpeg -y -ss 00:00:00 -to 00:00:24.000 -i .github\assets\tv_raw.mp4 -c:v libx264 -crf 23 -preset medium -pix_fmt yuv420p -an .github\assets\demo_tv_walkthrough.mp4

# Generate high quality 24-second animated GIF with palettegen
ffmpeg -y -ss 00:00:00 -to 00:00:24.000 -i .github\assets\demo_tv_walkthrough.mp4 -vf "fps=12,scale=640:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" .github\assets\demo_tv_walkthrough.gif

Remove-Item .github\assets\tv_raw.mp4 -Force -ErrorAction SilentlyContinue
Write-Host "Android TV Demo recording (24s) completed successfully!"
