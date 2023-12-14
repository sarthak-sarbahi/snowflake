-- Using the ACCOUNTADMIN role for creating warehouse
USE ROLE ACCOUNTADMIN;

-- Create warehouse (compute) required to perform operations
CREATE OR REPLACE WAREHOUSE COMPUTE_WAREHOUSE
WITH 
WAREHOUSE_SIZE = XSMALL
AUTO_SUSPEND = 300
AUTO_RESUME = TRUE
INITIALLY_SUSPENDED = TRUE

-- Create storage integration to read data from GCP cloud storage
CREATE STORAGE INTEGRATION gcp_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = GCS
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = ('gcs://scd-snowflake/');

-- View the properties of the storage integration
DESC STORAGE integration gcp_integration;

-- Create database and schema
CREATE OR REPLACE DATABASE DEMO_DB;
CREATE OR REPLACE SCHEMA DEMO_SCHEMA;

-- Create stage object
CREATE OR REPLACE stage DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    URL = 'gcs://scd-snowflake/'
    STORAGE_INTEGRATION = gcp_integration

-- View the contents of the cloud storage bucket using storage integration 
LIST @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE;

-- Create table in snowflake
CREATE OR REPLACE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS (
    item_serial_number INT,
    item_name VARCHAR(20),
    country_of_origin VARCHAR(15)
);

-- Create a staging table for data loading
CREATE OR REPLACE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING (
    item_serial_number INT,
    item_name VARCHAR(20),
    country_of_origin VARCHAR(15)
);

-- Create a stream object to capture changes to ITEMS_STAGING table
CREATE OR REPLACE STREAM DEMO_DB.DEMO_SCHEMA.ITEMS_STREAM ON TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING;

-- Validate the copy command to catch any errors if present (no data is loaded) 
COPY INTO DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING
    FROM @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('household_items.csv')
    VALIDATION_MODE = RETURN_ERRORS;

-- Rerun COPY command without validation mode to load data in staging table
COPY INTO DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING
    FROM @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('household_items.csv')
    ON_ERROR = 'CONTINUE';    

-- View staging table contents
SELECT * FROM DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING;

-- View stream contents
SELECT * FROM DEMO_DB.DEMO_SCHEMA.ITEMS_STREAM;

-- Insert data in final table by consuming stream (stream is empty after consumption)
INSERT INTO DEMO_DB.DEMO_SCHEMA.ITEMS SELECT ITEM_SERIAL_NUMBER, ITEM_NAME, COUNTRY_OF_ORIGIN FROM DEMO_DB.DEMO_SCHEMA.ITEMS_STREAM;

-- View final table contents
SELECT * FROM DEMO_DB.DEMO_SCHEMA.ITEMS;

-- SCD Type 0 -- 
-- Changes in data do not impact the dimensions in table. For instance if the country of origin for 'Toaster' is changed to Mexico from USA, we do not make any changes in the data.

-- SCD Type 1 --
-- Using validation mode we get notified of records with error
COPY INTO DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING
    FROM @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('household_items_error.csv')
    VALIDATION_MODE = RETURN_ERRORS;  
-- Create a table to store error records
CREATE OR REPLACE TABLE DEMO_DB.DEMO_SCHEMA.REJECTED_RECORDS (
    rejected_record TEXT
);
-- Insert error records in a separate table
INSERT INTO DEMO_DB.DEMO_SCHEMA.REJECTED_RECORDS SELECT rejected_record FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
-- View rejected records
SELECT * FROM DEMO_DB.DEMO_SCHEMA.REJECTED_RECORDS;
-- Load data and ignore error records
COPY INTO DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING
    FROM @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('household_items_error.csv')
    ON_ERROR = 'CONTINUE';  
-- Perform UPSERT (update and insert)
MERGE INTO DEMO_DB.DEMO_SCHEMA.ITEMS AS I
USING DEMO_DB.DEMO_SCHEMA.ITEMS_STREAM AS S
ON I.item_serial_number = S.item_serial_number
WHEN MATCHED THEN 
    UPDATE SET I.country_of_origin = S.country_of_origin
WHEN NOT MATCHED THEN
    INSERT (item_serial_number, item_name, country_of_origin) VALUES (S.item_serial_number, S.item_name, S.country_of_origin);
-- Now required column is overwritten
SELECT * FROM DEMO_DB.DEMO_SCHEMA.ITEMS;
-- Truncate staging table
TRUNCATE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING;

-- SCD Type 2 --
-- Create a new final table
CREATE OR REPLACE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_HIST (
    item_serial_number INT,
    item_name VARCHAR(20),
    country_of_origin VARCHAR(15),
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    feed_key VARCHAR(20) DEFAULT TO_VARCHAR(DATE_PART('YEAR', CURRENT_TIMESTAMP), 'FM0000')||TO_VARCHAR(DATE_PART('MONTH', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('DAY', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('HOUR', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('MINUTE', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('SECOND', CURRENT_TIMESTAMP), 'FM00'),
    crnt_flag INT DEFAULT 1
);
-- Create a staging table for data loading
CREATE OR REPLACE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING (
    item_serial_number INT,
    item_name VARCHAR(20),
    country_of_origin VARCHAR(15)
);
-- Create a stream object to capture changes to ITEMS table
CREATE OR REPLACE STREAM DEMO_DB.DEMO_SCHEMA.ITEMS_STREAM ON TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING;
-- Insert first batch in staging table
COPY INTO DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING
    FROM @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('household_items.csv')
    ON_ERROR = 'CONTINUE';
-- Insert into final table (Step 1)
MERGE INTO DEMO_DB.DEMO_SCHEMA.ITEMS_HIST AS I
USING DEMO_DB.DEMO_SCHEMA.ITEMS_STREAM AS S
ON I.item_serial_number = S.item_serial_number
WHEN MATCHED AND S.METADATA$ACTION = 'INSERT' THEN 
    UPDATE SET I.crnt_flag = 0
WHEN NOT MATCHED AND S.METADATA$ACTION = 'INSERT' THEN
    INSERT (item_serial_number, item_name, country_of_origin) VALUES (S.item_serial_number, S.item_name, S.country_of_origin);
-- Insert into final table (Step 2)
INSERT INTO DEMO_DB.DEMO_SCHEMA.ITEMS_HIST 
SELECT 
    item_serial_number, 
    item_name, 
    country_of_origin, 
    CURRENT_TIMESTAMP AS ingestion_timestamp,
    TO_VARCHAR(DATE_PART('YEAR', CURRENT_TIMESTAMP), 'FM0000')||TO_VARCHAR(DATE_PART('MONTH', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('DAY', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('HOUR', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('MINUTE', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('SECOND', CURRENT_TIMESTAMP), 'FM00') AS feed_key,
    1 AS crnt_flag
FROM DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING 
WHERE item_serial_number IN (SELECT DISTINCT(item_serial_number) FROM DEMO_DB.DEMO_SCHEMA.ITEMS_HIST WHERE crnt_flag = 0); 
-- Truncate staging table
TRUNCATE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING;
-- View data in final table
SELECT * FROM DEMO_DB.DEMO_SCHEMA.ITEMS_HIST ORDER BY item_serial_number;
-- Insert next batch of records in staging table
COPY INTO DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING
    FROM @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('household_items_error.csv')
    ON_ERROR = 'CONTINUE';

-- SCD Type 3 --
-- Create a fresj final table
CREATE OR REPLACE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS (
    item_serial_number INT,
    item_name VARCHAR(20),
    country_of_origin_current VARCHAR(15),
    country_of_origin_previous VARCHAR(15)
);
-- Create a staging table for data loading
CREATE OR REPLACE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING (
    item_serial_number INT,
    item_name VARCHAR(20),
    country_of_origin VARCHAR(15)
);
-- Create a stream object to capture changes to ITEMS table
CREATE OR REPLACE STREAM DEMO_DB.DEMO_SCHEMA.ITEMS_STREAM ON TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING;
-- Insert first batch in staging table
COPY INTO DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING
    FROM @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('household_items.csv')
    ON_ERROR = 'CONTINUE';
-- Insert data in final table
MERGE INTO DEMO_DB.DEMO_SCHEMA.ITEMS AS I
USING DEMO_DB.DEMO_SCHEMA.ITEMS_STREAM AS S
ON I.item_serial_number = S.item_serial_number
WHEN MATCHED THEN 
    UPDATE SET 
    I.country_of_origin_current = S.country_of_origin,
    I.country_of_origin_previous = I.country_of_origin_current
WHEN NOT MATCHED THEN
    INSERT (item_serial_number, item_name, country_of_origin_current, country_of_origin_previous) VALUES (S.item_serial_number, S.item_name, S.country_of_origin, NULL);
-- View data in final table
SELECT * FROM DEMO_DB.DEMO_SCHEMA.ITEMS;
-- Load second batch of data in staging table
COPY INTO DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING
    FROM @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('household_items_error.csv')
    ON_ERROR = 'CONTINUE';
-- View data in final table
SELECT * FROM DEMO_DB.DEMO_SCHEMA.ITEMS;

-- SCD Type 4 --
-- Create final table that will only contain latest data
CREATE OR REPLACE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_LATEST (
    item_serial_number INT,
    item_name VARCHAR(20),
    country_of_origin VARCHAR(15)
);
-- Create final table that will contain historical data
CREATE OR REPLACE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_HIST (
    item_serial_number INT,
    item_name VARCHAR(20),
    country_of_origin VARCHAR(15),
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    feed_key VARCHAR(20) DEFAULT TO_VARCHAR(DATE_PART('YEAR', CURRENT_TIMESTAMP), 'FM0000')||TO_VARCHAR(DATE_PART('MONTH', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('DAY', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('HOUR', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('MINUTE', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('SECOND', CURRENT_TIMESTAMP), 'FM00')
);
-- Create a staging table for data loading
CREATE OR REPLACE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING (
    item_serial_number INT,
    item_name VARCHAR(20),
    country_of_origin VARCHAR(15)
);
-- Create a stream object to capture changes to ITEMS table
CREATE OR REPLACE STREAM DEMO_DB.DEMO_SCHEMA.ITEMS_STREAM ON TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING;
-- Insert first batch in staging table
COPY INTO DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING
    FROM @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('household_items.csv')
    ON_ERROR = 'CONTINUE';
-- Perform upsert in latest final latest table
MERGE INTO DEMO_DB.DEMO_SCHEMA.ITEMS_LATEST AS I
USING DEMO_DB.DEMO_SCHEMA.ITEMS_STREAM AS S
ON I.item_serial_number = S.item_serial_number
WHEN MATCHED AND S.METADATA$ACTION = 'INSERT' THEN 
    UPDATE SET I.country_of_origin = S.country_of_origin
WHEN NOT MATCHED AND S.METADATA$ACTION = 'INSERT' THEN
    INSERT (item_serial_number, item_name, country_of_origin) VALUES (S.item_serial_number, S.item_name, S.country_of_origin);
-- Insert data in historical table 
INSERT INTO DEMO_DB.DEMO_SCHEMA.ITEMS_HIST 
SELECT 
    item_serial_number, 
    item_name, 
    country_of_origin,
    CURRENT_TIMESTAMP AS ingestion_timestamp,
    TO_VARCHAR(DATE_PART('YEAR', CURRENT_TIMESTAMP), 'FM0000')||TO_VARCHAR(DATE_PART('MONTH', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('DAY', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('HOUR', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('MINUTE', CURRENT_TIMESTAMP), 'FM00')||TO_VARCHAR(DATE_PART('SECOND', CURRENT_TIMESTAMP), 'FM00') AS feed_key
FROM DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING;
-- Cleanup staging table
TRUNCATE TABLE DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING;
-- View data in latest table
SELECT * FROM DEMO_DB.DEMO_SCHEMA.ITEMS_LATEST ORDER BY item_serial_number;
-- View data in historical table
SELECT * FROM DEMO_DB.DEMO_SCHEMA.ITEMS_HIST ORDER BY item_serial_number;
-- Load second batch of data in staging table
COPY INTO DEMO_DB.DEMO_SCHEMA.ITEMS_STAGING
    FROM @DEMO_DB.DEMO_SCHEMA.DEMO_STAGE
    file_format= (type = csv field_delimiter=',' skip_header=1)
    files = ('household_items_error.csv')
    ON_ERROR = 'CONTINUE';

-- SCD Type 6 --
-- This is simply a combination of 1,2 and 3 

-- Auditing
-- History of all COPY commands
USE DEMO_DB;
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.LOAD_HISTORY WHERE schema_name = 'DEMO_SCHEMA' ORDER BY LAST_LOAD_TIME DESC;