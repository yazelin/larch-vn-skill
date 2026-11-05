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
- **現在的介面只能從 `GET /projects/<id>` 讀**（`project.settings.customInterfaces`）。`GET /projects/<id>/settings` 不帶這個欄位（2026-11-03 實測），從那裡讀會拿到空字串，送出去的 `expectedHtml` 對不上，每次都回 409「介面已更新，請重新讀取後整合修改」，看起來像有人改過，其實沒有。
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

## 實測：手帳質感的介面（2026-11-03，《優理的圖文日記》）

- **對話框的框是照內容長高、從底部往上長的。** 外層 `.vn2-box` 有最大高度、`overflow:auto`。
  在介面裡寫 `html,body{height:100%}` 想把框貼到最底下，會把 iframe 撐到上限，外層冒出捲軸。
  要讓對話框不擋畫面，就讓框本身變矮或變窄（例如只佔左邊 64%，右邊留給立繪），不要撐高。
- **質感用生圖做，CSS 只負責排版。** 書封、紙條這類圖叫生圖服務在洋紅底上畫，去背後：
  固定比例的（書封）用 `<img>` 墊底、字用百分比位置排進空白處，字級用 `container-type` 配 `cqw`／`cqh` 跟著書縮放；
  會被拉長的（對話框紙條）用 `border-image: url(…) 上 右 下 左 fill / 寬度 stretch` 切九格，書背、撕邊、紙膠帶不會變形。
- **背景就是內容的作品，`stageFit` 要用 `contain`。** `auto` 與預設在直式手機上都會把 16:9 背景裁成直的，
  日記頁的四格漫畫被切掉一半，立繪還疊在上面。`contain` 會顯示整張，手機上再把對話框的字縮小，就不會蓋到頁面。
- **本機預覽要看還沒推上去的介面素材**，把 HTML 裡的 Pages 網址換成 `/files/…`：
  介面 iframe 是 srcdoc，相對網址照外層頁面解析，larch-preview 的 `/files/` 對到專案 JSON 所在的資料夾。

## 實測：選項、選單、收藏三個 CSS 部位（2026-11-04，《還沒送到的信》）

- **部位 CSS 裡只要有一行 `@import`，整個部位會被播放器丟掉**，畫面退回內建樣式，不報錯。所以這三個部位換不了字型，只能沿用播放器自己的 Noto Serif；要換字型的只有標題與對話框（它們是 iframe，可以 `@import` Google Fonts）。
- 第一行要是 `/* @larch-params … */` 那段註解；在它前面插東西也一樣不被認。
- `PUT /projects/<id>/interface` 這次**收了 gallery**（十月《雨幕》時不收），讀回一致。
- 部位 CSS 裡的 `url()` 用 Larch R2 網址的圖可以載（信封選項實測）。

## 專案字型（2026-11-04《還沒送到的信》實測，Larch 98c3feb5）

- 欄位在 `settings.dialogueUi` 裡：`fontFamily: "custom"`、`customFontUrl`、`customFontName`。寫在 `settings` 頂層播放器不讀。
- agent 的 `PATCH /projects/<id>/settings`（MCP `larch_project_settings`）不收這幾項，回 400。只能整份 `PUT /projects/<id>`：先 GET 存備份，照抄全專案只改 dialogueUi，帶 `If-Match: <_etag>`，寫完逐欄比對備份（media、characters、boards 都要一樣）。或請作者在對話編輯器右上「字體」選單上傳。
- 字型檔用 `POST /projects/<id>/media` 傳上 R2 就好。播放器會改走 `larch.ink/api/media/proxy` 載入，並在介面部位裡提供 `var(--larch-project-font)`。
- 不要在 title／dialogue 的 HTML 裡自己寫 `@font-face` 指向 R2：部位跑在 sandbox iframe，R2 沒有 CORS 標頭，字型會被擋（`document.fonts` 顯示 error）。CSS 部位的外部 `url()` 也會被擋。
- 設完要 refresh share link，分享連結才換新版。

## 背包（inventory）紙上的字色（Larch 技術支援 Obelisk 回覆，2026-11-04，版本 4b14ca2b）

背包裡的字只從 `--inventory-text` 與 `--inventory-accent` 兩個變數算，沒有給道具卡或說明欄分開用的變數：
說明欄的效果列是 `--inventory-text` 混 68% 透明，沒選中的 `item-keep` 小盾牌是 38%，持有數量和效果列的小圖示直接用 `--inventory-accent`。
所以外框改深色、紙改淺色之後，紙上的這些字會跟著變淺，幾乎看不到。跟 html 的 `data-theme`（亮色／暗色）無關。

官方建議兩個混用：外框的 `--inventory-surface`、`--inventory-text` 照樣在 `:scope` 設變數（要加 `!important` 才蓋得過背包設定）；
紙上的字直接寫在 hook 上，例如 `[data-larch-ui="detail-effects"] li`、`[data-larch-ui="item-keep"]`、`[data-larch-ui="detail-count"]`，
hook 不用 `!important`（系統會把介面 Skills 的選擇器權重墊高）。可以在 `:scope` 自己定一個 `--paper-ink` 給這幾個 hook 共用。
實例：glitch-vn `larch/ui/inv/inventory.css`。


## 標題畫面的字型會被專案字型蓋掉（2026-11-05《卯時》實測）

- 播放器在標題框裡注入一段樣式，其中有 `.larch-project-font body, .larch-project-font body * { font-family: var(--larch-project-font) !important }`。專案有設字型時，自訂標題裡每個元素的 `font-family` 都被蓋掉，連內嵌的 `@font-face` 也用不上（`document.fonts` 顯示已登記、從沒載入）。
- 要保留特定字型，選擇器權重要比它高、再加 `!important`，例如 `.larch-project-font body .masthead { font-family: "Bodoni Moda", serif !important; }`。
- Google Fonts 的 `@import` 在標題框裡沒有作用；拉丁展示字可以用 `fonts.googleapis.com/css2?...&text=<用到的字>` 抓子集，base64 內嵌成 `@font-face`（兩個字重約 35KB）。
- 圖片用 `<img data-larch-asset="media:<id>">` 引用媒體庫，五張輪播都載得到；`titleCoverImage` 另外設一張當退路。

## 收藏頁（gallery 部位）的標題列與 Esc（2026-11-05《卯時》實測）

- 收藏頁的 `[data-larch-ui="screen-header"]` 自己有一層深色底（`rgba(17,18,22,.86)`），只改 `:scope` 的背景不會換到它；淺色主題要另外蓋 `background`，不然深字壓在深底上看不見。
- 標題列裡是 `<small>COLLECTION</small><h1>CG 收藏</h1><p>N 個場景與回憶</p>`，文字沒有設定可改。要換名字可以 `font-size:0` 再用 `::after { content: "封面收藏" }` 補上。
- 標題的 `button[data-larch-action="gallery"]` 在 `cgGalleryEnabled` 開著、`cgGallerySource: "picked"` 有圖時才可按。
- `playerCloseButton: {mode:"hidden"}` 時 Esc 等於「離開遊戲」；預覽連結離開後會停在播放器內建的深色結束畫面，上面印的是**專案簡介**（`description`），所以簡介要保持是給玩家看的版本。

## 重新上架時沒帶介紹與封面會被換掉（2026-11-05《卯時》實測）

- `larch_publish_game`／`POST /publish` 沒帶 `description` 時，市集介紹會換成當下的**專案簡介**；《卯時》1.2、1.3 兩次只帶 `version`＋`updateNote`，市集介紹就退回最早的專案簡介，封面也退回標題底圖（`titleCoverImage`）。
- 做法：專案簡介和市集介紹用同一份文字（專案簡介上限約 1200 字，結束畫面也會顯示它，所以連結寫純網址、不要用 Markdown 連結），每次上架都帶 `description` 與 `coverUrl`。只改介紹或封面、不推新版本時用 `larch_update_listing`。
