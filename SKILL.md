---
name: larch-vn
description: 在 Larch 平台做視覺小說。要建專案、上素材、建角色與表情、排場景與立繪演出、設標題畫面的時候用。內含平台實際欄位與踩過的坑，avoid 從零猜。
---

# Larch 視覺小說

平台在 `https://larch.ink`（2026-08 從 larch.yapiflow.com 搬過來，舊網域回 308 導向：GET 跟得過去，**POST／PUT 不行**，urllib 不跟 308），agent REST 在 `/api/agent/projects/…`，
金鑰放 `~/.config/larch/key`（chmod 600，**絕對不要寫進專案、卡片、匯出檔或 repo**）。

底下所有欄位與可用值都是**從平台前端 bundle 與市集上已發佈的四個作品實測出來的**，
不是猜的。skill 官方文件沒有這些。

## 先做這件事：去讀別人的專案

```bash
curl -s "https://larch.ink/api/marketplace/<發佈id>?play=1" -o mk.json
```

**不用登入**，回的是完整專案 JSON。市集網址長這樣：
`https://larch.ink/play/market/<發佈id>`。

這是目前最有用的資料來源。要做什麼演出、不確定欄位怎麼填，就去撈一份人家的來看。

## 卡片

外層 `{id, type:"story", position:{x,y}, data:{…}}`，**真正的型別在 `data.type`**。
實際用得到的：`scene`／`dialogue`／`choice`／`input`／`miniGame`／`aiStory`／`plugin`。

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

**播放器要 Google 登入，但市集的公開作品不用。** `/play/market/<發佈id>`
在無痕視窗打得開也玩得到，`/api/marketplace/<發佈id>?play=1` 不帶權杖也拿得到
整包資料。所以用 agent API 做東西的人看不到自己的成果，發佈之後才看得到。

## 專案本身

- `POST /projects` 建得了新專案（201）。
- **`DELETE /projects/:id` 回 404，agent API 刪不掉專案。** 要清只能把 `boards`／
  `variables` 清空，空殼還會留在列表上。
- **`PUT /projects/:id` 的 body 一定要包一層 `{"project": {…}}`。** 不包的話伺服器回 `200`，
  然後把整個專案寫成空的：boards、characters、media、variables、settings 全部不見，
  而且回應裡沒有任何錯誤字樣。2026-09-01 實測踩過一次。
- 就算包對了，整包 PUT 仍然會**依 `(source, sourceHandle)` 去重**，同一個出口的多條分支只留一條。
  所以它不能拿來寫條件分支，見下面那一節。
- **不要用「有沒有被引用」去清孤兒素材。** 判斷當下角色欄位可能還沒寫進去，
  會把還在用的立繪整組刪掉。要清就同名去重，並且以自己那份 assets.json 為準。

## 條件分支（如果要做）

`edge.data.condition = {kind:"variable", variable, op:"eq|neq|gt|gte|lt|lte", value}`。
同一個出口可以拉多條線：有條件的先判，第一條**無條件**的當預設。

**`POST /nodes` 會把 `edge.data.condition` 整個丟掉，而且依 `(source, sourceHandle)` 去重**，
而且不會報錯，要驗才看得出來。

**寫版子只有一條正確的路：`PUT /projects/:id/boards/:boardId`**，body 是
`{"name":…, "nodes":[…], "edges":[…], "summary":"一句話交代改了什麼"}`。
這是平台自己的 agent 提示詞寫的做法（bundle 的 `assets/agentPrompts-*.js` 裡有全文），
整張白板覆蓋，條件與同出口多條邊都保得住。只改名字就不要送 `nodes`／`edges`。

整包 `PUT /projects/:id` 不行：它會去重掉分支。`POST /nodes` 也不行：它會把
`edge.data.condition` 整個丟掉。兩個都不報錯。

## 做一支本地預覽

**播放器要 Google 登入才玩得到，所以用 agent API 做東西的人看不到自己做的成果。**
不要靠猜。在本機照同樣的數字合成一張 1920×1080：背景、每個 actor 照 `slot` 與 `scale`
貼上去、底部畫一條照 `dialogueUi` 的對話框。

精準度到不了像素級，可是「頭貼太低」「立繪整組偏小」「臉朝畫面外」這種問題一眼就看得出來。
我在有這支工具之前改了四輪都沒改對。

`slot` 對到的水平位置大約是：

    farLeft .12   left .28   center .5   right .72   farRight .88

**對話框要抓 45%，不是 30%。** `presentation:"gradient"` 會往上暈開，
實際遮到的高度比面板本身高很多。我用 30% 模擬，結果做出來的東西在真的播放器裡
被蓋住，可是預覽看起來好好的。寧可抓過頭。

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
