# 舊作重寫成 RPG 版：流程與踩過的坑

2026-10 把三部第二屆挑戰的舊作（《晚霞是舌尖最後的刺痛》、《淡藍與草木灰綠的雨幕》、《最終遺忘的橘色餘燼》）重寫時整理的。
範本程式在 `yazelin/larch-sunset` 與 `yazelin/larch-rain`（`src/build.py`、`src/push.py`、`src/push_ui.py`、`ui/night.py`、`tests/`），開新的一部直接複製其中一個改。

## 0. 先抓原版、先寫設計，作者拍板才動手

1. `larch_get_project` 存一份 `snapshots/YYYYMMDD-original.json`，原版只當骨架（`skeleton/project.json`）。
2. 把全劇文字倒成一份純文字讀完，列出原版的矛盾、時空錯置、說明多於演出的地方。
3. 寫 `design/重寫.md`：故事核心哪些不能動（問作者）、角色各自的心境、時間線、玩家在地圖上「做」什麼讓情緒被感受到、兩個結局、作者決定與我的決定分開列。作者說「定稿」才開工。

## 1. 專案用 Python 組，不手改白板

- `build.py` 從骨架組出 `dist/project.json`：角色、變數、RPG 資料庫、地圖卡、劇情卡、連線。台詞集中在一個 dict（`script.py`／`memory.py`），配音、建置、測試都讀同一份。
- 建置裡放斷言：一格一個事件、選擇題不能是事件的第一個動作、卡數與連線數。
- 地圖動作一定要留 `text` 欄位（刪掉會「地圖資料無法讀取」）；`card()` 後面接 `jump()` 會吞掉那張卡，改直接跳到不同的卡。
- 主角行走圖一律用資料庫的「目前主角」，要換造型就在資料庫加一個角色，進地圖第一個動作 `A('hero', value=id)`，離開再切回。
- 接在 CG 後面的卡片也要給背景，不然 CG 留在畫面上、立繪疊在 CG 裡的人身上。
- 結局最後一張開 `data.stayOnCard = True`（編輯器的「無下一張時停留在此卡片」），不然播完自己跳走。
- CG 收藏：`cgGalleryEnabled: true`、`cgGalleryItems` 除封面外加 `locked: true`，在每張 CG 第一次出現的卡片放 `data.cgOps = [{id, mode: 'unlock', url}]`，不然一開遊戲兩個結局就被劇透。

## 2. 美術順序：定錨 → 行走圖 → 立繪 → CG → 地圖

- 畫圖走 .11 codex-image（或本機 codex），不用 Gemini。
- 立繪用**半身、電影感光線、有表演的姿勢**，拿已經滿意的 CG 當風格參考；全身＋平光＋站樁會被嫌「像 Gemini 畫的」。每人產 4 張讓作者挑。
- CG 帶「立繪＋全身定錨」當參考重產，不疊修。
- 地圖分層：地面（不含物件）＋物件各自一張；物件輸出 128 px/格以上，地面保持原解析度，縮到 48 px 會糊。

## 3. 配音：橋接服務 larch-tts-bridge

- 唸錯的字交給橋接服務的**替身表**（管理台或 `GET/PUT /subs`），本機不要再自己換字：本機先換掉，替身表就永遠套不到（雨幕的「許帆」被本機換成「許翻」，作者設的「許煩」一直沒生效）。
- 重配用 `force: true` 繞過快取；只重配某些句子用 `ONLY=詞1,詞2 FORCE=1`。並行最多 3 線（帳號會被凍結）。
- 地圖上林宇自言自語的句子在建置時轉成有配音的卡片。

## 4. 素材走 jsDelivr，用 commit 編號

- `push.py` 把 `/files/assets/…` 換成 `https://cdn.jsdelivr.net/gh/<user>/<repo>@<commit SHA>/…`，每個網址 HEAD 驗過才推。新 tag 一開始會 404，用 commit SHA。
- **例外：介面 Skill 裡的網址只收 Larch R2／larch.ink**，jsDelivr 會被靜默擋掉（音效無聲、標題 BGM 退回專案設定）。介面用的音檔先 `larch_upload_media` 拿 R2 網址。
- 圖先轉 webp 縮小再 commit。

## 5. 推送：快照、只覆蓋白名單設定、讀回對卡數

- `push.py`：先存線上快照 → 建置 → 換 CDN → PUT → 讀回比對卡數、連線、沒有本機路徑。設定用 merge：沿用線上，只覆蓋自己管的欄位（新加的設定欄位要記得加進白名單，例如 `cgGalleryEnabled`）。
- 推之前請作者關掉編輯器分頁，不然會把版子打回舊版。

## 6. 介面：拿官方 Skill 轉色，不從零寫

- 作者先在編輯器套一套接近的官方介面（雨幕用「晨霧玻璃」），讀回 `settings.customInterfaces` 存成 `ui/<原名>-original/`。
- `ui/night.py` 依 CSS 屬性分類換色（字色與底色各一張表），再補作品專屬的覆寫：藏掉沒用的戰鬥欄位（HP、攻防魔、`.pm-party-member:disabled`）、對話框留白、選項選中改貼邊亮框、地圖標籤 hover 不能動 transform。
- 寫回：`push_ui.py` 從 Python 打 `larch.ink/mcp` 的 `larch_update_interface`（帶 expectedHtml）；**gallery 部位工具不收**，用 `ui/pack.py` 把七個部位包成一檔（每段首行 `/* larch-skill-part: gallery */`），作者在編輯器「匯入 HTML」一次。
- 介面 BGM／音效一律用自己產的，不用內建素材包的曲子。

## 7. 試玩：16 倍、兩結局並行，改完最後一次都要重跑

- `tests/play_full.mjs` 照真人玩完整部（地圖點任務、讀每句、選項依 CHOICES 表），驗必出現的台詞與結局；`END=b` 走第二結局；`LIVE=<預覽網址>` 跑 Larch 本站。
- `SPEED=16`：`tests/lib.mjs` 注入計時器、時鐘、動畫、音訊加速，兩結局並行約 1 分鐘（原速 20 多分鐘）。結局判斷要看累積讀到的文字（最後一句只閃一下）。截圖會有淡出殘影，畫面驗收用原速截。
- 另外三支：`hover_check.mjs`（地圖標籤 hover 位移，線上舊版要先抓得到 30px 跳位當負控制）、`gallery_check.mjs`（新開遊戲鎖幾張、看過一張後少一張）、`ui_shots.mjs`（標題、對話、地圖、暫停選單、背包截圖）。

## 8. 上架：先備份市集資料，一定帶簡介

- 上架前 `curl https://larch.ink/api/marketplace/<market id>` 存一份（description、screenshots、customSlug）。
- `larch_publish_game` **沒帶 description 會換成專案的 project.description**，不會沿用上一版；**作品網址 customSlug 工具設不了，上架後會不見**，只能作者從網頁表單重設。（2026-10-30 另有新的「作品網站」`site`（`<handle>-<名稱>.larch.games`），也只能網頁設，但用工具重新上架**不會**掉，實測過。）預覽圖不會動。
- 只改商店資訊用 `larch_update_listing`（不發版、不通知追蹤者）。
- 更新說明要寫（version＋updateNote），文字過 speak-tw。作者玩過說可以才上架。

## 開工前必讀（2026-10-19 餘燼被作者退貨後補）

動任何一個階段之前，先讀對應的既有紀錄，再去看已上線作品的成品當標準，不憑印象做。餘燼就是因為沒做這件事，地圖歪歪扭扭、劇本滿是 AI 句。

- **地圖**：先讀 [rpg-map-playbook.md](rpg-map-playbook.md)（與記憶 `feedback_rpg_map_layered_design`）。順序固定：設計檔（有座標、每物件佔幾格往上幾格）→ 單色塊在遊戲裡驗證 → **作者確認** → 才產圖。沒有作者確認的色塊圖，不准生任何物件。標準成品看 `~/larch-eleven-minutes/art/check/blocks-office-plan.png` 與 `layer-office-*.jpg`；地面用色塊圖當精確構圖生成（`~/larch-start-line/art/prompts.md`）。物件一律正面、同視角、對齊格線；牆與門整排一次生成再切。
- **劇本**：台詞用 [improv-playbook.md](improv-playbook.md) 的即興法（演員隔離、導演單、編劇挑句、以舊稿為骨）。審稿不能只審結構。要另外請讀者模型專審「哪句像 AI、哪裡看不懂、情感哪裡太快」，並用作者已抓到的句子當召回對照；句子由 codex 寫，不由我寫。
- **配音**：選聲音要逐個試聽、同角色同句比較，不能只看清單名稱；沒耳朵就不要宣稱「配音完成」。
- **驗收**：從第一句玩到最後再說「完整」。檔案齊、地圖載得進去只是能玩，不是好。
