-- Setting up table
CREATE OR REPLACE TABLE OUR_FIRST_DB.public.test (
   id int,
   first_name string,
  last_name string,
  email string,
  gender string,
  Job string,
  Phone string);
    
COPY INTO OUR_FIRST_DB.public.test
from @MANAGE_DB.external_stages.time_travel_stage
files = ('customers.csv');

SELECT * FROM OUR_FIRST_DB.public.test;

-- Use-case: Update data (by mistake)
UPDATE OUR_FIRST_DB.public.test
SET LAST_NAME = 'Tyson';

UPDATE OUR_FIRST_DB.public.test
SET JOB = 'Data Analyst';

SELECT * FROM OUR_FIRST_DB.public.test before (statement => '')

-- Bad method
-- This is a bad method because time travel does not work if table is re-created, we lose all the metadata in the process
-- CREATE OR REPLACE TABLE OUR_FIRST_DB.public.test as
-- SELECT * FROM OUR_FIRST_DB.public.test before (statement => '')

-- SELECT * FROM OUR_FIRST_DB.public.test

-- CREATE OR REPLACE TABLE OUR_FIRST_DB.public.test as
-- SELECT * FROM OUR_FIRST_DB.public.test before (statement => '')

-- Good method
CREATE OR REPLACE TABLE OUR_FIRST_DB.public.test_backup as
SELECT * FROM OUR_FIRST_DB.public.test before (statement => '')

TRUNCATE OUR_FIRST_DB.public.test

INSERT INTO OUR_FIRST_DB.public.test
SELECT * FROM OUR_FIRST_DB.public.test_backup

SELECT * FROM OUR_FIRST_DB.public.test 