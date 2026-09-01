---
name: larch-vn
description: 在 Larch 平台做視覺小說。要建專案、上素材、建角色與表情、排場景與立繪演出、設標題畫面的時候用。內含平台實際欄位與踩過的坑，avoid 從零猜。
---

# Larch 視覺小說

平台在 `https://larch.ink`（2026-08 從 larch.yapiflow.com 搬過來，舊網域回 308 導向：GET 跟得過去，**POST／PUT 不行**，urllib 不跟 308），agent REST 在 `/api/agent/projects/…`，
金鑰放 `~/.config/larch/key`（chmod 600，**絕對不要寫進專案、卡片、匯出檔或 repo**）。

底下所有欄位與可用值都是**從平台前端 bundle 與市集上已發佈的四個作品實測出來的**，
不是猜的。

**端點清單要以官方那份為準。** 作者在 larch.ink 的「帳號設定 → AI 輔助 → 產生並複製完整
Larch Skill」按一次，會拿到一份含全部 MCP 工具與 REST 路徑的操作說明（那份會**內嵌一把
Agent Key**，所以它是機密，不要貼進對話、repo 或卡片）。這份 skill 補的是那份沒寫的東西：
欄位實際長什麼樣、哪幾支會靜默寫壞資料、演出的數字要抓多少。

REST 全表（2026-09-01 對過）：

    GET  /api/agent/resolve/:id
    GET|POST                /api/agent/projects
    GET|PUT                 /api/agent/projects/:id
    GET                     /api/agent/projects/:id/boards
    GET|PUT|DELETE          /api/agent/projects/:id/boards/:boardId
    POST|DELETE             /api/agent/projects/:id/nodes
    POST                    /api/agent/projects/:id/story/generate
    POST                    /api/agent/projects/:id/images/generate
    POST|PUT|DELETE         /api/agent/projects/:id/media
    GET|POST                /api/agent/projects/:id/characters
    DELETE                  /api/agent/projects/:id/characters/:characterId
    POST                    /api/agent/projects/:id/characters/:characterId/art
    POST                    /api/agent/projects/:id/voice/generate
    GET                     /api/agent/voices
    GET                     /api/agent/projects/:id/versions
    POST                    /api/agent/projects/:id/versions/:versionId/restore
    GET                     /api/agent/projects/:id/export
    GET                     /api/agent/projects/:id/preview
    POST|DELETE             /api/agent/projects/:id/publish
    POST                    /api/agent/projects/:id/share-link
    GET|PUT|DELETE          /api/agent/asset-packs/:packId

金鑰的權限是分項的（讀取／編輯／素材／AI 生成／匯出／版本／預覽／發佈），
在同一頁勾。**403 說少了某個 scope 是設定問題，不是 bug**，請作者去開那個開關，不要繞路。

## 先做這件事：去讀別人的專案

```bash
curl -s "https://larch.ink/api/marketplace/<發佈id>?play=1" -o mk.json
```

**不用登入**，回的是完整專案 JSON。市集網址長這樣：
`https://larch.ink/play/market/<發佈id>`。

這是目前最有用的資料來源。要做什麼演出、不確定欄位怎麼填，就去撈一份人家的來看。

## 卡片

外層 `{id, type:"story", position:{x,y}, data:{…}}`，**真正的型別在 `data.type`**。
官方列的全部型別：`dialogue`／`choice`／`event`／`scene`／`input`／`aiDialogue`／`aiStory`／
`miniGame`／`setVariable`／`boardJump`／`group`，另外還有作者裝的 `plugin` 卡。

### 對話卡

```jsonc
{"type":"dialogue", "title":"…", "speaker":"格莉奇", "characterId":"character-…",
 "text":"第一句", "emotion":"開心",
 "dialogueLines":[{"id":"l0","speaker":"A","text":"…","emotion":"…"}, …],
 "stage":{"actors":[…]}, "characterLayers":[…],
 "transition":"fade", "transitionMs":320,
 "background":"…", "bgm":"…", "visualEffect":"rain"}
```

- **`dialogueLines` 一張卡裝一整段來回對話。** 沒有它，兩個人鬥嘴就變成點十次滑鼠。
- **`transition` 是掛在對話卡上的**，不是只有場景卡。`background` 與 `bgm` 也可以。
- 播放器的取值是 `dialogueLines?.length ? dialogueLines : [{speaker, text, emotion}]`。

### 舞台 `stage.actors[]`

```jsonc
{"id":"…", "url":"<立繪圖>", "name":"格莉奇", "slot":"center",
 "scale":0.96, "offsetX":0, "offsetY":0,
 "enter":"fade", "loop":"breathe", "loopSpeed":1, "loopStrength":1}
```

| 欄位 | 可用值（實測） |
|---|---|
| `slot` | `farLeft` `left` `center` `right` `farRight` |
| `enter` | `fade` `zoom` `spring` `bounce` `blur` `glide` `riseUp` `swoopIn` `walkInLeft` `arcLeft` `arcRight` `slideLeft` `slideRight` `slideDown` |
| `loop` | `breathe` `nod` `sway` `shiver` `hop` `pulse` `none` |
| `scale` | 實際作品都在 **0.90–1.04** |
| `offsetX` / `offsetY` | 實際作品都在 **±11 / ±9**。**單位不是像素** |

**`loop` 不填的立繪就是一張不會動的貼圖。** 別人的作品幾乎每個角色都掛 `breathe`。

**要把小圖（頭像那種）擺在角落，不要靠 offset。** 那兩個的單位是小數，填 300 會直接推出畫面。
做法是**把定位做進圖裡**：開一張跟立繪同尺寸的透明畫布，小圖擺在要的位置，
然後 `scale:1, offset:0`。

`characterLayers`（舊欄位，`{position,x,y,scale,opacity,flipX}`）編輯器某些地方還在讀，
兩個都寫最安全。**不要用 `flipX`**：不對稱的記號（單邊耳飾、胸前徽章）會鏡射到另一邊。

### 立繪只在卡片邊界換，而且不會自己清掉

一張卡從頭到尾只有一套 `stage.actors`。所以「講到第五句她才把披風換上」這種演出，
**要在那一句把卡片切成兩張**，不是在同一張卡裡想辦法。寫劇本的時候就要照換裝的時機切卡。

**下一張卡沒有給舞台的話，前一張的立繪會留著。** 事件 CG（整張圖就是演出的那種）
一定要明確給 `stage: {"actors": []}` 加上 `characterLayers: []`，否則人物會站在圖前面擋住它。
2026-09-01 實測：溫泉那張三人 CG 被前一張的三個立繪蓋掉，補上空舞台才正常。

### 場景卡

```jsonc
{"type":"scene", "title":"…", "text":"…", "background":"…",
 "transition":"fadeBlack", "transitionMs":600,
 "visualEffect":"snow", "bgm":"…", "bgmVolume":0.22, "bgmLoop":true, "start":true}
```

`transition`：`fade` `wipeLeft` `wipeRight` `blurCut` `flash` `irisIn` `fadeBlack` `none`（一般 260–420ms）
`visualEffect`：`rain` `snow` `embers` `flash` `stars3d` `petals` `vignette` `speedLines` `fog` `shake` `none`

### 旁白

**旁白要做成一個角色**（沒有 `portraitUrl` 的角色，`role` 填「旁白」），
卡片照樣帶 `speaker:"旁白"` 與 `characterId`。

`speaker` 留空字串是沒驗過的狀態，編輯器裡看起來像沒填完。

## 素材

```jsonc
POST /media  {"name":"x.png", "mimeType":"image/png", "base64":"…", "category":"character"}
```

**`category` 一定要帶**：`scene` 場景／`character` 立繪／`prop` 道具。
不帶的話全部掉進「道具」，角色工坊也不會認。回 `{asset:{id,name,type,url,category}}`，
上限 50MB。道具＝可以獨立擺上場的圖（頭像、物件）。

## 角色

```jsonc
POST /characters  {"characterId":"character-…",   // 更新要用這個
                   "name","role","summary","backstory","personality","speakingStyle","secrets",
                   "portraitUrl":"…",
                   "expressions":[{"name":"開心","emotion":"開心","imageUrl":"…"}]}
```

- **更新要帶 `characterId`。傳 `id` 會變成新增一個重複角色。**
- 只覆蓋你傳的欄位，其餘保留。
- 差分實際只存 `{id,name,emotion,imageUrl}`。卡片的 `emotion` 要對得到 `expressions` 的
  `emotion`，播放器才換得了臉。
- `secrets` 是「知道但不主動說」，**發佈到市集時會被拿掉**（所以別人的專案裡看不到）。
- **不要用整包 `PUT /projects/:id` 寫角色**：寫得進去，可是角色工坊那一頁不見得認。
- **`expressions` 是附加不是覆蓋。** 送一份新清單過去，舊的差分不會消失，兩份會並存。
  帶**相同的 `id`**，或**相同的 `name` 加 `kind`**，才會就地取代那一張。
  送 `"expressions": []` 不會清空（回 200，內容原封不動）。
- `summary` 撞名：它同時是角色的一句話摘要與這次修改的稽核標籤。
  想寫「補齊背景故事」當標籤，結果會把角色的摘要蓋成那六個字。要嘛送摘要本身，要嘛不送。
- 三個角色的文字欄位分工（官方寫作要求）：`personality` 寫價值觀與反射動作不是形容詞串、
  `speakingStyle` 要具體到用字節奏與情緒怎麼洩漏、`secrets` 寫真正的秘密內容
  （runtime 當成「知道但不主動說」，寫暗示等於沒寫）、`systemPrompt` 留白。

**差分可以叫 API 產**：`POST /projects/:id/characters/:characterId/art`，
body 是 `{"kind":"expression"|"outfit"|"pose","variants":[{"name":…,"prompt":…}]}`，
一次最多 8 組，角色要先有 `portraitUrl` 當身份基準，回應裡逐項看 `failures`。
成功的會同時寫進差分清單與專案素材。**這支吃 Larch 的 AI 點數**
（網頁上同一個動作標示每張最多 7 點），所以有自己的生圖工具就先用自己的，
產完透明 PNG 走 `POST /media` 上傳再掛回角色。

**`kind` 的限制是伺服器端寫死的**：`outfit` 只改衣服、`pose` 只改姿勢、`expression` 只改臉。
要「換了衣服又換姿勢」就走兩段式：先 `outfit`，再把 `portraitUrl` 暫時指到那張成品、
叫 `pose` 差分，做完還原 `portraitUrl`。實測有效，身份不會跑掉。

**連載角色的服裝要有因果就要串鏈**：正裝 → 男身 → 男甲 → 跌坐，每一段拿前一段當
`portraitUrl`。從錯的基準長（例如讓「掉下來的男裝」從女式正裝長出來）整組要重做。

**`POST /images/generate` 不吃參考圖**：`references` 傳 data URL 或裸 base64，
回應的 `input_images` 都是 `0`。所以 agent 這條做不了「以參考圖為基準的編輯」，
只有 `/art` 可以（它以 `portraitUrl` 當基準，另外還吃得下 `references` 陣列當第二張參考圖）。

（`/api/akarion/ai/image`、`/character-expression`、`/remove-background` 是網頁前端在打的，
那三支**只吃 Google 登入 cookie**，agent 金鑰一律 401。agent 要生圖走上面那支 `/art`。）

## 專案設定

```jsonc
titleScreenEnabled: true
titleScreen: {frame:"film"|null, frameColor, bgm, bgmVolume, layers:[…]}
titleCoverShade / titleCoverPositionX / titleCoverPositionY
projectThumbnail            // 市集與列表的縮圖
dialogueUi: {preset, presentation:"gradient", fontFamily, fontSize, nameFontSize,
             textColor, speakerColor, accentColor, borderColor,
             panelColor, panelOpacity, panelWidth, panelPadding, borderRadius, backdropBlur}
cgGalleryEnabled / cgGallerySource:"picked" / cgGalleryItems:[{url,title}]
cursorMode:"custom" / cursorImage / cursorSize / cursorHotspotX / cursorHotspotY
cursorEffects: {effects:["squash","tilt","ripple","trail","particles"], …}
stageFit:"auto" / keepActorsInFrame / textSpeed / typingEffect / autoAdvanceDelay
resolution: {width:1920, height:1080}
```

### 標題畫面的兩個坑

**一、按鈕是 layer，不會自己出現。** 只放文字層的話畫面上一個按鈕都沒有：

```jsonc
{"id":"action-start",    "kind":"button", "action":"start",    "icon":true, "x":…,"y":…,"size":…,"width":…}
{"id":"action-continue", "kind":"button", "action":"continue", …}
{"id":"action-gallery",  "kind":"button", "action":"gallery",  …}
{"id":"languages",       "kind":"language", "x":…,"y":…,"size":…}
{"id":"name",            "kind":"text", "role":"title",       …}   // eyebrow / title / description
```

`x`/`y`/`width` 是畫面百分比。

**二、標題畫面吃的是第一張卡的背景**，不是 `projectThumbnail`。所以：

| | 放什麼 |
|---|---|
| 第一張卡的背景 | 乾淨的封面。**不要把標題燒在圖上**，文字是 layer 畫的 |
| `projectThumbnail` | 有標題的那張，縮圖要自己站得住 |

## 語音的兩道閘要分開設

**線上播放器只看卡片的 `data.voiceMode`；匯出的單檔版只看 `project.languages[].voiceMode`。**
兩邊各要各的，設一邊另一邊一定不會響。

- 線上沒聲音 → 卡片的 `voiceMode` 是 `off`。`POST /voice/generate` 會把那張卡設成 `ai`，
  所以配完就會自己打開；但**用腳本重推版子的時候如果寫死 `voiceMode: "off"`，
  會把全部配好的語音一次關掉**，而且音檔還在、完全不報錯。2026-09-01 踩過。
- 匯出版沒聲音 → 見下一節。

腳本重推版子還有一個更貴的坑：**`dialogueLines` 重組會把每一句的 `voiceUrl` 洗掉**。
配一次兩百句要一個多小時，洗掉就白做。重推時要用 `(nodeId, lineIndex, text)` 當鍵，
把伺服器上的 `voiceUrl` 帶回來；文字改過的那句才需要重配。

## 匯出的單檔 HTML 沒有聲音

匯出的播放器那道閘是：

    if (d.voiceMode && d.voiceMode!=='off' && d.voiceMode!=='realtime') playVoice(...)

它讀**卡片層**的 `d.voiceMode`。可是**卡片上自己寫的 voiceMode 會被匯出程序丟掉**
（雲端存得下，匯出的 JSON 裡是 0 個）——匯出時是從 `project.languages[].voiceMode`
複製到每張卡的。所以要設的是**專案的語言**，不是卡片：

    project.languages = [{"code": "zh-Hant", "label": "繁體中文", "voiceMode": "shared"}]

**線上播放器不看這個欄位**，所以會出現「線上七百句都正常、匯出版一句都不播、
而且完全不報錯」。實測排除過：音檔沒進去（1345 筆內嵌音訊、索引全在表內）、
MIME 不合法（匯出用 `audio/mp3`，實測能播）、`file://` 被擋（背景樂同機制正常）。

## 發佈

**市集發佈的是快照，不是即時鏡像。** 按下發佈那一刻的內容被凍結起來，
之後改專案、重建章節、換素材，市集上那一份都不會跟著變——要再發佈一次。
實測：發佈後改了片尾卡的網址，市集版本仍是舊的，而且沒有任何提示。

**正式播放器要 Google 登入，但市集的公開作品不用。** `/play/market/<發佈id>`
在無痕視窗打得開也玩得到，`/api/marketplace/<發佈id>?play=1` 不帶權杖也拿得到整包資料。

要給人玩但還不想上架，用 `POST /projects/:id/share-link`（固定網址，再打一次會刷新成當下版本）。
自己要看成果用下面那支預覽，不要為了看一眼就去發佈。

## 專案本身

- `POST /projects` 建得了新專案（201）。
- **`DELETE /projects/:id` 回 404，agent API 刪不掉專案。** 要清只能把 `boards`／
  `variables` 清空，空殼還會留在列表上。
- **`PUT /projects/:id` 的 body 一定要包一層 `{"project": {…}}`。** 不包的話伺服器回 `200`，
  然後把整個專案寫成空的：boards、characters、media、variables、settings 全部不見，
  而且回應裡沒有任何錯誤字樣。2026-09-01 實測踩過一次。
- 就算包對了，整包 PUT 仍然會**依 `(source, sourceHandle)` 去重**，同一個出口的多條分支只留一條。
  所以它不能拿來寫條件分支，見下面那一節。
- **版本救得回來。** `GET /projects/:id/versions` 列出來，
  `POST /projects/:id/versions/:versionId/restore` 還原。
  （`GET /versions/:id` 是 404，所以讀不到單一版本的內容，只能直接還原下去。）
  即使如此，動手前還是先抓一份自己的快照，因為還原也是一次寫入。
- **不要用「有沒有被引用」去清孤兒素材。** 判斷當下角色欄位可能還沒寫進去，
  會把還在用的立繪整組刪掉。要清就同名去重，並且以自己那份 assets.json 為準。

## 插件卡

專案設定的 `settings.plugins` 決定哪些插件開著（`{"larch-inventory": {"enabled": true}, …}`）。
`GET /api/plugins` 列的是市集上架的那些（有作者掛名）；`larch-` 前綴的是平台內建，
不在那份清單裡，單獨查會回「找不到插件」。

卡片外層是 `data.type = "plugin"`，實際是哪一張看 `pluginCardId`。**整份 `pluginHtml`
存在卡片裡**，所以要改配色就直接換它 CSS 的色值（插件本身通常沒開放配色設定）。

### 背包（`larch-inventory`，兩張卡）

```jsonc
// pluginCardId: "grant-item"  — 全螢幕演出「獲得道具」,畫面暗下來、中間一個圓形道具徽章
{"bagVar":"inventory", "countVar":"inventoryCount",
 "itemName":"一壺清水", "itemCount":1, "itemNote":"桃林深處那口小泉打的。",
 "itemImage":"<透明 PNG 的網址>",      // 空的話會顯示預設方塊圖示,這是唯一的視覺設定
 "itemId":"water", "consumable":true, "hideAfterCollect":true,
 "effectKind":"none", "effectValue":"", "effectVar":"", "storyNodeId":""}

// pluginCardId: "open-bag"    — 列出道具,玩家挑一件才繼續
{"title":"行囊", "bagVar":"inventory", "pickVar":"inventoryLastUsed",
 "consume":true, "allowSkip":false, "emptyText":"行囊是空的。"}
```

- 兩張靠 `bagVar` 串起來，預設變數是 `inventory`（字串，內容是 JSON 陣列）。
  `countVar` 指到的變數會同步件數，HUD 右上角那顆「背包 N」就是它。
- `open-bag` 的 `pickVar`（預設 `inventoryLastUsed`）記下玩家挑了哪一件，
  可以拿去做條件分支。`consume:true` 會把道具用掉。
- 元素 id：`grant-item` 只有一顆 `#go`；`open-bag` 有 `#grid`（道具格）、`#skip`
  （什麼都不拿）、`#go`（使用）。**要先點道具再按使用**。
- 用法上最順的是「取得的地方各自給不同的 `itemNote`」：三條分支各拿一壺水、
  備註寫成各自的來源，玩家打開行囊就看得到自己走過哪一條。

### 這些卡都在 sandbox iframe 裡

`srcdoc` + `sandbox="allow-scripts"`，opaque origin。**拿不到麥克風**（見
[[reference-larch-plugin-sandbox-no-mic]]），開發者協定也**進不去它的執行環境**：
`Runtime.evaluate` 帶 contextId 或 uniqueContextId 都找不到，`Page.getFrameTree`
也看不到那個 frame。要自動化測試只能送 CDP 的真實滑鼠鍵盤事件，座標從外層量
`document.querySelector('iframe').getBoundingClientRect()` 推算。
（`open-bag` 是例外，它畫在主文件裡，可以直接用 DOM 點。）

## 條件分支（如果要做）

`edge.data.condition = {kind:"variable", variable, op:"eq|neq|gt|gte|lt|lte", value}`。
同一個出口可以拉多條線：有條件的先判，第一條**無條件**的當預設。

**`POST /nodes` 會把 `edge.data.condition` 整個丟掉，而且依 `(source, sourceHandle)` 去重**，
而且不會報錯，要驗才看得出來。

官方文件另外寫了一條規則：**「一個出口 handle 最多接一個目標，伺服器留最新的那條。」**
可是實測用整張白板覆蓋推六條同出口的條件邊，六條全部留著、條件也在。
所以那條規則講的是 `POST /nodes` 那種增量寫入，不是整張覆蓋。**兩種都要自己驗**。

**寫版子只有一條正確的路：`PUT /projects/:id/boards/:boardId`**，body 是
`{"name":…, "nodes":[…], "edges":[…], "summary":"一句話交代改了什麼"}`。
這是平台自己的 agent 提示詞寫的做法（bundle 的 `assets/agentPrompts-*.js` 裡有全文），
整張白板覆蓋，條件與同出口多條邊都保得住。只改名字就不要送 `nodes`／`edges`。

整包 `PUT /projects/:id` 不行：它會去重掉分支。`POST /nodes` 也不行：它會把
`edge.data.condition` 整個丟掉。兩個都不報錯。

## 看實際畫面：免登入預覽

**這是驗收的唯一方法，讀 JSON 讀回來不算看過。**

    GET /api/agent/projects/:id/preview?boardId=&cardId=&hours=

回 `{url, playUrl, boardUrl, expiresAt}`。不用登入，金鑰本身就是通行證。

- `playUrl`：從起點卡開始播，玩家看到什麼就是什麼。
- **帶 `cardId` 只播那一張**，剛改完一張卡要看效果就用這個，最快。
- `boardUrl`（`?view=board`）：整張白板的地圖，看結構與接線用，不是看畫面用。

網址讀的是當下的專案，所以改完重新整理就好，不必每次重開一條。
預設 24 小時到期（`hours` 最多 168），唯讀，金鑰一停用就失效。
**這條連結是私人的，不是拿給玩家的那條**（那條走 `share-link`）。

演出的數字對照（在有預覽之前是靠本機合成猜的，現在可以直接看，但這些仍然管用）：

    slot 的水平位置   farLeft .12   left .28   center .5   right .72   farRight .88
    對話框遮住的高度   抓 45%，不是 30%（presentation:"gradient" 會往上暈開）

## 立繪的朝向

**不要無條件鏡射，也不要憑縮圖判斷。** 判斷方法是**把圖放大、畫一條垂直中線**，
看五官偏在哪一半。我在縮圖上看錯過一次，把一張真的朝畫面外的頭像判成朝內，
於是拿掉了正確的鏡射。

七個角色逐一比對之後，只有一個是真的朝畫面外。其他鏡過去反而破壞。

而且立繪通常是**正面朝鏡頭**畫的，兩個人並排本來就不會互看，
真的視覺小說也是這樣。市集四個作品的 148 個 actor 裡 135 個是 `center`：
**一次一個人站中間才是常態。**

## 改完素材要重建板子

**卡片存的是素材網址，不是素材名稱。** 重新上傳一張同名的圖，
會拿到一個**新的網址**，而舊卡片還指著舊網址——線上完全沒有變化。

我在這裡誤報過一次「修好了」：素材確實傳上去了，assets.json 也更新了，
可是沒重跑建置腳本，所以板子還指著舊圖。

改完素材一定要：**重新上傳 → 更新 assets.json → 重建板子 → 從伺服器讀回來驗**。
驗的方法是把卡片指到的網址抓下來看，不要看本機檔案。

## 動手前先把整包抓下來

```bash
curl -s -H "Authorization: Bearer $KEY" \
  "https://larch.ink/api/agent/projects/<專案ID>" -o snapshot.json
```

寫壞了就靠這份還原（`PUT /projects/:id`，body 包 `{"project": <snapshot>}`）。
`GET /projects/:id/versions` 列得出伺服器留的版本，**但沒有讀單一版本的端點**
（`/versions/<id>` 回 404），所以伺服器的版本救不回內容，只有自己的快照救得回來。

還有一件事：**作者的瀏覽器開著編輯器的時候會把它自己的狀態推上來。**
還原完發現內容跟快照對不起來，先確認是不是有人正在編輯，不要急著再寫一次。

## 用腳本重推版子，要保住作者手排的東西

整張白板覆蓋很方便，代價是會蓋掉作者在編輯器裡做的事。重推之前先把伺服器上那張板子讀回來，
下面這幾樣用既有值、不要重新產生：

| 欄位 | 為什麼 |
|---|---|
| `position` | 作者會手排版面。自動排版一推就洗掉，只有新卡片才該自動放 |
| `dialogueLines[].voiceUrl` | 配一次兩百句要一個多小時 |
| `data.voiceMode` | 寫死 `off` 會把配好的語音全部關掉 |

排版清不清楚可以用量的，不必用看的：兩張卡中心距離小於卡片寬高就是重疊；
邊的終點 x 小於等於起點就是往回接（編輯器裡會看到線繞回去）；同一條分支的卡片 Y 是否對齊。

## 一定要有的檢查

線性的東西也會壞。每次推完至少驗這些：

- 邊的來源／目標存在
- 沒有入邊的孤島、沒有出邊的死路（**刻意的終點要自己標記**，否則分不出來）
- 空的對話卡（會變成要點掉的空白框）
- `characterId` 對得到角色、立繪圖層有 url、場景卡有背景
- 線性的板子不該有分岔

有條件分支的話還要寫一支帶變數狀態的模擬器：照 `set`/`add` 更新變數、照條件挑邊，
才驗得出哪些卡實際走不到。單純的可達性檢查抓不到。

## 授權

MIT © 林亞澤
