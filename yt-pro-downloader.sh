#!/bin/bash

# ==============================
#  YT Pro Downloader Terminal App
#  Author: YourName
# ==============================

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

clear
echo -e "${CYAN}======================================${RESET}"
echo -e "${GREEN}      YT Pro Downloader v1.0${RESET}"
echo -e "${YELLOW}  Powered by yt-dlp + ffmpeg${RESET}"
echo -e "${CYAN}======================================${RESET}"
echo ""

install_linux_packages() {
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y yt-dlp ffmpeg
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y yt-dlp ffmpeg
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm yt-dlp ffmpeg
    else
        echo -e "${RED}Unsupported Linux package manager. Please install yt-dlp and ffmpeg manually.${RESET}"
        exit 1
    fi
}

install_mac_packages() {
    if ! command -v brew >/dev/null 2>&1; then
        echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${RESET}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install yt-dlp ffmpeg
}

install_windows_packages() {
    if command -v winget >/dev/null 2>&1; then
        echo -e "${GREEN}Installing yt-dlp and ffmpeg via winget...${RESET}"
        winget install --id=yt-dlp.yt-dlp -e --accept-package-agreements --accept-source-agreements
        winget install --id=Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
    else
        echo -e "${RED}winget not found. Please install yt-dlp and ffmpeg manually from:"
        echo -e "yt-dlp: https://github.com/yt-dlp/yt-dlp/releases"
        echo -e "FFmpeg: https://ffmpeg.org/download.html"
        exit 1
    fi
}

echo -e "${YELLOW}Checking dependencies...${RESET}"
OS=$(uname -s)

# On Windows with Git Bash or WSL uname reports MINGW* or Linux, handle Windows separately:
if [[ "$OS" == "Linux" ]]; then
    # Check if WSL by looking for Windows environment variables
    if grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
        # WSL detected, use winget if possible
        if command -v winget >/dev/null 2>&1; then
            install_windows_packages
        else
            install_linux_packages
        fi
    else
        install_linux_packages
    fi
elif [[ "$OS" == "Darwin" ]]; then
    install_mac_packages
elif [[ "$OS" =~ ^MINGW|^MSYS|^CYGWIN ]]; then
    install_windows_packages
else
    echo -e "${RED}Unsupported OS: $OS. Please install yt-dlp and ffmpeg manually.${RESET}"
    exit 1
fi

# Double-check yt-dlp and ffmpeg availability after install attempt
if ! command -v yt-dlp >/dev/null 2>&1; then
    echo -e "${RED}yt-dlp installation failed or yt-dlp not found in PATH.${RESET}"
    exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo -e "${RED}ffmpeg installation failed or ffmpeg not found in PATH.${RESET}"
    exit 1
fi

echo -e "${GREEN}All dependencies are installed.${RESET}"
echo ""

# === Ask user: Single or Playlist ===
echo -e "${CYAN}Select download mode:${RESET}"
echo "1) Single Video"
echo "2) Playlist"
read -rp "Enter choice (1 or 2): " MODE

if [[ "$MODE" == "1" ]]; then
    read -rp "Enter video URL: " VIDEO_URL
    PLAYLIST_FLAG="--no-playlist"
elif [[ "$MODE" == "2" ]]; then
    read -rp "Enter playlist URL: " VIDEO_URL
    PLAYLIST_FLAG="--yes-playlist"
else
    echo -e "${RED}Invalid choice. Exiting.${RESET}"
    exit 1
fi

# === Show available formats ===
echo -e "${YELLOW}Fetching available formats...${RESET}"
yt-dlp -F "$VIDEO_URL"

# === User selects format ===
read -rp "Enter format code (leave blank for best quality): " FORMAT_CODE

if [[ -z "$FORMAT_CODE" ]]; then
    DL_FORMAT="bv*+ba"
else
    # Detect if video-only format selected and add best audio
    if yt-dlp -F "$VIDEO_URL" | grep -E "^$FORMAT_CODE\s" | grep -q "video only"; then
        echo -e "${CYAN}Video-only format detected. Adding best audio...${RESET}"
        DL_FORMAT="${FORMAT_CODE}+ba"
    else
        DL_FORMAT="$FORMAT_CODE"
    fi
fi

# === Download ===
echo -e "${GREEN}Starting download...${RESET}"
if [[ "$MODE" == "2" ]]; then
    yt-dlp -f "$DL_FORMAT" $PLAYLIST_FLAG "$VIDEO_URL" -o "%(playlist_title)s/%(title)s.%(ext)s"
else
    yt-dlp -f "$DL_FORMAT" $PLAYLIST_FLAG "$VIDEO_URL" -o "%(title)s.%(ext)s"
fi

# === Conversion Option ===
read -rp "Do you want to convert the file(s) to another format? (y/n): " CONVERT
if [[ "$CONVERT" =~ ^[Yy]$ ]]; then
    read -rp "Enter output format (e.g., mp4, mp3, mkv, wav): " OUTPUT_FORMAT
    if [[ "$MODE" == "2" ]]; then
        PLAYLIST_FOLDER=$(yt-dlp --get-filename -o "%(playlist_title)s" "$VIDEO_URL" | head -n1)
        find "./$PLAYLIST_FOLDER" -type f | while read -r FILE; do
            ffmpeg -i "$FILE" "${FILE%.*}.$OUTPUT_FORMAT"
        done
    else
        INPUT_FILE=$(ls -t | head -n1)
        OUTPUT_FILE="${INPUT_FILE%.*}.$OUTPUT_FORMAT"
        ffmpeg -i "$INPUT_FILE" "$OUTPUT_FILE"
    fi
    echo -e "${GREEN}Conversion completed.${RESET}"
else
    echo -e "${GREEN}Download completed without conversion.${RESET}"
fi

echo -e "${CYAN}======================================${RESET}"
echo -e "${GREEN}     Thank you for using YT Pro!${RESET}"
echo -e "${CYAN}======================================${RESET}"
