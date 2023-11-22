-- Create storage integration object: AWS S3 --
-- ideally requires ACCOUNTADMIN role
create or replace storage integration s3_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = S3
  ENABLED = TRUE 
  STORAGE_AWS_ROLE_ARN = '' -- get role ARN from IAM
  STORAGE_ALLOWED_LOCATIONS = ('s3://<your-bucket-name>/<your-path>/', 's3://<your-bucket-name>/<your-path>/') -- access to multiple buckets
   COMMENT = 'This an optional comment' 

-- See storage integration properties to fetch external_id so we can update it in S3
DESC integration s3_int;

-- Create stage object with integration object & file format object
CREATE OR REPLACE stage MANAGE_DB.external_stages.csv_folder
    URL = 's3://<your-bucket-name>/<your-path>/'
    STORAGE_INTEGRATION = s3_int
    FILE_FORMAT = MANAGE_DB.file_formats.csv_fileformat

-- Create file format object
CREATE OR REPLACE file format MANAGE_DB.file_formats.csv_fileformat
    type = csv
    field_delimiter = ','
    skip_header = 1
    null_if = ('NULL','null')
    empty_field_as_null = TRUE    
    FIELD_OPTIONALLY_ENCLOSED_BY = '"' -- if a value in a column has commas in it then the value can be enclosed with ""   

-- Create storage integration object: Azure Storage Account -- 
CREATE STORAGE INTEGRATION azure_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = AZURE
  ENABLED = TRUE
  AZURE_TENANT_ID = '' -- go to active directory to get tenant ID
  STORAGE_ALLOWED_LOCATIONS = ('azure://<account_name>.blob.core.windows.net/<container_name>', 'azure://<account_name>.blob.core.windows.net/<container_name>'); -- storage account name

-- Describe integration object to provide access
-- Click on AZURE_CONSENT_URL and provide required approval
-- Add role assigment to storage account (contributor), try to search for snowflake and a name should appear
DESC STORAGE integration azure_integration;  

-- create stage object
create or replace stage demo_db.public.stage_azure
    STORAGE_INTEGRATION = azure_integration
    URL = 'azure://storageaccountsnow.blob.core.windows.net/snowflakecsv'
    FILE_FORMAT = fileformat_azure;

-- Create storage integration object: GCS --
-- create integration object that contains the access information
CREATE STORAGE INTEGRATION gcp_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = GCS
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = ('gcs://<bucket_name>/path', 'gcs://<bucket_name>/path2');

-- Describe integration object to provide access
-- add member to GCS buckets (STORAGE_GCP_SERVICE_ACCOUNT) and assign storage related role
DESC STORAGE integration gcp_integration;
