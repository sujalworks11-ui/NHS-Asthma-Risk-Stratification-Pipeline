------------------------------------------------------------
-- PATIENT DATA: CLEANING + FEATURE ENGINEERING (WITH CTEs)
-- Table: PATIENTS
-- CI7524 Big Data & Data Mining - Dr. Pushpa Kumarapeli
-- 1. Add derived columns (safe / idempotent)
-- 2. Populate cleaned + feature columns
-- 3. Create a CTE-based modelling view
------------------------------------------------------------


------------------------------------------------------------
-- (OPTIONAL) BACKUP ORIGINAL TABLE
------------------------------------------------------------
-- CREATE TABLE patients_raw AS SELECT * FROM patients;
-- (Uncomment and run once if you want a snapshot)


------------------------------------------------------------
-- 1. ADD DERIVED COLUMNS (SAFE / IDEMPOTENT)
------------------------------------------------------------
DECLARE
    col_count INTEGER;

    -- Helper: add column only if it does NOT already exist
    PROCEDURE add_column(colname IN VARCHAR2, datatype IN VARCHAR2) IS
    BEGIN
        SELECT COUNT(*)
        INTO col_count
        FROM user_tab_columns
        WHERE table_name = 'BIGDATACOURSEWORK'
          AND column_name = UPPER(colname);

        IF col_count = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE BIGDATACOURSEWORK ADD ' || colname || ' ' || datatype;
        END IF;
    END;
BEGIN
    -- Cleaned demographic + BP features
    add_column('C_GENDER',          'VARCHAR2(1)');  -- cleaned gender: M/F/U
    add_column('C_AGE',             'NUMBER');       -- cleaned age
    add_column('C_SYS_OUTLIER',     'NUMBER(1)');    -- 1 = out-of-range sys_val1
    add_column('C_DIAS_OUTLIER',    'NUMBER(1)');    -- 1 = out-of-range dias_val1
    add_column('C_BP_PAIR_INVALID', 'NUMBER(1)');    -- 1 = sys < dias
    add_column('C_PP',              'NUMBER');       -- pulse pressure

    -- Cholesterol + clinical flags
    add_column('C_CHOL_OUTLIER',    'NUMBER(1)');    -- 1 = suspicious chol
    add_column('C_DIABETES',        'NUMBER(1)');    -- 1 = diabetes dx
    add_column('C_SMOKER',          'NUMBER(1)');    -- 1 = smoker, 0 = non, NULL = unknown
    add_column('C_CVDRX',           'NUMBER(1)');    -- 1 = on cv meds
    add_column('C_HTN',             'NUMBER(1)');    -- 1 = hypertensive

    -- Data quality flags
    add_column('C_BAD_YOB',         'NUMBER(1)');    -- 1 = invalid Year_of_Birth
    add_column('C_BAD_BP_DATE1',    'NUMBER(1)');    -- 1 = invalid bp_date1
    add_column('C_BAD_CHOL_DATE1',  'NUMBER(1)');    -- 1 = invalid chlhdl_date1

    -- Asthma related features
    add_column('C_FH_ASTHMA',          'NUMBER(1)'); -- 1= family history, 0 = No
    add_column('C_DIST_BAND',        'VARCHAR2(10)'); -- Close, far, Very far (Categories)
    add_column('C_MWAY_DIST_CLEAN',     'NUMBER');   -- Cleaned distance 
END;
/

------------------------------------------------------------
-- 2. POPULATE CLEANING + FEATURE COLUMNS
------------------------------------------------------------

UPDATE BIGDATACOURSEWORK
SET
    --------------------------------------------------------
    -- 2.1 CLEAN GENDER (SNOMED → M/F/U)
    -- male_code   = '446141000124107'
    -- female_code = '446151000124109'
    --------------------------------------------------------
    c_gender =
        CASE
            WHEN Gender = '446141000124107' THEN 'M'
            WHEN Gender = '446151000124109'  THEN 'F'
            ELSE 'U'
        END,

    --------------------------------------------------------
    -- 2.2 CLEAN AGE FROM YEAR_OF_BIRTH
    --------------------------------------------------------
    c_age =
        CASE
            WHEN Year_of_Birth IS NULL THEN NULL
            WHEN Year_of_Birth < 1900 THEN NULL
            WHEN Year_of_Birth > EXTRACT(YEAR FROM SYSDATE) THEN NULL
            ELSE EXTRACT(YEAR FROM SYSDATE) - Year_of_Birth
        END,

    c_bad_yob =
        CASE
            WHEN Year_of_Birth IS NULL THEN 0
            WHEN Year_of_Birth < 1900 THEN 1
            WHEN Year_of_Birth > EXTRACT(YEAR FROM SYSDATE) THEN 1
            ELSE 0
        END,

    --------------------------------------------------------
    -- 2.3 BLOOD PRESSURE VALUE CHECKS & PULSE PRESSURE
    -- systolic:  60–260
    -- diastolic: 30–160
    --------------------------------------------------------
    c_sys_outlier =
        CASE
            WHEN sys_val1 IS NULL THEN 0
            WHEN sys_val1 < 60 OR sys_val1 > 260 THEN 1
            ELSE 0
        END,

    c_dias_outlier =
        CASE
            WHEN dias_val1 IS NULL THEN 0
            WHEN dias_val1 < 30 OR dias_val1 > 160 THEN 1
            ELSE 0
        END,

    c_bp_pair_invalid =
        CASE
            WHEN sys_val1 IS NOT NULL
             AND dias_val1 IS NOT NULL
             AND sys_val1 < dias_val1 THEN 1
            ELSE 0
        END,

    c_pp =
        CASE
            WHEN sys_val1 IS NOT NULL AND dias_val1 IS NOT NULL
                THEN sys_val1 - dias_val1
            ELSE NULL
        END,

    --------------------------------------------------------
    -- 2.4 CHOLESTEROL OUTLIER FLAG (1–20 mmol/L plausible)
    --------------------------------------------------------
    c_chol_outlier =
        CASE
            WHEN chlhdl_val1 IS NULL THEN 0
            WHEN chlhdl_val1 < 1 OR chlhdl_val1 > 20 THEN 1
            ELSE 0
        END,

    --------------------------------------------------------
    -- 2.5 DIABETES FLAG
    -- diabetes_codes = 44054006,111552007,237599002,73211009
    --------------------------------------------------------
    c_diabetes =
        CASE
            WHEN diab_code1 IN ('44054006','111552007','237599002','73211009')
                THEN 1
            ELSE 0
        END,

    --------------------------------------------------------
    -- 2.6 SMOKING FLAG
    -- all smoking codes:
    --   8392000,230056004,230057008,230058003,266919005,266920004
    -- smoker=1:
    --   230056004,230057008,230058003,266920004
    --------------------------------------------------------
    c_smoker =
        CASE
            WHEN smok_code1 IN ('230056004','230057008','230058003','266920004') THEN 1   -- smoker
            WHEN smok_code1 IN ('8392000','266919005') THEN NULL                           -- ambiguous
            WHEN smok_code1 IS NULL THEN NULL                                              -- unknown
            ELSE 0                                                                         -- explicit non-smoker (if coded)
        END,

    --------------------------------------------------------
    -- 2.7 CARDIOVASCULAR MEDICATION FLAG
    -- bp_management_rx_codes:
    --   6131004,372727001,11000132102,11000129103,
    --   1040010010001002,111708003,372729009,
    --   324121000000109,11560009
    --------------------------------------------------------
    c_cvdrx =
        CASE
            WHEN cvdrx_code1 IN (
                '6131004','372727001','11000132102','11000129103',
                '1040010010001002','111708003','372729009',
                '324121000000109','11560009'
            ) THEN 1
            ELSE 0
        END,

    --------------------------------------------------------
    -- 2.8 HYPERTENSION FLAG
    -- c_htn = 1 if sys ≥ 140 OR dias ≥ 90
    --------------------------------------------------------
    c_htn =
        CASE
            WHEN sys_val1 >= 140 OR dias_val1 >= 90 THEN 1
            ELSE 0
        END,

    --------------------------------------------------------
    -- 2.9 DATE QUALITY FLAGS
    --------------------------------------------------------
    c_bad_bp_date1 =
        CASE
            WHEN bp_date1 IS NULL THEN 0
            WHEN bp_date1 < DATE '1900-01-01' THEN 1
            WHEN bp_date1 > SYSDATE THEN 1
            ELSE 0
        END,

    c_bad_chol_date1 =
        CASE
            WHEN chlhdl_date1 IS NULL THEN 0
            WHEN chlhdl_date1 < DATE '1900-01-01' THEN 1
            WHEN chlhdl_date1 > SYSDATE THEN 1
            ELSE 0
        END,
    --------------------------------------------------------
    -- 2.10 Family history of asthma 
    -- If they have recorded date they have history
    --------------------------------------------------------
    c_fh_asthma =
        CASE
            WHEN fh_asthma_date1 IS NOT NULL THEN 1
            ELSE 0
        END,
    --------------------------------------------------------
    -- 2.11 Distance Bands
    -- adding categories to the distance 
    --------------------------------------------------------
    c_dist_band = 
        CASE 
            WHEN mwaydist_km1 IS NULL THEN 'UNKNOWN'
            WHEN mwaydist_km1 < 0.5 THEN 'VERY CLOSE' -- being very close increases the risk ( HIGH RISK)
            WHEN mwaydist_km1 < 1.0 THEN 'CLOSE'
            WHEN mwaydist_km1 < 2.0 THEN 'MEDIUM'
            ELSE 'FAR'
        END
           

;

COMMIT;


------------------------------------------------------------
-- 3. FEATURE VIEW FOR MODELLING (USING CTE PIPELINE)
------------------------------------------------------------
-- CTE chain:
--   base_raw      → demo_bp
--   demo_bp       → clinical
--   clinical      → final_features
------------------------------------------------------------

CREATE OR REPLACE VIEW vw_patient_features_cte AS
WITH base_raw AS (
    --------------------------------------------------------
    -- Step 1: Start from cleaned columns on PATIENTS
    --------------------------------------------------------
    SELECT
        Patient_ID,
        c_gender,
        c_age,
        sys_val1,
        dias_val1,
        c_pp,
        chlhdl_val1,
        c_diabetes,
        c_smoker,
        c_cvdrx,
        c_htn,
        c_bad_yob,
        c_sys_outlier,
        c_dias_outlier,
        c_bp_pair_invalid,
        c_chol_outlier,
        c_bad_bp_date1,
        c_bad_chol_date1,
        c_fh_asthma,
        c_dist_band,
        asthma_worsened
    FROM BIGDATACOURSEWORK
),

demo_bp AS (
    ----------------------------------------------------------------
    -- Step 2: Apply basic data-quality filters on demographics + BP
    ----------------------------------------------------------------
    SELECT
        Patient_ID,
        c_gender,
        c_age,
        sys_val1,
        dias_val1,
        c_pp,
        chlhdl_val1,
        c_diabetes,
        c_smoker,
        c_cvdrx,
        c_htn,
        c_bad_yob,
        c_sys_outlier,
        c_dias_outlier,
        c_bp_pair_invalid,
        c_chol_outlier,
        c_bad_bp_date1,
        c_bad_chol_date1,
        c_fh_asthma,
        c_dist_band,
        asthma_worsened
    FROM base_raw
    WHERE c_bad_yob = 0           -- plausible age
      AND c_sys_outlier = 0       -- sensible sys BP
      AND c_dias_outlier = 0      -- sensible dias BP
      AND c_bp_pair_invalid = 0   -- sys >= dias
),

clinical AS (
    --------------------------------------------------------
    -- Step 3: Choose final clinical features / aliases
    --------------------------------------------------------
    SELECT
        Patient_ID,
        c_gender       AS gender,
        c_age          AS age,
        sys_val1       AS sys_bp,
        dias_val1      AS dias_bp,
        c_pp           AS pulse_pressure,
        chlhdl_val1    AS chol_hdl_ratio,
        c_diabetes,
        c_smoker,
        c_cvdrx,
        c_htn,
        c_chol_outlier,
        c_bad_bp_date1,
        c_bad_chol_date1,
        c_fh_asthma,
        c_dist_band,
        asthma_worsened
    FROM demo_bp
),

final_features AS (
    ----------------------------------------------------------------
    -- Step 4: Optionally filter out extreme cholesterol, bad dates
    ----------------------------------------------------------------
    SELECT
        Patient_ID,
        gender,
        age,
        sys_bp,
        dias_bp,
        pulse_pressure,
        chol_hdl_ratio,
        c_diabetes,
        c_smoker,
        c_cvdrx,
        c_htn,
        c_fh_asthma         AS family_history,
        c_dist_band         AS pollution_risk_band,
        asthma_worsened     
    FROM clinical
    WHERE c_chol_outlier   = 0   -- optional
      AND c_bad_bp_date1   = 0   -- optional
      AND c_bad_chol_date1 = 0   -- optional
)

SELECT *
FROM final_features;


------------------------------------------------------------
-- 4. QUICK CHECK: SAMPLE FROM FEATURE VIEW
------------------------------------------------------------

SELECT *
FROM vw_patient_features_cte
FETCH FIRST 20 ROWS ONLY;

------------------------------------------------------------
-- END OF SCRIPT
------------------------------------------------------------
