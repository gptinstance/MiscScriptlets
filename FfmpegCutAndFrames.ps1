# Improved version of FfmpegCutAndFrames.ps1
# This script trims a video between a start and end time and extracts frames as images.
# It accepts parameters for input file, output directory, start time and end time. It also
# performs basic validation and creates the output directory if it does not exist.

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$InputFile,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$OutputFolder,

    [Parameter(Mandatory=$true, Position=2)]
    [ValidatePattern("^\d{2}:\d{2}:\d{2}(\.\d{1,3})?$", ErrorMessage="StartTime must be in HH:MM:SS[.fff] format")]
    [string]$StartTime,

    [Parameter(Mandatory=$true, Position=3)]
    [ValidatePattern("^\d{2}:\d{2}:\d{2}(\.\d{1,3})?$", ErrorMessage="EndTime must be in HH:MM:SS[.fff] format")]
    [string]$EndTime
)

# Validate that ffmpeg and ffprobe are available
function Test-Command {
    param([string]$Command)
    $exists = Get-Command $Command -ErrorAction SilentlyContinue
    return [bool]$exists
}

if (-not (Test-Command 'ffmpeg')) {
    Write-Error "ffmpeg is not installed or not found in PATH. Please install ffmpeg to continue."
    exit 1
}
if (-not (Test-Command 'ffprobe')) {
    Write-Error "ffprobe is not installed or not found in PATH. Please install ffprobe to continue."
    exit 1
}

# Validate input file
if (-not (Test-Path -Path $InputFile -PathType Leaf)) {
    Write-Error "Input file '$InputFile' does not exist."
    exit 1
}

# Create output directory if it does not exist
if (-not (Test-Path -Path $OutputFolder -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

# Determine the last keyframe time (for informational purposes)
try {
    $frames = & ffprobe -select_streams v:0 -show_frames -show_entries frame=pict_type,pkt_pts_time -of csv -v quiet $InputFile |
        ConvertFrom-Csv -Header 'pict_type','pkt_pts_time'
    $lastKeyFrame = ($frames | Where-Object { $_.pict_type -eq 'I' } | Select-Object -Last 1).pkt_pts_time
    Write-Host "Last keyframe time detected: $lastKeyFrame"
} catch {
    Write-Warning "Unable to detect last keyframe time: $_"
}

# Define names for temporary and final outputs
$trimmedVideo = Join-Path $OutputFolder 'trimmed_output.mp4'
$framesOutputPattern = Join-Path $OutputFolder 'frame-%04d.png'

# Trim the video to the specified segment
Write-Host "Trimming video from $StartTime to $EndTime..."
$trimArgs = @('-hide_banner', '-loglevel', 'error', '-ss', $StartTime, '-to', $EndTime, '-i', $InputFile, '-c:v', 'copy', '-c:a', 'copy', $trimmedVideo)
& ffmpeg @trimArgs

if (-not (Test-Path -Path $trimmedVideo -PathType Leaf)) {
    Write-Error "Failed to create trimmed video."
    exit 1
}

# Extract frames
Write-Host "Extracting frames to $OutputFolder..."
$frameArgs = @('-hide_banner', '-loglevel', 'error', '-i', $trimmedVideo, '-vsync', '0', $framesOutputPattern)
& ffmpeg @frameArgs

Write-Host "Processing complete. Trimmed video and frames saved in '$OutputFolder'."
