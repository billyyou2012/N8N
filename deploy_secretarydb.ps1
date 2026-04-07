# ============================================
# SecretaryDB 部署腳本 (PowerShell)
# 版本：1.0
# 最後更新：2026-04-07
# ============================================

param(
    [string]$SqlInstance = "localhost",
    [string]$DatabaseName = "SecretaryDB",
    [string]$Username = "secretary_user",
    [string]$Password = "SecretaryDB@2026",
    [switch]$TestOnly = $false,
    [switch]$Force = $false
)

# 設定錯誤處理
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# 顏色定義
$SuccessColor = "Green"
$WarningColor = "Yellow"
$ErrorColor = "Red"
$InfoColor = "Cyan"

# 函數：輸出彩色訊息
function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewLine = $false
    )
    
    if ($NoNewLine) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

# 函數：檢查 SQL Server 連線
function Test-SqlConnection {
    param([string]$ServerInstance)
    
    try {
        Write-ColorMessage "檢查 SQL Server 連線..." -Color $InfoColor
        $connectionString = "Server=$ServerInstance;Integrated Security=true;Connection Timeout=5"
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        $connection.Close()
        Write-ColorMessage "✅ SQL Server 連線成功" -Color $SuccessColor
        return $true
    } catch {
        Write-ColorMessage "❌ 無法連線到 SQL Server: $_" -Color $ErrorColor
        return $false
    }
}

# 函數：執行 SQL 指令
function Invoke-SqlCommand {
    param(
        [string]$ServerInstance,
        [string]$Database,
        [string]$Query,
        [string]$Username = $null,
        [string]$Password = $null
    )
    
    try {
        # 建立連線字串
        if ($Username -and $Password) {
            $connectionString = "Server=$ServerInstance;Database=$Database;User Id=$Username;Password=$Password;Connection Timeout=30"
        } else {
            $connectionString = "Server=$ServerInstance;Database=$Database;Integrated Security=true;Connection Timeout=30"
        }
        
        # 建立連線
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        
        # 執行指令
        $command = New-Object System.Data.SqlClient.SqlCommand($Query, $connection)
        $result = $command.ExecuteNonQuery()
        
        $connection.Close()
        return $true
    } catch {
        Write-ColorMessage "SQL 執行錯誤: $_" -Color $ErrorColor
        return $false
    }
}

# 函數：執行 SQL 腳本檔案
function Invoke-SqlScript {
    param(
        [string]$ServerInstance,
        [string]$ScriptPath,
        [string]$Username = $null,
        [string]$Password = $null
    )
    
    try {
        Write-ColorMessage "執行 SQL 腳本: $(Split-Path $ScriptPath -Leaf)" -Color $InfoColor
        
        # 讀取腳本內容
        $scriptContent = Get-Content $ScriptPath -Raw -Encoding UTF8
        
        # 分割成批次執行
        $batches = $scriptContent -split "GO\r?\n"
        
        # 建立連線字串
        if ($Username -and $Password) {
            $connectionString = "Server=$ServerInstance;Integrated Security=false;User Id=$Username;Password=$Password;Connection Timeout=60"
        } else {
            $connectionString = "Server=$ServerInstance;Integrated Security=true;Connection Timeout=60"
        }
        
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        
        $successCount = 0
        $totalCount = $batches.Count
        
        foreach ($batch in $batches) {
            $trimmedBatch = $batch.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmedBatch)) {
                continue
            }
            
            try {
                $command = New-Object System.Data.SqlClient.SqlCommand($trimmedBatch, $connection)
                $command.CommandTimeout = 300  # 5分鐘超時
                $command.ExecuteNonQuery() | Out-Null
                $successCount++
                
                # 顯示進度
                $progress = [math]::Round(($successCount / $totalCount) * 100)
                Write-Progress -Activity "執行 SQL 腳本" -Status "進度: $progress%" -PercentComplete $progress
            } catch {
                Write-ColorMessage "批次執行錯誤: $_" -Color $WarningColor
                # 繼續執行下一個批次
            }
        }
        
        $connection.Close()
        Write-Progress -Activity "執行 SQL 腳本" -Completed
        Write-ColorMessage "✅ SQL 腳本執行完成 ($successCount/$totalCount 批次成功)" -Color $SuccessColor
        return $true
    } catch {
        Write-ColorMessage "❌ SQL 腳本執行失敗: $_" -Color $ErrorColor
        return $false
    }
}

# 函數：驗證安裝
function Test-Installation {
    param([string]$ServerInstance, [string]$DatabaseName)
    
    Write-ColorMessage "`n🔍 驗證安裝..." -Color $InfoColor
    
    $tests = @(
        @{Name = "檢查資料庫存在"; Query = "SELECT COUNT(*) FROM sys.databases WHERE name = '$DatabaseName'"; Expected = 1},
        @{Name = "檢查 schedules 資料表"; Query = "USE $DatabaseName; SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'schedules'"; Expected = 1},
        @{Name = "檢查 execution_logs 資料表"; Query = "USE $DatabaseName; SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'execution_logs'"; Expected = 1},
        @{Name = "檢查儲存程序"; Query = "USE $DatabaseName; SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE = 'PROCEDURE' AND SPECIFIC_NAME LIKE 'sp_%'"; Expected = 3}
    )
    
    $allPassed = $true
    
    foreach ($test in $tests) {
        try {
            $connectionString = "Server=$ServerInstance;Integrated Security=true;Connection Timeout=10"
            $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
            $connection.Open()
            
            $command = New-Object System.Data.SqlClient.SqlCommand($test.Query, $connection)
            $result = $command.ExecuteScalar()
            
            $connection.Close()
            
            if ($result -eq $test.Expected) {
                Write-ColorMessage "✅ $($test.Name)" -Color $SuccessColor
            } else {
                Write-ColorMessage "❌ $($test.Name) (預期: $($test.Expected), 實際: $result)" -Color $ErrorColor
                $allPassed = $false
            }
        } catch {
            Write-ColorMessage "❌ $($test.Name) (錯誤: $_)" -Color $ErrorColor
            $allPassed = $false
        }
    }
    
    return $allPassed
}

# 主程式開始
Write-ColorMessage "============================================" -Color $InfoColor
Write-ColorMessage "    SecretaryDB 部署腳本" -Color $InfoColor
Write-ColorMessage "============================================" -Color $InfoColor

# 顯示參數
Write-ColorMessage "`n部署設定：" -Color $InfoColor
Write-ColorMessage "  SQL 實例: $SqlInstance" -Color $InfoColor
Write-ColorMessage "  資料庫名稱: $DatabaseName" -Color $InfoColor
Write-ColorMessage "  使用者名稱: $Username" -Color $InfoColor
Write-ColorMessage "  密碼: $Password" -Color $InfoColor
Write-ColorMessage "  測試模式: $TestOnly" -Color $InfoColor

# 確認繼續
if (-not $Force) {
    Write-ColorMessage "`n⚠️  即將部署 SecretaryDB 資料庫，請確認：" -Color $WarningColor
    Write-ColorMessage "  1. SQL Server 正在執行" -Color $WarningColor
    Write-ColorMessage "  2. 您有足夠的權限" -Color $WarningColor
    Write-ColorMessage "  3. 資料庫 $DatabaseName 不存在或可以覆寫" -Color $WarningColor
    
    $confirmation = Read-Host "`n是否繼續？(Y/N)"
    if ($confirmation -ne "Y" -and $confirmation -ne "y") {
        Write-ColorMessage "部署已取消" -Color $WarningColor
        exit 0
    }
}

# 測試模式：只驗證連線
if ($TestOnly) {
    Write-ColorMessage "`n🔍 測試模式..." -Color $InfoColor
    $connectionTest = Test-SqlConnection -ServerInstance $SqlInstance
    if ($connectionTest) {
        Write-ColorMessage "✅ 連線測試通過" -Color $SuccessColor
    } else {
        Write-ColorMessage "❌ 連線測試失敗" -Color $ErrorColor
    }
    exit 0
}

# 步驟 1：檢查 SQL Server 連線
Write-ColorMessage "`n步驟 1：檢查 SQL Server 連線..." -Color $InfoColor
$connectionTest = Test-SqlConnection -ServerInstance $SqlInstance
if (-not $connectionTest) {
    Write-ColorMessage "❌ 部署中止：無法連線到 SQL Server" -Color $ErrorColor
    exit 1
}

# 步驟 2：執行資料庫設定腳本
Write-ColorMessage "`n步驟 2：執行資料庫設定腳本..." -Color $InfoColor
$scriptPath = Join-Path $PSScriptRoot "database_setup.sql"
if (-not (Test-Path $scriptPath)) {
    Write-ColorMessage "❌ 找不到 database_setup.sql 檔案" -Color $ErrorColor
    exit 1
}

$scriptResult = Invoke-SqlScript -ServerInstance $SqlInstance -ScriptPath $scriptPath
if (-not $scriptResult) {
    Write-ColorMessage "❌ 資料庫設定失敗" -Color $ErrorColor
    exit 1
}

# 步驟 3：驗證安裝
Write-ColorMessage "`n步驟 3：驗證安裝..." -Color $InfoColor
$validationResult = Test-Installation -ServerInstance $SqlInstance -DatabaseName $DatabaseName

if ($validationResult) {
    # 顯示成功訊息
    Write-ColorMessage "`n============================================" -Color $SuccessColor
    Write-ColorMessage "✅ SecretaryDB 部署成功！" -Color $SuccessColor
    Write-ColorMessage "============================================" -Color $SuccessColor
    
    Write-ColorMessage "`n📊 部署摘要：" -Color $InfoColor
    Write-ColorMessage "  資料庫名稱: $DatabaseName" -Color $InfoColor
    Write-ColorMessage "  使用者帳號: $Username" -Color $InfoColor
    Write-ColorMessage "  密碼: $Password" -Color $InfoColor
    
    Write-ColorMessage "`n🔗 連接字串：" -Color $InfoColor
    Write-ColorMessage "  Server=$SqlInstance;Database=$DatabaseName;User Id=$Username;Password=$Password;" -Color $InfoColor
    
    Write-ColorMessage "`n📋 下一步：" -Color $InfoColor
    Write-ColorMessage "  1. 在 n8n 中設定 Microsoft SQL 節點" -Color $InfoColor
    Write-ColorMessage "  2. 使用上述連接字串" -Color $InfoColor
    Write-ColorMessage "  3. 測試資料庫連線" -Color $InfoColor
    Write-ColorMessage "  4. 導入 AI_Secretary_enhanced_B1_complete_v1.json" -Color $InfoColor
    
    # 建立 n8n 設定範例
    $n8nConfig = @"
// n8n Microsoft SQL 節點設定範例
{
  "host": "$SqlInstance",
  "database": "$DatabaseName",
  "user": "$Username",
  "password": "$Password",
  "port": 1433,
  "connectionTimeout": 30000
}
"@
    
    $configPath = Join-Path $PSScriptRoot "n8n_sql_config.json"
    $n8nConfig | Out-File -FilePath $configPath -Encoding UTF8
    Write-ColorMessage "`n💾 已建立 n8n 設定範例：$(Split-Path $configPath -Leaf)" -Color $SuccessColor
    
} else {
    Write-ColorMessage "`n❌ 部署驗證失敗，請檢查錯誤訊息" -Color $ErrorColor
    exit 1
}

Write-ColorMessage "`n✨ 部署完成！" -Color $SuccessColor