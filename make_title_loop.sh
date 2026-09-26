#!/usr/bin/env bash
# 把一支短片做成 Larch 標題畫面用的無接縫循環動態 AVIF（說明見 interface-skills.md）。
# 用法：make_title_loop.sh 原片.mp4 輸出.avif [淡入秒數=1.5] [crf=38]
# 最後 N 秒淡入開頭，片長變成「原長 − N」；去掉聲音；印出檔案大小、接縫 SSIM、跟原片比的畫質 SSIM。
set -euo pipefail
in=$1; out=$2; fade=${3:-1.5}; crf=${4:-38}
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
off=$(awk -v d="$dur" -v f="$fade" 'BEGIN{printf "%.3f", d-2*f}')
awk -v o="$off" 'BEGIN{exit !(o>0)}' || { echo "片長 ${dur}s 太短，至少要 2×${fade}s" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

ffmpeg -v error -y -i "$in" -i "$in" -filter_complex \
  "[0:v]trim=start=$fade:end=$dur,setpts=PTS-STARTPTS,fps=24,format=yuv420p[a];\
   [1:v]trim=start=0:end=$fade,setpts=PTS-STARTPTS,fps=24,format=yuv420p[b];\
   [a][b]xfade=transition=fade:duration=$fade:offset=$off[v]" \
  -map "[v]" -an -c:v libx264 -crf 18 -pix_fmt yuv420p "$tmp/loop.mp4"
SVT_LOG=1 ffmpeg -v error -y -i "$tmp/loop.mp4" -vf "fps=24,format=yuv420p" -c:v libsvtav1 -crf "$crf" -preset 6 -an -f avif "$out"

ssim() { ffmpeg -hide_banner -i "$1" -i "$2" -lavfi "[0:v]format=yuv420p[x];[1:v]format=yuv420p[y];[x][y]ssim" -f null - 2>&1 | grep -o 'All:[0-9.]*' | cut -d: -f2; }
ffmpeg -v error -y -i "$tmp/loop.mp4" -frames:v 2 "$tmp/f%d.png"
ffmpeg -v error -y -sseof -0.05 -i "$tmp/loop.mp4" -frames:v 1 "$tmp/last.png"
echo "輸出：$out  $(du -h "$out" | cut -f1)  片長 $(awk -v d="$dur" -v f="$fade" 'BEGIN{printf "%.2f", d-f}')s"
echo "接縫 SSIM（最後一格→第一格）：$(ssim "$tmp/last.png" "$tmp/f1.png")　對照：相鄰兩格 $(ssim "$tmp/f1.png" "$tmp/f2.png")"
echo "畫質 SSIM（AVIF 對循環原片）：$(ssim "$out" "$tmp/loop.mp4")"
