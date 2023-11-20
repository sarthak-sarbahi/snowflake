--  To be able to create the virtual warehouse, you have to use at least the role SYSADMIN (or SECURITYADMIN or ACCOUNTADMIN).
USE ROLE SYSADMIN;

-- setup warehouse
CREATE OR REPLACE WAREHOUSE COMPUTE_WAREHOUSE
WITH 
WAREHOUSE_SIZE = XSMALL
MAX_CLUSTER_COUNT = 3
AUTO_SUSPEND = 300 -- amount of time in seconds
AUTO_RESUME = TRUE
INITIALLY_SUSPENDED = TURE -- it will be OFF when first created
COMMENT = 'This is our second warehouse'

-- drop warehouse
DROP WAREHOUSE COMPUTE_WAREHOUSE;