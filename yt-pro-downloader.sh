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

# Welcome Banner
clear
echo -e "${CYAN}======================================${RESET}"
echo -e "${GREEN}      YT Pro Downloader v1.0${RESET}"
echo -e "${YELLOW}  Powered by yt-dlp + ffmpeg${RESET}"
echo -e "${CYAN}======================================${RESET}"
echo ""

# === Install yt-dlp & ffmpeg if missing ===
echo -e "${YELLOW}Checking dependencies...${RESET}"
OS=$(uname -s)

if ! command -v yt-dlp >/dev/null 2>&1 || ! command -v ffmpeg >/dev/null 2>&1; then
    echo -e "${GREEN}Installing yt-dlp and ffmpeg...${RESET}"
    if [[ "$OS" == "Linux" ]]; then
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y yt-dlp ffmpeg
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y yt-dlp ffmpeg
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy yt-dlp ffmpeg
        else
            echo -e "${RED}Unsupported package manager. Install yt-dlp & ffmpeg manually.${RESET}"
            exit 1
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        if ! command -v brew >/dev/null 2>&1; then
            echo -e "${YELLOW}Installing Homebrew...${RESET}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install yt-dlp ffmpeg
    else
        echo -e "${RED}Windows detected. Please install yt-dlp.exe and ffmpeg manually.${RESET}"
    fi
else
    echo -e "${GREEN}All dependencies are installed.${RESET}"
fi

echo ""

# === Ask user: Single or Playlist ===
echo -e "${CYAN}Select download mode:${RESET}"
echo "1) Single Video"
echo "2) Playlist"
read -p "Enter choice (1 or 2): " MODE

if [[ "$MODE" == "1" ]]; then
    read -p "Enter video URL: " VIDEO_URL
    PLAYLIST_FLAG="--no-playlist"
elif [[ "$MODE" == "2" ]]; then
    read -p "Enter playlist URL: " VIDEO_URL
    PLAYLIST_FLAG="--yes-playlist"
else
    echo -e "${RED}Invalid choice. Exiting.${RESET}"
    exit 1
fi

# === Show available formats ===
echo -e "${YELLOW}Fetching available formats...${RESET}"
yt-dlp -F "$VIDEO_URL"

# === User selects format ===
read -p "Enter format code (leave blank for best quality): " FORMAT_CODE

if [[ -z "$FORMAT_CODE" ]]; then
    DL_FORMAT="bv*+ba"
else
    if yt-dlp -F "$VIDEO_URL" | grep -E "^$FORMAT_CODE\s" | grep -q "video only"; then
        echo -e "${CYAN}Video-only format detected. Adding best audio...${RESET}"
        DL_FORMAT="$FORMAT_CODE+ba"
    else
        DL_FORMAT="$FORMAT_CODE"
    fi
fi

# === Download ===
echo -e "${GREEN}Downloading...${RESET}"
if [[ "$MODE" == "2" ]]; then
    yt-dlp -f "$DL_FORMAT" $PLAYLIST_FLAG "$VIDEO_URL" -o "%(playlist_title)s/%(title)s.%(ext)s"
else
    yt-dlp -f "$DL_FORMAT" $PLAYLIST_FLAG "$VIDEO_URL" -o "%(title)s.%(ext)s"
fi

# === Conversion Option ===
read -p "Do you want to convert the file(s) to another format? (y/n): " CONVERT
if [[ "$CONVERT" == "y" || "$CONVERT" == "Y" ]]; then
    read -p "Enter output format (e.g., mp4, mp3, mkv, wav): " OUTPUT_FORMAT
    if [[ "$MODE" == "2" ]]; then
        find "./$(yt-dlp --get-filename -o "%(playlist_title)s" "$VIDEO_URL")" -type f | while read FILE; do
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
