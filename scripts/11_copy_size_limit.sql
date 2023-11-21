-- SIZE_LIMIT: Specify max size in bytes of data loaded in that command (at least one file)
-- When threshold is exceeded, the COPY operation stops loading 

-- Prepare database & table
CREATE OR REPLACE DATABASE COPY_DB;
CREATE OR REPLACE TABLE  COPY_DB.PUBLIC.ORDERS (
    ORDER_ID VARCHAR(30),
    AMOUNT VARCHAR(30),
    PROFIT INT,
    QUANTITY INT,
    CATEGORY VARCHAR(30),
    SUBCATEGORY VARCHAR(30));
    
-- Prepare stage object
CREATE OR REPLACE STAGE COPY_DB.PUBLIC.aws_stage_copy
    url='s3://snowflakebucket-copyoption/size/';
    
-- List files in stage
LIST @aws_stage_copy;

-- Load data using copy command
-- if two files are being loaded and the first one exceeds the SIZE_LIMIT then first one gets loaded completely but second one does not get loaded
COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format= (type = csv field_delimiter=',' skip_header=1)
    pattern='.*Order.*'
    SIZE_LIMIT=20000; -- here 20000 accounts for total file size including all files