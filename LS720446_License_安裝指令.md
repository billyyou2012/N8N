# LS720446 License 安裝指令清單

> 適用流程：Windows PC → `10.76.191.171` → `10.76.217.21` → AMOS 安裝 License  
> 帳號：`f65765`  
> 密碼同東尼設定中的 10.76.191.171的密碼 ; 10.76.217.21與 10.76.217.22的密碼相同
> License 檔案：`LS720446.xml`

## 注意事項

- 密碼請在系統提示時手動輸入，不要寫入指令或操作紀錄。
- License XML 建議使用 FTP `binary` 模式上傳，避免 ASCII 模式改變檔案內容或大小。
- 執行 `deb cell` 會變更 Cell administrative state，必須先確認站台及維運窗口。

---

## 1. Windows 傳送 XML 到 10.76.191.171

在 Windows CMD 執行：

```cmd
ftp 10.76.191.171
```

依提示輸入：

```text
User: f65765
Password: 輸入密碼
```

進入 `ftp>` 後依序執行：

```text
binary
put D:\LICENSE\LS720446\LS720446.xml
ls LS720446.xml
bye
```

成功時應看到：

```text
200 Type set to I.
150 Opening BINARY mode data connection
226 Transfer complete.
```

---

## 2. 使用 Plink 登入 10.76.191.171

Windows CMD 執行：

```cmd
plink f65765@10.76.191.171
```

輸入密碼。若出現以下訊息，按一次 Enter：

```text
Access granted. Press Return to begin session.
```

登入成功後應看到：

```text
f65765@n1osscx1:~$
```

---

## 3. 在 10.76.191.171 確認 XML

```bash
cd /home/f65765
ls -l LS720446.xml
wc -c LS720446.xml
```

原始檔案大小應為：

```text
48509 LS720446.xml
```

若仍顯示 `46873` bytes，可能是先前以 ASCII 模式傳送的版本。請回到步驟 1，以 `binary` 模式重新上傳。

---

## 4. 從 10.76.191.171 傳送到 10.76.217.21

在 `10.76.191.171` 執行：

```bash
sftp f65765@10.76.217.21
```

輸入密碼，進入 `sftp>` 後執行：

```text
put LS720446.xml
ls -l LS720446_.xml
bye
```

檔案預期放置於：

```text
/home/shared/f65765/LS720446.xml
```

---

## 5. 登入 10.76.217.21 並確認檔案

回到 `10.76.191.171` Shell 後執行：

```bash
ssh f65765@10.76.217.21
```

登入後確認檔案：

```bash
ls -l /home/shared/f65765/LS720446.xml
wc -c /home/shared/f65765/LS720446.xml
```

---

## 6. 進入 AMOS

```bash
amos LS720446
```

進入 AMOS 後執行：

```text
lt all
acl Licensing=1
```

---

## 7. 安裝 License XML

執行：

```text
acc KeyFileManagement installKeyFile
```

出現確認提示時輸入：

```text
y
```

系統要求輸入 License URL 時貼上：

```text
sftp://f65765@10.76.217.21/home/shared/f65765/LS720446.xml
```

系統要求以下參數時，輸入 `10.76.217.21` 上 `f65765` 的密碼：

```text
Parameter 2 of 2, password
```

成功時應看到：

```text
>>> Return value = 1
Total: 1 MOs attempted, 1 MOs actioned
```

---

## 8. 驗證 License

```text
invl
```

確認關鍵結果：

```text
LicenseState: NORMAL
FingerPrint: LS720446
```

---

## 9. 檢查 Cell 與告警

先檢查狀態：

```text
st cell
alt
```

確認 License 正確、站台及維運窗口允許後，才執行 Cell 解鎖：

```text
deb cell
```

出現確認提示時輸入：

```text
y
```

最後再次確認：

```text
st cell
alt
```
