# larch-vn

在 [Larch](https://larch.ink) 平台做視覺小說的 Claude Code skill。

裡面是**實測出來的平台格式**：卡片欄位、舞台與立繪動畫、轉場與畫面特效、
素材分類、角色與表情差分、標題畫面的按鈕怎麼做出來、以及一串踩過的坑。
官方 skill 文件沒有這些。

## 為什麼需要

做第一版的時候我把角色建成只有名字的空殼、圖全部當道具上傳、立繪不會動、
標題畫面沒有任何按鈕。每一項都是因為**不知道欄位存在**。

後來發現市集上已發佈的作品可以直接抓下來讀：

```bash
curl -s "https://larch.ink/api/marketplace/<發佈id>?play=1" -o mk.json
```

不用登入，回完整專案 JSON。這支 skill 就是讀了四個作品之後整理出來的。

## 跟官方那份 skill 的關係

Larch 官方在「帳號設定 → AI 輔助」可以產生一份 `larch-story-studio` skill，講的是 API 怎麼呼叫、
工具怎麼路由、工作流程的紀律。**這份不取代它，補的是它沒寫的另一半**：平台實際上不照文件跑的地方。

2026-09-10 對照過，官方那份（186 行）完全沒提到立繪不會自己清、編輯器分頁會把版子打回舊版、
`PUT` 會清空專案、背包插件的三個坑、`If-Match` revision、去背與透明底。兩份一起看。

## 安裝

```bash
git clone https://github.com/yazelin/larch-vn-skill ~/larch-vn-skill
ln -s ~/larch-vn-skill ~/.claude/skills/larch-vn
```

金鑰放 `~/.config/larch/key`（chmod 600）。**不要寫進專案、卡片、匯出檔或 repo。**

## 其他 agent

skill 本體就是 `SKILL.md`，不綁 Claude。Codex／Gemini 直接讀它照做即可。

## 授權

MIT © 林亞澤

---

[GitHub](https://github.com/yazelin) · [Facebook](https://www.facebook.com/yaze.lin.gm) · [請亞澤喝咖啡](https://buymeacoffee.com/yazelin) · [亞澤的部落格](https://yazelin.github.io/)
