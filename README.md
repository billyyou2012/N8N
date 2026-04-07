# AI Secretary 專案

## 📁 專案結構

```
C:\AI_Secretary\
├── README.md                            # 本文件
├── database_setup.sql                   # 資料庫設定腳本 (SQL Server)
├── deploy_secretarydb.ps1               # PowerShell 部署腳本
├── n8n_sql_config.json                  # n8n SQL 節點設定範例
├── AI_Secretary.json                    # 原始工作流程 (13個節點)
├── AI_Secretary_enhanced_B1_complete_v1.json  # ✅ 選項 B1 完整版 (25個節點，推薦使用)
├── AI_Secretary_enhanced_B2.json        # 選項 B2 簡化版
├── AI_Secretary_enhanced_optionA.json   # 選項 A 基礎版
├── merge_complete_workflow.py           # 合併腳本
└── test_permission.txt                  # 權限測試檔案
```

## 🎯 功能概述

AI Secretary 是一個基於 n8n 的工作流程，整合 Teams、AI Agent 與 SQL 資料庫，實現智慧排程管理系統。

### 核心功能：
1. **自然語言解析**：透過 Teams 接收用戶指令，AI Agent 解析時間與任務
2. **排程儲存**：將解析結果儲存到 secretarydb 資料庫
3. **精確排程執行**：每分鐘檢查並執行到期任務
4. **結果回傳**：將執行結果發回 Teams 頻道
5. **完整錯誤處理**：記錄日誌、錯誤通知、狀態更新

### 支援任務類型：
- ✅ **查詢工單** (query_ticket) - 查詢 NOC_TT_AI_3 資料庫
- ✅ **提醒通知** (reminder) - 發送提醒訊息
- ✅ **自訂查詢** (custom_query) - 執行自訂 SQL 查詢
- ✅ **SSH指令** (ssh_command) - 執行遠端 SSH 指令

## 🚀 快速開始

### 步驟 1：建立資料庫
```powershell
# 方法 A：使用 PowerShell 腳本
.\deploy_secretarydb.ps1

# 方法 B：手動執行 SQL 腳本
# 1. 使用 SQL Server Management Studio (SSMS)
# 2. 打開 database_setup.sql
# 3. 執行所有指令
```

### 步驟 2：導入 n8n 工作流程
```
1. 打開 n8n
2. 點擊「Import from file」
3. 選擇 AI_Secretary_enhanced_B1_complete_v1.json
4. 點擊「Import」
```

### 步驟 3：設定憑證
確保以下憑證已在 n8n 中設定：
1. **Microsoft Teams OAuth2** (已預先設定)
2. **Microsoft SQL account** (已預先設定)
3. **Azure OpenAI** (已預先設定)

**SQL 設定參考**：可參考 `n8n_sql_config.json` 中的設定範例

### 步驟 4：測試功能
```
1. 用戶互動測試：
   - 在 Teams 頻道發送：「明天下午三點查詢 Class 1 工單」
   - 檢查 AI 是否正確回應並儲存到資料庫

2. 排程執行測試：
   - 等待 1-2 分鐘（每分鐘觸發）
   - 檢查排程是否被執行
   - 查看 Teams 頻道是否收到結果
```

## 📊 SecretaryDB 資料庫結構

### 主要資料表：
1. **schedules** - 排程記錄主表
   - 儲存所有排程任務
   - 包含任務參數、執行時間、狀態等
   - 自動產生 UUID 確保唯一性

2. **execution_logs** - 執行日誌表
   - 記錄所有執行歷史
   - 包含成功/失敗日誌
   - 用於錯誤分析與審計

### 儲存程序：
- **sp_get_pending_schedules** - 取得待執行排程
- **sp_update_schedule_status** - 更新排程狀態
- **sp_insert_schedule** - 插入新排程

## 🔧 詳細設定

### 資料庫連接字串
```
Server=localhost;Database=SecretaryDB;User Id=secretary_user;Password=SecretaryDB@2026;
```

### n8n 設定參考
完整的 n8n SQL 節點設定可參考 `n8n_sql_config.json` 檔案，包含：
- 連接參數詳細設定
- 常用查詢範例
- AI Agent 工具設定
- 故障排除指南

### n8n 工作流程節點說明

#### 用戶互動流程 (8個節點)：
1. **Microsoft Teams Trigger** - 監聽 Teams 頻道訊息
2. **取頻道對話1** - 取得最新訊息
3. **Filter** - 過濾系統訊息
4. **AI Agent** - 解析自然語言指令
5. **Azure OpenAI Chat Model** - AI 模型
6. **Simple Memory1** - 對話記憶
7. **secretarydb** - SQL 資料庫工具
8. **Create message** - 回傳結果到 Teams

#### 精確排程流程 (17個節點)：
1. **Precise Schedule Trigger** - 每分鐘觸發
2. **Get Pending Schedules** - 取得待執行排程
3. **Split in Batches** - 分批處理
4. **Prepare Execution** - 準備執行參數
5. **Update Status to Executing** - 更新狀態為執行中
6. **Route by Task Type** - 根據任務類型路由
7. **Execute NOCTT Query** - 執行工單查詢
8. **Format Query Result** - 格式化結果
9. **Prepare Teams Message** - 準備 Teams 訊息
10. **Send Result to Teams** - 發送結果
11. **Update Status to Completed** - 更新為完成狀態
12. **Handle Error** - 錯誤處理
13. **Log Error** - 記錄錯誤日誌
14. **Send Error Message** - 發送錯誤訊息
15. **Update Status to Failed** - 更新為失敗狀態

## ⚠️ 注意事項

### 資料庫需求：
- **SQL Server 2016+** 以支援 JSON 函數
- 建議至少 1GB 可用空間
- 定期備份重要資料

### 安全性：
- 預設密碼為 `SecretaryDB@2026`，建議在生產環境中變更
- 限制資料庫使用者的權限
- 啟用 SQL Server 稽核功能

### 效能考量：
- 排程檢查頻率：每分鐘一次
- 每次處理最大排程數：10個
- 執行超時時間：300秒（5分鐘）

## 🔄 版本比較

| 版本 | 節點數 | 推薦使用場景 | 特點 |
|------|--------|--------------|------|
| **B1 完整版** | 25個 | 生產環境、完整功能 | ✅ 完整錯誤處理<br>✅ 執行日誌記錄<br>✅ 所有任務類型支援 |
| **B2 簡化版** | 15個 | 測試環境、快速驗證 | ⚡ 快速部署<br>⚡ 核心功能完整<br>⚠️ 錯誤處理簡化 |
| **A 基礎版** | 13個 | 概念驗證、學習使用 | 📚 基礎架構<br>📚 易於理解<br>⚠️ 功能有限 |

## 🐛 故障排除

### 常見問題：

#### 1. 資料庫連線失敗
```
錯誤：無法連線到 SQL Server
解決方案：
- 確認 SQL Server 服務正在執行
- 檢查防火牆設定 (Port 1433)
- 驗證使用者名稱與密碼
```

#### 2. Teams 訊息無法接收
```
錯誤：Teams Trigger 未觸發
解決方案：
- 確認 Teams Bot 已加入頻道
- 檢查 OAuth2 憑證是否有效
- 確認頻道 ID 設定正確
```

#### 3. AI Agent 無法解析
```
錯誤：AI 回應不正確
解決方案：
- 檢查 Azure OpenAI 憑證
- 確認 API 額度足夠
- 調整提示詞參數
```

#### 4. 排程未執行
```
錯誤：排程觸發器未工作
解決方案：
- 檢查 Schedule Trigger 設定
- 確認資料庫中有待執行排程
- 查看執行日誌表
```

## 📞 支援

### 技術支援：
- **珠珢**：您的 AI 助手，可協助設定與問題排除
- **OpenClaw 社群**：https://discord.com/invite/clawd

### 相關檔案：
- `database_setup.sql` - 完整的資料庫設定腳本
- `deploy_secretarydb.ps1` - 自動化部署腳本
- `n8n_sql_config.json` - n8n SQL 節點設定範例
- 所有 JSON 工作流程檔案均可直接導入 n8n

## 📈 未來擴展

### 計畫功能：
1. **報表生成** - 自動產生排程統計報表
2. **多頻道支援** - 支援多個 Teams 頻道
3. **進階錯誤處理** - 自動重試與通知升級
4. **API 整合** - 提供 REST API 介面

### 自訂開發：
如需自訂功能，可修改：
1. `schedules` 資料表結構
2. AI Agent 提示詞
3. 任務路由邏輯
4. 結果格式化方式

---
**最後更新：2026-04-07**
**維護者：珠珢 (您的 AI 助手)**