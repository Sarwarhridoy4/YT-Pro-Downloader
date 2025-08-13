#!/bin/bash

# ==============================
#  YT Pro Downloader Terminal App
#  Author: Sarwar Hossain
# ==============================

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
MAGENTA="\033[35m"
BOLD="\033[1m"
RESET="\033[0m"

clear
echo -e "${CYAN}=============================================${RESET}"
echo -e "${GREEN}${BOLD}         YT Pro Downloader v1.3${RESET}"
echo -e "${YELLOW}     Powered by yt-dlp + ffmpeg${RESET}"
echo -e "${CYAN}=============================================${RESET}\n"

# -----------------------------
# Dependency Installation
# -----------------------------
install_linux_packages() {
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y yt-dlp ffmpeg
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y yt-dlp ffmpeg
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm yt-dlp ffmpeg
    else
        echo -e "${RED}Unsupported Linux package manager.${RESET}"
        exit 1
    fi
}

install_mac_packages() {
    if ! command -v brew >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing Homebrew...${RESET}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install yt-dlp ffmpeg
}

install_windows_packages() {
    if command -v winget >/dev/null 2>&1; then
        echo -e "${GREEN}Installing yt-dlp & ffmpeg via winget...${RESET}"
        winget install --id=yt-dlp.yt-dlp -e --accept-package-agreements --accept-source-agreements
        winget install --id=Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
    else
        echo -e "${RED}winget not found. Install manually:${RESET}"
        echo "yt-dlp: https://github.com/yt-dlp/yt-dlp/releases"
        echo "FFmpeg: https://ffmpeg.org/download.html"
        exit 1
    fi
}

echo -e "${YELLOW}Checking dependencies...${RESET}"
OS=$(uname -s)

if [[ "$OS" == "Linux" ]]; then
    if grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
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
    echo -e "${RED}Unsupported OS: $OS${RESET}"
    exit 1
fi

if ! command -v yt-dlp >/dev/null || ! command -v ffmpeg >/dev/null; then
    echo -e "${RED}Dependencies missing after install attempt.${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ All dependencies are installed.${RESET}\n"

# -----------------------------
# Mode Selection
# -----------------------------
echo -e "${CYAN}${BOLD}Select download mode:${RESET}"
echo -e "  1) Single Video"
echo -e "  2) Playlist"
read -rp "Enter choice (1 or 2): " MODE

if [[ "$MODE" == "1" ]]; then
    read -rp "🎯 Enter video URL: " VIDEO_URL
    PLAYLIST_FLAG="--no-playlist"

    echo -e "\n${YELLOW}📡 Fetching available formats...${RESET}"
    yt-dlp -F "$VIDEO_URL"

elif [[ "$MODE" == "2" ]]; then
    read -rp "📜 Enter playlist URL: " VIDEO_URL
    read -rp "🎯 Enter video range (e.g., 1-5, 3-3, leave blank for all): " RANGE

    if [[ -n "$RANGE" ]]; then
        RANGE_FLAG="--playlist-items $RANGE"
        FIRST_ITEM=$(echo "$RANGE" | cut -d'-' -f1)
    else
        RANGE_FLAG=""
        FIRST_ITEM=1
    fi
    PLAYLIST_FLAG="--yes-playlist"

    echo -e "\n${YELLOW}📡 Fetching formats for playlist item $FIRST_ITEM only...${RESET}"
    yt-dlp -F --playlist-items "$FIRST_ITEM" "$VIDEO_URL"

else
    echo -e "${RED}Invalid choice.${RESET}"
    exit 1
fi

# -----------------------------
# Format Selection
# -----------------------------
read -rp "🎥 Enter format code (blank for best quality): " FORMAT_CODE

if [[ -z "$FORMAT_CODE" ]]; then
    DL_FORMAT="bv*+ba"
else
    if yt-dlp -F --playlist-items "${FIRST_ITEM:-1}" "$VIDEO_URL" | grep -E "^$FORMAT_CODE\s" | grep -q "video only"; then
        echo -e "${CYAN}🎧 Adding best audio to video-only format...${RESET}"
        DL_FORMAT="${FORMAT_CODE}+ba"
    else
        DL_FORMAT="$FORMAT_CODE"
    fi
fi

# -----------------------------
# Download
# -----------------------------
echo -e "\n${GREEN}🚀 Starting download...${RESET}"

if [[ "$MODE" == "2" ]]; then
    yt-dlp -f "$DL_FORMAT" $PLAYLIST_FLAG $RANGE_FLAG "$VIDEO_URL" \
        -o "%(playlist_title)s/%(title)s.%(ext)s" --newline \
        | while read -r line; do
            echo -e "${MAGENTA}$line${RESET}"
        done
else
    yt-dlp -f "$DL_FORMAT" $PLAYLIST_FLAG "$VIDEO_URL" \
        -o "%(title)s.%(ext)s" --newline \
        | while read -r line; do
            echo -e "${MAGENTA}$line${RESET}"
        done
fi

# -----------------------------
# Conversion
# -----------------------------
read -rp "🔄 Convert the file(s) to another format? (y/n): " CONVERT
if [[ "$CONVERT" =~ ^[Yy]$ ]]; then
    read -rp "🎯 Enter output format (e.g., mp4, mp3, mkv, wav): " OUTPUT_FORMAT
    if [[ "$MODE" == "2" ]]; then
        PLAYLIST_FOLDER=$(yt-dlp --get-filename -o "%(playlist_title)s" --playlist-items "${FIRST_ITEM:-1}" "$VIDEO_URL" | head -n1)
        find "./$PLAYLIST_FOLDER" -type f | while read -r FILE; do
            ffmpeg -i "$FILE" "${FILE%.*}.$OUTPUT_FORMAT"
        done
    else
        INPUT_FILE=$(ls -t | head -n1)
        OUTPUT_FILE="${INPUT_FILE%.*}.$OUTPUT_FORMAT"
        ffmpeg -i "$INPUT_FILE" "$OUTPUT_FILE"
    fi
    echo -e "${GREEN}✅ Conversion completed.${RESET}"
else
    echo -e "${GREEN}✅ Download completed without conversion.${RESET}"
fi

echo -e "\n${CYAN}=============================================${RESET}"
echo -e "${GREEN}${BOLD}   🎉 Thank you for using YT Pro!${RESET}"
echo -e "${CYAN}=============================================${RESET}"
