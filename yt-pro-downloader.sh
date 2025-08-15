#!/bin/bash
# ==============================
#  YT Pro Downloader Terminal App v2.6
#  Author: Sarwar Hossain + UX Improvements
# ==============================

# ---------- Colors & UI ----------
RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; CYAN="\033[36m"; MAGENTA="\033[35m"
BOLD="\033[1m"; DIM="\033[2m"; RESET="\033[0m"
HIDE_CURSOR="\033[?25l"; SHOW_CURSOR="\033[?25h"

cleanup() { printf "${SHOW_CURSOR}${RESET}\n"; }
trap cleanup EXIT

# ---------- Banner ----------
clear
printf "${CYAN}=============================================${RESET}\n"
printf "${GREEN}${BOLD}         YT Pro Downloader v2.6${RESET}\n"
printf "${YELLOW}     Powered by yt-dlp + ffmpeg${RESET}\n"
printf "${CYAN}=============================================${RESET}\n\n"
printf "${HIDE_CURSOR}"

# ---------- Dependency Check ----------
log_dir="${TMPDIR:-/tmp}/ytpro"
mkdir -p "$log_dir"

install_deps() {
  echo -e "${YELLOW}Checking & installing dependencies…${RESET}"
  OS="$(uname -s)"
  if ! command -v yt-dlp >/dev/null 2>&1 || ! command -v ffmpeg >/dev/null 2>&1; then
    case "$OS" in
      Linux)
        if command -v apt >/dev/null 2>&1; then
          sudo apt update -y && sudo apt install -y yt-dlp ffmpeg
        elif command -v dnf >/dev/null 2>&1; then
          sudo dnf install -y yt-dlp ffmpeg
        elif command -v pacman >/dev/null 2>&1; then
          sudo pacman -Sy --noconfirm yt-dlp ffmpeg
        else
          echo -e "${RED}Unsupported Linux package manager.${RESET}"; exit 1
        fi
        ;;
      Darwin)
        command -v brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install yt-dlp ffmpeg
        ;;
      MINGW*|MSYS*|CYGWIN*)
        command -v winget >/dev/null 2>&1 || { echo -e "${RED}winget not found.${RESET}"; exit 1; }
        winget install --id=yt-dlp.yt-dlp -e --accept-package-agreements --accept-source-agreements
        winget install --id=Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
        ;;
      *)
        echo -e "${RED}Unsupported OS: $OS${RESET}"; exit 1
        ;;
    esac
  fi
  echo -e "${GREEN}✅ Dependencies installed.${RESET}\n"
}
install_deps

# ---------- Mode Selection ----------
echo -e "${CYAN}${BOLD}Select download mode:${RESET}"
echo "  1) Single Video"
echo "  2) Playlist"
read -rp "Enter choice (1 or 2): " MODE

VIDEO_URL=""
PLAYLIST_FLAG=""; RANGE_FLAG=""; FIRST_ITEM=1; OUTPUT_TEMPLATE=""
if [[ "$MODE" == "1" ]]; then
  read -rp "🎯 Enter video URL: " VIDEO_URL
  PLAYLIST_FLAG="--no-playlist"
  OUTPUT_TEMPLATE="%(title)s.%(ext)s"
elif [[ "$MODE" == "2" ]]; then
  read -rp "📜 Enter playlist URL: " VIDEO_URL
  PLAYLIST_FLAG="--yes-playlist"
  OUTPUT_TEMPLATE="%(playlist_title)s/%(playlist_index)02d - %(title)s.%(ext)s"

  # Playlist selection
  mapfile -t playlist_items < <(yt-dlp --flat-playlist --print "%(playlist_index)03d|%(title)s|%(duration_string)s" "$VIDEO_URL")
  total=${#playlist_items[@]}
  page_size=10
  start=0
  selections=()
  while (( start < total )); do
    clear
    echo -e "${CYAN}${BOLD}Playlist Videos (Items $((start+1))-$((start+page_size>total?total:start+page_size)) of $total):${RESET}"
    for ((i=start;i<start+page_size&&i<total;i++)); do
      idx="${playlist_items[$i]%%|*}"
      rest="${playlist_items[$i]#*|}"
      title="${rest%%|*}"; dur="${rest#*|}"
      echo -e "${MAGENTA}$idx${RESET}) $title ${DIM}[$dur]${RESET}"
    done
    echo
    echo "n) Next 10 items"
    echo "0) Done selecting"
    read -rp "🎯 Enter selections (e.g., 1,3,5-7): " choice
    if [[ "$choice" == "n" || "$choice" == "N" ]]; then start=$((start+page_size)); continue
    elif [[ "$choice" == "0" ]]; then break
    elif [[ -n "$choice" ]]; then selections+=("$choice"); fi
    start=$((start+page_size))
  done
  if (( ${#selections[@]} > 0 )); then
    RANGE_FLAG="--playlist-items $(IFS=,; echo "${selections[*]}")"
    FIRST_ITEM=$(echo "${selections[0]}" | cut -d',' -f1 | cut -d'-' -f1)
  else RANGE_FLAG=""; FIRST_ITEM=1; fi
else
  echo -e "${RED}Invalid choice.${RESET}"; exit 1
fi

# ---------- Format ----------
read -rp "🎥 Enter format code (blank=best): " FORMAT_CODE
if [[ -z "$FORMAT_CODE" ]]; then DL_FORMAT="bv*+ba"
else
  if yt-dlp -F --playlist-items "$FIRST_ITEM" "$VIDEO_URL" | grep -qE "^[[:space:]]*$FORMAT_CODE[[:space:]].*video[[:space:]]only"; then
    echo -e "${CYAN}🎧 Adding best audio…${RESET}"; DL_FORMAT="$FORMAT_CODE+ba"
  else DL_FORMAT="$FORMAT_CODE"; fi
fi

# ---------- Download ----------
download_list="$log_dir/downloaded_files.txt"; : > "$download_list"
echo -e "\n${GREEN}🚀 Starting download…${RESET}\n"

yt-dlp -f "$DL_FORMAT" $PLAYLIST_FLAG $RANGE_FLAG -o "$OUTPUT_TEMPLATE" "$VIDEO_URL" --newline

# Save downloaded files list
if [[ "$MODE" == "1" ]]; then
  echo "$VIDEO_URL" >> "$download_list"
else
  playlist_dir="$(yt-dlp --get-filename -o "$OUTPUT_TEMPLATE" --playlist-items "$FIRST_ITEM" "$VIDEO_URL" | head -n1)"
  playlist_dir="${playlist_dir%/*}"
  find "$playlist_dir" -type f -iname "*.*" > "$download_list"
fi

echo -e "${GREEN}✅ Download(s) finished.${RESET}\n"

# ---------- Conversion with live textual progress ----------
read -rp "🔄 Convert file(s)? (y/n): " CONVERT
if [[ "$CONVERT" =~ ^[Yy]$ ]]; then
  read -rp "🎯 Enter output format: " OUTPUT_FORMAT
  [[ ! -s "$download_list" ]] && find . -maxdepth 3 -type f -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n 10 | awk '{ $1=""; sub(/^ /,""); print }' > "$download_list"
  while IFS= read -r in_file; do
    [[ -z "$in_file" || ! -f "$in_file" ]] && continue
    out_file="${in_file%.*}.$OUTPUT_FORMAT"
    filesize_bytes=$(stat -c%s "$in_file" 2>/dev/null || stat -f%z "$in_file")
    echo -e "\n${CYAN}Converting:${RESET} ${MAGENTA}$(basename "$in_file") → $(basename "$out_file")${RESET}"

    ffmpeg -y -hide_banner -loglevel error -i "$in_file" "$out_file" -progress pipe:1 2>/dev/null \
    | while IFS='=' read -r key val; do
        case "$key" in
          out_time_ms)
            if [[ "$filesize_bytes" != "0" ]]; then
              # rough estimate: percent = out_size / filesize
              out_size=$(stat -c%s "$out_file" 2>/dev/null || stat -f%z "$out_file")
              percent=$(( out_size * 100 / filesize_bytes ))
              [[ $percent -gt 100 ]] && percent=100
              echo -ne "\r[conversion] $percent% of $(numfmt --to=iec "$filesize_bytes") completed"
            fi
            ;;
          progress) [[ "$val" == "end" ]] && echo -e "\r[conversion] 100% of $(numfmt --to=iec "$filesize_bytes") in done" ;;
        esac
    done
    echo -e "\n${GREEN}✔ Converted:${RESET} $out_file"
  done < "$download_list"
else
  echo -e "${GREEN}✅ Download completed without conversion.${RESET}"
fi

echo -e "\n${CYAN}=============================================${RESET}"
echo -e "${GREEN}${BOLD}   🎉 Thank you for using YT Pro!${RESET}"
echo -e "${CYAN}=============================================${RESET}"
