-- Create Reader Account --
CREATE MANAGED ACCOUNT tech_joy_account
ADMIN_NAME = tech_joy_admin,
ADMIN_PASSWORD = 'set-pwd',
TYPE = READER;

-- Make sure to have selected the role of accountadmin
--Show accounts
SHOW MANAGED ACCOUNTS;

-- Share the data -- 
ALTER SHARE ORDERS_SHARE 
ADD ACCOUNT = <reader-account-id>; -- locator from SHOW MANAGED ACCOUNTS

ALTER SHARE ORDERS_SHARE 
ADD ACCOUNT =  <reader-account-id>
SHARE_RESTRICTIONS=false;

-- Create database from share --
-- Show all shares (consumer & producers)
SHOW SHARES;

-- See details on share
DESC SHARE <share_name>.ORDERS_SHARE;

-- Create a database in consumer account using the share
CREATE DATABASE DATA_SHARE_DB FROM SHARE <account_name_producer>.ORDERS_SHARE;

-- Validate table access
SELECT * FROM  DATA_SHARE_DB.PUBLIC.ORDERS

-- Setup virtual warehouse
CREATE WAREHOUSE READ_WH WITH
WAREHOUSE_SIZE='X-SMALL'
AUTO_SUSPEND = 180
AUTO_RESUME = TRUE
INITIALLY_SUSPENDED = TRUE;

-- Create and set up users --

-- Create user
CREATE USER MYRIAM PASSWORD = 'difficult_passw@ord=123'

-- Grant usage on warehouse
GRANT USAGE ON WAREHOUSE READ_WH TO ROLE PUBLIC;

-- Grating privileges on a Shared Database for other users
GRANT IMPORTED PRIVILEGES ON DATABASE DATA_SHARE_DB TO ROLE PUBLIC;

-- sharing multiple tables --
SHOW SHARES;

-- Create share object
CREATE OR REPLACE SHARE COMEPLETE_SCHEMA_SHARE;

-- Grant usage on dabase & schema
GRANT USAGE ON DATABASE OUR_FIRST_DB TO SHARE COMEPLETE_SCHEMA_SHARE;
GRANT USAGE ON SCHEMA OUR_FIRST_DB.PUBLIC TO SHARE COMEPLETE_SCHEMA_SHARE;

-- Grant select on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA OUR_FIRST_DB.PUBLIC TO SHARE COMEPLETE_SCHEMA_SHARE;
GRANT SELECT ON ALL TABLES IN DATABASE OUR_FIRST_DB TO SHARE COMEPLETE_SCHEMA_SHARE;

-- Add account to share
ALTER SHARE COMEPLETE_SCHEMA_SHARE
ADD ACCOUNT=;

-- Updating data
UPDATE OUR_FIRST_DB.PUBLIC.ORDERS
SET PROFIT=0 WHERE PROFIT < 0;

-- Add new table
CREATE TABLE OUR_FIRST_DB.PUBLIC.NEW_TABLE (ID int);



