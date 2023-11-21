-- Create file format and stage object
CREATE OR REPLACE FILE FORMAT MANAGE_DB.FILE_FORMATS.PARQUET_FORMAT
    TYPE = 'parquet';
CREATE OR REPLACE STAGE MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
    url = 's3://snowflakeparquetdemo'   
    FILE_FORMAT = MANAGE_DB.FILE_FORMATS.PARQUET_FORMAT; -- need to be defined unless file format is CSV
    
-- Preview the data
LIST  @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;   
SELECT * FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;
    
-- File format in Queries
CREATE OR REPLACE STAGE MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
    url = 's3://snowflakeparquetdemo'  
SELECT * 
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
(file_format => 'MANAGE_DB.FILE_FORMATS.PARQUET_FORMAT') -- use this only if file format is not specified in stage object

-- Quotes can be omitted in case of the current namespace
USE MANAGE_DB.FILE_FORMATS;
SELECT * 
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
(file_format => MANAGE_DB.FILE_FORMATS.PARQUET_FORMAT)

CREATE OR REPLACE STAGE MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
    url = 's3://snowflakeparquetdemo'   
    FILE_FORMAT = MANAGE_DB.FILE_FORMATS.PARQUET_FORMAT;

-- Syntax for Querying unstructured data
-- use double quotes if there are spaces in names of columns
SELECT 
$1:__index_level_0__,
$1:cat_id,
$1:date,
$1:"__index_level_0__",
$1:"cat_id",
$1:"d",
$1:"date",
$1:"dept_id",
$1:"id",
$1:"item_id",
$1:"state_id",
$1:"store_id",
$1:"value"
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;

-- Date conversion
SELECT 1;
SELECT DATE(365*60*60*24);

-- Querying with conversions and aliases 
SELECT 
$1:__index_level_0__::int as index_level,
$1:cat_id::VARCHAR(50) as category,
DATE($1:date::int ) as Date,
$1:"dept_id"::VARCHAR(50) as Dept_ID,
$1:"id"::VARCHAR(50) as ID,
$1:"item_id"::VARCHAR(50) as Item_ID,
$1:"state_id"::VARCHAR(50) as State_ID,
$1:"store_id"::VARCHAR(50) as Store_ID,
$1:"value"::int as value
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;

-- Adding metadata
SELECT 
$1:__index_level_0__::int as index_level,
$1:cat_id::VARCHAR(50) as category,
DATE($1:date::int ) as Date,
$1:"dept_id"::VARCHAR(50) as Dept_ID,
$1:"id"::VARCHAR(50) as ID,
$1:"item_id"::VARCHAR(50) as Item_ID,
$1:"state_id"::VARCHAR(50) as State_ID,
$1:"store_id"::VARCHAR(50) as Store_ID,
$1:"value"::int as value,
METADATA$FILENAME as FILENAME, -- parquet file name
METADATA$FILE_ROW_NUMBER as ROWNUMBER, -- parquet file row number for record
TO_TIMESTAMP_NTZ(current_timestamp) as LOAD_DATE -- timestamp with no time zone
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;

SELECT TO_TIMESTAMP_NTZ(current_timestamp)

-- Create destination table
CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.PARQUET_DATA (
    ROW_NUMBER int,
    index_level int,
    cat_id VARCHAR(50),
    date date,
    dept_id VARCHAR(50),
    id VARCHAR(50),
    item_id VARCHAR(50),
    state_id VARCHAR(50),
    store_id VARCHAR(50),
    value int,
    Load_date timestamp default TO_TIMESTAMP_NTZ(current_timestamp) -- by default loads timestamp
    )

-- Load the parquet data
COPY INTO OUR_FIRST_DB.PUBLIC.PARQUET_DATA
    FROM (SELECT 
            METADATA$FILE_ROW_NUMBER,
            $1:__index_level_0__::int,
            $1:cat_id::VARCHAR(50),
            DATE($1:date::int ),
            $1:"dept_id"::VARCHAR(50),
            $1:"id"::VARCHAR(50),
            $1:"item_id"::VARCHAR(50),
            $1:"state_id"::VARCHAR(50),
            $1:"store_id"::VARCHAR(50),
            $1:"value"::int,
            TO_TIMESTAMP_NTZ(current_timestamp)
        FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE);
SELECT * FROM OUR_FIRST_DB.PUBLIC.PARQUET_DATA;