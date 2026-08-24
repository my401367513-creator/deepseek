---
name: read-office-docs
description: 读取 Word（.docx/.doc）、PDF、Excel（.xlsx）、PPT（.pptx）等办公文档并提取为文本。用户给出文档路径或把文档放进工作区时，先加载本技能再提取。
---

# 办公文档读取技能（read-office-docs）

目标：把用户提供的剧本/资料（.docx/.doc/.pdf/.xlsx/.pptx）变成可分析的纯文本。

## 0. 总原则

- 先确认文件存在：用 `glob`/`ls` 按路径或扩展名找到文档。
- 提取需要写临时目录：在**工作区内**建 `.<doc-extract>/`（工作区默认可写），提取完删除。
- 提取顺序：`.docx/.xlsx/.pptx` 用「解包 + XML」（零依赖、最快）；`.doc/.pdf` 用 **Word COM**（本机已装 MS Word/WPS，已验证可用）；都失败则请用户另存为 `.txt/.md` 或复制文本。
- 提取结果是纯文本，格式/图片/页码会丢失；图片型（扫描件）PDF 无法提取文本，需 OCR，明确告知用户。
- 注意：PowerShell 5.1 的 `Expand-Archive` 只接受 `.zip` 扩展名，所以先复制一份为 `.zip` 再解包（下方脚本已内置）。

## 1. .docx（Word 文档，最常用）

docx 是 zip：正文在 `word/document.xml`，段落 `<w:p>`，文本在 `<w:t>`，表格 `<w:tbl>`。

```powershell
$src = "<文档绝对路径>"
$root = "<工作区>\.doc-extract"
New-Item -ItemType Directory -Path "$root\unzip" -Force | Out-Null
Copy-Item $src "$root\doc.zip" -Force
Expand-Archive -Path "$root\doc.zip" -DestinationPath "$root\unzip" -Force
$xml = Get-Content "$root\unzip\word\document.xml" -Raw -Encoding UTF8
$text = [regex]::Replace($xml, '</w:p>', "`n")
$text = [regex]::Replace($text, '</w:tr>', "`n")
$text = [regex]::Replace($text, '</w:tc>', " | ")
$text = [regex]::Replace($text, '<w:tab[^>]*/>', "`t")
$text = [regex]::Replace($text, '<[^>]+>', '')
$text = $text -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>' -replace '&quot;','"' -replace '&apos;',"'"
$text = ($text -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 }) -join "`n"
$text
```

- 表格会变成「单元格 | 单元格」的行，可直接用于分镜表等场景。
- 若 `word/document.xml` 不存在（文件损坏/加密），改用第 2 节 COM 路径。

## 2. .doc（旧版 Word 二进制）与 .pdf

用 Word COM（本机已装 MS Word，ProgID `Word.Application`；WPS 也可用 `KWps.Application`）。脚本需要 FullLanguage（工作区可写时默认满足）。

```powershell
$src = "<文档绝对路径>"
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
  # 第2参 ConfirmConversions=$false 避免转换弹窗；第3参 ReadOnly
  $doc = $word.Documents.Open($src, $false, $true)
  $text = $doc.Content.Text
  $doc.Close($false)
  $text
} finally {
  $word.Quit()
  try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null } catch {}
}
```

- `.pdf` 用同一脚本：Word 2013+ 可打开 PDF 并转成可编辑文本（首次可能弹一次转换提示，属正常）。
- COM 不可用（只读会话/无 Office）时：检查 `pdftotext`（poppler），有则 `pdftotext -layout <pdf> -`；都没有就请用户另存为 `.docx` 或复制文本。

## 3. .xlsx（Excel）

解包提取字符串（`xl/sharedStrings.xml` 含全部文本，`<si>` 一项一个字符串）：

```powershell
$src = "<文档绝对路径>"
$root = "<工作区>\.doc-extract"
New-Item -ItemType Directory -Path "$root\unzip" -Force | Out-Null
Copy-Item $src "$root\book.zip" -Force
Expand-Archive -Path "$root\book.zip" -DestinationPath "$root\unzip" -Force
$ss = Get-Content "$root\unzip\xl\sharedStrings.xml" -Raw -Encoding UTF8
$m = [regex]::Matches($ss, '<si>.*?</si>')
$strings = foreach ($x in $m) { [regex]::Replace($x.Value, '<[^>]+>', '') -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>' -replace '&quot;','"' -replace '&apos;',"'" }
$strings -join "`n"
```

- 想保留行列结构：用 WPS 表格 COM（`KET.Application`）逐单元格读，或请用户另存为 CSV。
- 纯数字表没有 sharedStrings，提取结果为空属正常；此时请用户另存 CSV。

## 4. .pptx（PPT）

每页一个 `ppt/slides/slideN.xml`，文本在 `<a:t>`：

```powershell
$src = "<文档绝对路径>"
$root = "<工作区>\.doc-extract"
New-Item -ItemType Directory -Path "$root\unzip" -Force | Out-Null
Copy-Item $src "$root\deck.zip" -Force
Expand-Archive -Path "$root\deck.zip" -DestinationPath "$root\unzip" -Force
Get-ChildItem "$root\unzip\ppt\slides\slide*.xml" | Sort-Object Name | ForEach-Object {
  "--- $($_.Name) ---"
  $x = Get-Content $_.FullName -Raw -Encoding UTF8
  $t = ([regex]::Replace($x, '</a:p>', "`n") -replace '<[^>]+>', '') -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>' -replace '&quot;','"' -replace '&apos;',"'"
  ($t -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 }) -join "`n"
}
```

## 5. 注意事项

- 提取前确认扩展名与类型（docx/pptx/xlsx 的魔数是 zip：文件头 `PK`）。
- 大文件（>20MB）或加密文档可能失败，如实告知用户。
- 提取完成后删除 `.<doc-extract>` 临时目录（除非用户要求保留）。
- 只读沙箱会话下写临时目录会被拒绝：此时改用 COM（若可用）或请用户提供 .txt/.md。
