CREATE DATABASE IF NOT EXISTS online_retail_analysis
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE online_retail_analysis;

SELECT
    DATABASE() AS active_database,
    VERSION() AS mysql_version;