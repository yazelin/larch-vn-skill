# 自訂介面（Interface Skills）：標題畫面與對話框

Larch 專案設定裡的「Skills」分頁可以產生一份給 agent 的提示（`larch-title-designer`），
讓 agent 用一頁 HTML 取代內建的標題畫面或對話框。下面是那份提示的通用部分，
加上 2026-09-26 做《仙泉．香布纏》標題影片時實測到、提示裡沒寫的事。

那份提示本身會附上專案 id 與整份素材清單，每個專案不一樣，這裡不收；要做時到 Skills 面板重新產生。

## 存在哪裡、怎麼寫回

```jsonc
settings.customInterfaces = {
  title:    {enabled: true, html: "…"},   // 有值就取代內建標題畫面（titleScreen.layers 整個不用）
  dialogue: {enabled: true, html: "…"}    // 只套一般台詞與旁白；選項、輸入、小遊戲、存讀檔仍是 Larch 的
}
```

- MCP：先 `larch_get_project` 讀，再 `larch_update_interface`，參數 `projectId, surface, html, enabled: true, expectedHtml, summary`。
- REST：`GET /api/agent/projects/<id>`，然後 `PUT /api/agent/projects/<id>/interface`，
  body `{"surface":"title","html":"…","enabled":true,"expectedHtml":"剛讀到的 html，沒有就空字串","summary":"…"}`。
- `expectedHtml` 是樂觀鎖，409 表示有人改過，重讀再整合。**不要為了改介面去 PUT 整份專案。**
- 伺服器覆寫前會留完整專案的復原副本。寫完重新 GET 核對。
- 跟改版子一樣，**作者的編輯器分頁開著會把舊版存回去**，寫之前請作者關分頁，發佈前硬重新整理。

## 介面契約

HTML 在 `sandbox="allow-scripts" allow="autoplay"` 的 srcdoc iframe 裡跑，只能用行內腳本，
碰不到父頁、帳號、網路 API、外部腳本或其他 iframe。不要依賴 CDN。上限 200000 字元，不要塞 base64。

| 屬性 | 作用 |
|---|---|
| `data-larch-slot="title\|description\|speaker\|text"` | 播放器以純文字即時填入，不要寫死台詞 |
| `img[data-larch-slot="cover"]` | 自動填封面（`titleCoverImage`，沒設就用開始卡的背景） |
| `button[data-larch-action="start"]` | 標題**必須有**。另有 `continue`、`chapters`、`gallery`，播放器會自己設 `disabled`／`hidden` |
| `data-larch-slot="text"` + `button[data-larch-action="advance"]` | 對話框必須有；點非控制區也會繼續；字級用 `var(--larch-text-size, 22px)` |
| `<img data-larch-asset="素材id">`、`<audio …>`、`<video …>` | 播放器填 `src`；Web 匯出時會跟著專案素材打包 |
| `<div data-larch-background="素材id">` | 填 CSS 背景圖 |

素材 id 的格式：`title-cover`、`title-bgm`、`media:<媒體庫 id>`。

每次狀態變動，iframe 會收到 `larch:state` 事件，`event.detail` 有 `title, description, speaker, text,
textSize, active, muted, assets`；`assets` 只含 HTML 裡用 `data-larch-asset`／`data-larch-background` 引用到的 id 與網址。

其他要求：相對尺寸加手機 media query；照顧 hover、focus-visible、active、disabled；
文字對比 4.5:1、控制項 3:1；支援 `prefers-reduced-motion`。
背景音樂沿用標題畫面的 BGM 設定，不要在 HTML 裡再放一份。

## 實測：標題背景影片（2026-09-26）

**一、傳到 Larch 的影片都進 Cloudflare Stream，介面用不了。**
agent `POST /media`（`mimeType: video/mp4`，`category: video`）和網頁媒體庫上傳都試過，
存下來的 `url` 都是 `https://customer-….cloudflarestream.com/<uid>/iframe`：一個播放頁，不是檔案，也沒有 `videoFileUrl`。
播放器組 `assets` 時會跳過「`type: video`、沒有 `videoFileUrl`、網址也不是 `.mp4/.webm/.ogg`」的素材，
所以 `<video data-larch-asset="media:…">` 拿不到 `src`。Stream 的 `downloads/default.mp4` 回 404（沒開下載），
HLS 在 iframe 裡又不能載外部腳本，也走不通。
（前端 bundle 裡網頁上傳會讀 `metadata.r2_url` 當 `videoFileUrl`，但實測那筆沒有，不要照程式碼推論。）

**解法：做成動態 AVIF，當圖片上傳。** 圖片走 R2，`<img data-larch-asset="media:…">` 拿得到網址，Web 匯出也會打包。
8.5 秒 1280×720 24fps，`libsvtav1 -crf 38` 只有 1.6 MB（同一段做成動態 WebP 要 10 MB），跟原片的 SSIM 0.98；
avif muxer 預設 `-loop 0` 無限循環。Chrome、Firefox、Safari 16.4 以上都會播。

```bash
ffmpeg -i loop.mp4 -vf "fps=24,format=yuv420p" -c:v libsvtav1 -crf 38 -preset 6 -an -f avif loop.avif
```

**二、真的有檔案網址的話，背景影片自動播放可以。** iframe 有 `allow="autoplay"`，`muted autoplay loop playsinline` 會自己播（本機用 mp4 驗過）。
播放器每次套狀態都會把 `audio`、`video` 設成 `muted = state.muted !== false`，`active === false` 時暫停。
影片不要帶聲音，聲音交給標題 BGM。

**三、做成循環要處理接縫。** AI 動起來的短片頭尾通常對不上（實測頭尾兩格 SSIM 0.70，一看就跳）。
把最後 1.5 秒交叉淡入開頭，片長變成 `原長 − 1.5` 秒，頭尾就接得起來：

```bash
ffmpeg -i in.mp4 -i in.mp4 -filter_complex \
 "[0:v]trim=start=1.5:end=<原長>,setpts=PTS-STARTPTS,fps=24,format=yuv420p[a];\
  [1:v]trim=start=0:end=1.5,setpts=PTS-STARTPTS,fps=24,format=yuv420p[b];\
  [a][b]xfade=transition=fade:duration=1.5:offset=<原長-3>[v]" \
 -map "[v]" -an -c:v libx264 -crf 23 -preset slow -pix_fmt yuv420p -movflags +faststart loop.mp4
```

**四、動態圖載入前先顯示封面圖。** `img[data-larch-slot="cover"]` 墊底，動態圖 `load`（影片是 `playing`）之後再淡入；
`prefers-reduced-motion` 時不放影片，只留封面圖。

**五、自訂標題會取代內建標題的全部圖層。** 原本 `titleScreen.layers` 裡的文字、按鈕都不會出現，
書名、開始、繼續要自己在 HTML 裡放。標題 BGM（`titleScreen.bgm`）照舊。

## 一條龍：從封面圖到標題動畫（2026-09-26 做過兩部）

**一、叫影片模型把封面動起來。** 鏡頭固定、只動本來會動的元素、結尾回到接近開頭的姿勢，頭尾才接得起來，標題字也不會被構圖變動擋到。換作品只改「Subtle motion only」那一段：

```
Animate this illustration as a calm, seamless looping cinemagraph. Keep the camera completely static and the composition, framing, character design, face, and art style exactly as in the original image. No zoom, no pan, no new objects, no text.

Subtle motion only:
- <人物：站著不動、慢慢呼吸、眨一次眼、飄帶／髮絲隨風>
- <環境：水霧、漣漪、花瓣、燭火、香煙、光裡的浮塵、布簾……>

<背景裡的畫像、剪影要寫明 stay still，免得模型把它們變成會走的人。>
The motion at the end should return close to the starting pose so the clip can loop.
```

**二、檢查浮水印。** 實測這類工具產的片右下角會帶一個四角星形的小標記，標題畫面滿版時看得到，交給作者決定怎麼處理。

**三、一行做成循環 AVIF。** `make_title_loop.sh 原片.mp4 輸出.avif [淡入秒數=1.5] [crf=38]`：讀片長、最後 N 秒淡入開頭、去聲音、轉 AVIF，印出大小與兩個 SSIM。
實測兩支 10 秒 720p：1.6 MB／1.0 MB；接縫 SSIM 0.83／0.96（相鄰兩格的對照值 0.90／0.98，接縫值接近對照值就看不出來）；畫質 SSIM 0.98。

**四、上傳與寫回。** AVIF 用 `POST /media`（`mimeType: image/avif`、`category: scene`）上傳，拿回 `media:<id>`；
HTML 從 `title-template.html` 改，換掉 `LOOP_ID`，用 `PUT /interface` 寫回（見上面「存在哪裡、怎麼寫回」）。寫之前請作者關編輯器分頁。

## 實測：字型、連結與分享連結快照（2026-10-30，《格莉奇日記》）

**一、播放器會把專案字型強制套到自訂介面。** iframe 根元素帶行內樣式 `--larch-project-font:"Noto Serif TC",…`，
另有一條看不到的樣式 `.larch-project-font body, .larch-project-font body * { font-family: var(--larch-project-font) !important }`，
自己寫 `.box * {font-family:… !important}` 會輸（對方選擇器較具體）。要換字型就覆寫變數本身：
`html{--larch-project-font:"Noto Sans TC",…,sans-serif!important}`（樣式表的 !important 贏過行內的非 important）。
CSP 允許 `style-src https:`、`font-src https:`，可以 `@import` Google Fonts。

**二、介面 iframe 的 sandbox 只有 `allow-scripts`。** `<a target="_blank">` 點了不會開新分頁，也不能導覽上層頁面；
miniGame 卡的 iframe 也一樣。不要在介面或小遊戲裡放外部連結按鈕，網址改放專案介紹或市集頁。外部圖片可以載（`img-src https:`）。

要放能點的外部連結，用舞台道具（或角色、影片）的 `clickAction: {kind:"link", linkUrl, label, showLabel:false}`，
由播放器自己 `window.open`，不受框的限制（2026-10-30 分享連結實測：開新分頁，點了不會換下一句）。幾個實測細節：
道具的 `x`、`y` 是百分比，對的是圖的中心；能點的只有 `.stage-prop-inner` 那層圖；圖的像素大小不隨畫面縮放
（1600 寬與 844 寬都是同樣大），手機上位置會偏；**畫面最上方約 35px 不要放**，滑鼠一動播放器的上方控制列就出來，
把點擊吃掉。對話卡每一句的 `stage` 都要帶同一個道具，不然換句就消失。
**左上角也不行**：滑鼠一移過去，播放器左上角會浮出白板名稱標籤（`.vn2-board-badge`，例如「2026 年 10 月」），
蓋在背景圖上方，也吃掉點擊，沒有設定可以關。所以背景圖上畫在左上角的字，不能拿來當透明點擊區（2026-10-30 實測）。
**道具的圖不隨畫面縮放**：1920 寬看起來太小、1280 寬超出、手機上壓到內文，要對齊背景圖上的元素做不到；
《格莉奇日記》最後決定日記頁不放外連結。

**三、分享連結（`/play/<token>`）讀的是刷新當下的快照。** 改完介面要再刷新一次分享連結（`POST …/share-link`），玩家才看得到；
用分享連結驗收前先確認刷新過。
