-- ============================================================
-- jobs_schedule.sql
-- Daily SQL Server Agent job: Bronze -> Silver -> Gold
--
-- One-time DDL prerequisites:
--   SQL/Bronze/ddl_bronze_tables.sql
--   SQL/Silver/ddl_silver_tables.sql
--   SQL/Gold/ddl_gold_tables.sql
--
-- Run once to create the job. If the job already exists, delete it first.
-- ============================================================

USE msdb;
GO

-- ============================================================
-- STEP 1: Create Job
-- ============================================================
EXEC sp_add_job
    @job_name        = N'SocomDW_DailyLoad',
    @enabled         = 1,
    @description     = N'Daily load: Bronze (CSV) -> Silver -> Gold physical tables with stable surrogate keys.',
    @notify_level_eventlog = 2;   -- write to event log on failure
GO

-- ============================================================
-- STEP 2: Add Step 1 - Load Bronze
-- ============================================================
EXEC sp_add_jobstep
    @job_name        = N'SocomDW_DailyLoad',
    @step_name       = N'1. Load Bronze',
    @step_id         = 1,
    @subsystem       = N'TSQL',
    @database_name   = N'SocomDataWarehouse',
    @command         = N'EXEC bronze.sp_load_bronze;',
    @on_success_action = 3,       -- go to next step
    @on_fail_action    = 2;       -- quit with failure
GO

-- ============================================================
-- STEP 3: Add Step 2 - Load Silver
-- ============================================================
EXEC sp_add_jobstep
    @job_name        = N'SocomDW_DailyLoad',
    @step_name       = N'2. Load Silver',
    @step_id         = 2,
    @subsystem       = N'TSQL',
    @database_name   = N'SocomDataWarehouse',
    @command         = N'EXEC silver.sp_load_silver;',
    @on_success_action = 3,       -- go to next step
    @on_fail_action    = 2;       -- quit with failure
GO

-- ============================================================
-- STEP 4: Add Step 3 - Load Gold
-- ============================================================
EXEC sp_add_jobstep
    @job_name        = N'SocomDW_DailyLoad',
    @step_name       = N'3. Load Gold',
    @step_id         = 3,
    @subsystem       = N'TSQL',
    @database_name   = N'SocomDataWarehouse',
    @command         = N'EXEC gold.sp_load_gold;',
    @on_success_action = 1,       -- quit with success
    @on_fail_action    = 2;       -- quit with failure
GO

-- ============================================================
-- STEP 5: Attach Daily Schedule (02:00 AM)
-- ============================================================
EXEC sp_add_schedule
    @schedule_name       = N'Daily_2AM',
    @enabled             = 1,
    @freq_type           = 4,         -- daily
    @freq_interval       = 1,         -- every 1 day
    @active_start_time   = 020000,    -- 02:00:00
    @active_start_date   = 20260101;  -- change as needed
GO

EXEC sp_attach_schedule
    @job_name      = N'SocomDW_DailyLoad',
    @schedule_name = N'Daily_2AM';
GO

-- ============================================================
-- STEP 6: Register Job on Local SQL Agent
-- ============================================================
EXEC sp_add_jobserver
    @job_name   = N'SocomDW_DailyLoad',
    @server_name = N'(local)';
GO

PRINT 'Job SocomDW_DailyLoad created. Runs daily at 02:00 AM.';
PRINT 'Check in SQL Server Agent > Jobs > SocomDW_DailyLoad';
GO
