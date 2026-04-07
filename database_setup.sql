-- ============================================
-- SecretaryDB 資料庫設定腳本
-- 適用於 SQL Server 2016+
-- 最後更新：2026-04-07
-- ============================================

-- 步驟 1：建立資料庫
PRINT '步驟 1：建立 SecretaryDB 資料庫...';
CREATE DATABASE SecretaryDB;
GO

USE SecretaryDB;
GO

-- ============================================
-- 步驟 2：建立資料表
-- ============================================

PRINT '步驟 2：建立 schedules 排程記錄表...';
CREATE TABLE schedules (
    id INT IDENTITY(1,1) PRIMARY KEY,
    record_uuid UNIQUEIDENTIFIER DEFAULT NEWID(),
    original_message NVARCHAR(MAX) NOT NULL,
    schedule_time DATETIME2 NOT NULL,
    task_type NVARCHAR(50) NOT NULL,
    task_parameters NVARCHAR(MAX),
    task_description NVARCHAR(500),
    parsed_intent NVARCHAR(MAX),
    
    -- 用戶資訊
    user_id NVARCHAR(100),
    user_name NVARCHAR(200),
    channel_id NVARCHAR(200),
    
    -- 執行控制
    handler_agent NVARCHAR(100) DEFAULT 'AI Agent2',
    timeout_seconds INT DEFAULT 300,
    priority_level INT DEFAULT 5,
    
    -- 狀態追蹤
    status NVARCHAR(50) DEFAULT 'pending',
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    executed_at DATETIME2,
    completed_at DATETIME2,
    
    -- 結果記錄
    execution_result NVARCHAR(MAX),
    error_message NVARCHAR(MAX)
);
GO

PRINT '步驟 3：建立 execution_logs 執行日誌表...';
CREATE TABLE execution_logs (
    id INT IDENTITY(1,1) PRIMARY KEY,
    schedule_id INT NOT NULL,
    execution_time DATETIME2 DEFAULT GETDATE(),
    status NVARCHAR(50) NOT NULL,
    log_message NVARCHAR(500),
    error_details NVARCHAR(MAX),
    handler_agent NVARCHAR(100),
    execution_duration_ms INT
);
GO

-- ============================================
-- 步驟 3：建立索引
-- ============================================

PRINT '步驟 4：建立索引...';
CREATE INDEX idx_schedule_time ON schedules(schedule_time);
CREATE INDEX idx_status ON schedules(status);
CREATE INDEX idx_user_id ON schedules(user_id);
CREATE INDEX idx_task_type ON schedules(task_type);
CREATE INDEX idx_schedule_id ON execution_logs(schedule_id);
CREATE INDEX idx_execution_time ON execution_logs(execution_time);
CREATE INDEX idx_log_status ON execution_logs(status);
GO

-- ============================================
-- 步驟 4：建立外鍵約束
-- ============================================

PRINT '步驟 5：建立外鍵約束...';
ALTER TABLE execution_logs 
ADD CONSTRAINT fk_execution_logs_schedules 
FOREIGN KEY (schedule_id) 
REFERENCES schedules(id) 
ON DELETE CASCADE;
GO

-- ============================================
-- 步驟 5：建立觸發器
-- ============================================

PRINT '步驟 6：建立自動更新觸發器...';
CREATE TRIGGER trg_schedules_update
ON schedules
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE schedules
    SET updated_at = GETDATE()
    FROM inserted
    WHERE schedules.id = inserted.id;
END;
GO

-- ============================================
-- 步驟 6：建立儲存程序
-- ============================================

PRINT '步驟 7：建立儲存程序...';

-- sp_get_pending_schedules：取得待執行排程
CREATE PROCEDURE sp_get_pending_schedules
    @limit INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@limit)
        id,
        record_uuid,
        schedule_time,
        task_type,
        task_parameters,
        task_description,
        user_id,
        user_name,
        channel_id,
        handler_agent,
        timeout_seconds,
        priority_level
    FROM schedules
    WHERE status = 'pending'
        AND schedule_time <= GETDATE()
        AND (executed_at IS NULL OR DATEDIFF(MINUTE, executed_at, GETDATE()) > 5)
    ORDER BY 
        priority_level ASC,
        schedule_time ASC;
END;
GO

-- sp_update_schedule_status：更新排程狀態
CREATE PROCEDURE sp_update_schedule_status
    @schedule_id INT,
    @new_status NVARCHAR(50),
    @execution_result NVARCHAR(MAX) = NULL,
    @error_message NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @now DATETIME2 = GETDATE();
    DECLARE @handler_agent NVARCHAR(100);
    
    -- 取得 handler_agent
    SELECT @handler_agent = handler_agent
    FROM schedules
    WHERE id = @schedule_id;
    
    -- 更新排程狀態
    UPDATE schedules
    SET 
        status = @new_status,
        execution_result = @execution_result,
        error_message = @error_message,
        updated_at = @now,
        executed_at = CASE WHEN @new_status = 'executing' THEN @now ELSE executed_at END,
        completed_at = CASE WHEN @new_status IN ('completed', 'failed', 'cancelled') THEN @now ELSE completed_at END
    WHERE id = @schedule_id;
    
    -- 記錄到日誌表
    IF @new_status IN ('executing', 'completed', 'failed')
    BEGIN
        INSERT INTO execution_logs (
            schedule_id,
            status,
            log_message,
            error_details,
            handler_agent,
            execution_time
        )
        VALUES (
            @schedule_id,
            @new_status,
            CASE 
                WHEN @new_status = 'executing' THEN '開始執行任務'
                WHEN @new_status = 'completed' THEN '任務執行完成'
                WHEN @new_status = 'failed' THEN '任務執行失敗'
                ELSE '狀態更新'
            END,
            CASE 
                WHEN @new_status = 'failed' AND @error_message IS NOT NULL 
                THEN JSON_QUERY('{"error_message":"' + @error_message + '"}')
                ELSE NULL 
            END,
            @handler_agent,
            @now
        );
    END
END;
GO

-- sp_insert_schedule：插入新排程
CREATE PROCEDURE sp_insert_schedule
    @original_message NVARCHAR(MAX),
    @schedule_time DATETIME2,
    @task_type NVARCHAR(50),
    @task_parameters NVARCHAR(MAX),
    @task_description NVARCHAR(500),
    @parsed_intent NVARCHAR(MAX),
    @user_id NVARCHAR(100) = NULL,
    @user_name NVARCHAR(200) = NULL,
    @channel_id NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO schedules (
        original_message,
        schedule_time,
        task_type,
        task_parameters,
        task_description,
        parsed_intent,
        user_id,
        user_name,
        channel_id,
        status,
        created_at,
        updated_at
    )
    VALUES (
        @original_message,
        @schedule_time,
        @task_type,
        @task_parameters,
        @task_description,
        @parsed_intent,
        @user_id,
        @user_name,
        @channel_id,
        'pending',
        GETDATE(),
        GETDATE()
    );
    
    SELECT SCOPE_IDENTITY() AS new_schedule_id;
END;
GO

-- ============================================
-- 步驟 7：建立資料庫使用者
-- ============================================

PRINT '步驟 8：建立資料庫使用者...';
CREATE LOGIN secretary_user WITH PASSWORD = 'SecretaryDB@2026';
CREATE USER secretary_user FOR LOGIN secretary_user;

-- 授予權限
GRANT EXECUTE ON sp_insert_schedule TO secretary_user;
GRANT EXECUTE ON sp_get_pending_schedules TO secretary_user;
GRANT EXECUTE ON sp_update_schedule_status TO secretary_user;
GRANT SELECT, INSERT, UPDATE ON schedules TO secretary_user;
GRANT SELECT, INSERT ON execution_logs TO secretary_user;
GO

-- ============================================
-- 步驟 8：插入測試資料
-- ============================================

PRINT '步驟 9：插入測試資料...';

-- 測試排程 1：查詢工單
EXEC sp_insert_schedule 
    @original_message = '明天下午三點查詢 Class 1 工單',
    @schedule_time = DATEADD(DAY, 1, CONVERT(DATETIME2, CONVERT(DATE, GETDATE())) + '15:00:00'),
    @task_type = 'query_ticket',
    @task_parameters = '{"class_level": "Class 1", "status": "open", "date_range": {"days": 7}}',
    @task_description = '查詢 Class 1 未結工單',
    @parsed_intent = '{"intent": "query_ticket", "parameters": {"time": "' + CONVERT(NVARCHAR(50), DATEADD(DAY, 1, GETDATE()), 126) + '", "class_level": "Class 1"}, "confidence": 0.95}',
    @user_id = '6993952262',
    @user_name = 'Bird Parrot',
    @channel_id = '19:Sox62wdO17L8xais5cZjhDSMiEXNsni9syXcI0-ZKLM1@thread.tacv2';

-- 測試排程 2：提醒
EXEC sp_insert_schedule 
    @original_message = '兩小時後提醒我開會',
    @schedule_time = DATEADD(HOUR, 2, GETDATE()),
    @task_type = 'reminder',
    @task_parameters = '{"meeting_topic": "專案進度會議", "duration_minutes": 60}',
    @task_description = '專案進度會議提醒',
    @parsed_intent = '{"intent": "reminder", "time_offset_hours": 2}',
    @user_id = '6993952262',
    @user_name = 'Bird Parrot',
    @channel_id = '19:Sox62wdO17L8xais5cZjhDSMiEXNsni9syXcI0-ZKLM1@thread.tacv2';

-- ============================================
-- 步驟 9：驗證安裝
-- ============================================

PRINT '步驟 10：驗證安裝...';

-- 檢查資料表
SELECT 
    TABLE_NAME,
    COUNT(*) as column_count
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'dbo' 
    AND TABLE_NAME IN ('schedules', 'execution_logs')
GROUP BY TABLE_NAME;

-- 檢查儲存程序
SELECT 
    SPECIFIC_NAME as stored_procedure
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE ROUTINE_TYPE = 'PROCEDURE' 
    AND SPECIFIC_NAME LIKE 'sp_%';

-- 測試待執行排程查詢
EXEC sp_get_pending_schedules @limit = 5;

-- ============================================
-- 完成訊息
-- ============================================

PRINT '============================================';
PRINT '✅ SecretaryDB 資料庫設定完成！';
PRINT '============================================';
PRINT '資料庫名稱：SecretaryDB';
PRINT '使用者帳號：secretary_user';
PRINT '密碼：SecretaryDB@2026';
PRINT '連接字串範例：';
PRINT 'Server=localhost;Database=SecretaryDB;User Id=secretary_user;Password=SecretaryDB@2026;';
PRINT '============================================';
GO