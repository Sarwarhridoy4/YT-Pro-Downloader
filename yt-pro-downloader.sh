#!/bin/bash
# ==============================
#  YT Pro Downloader Terminal App v2.4
#  Author: Sarwar Hossain
# ==============================

# ---------- Colors & UI ----------
RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; CYAN="\033[36m"; MAGENTA="\033[35m"
BOLD="\033[1m"; DIM="\033[2m"; RESET="\033[0m"
HIDE_CURSOR="\033[?25l"; SHOW_CURSOR="\033[?25h"

supports_tput=true
command -v tput >/dev/null 2>&1 || supports_tput=false
cols=60
$supports_tput && cols=$(tput cols 2>/dev/null || echo 60)
[[ -z "$cols" || "$cols" -lt 40 ]] && cols=60
bar_width=$(( cols>70 ? 50 : 40 ))

cleanup() { printf "${SHOW_CURSOR}${RESET}\n"; }
trap cleanup EXIT

spinner() {
  local pid=$1 msg="$2"
  local spin='|/-\' i=0
  printf "${DIM}"
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r%s %s" "${spin:i++%4:1}" "$msg"
    sleep 0.12
  done
  printf "\r\033[K${RESET}"
}

draw_bar() {
  local percent=$1 width=$2
  (( percent<0 )) && percent=0
  (( percent>100 )) && percent=100
  local filled=$(( percent*width/100 ))
  local empty=$(( width-filled ))
  printf "["
  printf "%0.s█" $(seq 1 $filled)
  printf "%0.s░" $(seq 1 $empty)
  printf "] %3d%%" "$percent"
}

update_2line_ui() {
  local header="$1" percent="$2" tail="$3"
  if $supports_tput; then
    tput cuu 2 2>/dev/null || true
    tput el 2>/dev/null || true
    printf "%b\n" "$header"
    tput el 2>/dev/null || true
    draw_bar "$percent" "$bar_width"
    [[ -n "$tail" ]] && printf "  %s" "$tail"
    printf "\n"
  else
    printf "\r\033[K%b\n" "$header"
    draw_bar "$percent" "$bar_width"
    [[ -n "$tail" ]] && printf "  %s" "$tail"
    printf "\n"
  fi
}

# ---------- Banner ----------
clear
printf "${CYAN}=============================================${RESET}\n"
printf "${GREEN}${BOLD}         YT Pro Downloader v2.4${RESET}\n"
printf "${YELLOW}     Powered by yt-dlp + ffmpeg${RESET}\n"
printf "${CYAN}=============================================${RESET}\n\n"
printf "${HIDE_CURSOR}"

# ---------- Dependency Installation ----------
log_dir="${TMPDIR:-/tmp}/ytpro"
mkdir -p "$log_dir"

run_step() {
  local msg="$1"; shift
  local logfile="$log_dir/step_$(date +%s%N).log"
  ("$@" >"$logfile" 2>&1) &
  local cmd_pid=$!
  spinner "$cmd_pid" "${msg}…"
  wait "$cmd_pid"
  local rc=$?
  if (( rc != 0 )); then
    printf "${RED}✖ ${msg} failed.${RESET}\n"
    printf "${DIM}See log:${RESET} %s\n" "$logfile"
    tail -n 15 "$logfile" || true
    exit $rc
  else
    printf "${GREEN}✔ ${msg}${RESET}\n"
  fi
}

need_install=false
command -v yt-dlp >/dev/null 2>&1 || need_install=true
command -v ffmpeg >/dev/null 2>&1 || need_install=true

if $need_install; then
  printf "${YELLOW}Checking & installing dependencies…${RESET}\n"
  OS="$(uname -s)"
  if [[ "$OS" == "Linux" ]]; then
    if command -v apt >/dev/null 2>&1; then
      run_step "Refreshing apt" sudo apt update -y
      run_step "Installing yt-dlp & ffmpeg" sudo apt install -y yt-dlp ffmpeg
    elif command -v dnf >/dev/null 2>&1; then
      run_step "Installing yt-dlp & ffmpeg" sudo dnf install -y yt-dlp ffmpeg
    elif command -v pacman >/dev/null 2>&1; then
      run_step "Syncing pacman" sudo pacman -Sy --noconfirm
      run_step "Installing yt-dlp & ffmpeg" sudo pacman -S --noconfirm yt-dlp ffmpeg
    else
      printf "${RED}Unsupported Linux package manager.${RESET}\n"; exit 1
    fi
  elif [[ "$OS" == "Darwin" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      run_step "Installing Homebrew" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    run_step "Installing yt-dlp" brew install yt-dlp
    run_step "Installing ffmpeg" brew install ffmpeg
  elif [[ "$OS" =~ ^(MINGW|MSYS|CYGWIN) ]]; then
    if command -v winget >/dev/null 2>&1; then
      run_step "Installing yt-dlp" winget install --id=yt-dlp.yt-dlp -e --accept-package-agreements --accept-source-agreements
      run_step "Installing FFmpeg" winget install --id=Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
    else
      printf "${RED}winget not found.${RESET}\n"; exit 1
    fi
  else
    printf "${RED}Unsupported OS: %s${RESET}\n" "$OS"; exit 1
  fi
fi

printf "${GREEN}✅ All dependencies are installed.${RESET}\n\n"

# ---------- Mode Selection ----------
printf "${CYAN}${BOLD}Select download mode:${RESET}\n"
printf "  1) Single Video\n"; printf "  2) Playlist\n"
MODE=""
echo -n "Enter choice (1 or 2): "; IFS= read MODE

PLAYLIST_FLAG=""; RANGE_FLAG=""; VIDEO_URL=""; FIRST_ITEM=1; OUTPUT_TEMPLATE=""
if [[ "$MODE" == "1" ]]; then
  echo -n "🎯 Enter video URL: "; IFS= read VIDEO_URL
  PLAYLIST_FLAG="--no-playlist"
  OUTPUT_TEMPLATE="%(title)s.%(ext)s"
  printf "\n${YELLOW}📡 Fetching available formats…${RESET}\n"
  yt-dlp -F "$VIDEO_URL"
elif [[ "$MODE" == "2" ]]; then
  echo -n "📜 Enter playlist URL: "; IFS= read VIDEO_URL
  echo -n "🎯 Enter video range (1-5, blank=all): "; IFS= read RANGE
  if [[ -n "$RANGE" ]]; then
    RANGE_FLAG="--playlist-items $RANGE"
    FIRST_ITEM="${RANGE%%-*}"; [[ -z "$FIRST_ITEM" ]] && FIRST_ITEM=1
  fi
  PLAYLIST_FLAG="--yes-playlist"
  OUTPUT_TEMPLATE="%(playlist_title)s/%(playlist_index)02d - %(title)s.%(ext)s"
  printf "\n${YELLOW}📡 Fetching formats for playlist item %s…${RESET}\n" "$FIRST_ITEM"
  yt-dlp -F --playlist-items "$FIRST_ITEM" "$VIDEO_URL"
else
  printf "${RED}Invalid choice.${RESET}\n"; exit 1
fi

# ---------- Format Selection ----------
echo -n "🎥 Enter format code (blank=best): "; IFS= read FORMAT_CODE
if [[ -z "$FORMAT_CODE" ]]; then DL_FORMAT="bv*+ba"
else
  if yt-dlp -F --playlist-items "$FIRST_ITEM" "$VIDEO_URL" | awk '{print $1,$0}' | grep -E "^[[:space:]]*$FORMAT_CODE[[:space:]].*video[[:space:]]only" >/dev/null; then
    printf "${CYAN}🎧 Adding best audio…${RESET}\n"; DL_FORMAT="${FORMAT_CODE}+ba"
  else DL_FORMAT="$FORMAT_CODE"
  fi
fi

# ---------- Download with Live Progress ----------
download_list="$log_dir/downloaded_files.txt"; : > "$download_list"
printf "\n${GREEN}🚀 Starting download…${RESET}\n"; printf "%s\n%s\n" " " " "
stdbuf -oL yt-dlp -f "$DL_FORMAT" $PLAYLIST_FLAG $RANGE_FLAG -o "$OUTPUT_TEMPLATE" "$VIDEO_URL" \
  --newline --progress-template "%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(filename)s" \
  --print "before_dl:START|%(filename)s" \
  --print "after_move:FILE|%(filepath)s" \
| while IFS= read -r line; do
    case "$line" in
      START\|*) file="${line#START|}"; update_2line_ui "${CYAN}📥 Downloading:${RESET} ${MAGENTA}$(basename "$file")${RESET}" 0 "${YELLOW}Speed:${RESET} --  ${YELLOW}ETA:${RESET} --" ;;
      FILE\|*) printf "%s\n" "${line#FILE|}" >> "$download_list" ;;
      *\|*\|*\|*) percent="${line%%|*}"; rest="${line#*|}"; speed="${rest%%|*}"; rest="${rest#*|}"; eta="${rest%%|*}"; file="${rest#*|}"
        percent_int="${percent//[^0-9.]}"
        percent_int="${percent_int%.*}"; [[ -z "$percent_int" ]] && percent_int=0
        header="${CYAN}📥 Downloading:${RESET} ${MAGENTA}$(basename "$file")${RESET}"
        tail_text="${YELLOW}Speed:${RESET} ${speed:-N/A}  ${YELLOW}ETA:${RESET} ${eta:-N/A}"
        update_2line_ui "$header" "$percent_int" "$tail_text" ;;
    esac
done
printf "${GREEN}✅ Download(s) finished.${RESET}\n"

# ---------- Conversion ----------
echo -n "🔄 Convert file(s)? (y/n): "; IFS= read CONVERT
if [[ "$CONVERT" =~ ^[Yy]$ ]]; then
  echo -n "🎯 Enter output format: "; IFS= read OUTPUT_FORMAT
  [[ ! -s "$download_list" ]] && find . -maxdepth 3 -type f -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n 10 | awk '{ $1=""; sub(/^ /,""); print }' > "$download_list"
  while IFS= read -r in_file; do
    [[ -z "$in_file" || ! -f "$in_file" ]] && continue
    out_file="${in_file%.*}.$OUTPUT_FORMAT"
    duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$in_file" 2>/dev/null)"
    [[ -z "$duration" ]] && duration=0
    printf "\n${CYAN}Converting:${RESET} ${MAGENTA}$(basename "$in_file") → $(basename "$out_file")${RESET}\n"; printf "%s\n%s\n" " " " "
    stdbuf -oL ffmpeg -y -hide_banner -loglevel error -i "$in_file" "$out_file" -progress pipe:1 2>/dev/null \
      | while IFS='=' read -r key val; do
          case "$key" in
            out_time_ms)
              if [[ "$duration" != "0" ]]; then
                secs=$(( val / 1000000 )); int_dur=${duration%.*}; (( int_dur <= 0 )) && int_dur=1
                percent=$(( secs * 100 / int_dur ))
              else percent=0
              fi
              header="${CYAN}🔄 Converting:${RESET} ${MAGENTA}$(basename "$in_file") → $(basename "$out_file")${RESET}"
              update_2line_ui "$header" "$percent" ""
              ;;
            progress) [[ "$val" == "end" ]] && update_2line_ui "$header" 100 "" ;;
          esac
      done
    printf "${GREEN}✔ Converted:${RESET} %s\n" "$out_file"
  done < "$download_list"
else
  printf "${GREEN}✅ Download completed without conversion.${RESET}\n"
fi

printf "\n${CYAN}=============================================${RESET}\n"
printf "${GREEN}${BOLD}   🎉 Thank you for using YT Pro!${RESET}\n"
printf "${CYAN}=============================================${RESET}\n"