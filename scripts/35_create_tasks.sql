CREATE OR REPLACE TRANSIENT DATABASE TASK_DB;

-- Prepare table
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID INT AUTOINCREMENT START = 1 INCREMENT =1,
    FIRST_NAME VARCHAR(40) DEFAULT 'JENNIFER' ,
    CREATE_DATE DATE)
    
-- Create task
CREATE OR REPLACE TASK CUSTOMER_INSERT
    WAREHOUSE = COMPUTE_WH -- compute warehouse
    SCHEDULE = '1 MINUTE' -- schedule frequency (every 1 minute) 
    AS 
    INSERT INTO CUSTOMERS(CREATE_DATE) VALUES(CURRENT_TIMESTAMP); -- what the task will do?
    
SHOW TASKS;

-- Task starting and suspending
ALTER TASK CUSTOMER_INSERT RESUME; -- start the task
ALTER TASK CUSTOMER_INSERT SUSPEND; -- stop the task

SELECT * FROM CUSTOMERS

------CRON------
CREATE OR REPLACE TASK CUSTOMER_INSERT
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 7,10 * * 5L UTC'
    AS 
    INSERT INTO CUSTOMERS(CREATE_DATE) VALUES(CURRENT_TIMESTAMP);
    
-- # __________ minute (0-59)
-- # | ________ hour (0-23)
-- # | | ______ day of month (1-31, or L)
-- # | | | ____ month (1-12, JAN-DEC)
-- # | | | | __ day of week (0-6, SUN-SAT, or L)
-- # | | | | |
-- # | | | | |
-- # * * * * *

-- Every minute
SCHEDULE = 'USING CRON * * * * * UTC'

-- Every day at 6am UTC timezone
SCHEDULE = 'USING CRON 0 6 * * * UTC'

-- Every hour starting at 9 AM and ending at 5 PM on Sundays 
SCHEDULE = 'USING CRON 0 9-17 * * SUN America/Los_Angeles'

CREATE OR REPLACE TASK CUSTOMER_INSERT
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 9,17 * * * UTC'
    AS 
    INSERT INTO CUSTOMERS(CREATE_DATE) VALUES(CURRENT_TIMESTAMP);