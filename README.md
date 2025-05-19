# DataAnalytics-Assessment
Task response to Cowryrise assesmennt
Customer Financial Data Analysis with MySQL
This repository contains MySQL queries to analyze customer financial data for a business with savings and investment products. The queries address four business scenarios: identifying high-value customers, analyzing transaction frequency, flagging inactive accounts, and estimating customer lifetime value (CLV). Additionally, comprehensive data cleaning queries ensure data quality. This README explains the approach for each query, challenges encountered, and their resolutions.
Table of Contents
Project Overview 

Database Schema

Query Explanations
1. High-Value Customers with Multiple Products (#1-high-value-customers-with-multiple-products)

2. Transaction Frequency Analysis (#2-transaction-frequency-analysis)

3. Account Inactivity Alert (#3-account-inactivity-alert)

4. Customer Lifetime Value (CLV) Estimation (#4-customer-lifetime-value-clv-estimation)

5. Data Cleaning Queries (#5-data-cleaning-queries)

Challenges and Resolutions (#challenges-and-resolutions)

Setup and Usage (#setup-and-usage)

Contributing (#contributing)

License (#license)

Project Overview
The project involves writing MySQL queries to extract insights from a financial database with three main tables: users_customuser, savings_savingsaccount, and plans_plan. The queries address specific business needs, such as identifying cross-selling opportunities, segmenting customers by transaction frequency, flagging inactive accounts, and estimating CLV. Data cleaning queries ensure the dataset is reliable by handling missing values, duplicates, and inconsistencies.
Database Schema
The following tables are used:
users_customuser:
id (PK): Unique user identifier.

name: Customer name.

signup_date: Date of user registration.

savings_savingsaccount:
id (PK): Unique account identifier.

owner_id (FK): References users_customuser.id.

confirmed_amount: Inflow amount (in kobo).

amount_withdrawn: Outflow amount (in kobo).

transaction_date: Date of transaction.

is_regular_savings: Boolean (1 = savings plan, 0 = otherwise).

plans_plan:
id (PK): Unique plan identifier.

owner_id (FK): References users_customuser.id.

confirmed_amount: Inflow amount (in kobo).

amount_withdrawn: Outflow amount (in kobo).

transaction_date: Date of transaction.

is_a_fund: Boolean (1 = investment plan, 0 = otherwise).

Notes:
All amounts are in kobo (1 Naira = 100 kobo).

confirmed_amount represents inflows, and amount_withdrawn represents outflows.

is_regular_savings and is_a_fund are binary (0 or 1).

Query Explanations
1. High-Value Customers with Multiple Products
Objective: Identify customers with at least one funded savings plan (is_regular_savings = 1) and one funded investment plan (is_a_fund = 1), sorted by total deposits (in Naira).
Approach:
Join Tables: Inner join users_customuser with savings_savingsaccount and plans_plan on owner_id to ensure customers have both plan types.

Filter Funded Plans: Use confirmed_amount > 0 and is_regular_savings = 1/is_a_fund = 1 to identify funded savings and investment plans.

Aggregate Data: 
Count distinct savings and investment plans using COUNT(DISTINCT s.id) and COUNT(DISTINCT p.id).

Sum confirmed_amount from both tables and convert to Naira (/ 100.0).

Ensure Multiple Products: Use HAVING savings_count >= 1 AND investment_count >= 1 to filter customers with both plan types.

Sort: Order by total_deposits descending.

Query:
sql

SELECT 
    u.id AS owner_id,
    u.name,
    COUNT(DISTINCT s.id) AS savings_count,
    COUNT(DISTINCT p.id) AS investment_count,
    SUM(COALESCE(s.confirmed_amount, 0) + COALESCE(p.confirmed_amount, 0)) / 100.0 AS total_deposits
FROM 
    users_customuser u
    INNER JOIN savings_savingsaccount s ON u.id = s.owner_id
    INNER JOIN plans_plan p ON u.id = p.owner_id
WHERE 
    s.is_regular_savings = 1
    AND p.is_a_fund = 1
    AND s.confirmed_amount > 0
    AND p.confirmed_amount > 0
GROUP BY 
    u.id, u.name
HAVING 
    savings_count >= 1 AND investment_count >= 1
ORDER BY 
    total_deposits DESC;

2. Transaction Frequency Analysis
Objective: Calculate the average number of transactions per customer per month and categorize as High (≥10), Medium (3-9), or Low (≤2) frequency.
Approach:
Use CTE: Compute average transactions per month in a CTE (TransactionCounts):
Count transactions (confirmed_amount > 0) in the last 12 months.

Calculate tenure in months using DATEDIFF / 30.42 (average days per month).

Compute average as COUNT / tenure.

Categorize: Use CASE to assign categories based on avg_transactions_per_month.

Aggregate: Group by category to get customer_count and average transactions per category.

Format: Round averages to 1 decimal place and order by average transactions descending.

Query:
sql

WITH TransactionCounts AS (
    SELECT 
        owner_id,
        COUNT(*) / (DATEDIFF(CURDATE(), MIN(transaction_date)) / 30.42) AS avg_transactions_per_month
    FROM 
        savings_savingsaccount
    WHERE 
        confirmed_amount > 0
        AND transaction_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
    GROUP BY 
        owner_id
)
SELECT 
    CASE 
        WHEN avg_transactions_per_month >= 10 THEN 'High Frequency'
        WHEN avg_transactions_per_month BETWEEN 3 AND 9 THEN 'Medium Frequency'
        ELSE 'Low Frequency'
    END AS frequency_category,
    COUNT(*) AS customer_count,
    ROUND(AVG(avg_transactions_per_month), 1) AS avg_transactions_per_month
FROM 
    TransactionCounts
GROUP BY 
    frequency_category
ORDER BY 
    avg_transactions_per_month DESC;

3. Account Inactivity Alert
Objective: Identify active savings or investment accounts with no inflow transactions in the last 365 days.
Approach:
Union Tables: Use UNION to combine results from savings_savingsaccount and plans_plan.

Filter Active Plans: Select plans where is_regular_savings = 1 or is_a_fund = 1 and confirmed_amount > 0.

Calculate Inactivity: Use MAX(transaction_date) to find the last transaction and compute inactivity_days with DATEDIFF.

Filter Inactive: Use HAVING inactivity_days > 365 to identify accounts with no activity in the last year.

Label Type: Assign 'Savings' or 'Investment' based on the table.

Sort: Order by inactivity_days descending.

Query:
sql

SELECT 
    s.id AS plan_id,
    s.owner_id,
    'Savings' AS type,
    MAX(s.transaction_date) AS last_transaction_date,
    DATEDIFF(CURDATE(), MAX(s.transaction_date)) AS inactivity_days
FROM 
    savings_savingsaccount s
WHERE 
    s.is_regular_savings = 1
    AND s.confirmed_amount > 0
GROUP BY 
    s.id, s.owner_id
HAVING 
    inactivity_days > 365
UNION
SELECT 
    p.id AS plan_id,
    p.owner_id,
    'Investment' AS type,
    MAX(p.transaction_date) AS last_transaction_date,
    DATEDIFF(CURDATE(), MAX(p.transaction_date)) AS inactivity_days
FROM 
    plans_plan p
WHERE 
    p.is_a_fund = 1
    AND p.confirmed_amount > 0
GROUP BY 
    p.id, p.owner_id
HAVING 
    inactivity_days > 365
ORDER BY 
    inactivity_days DESC;

4. Customer Lifetime Value (CLV) Estimation
Objective: Estimate CLV based on account tenure, total transactions, and profit per transaction (0.1% of transaction value).
Approach:
Join Tables: Left join users_customuser with savings_savingsaccount to include all customers, even those without transactions.

Calculate Metrics:
Tenure: DATEDIFF(CURDATE(), signup_date) / 30.42 (months).

Total transactions: COUNT(s.id) where confirmed_amount > 0.

CLV: (total_transactions / tenure) * 12 * (AVG(confirmed_amount) * 0.001 / 100.0).

Filter Valid Tenure: Ensure tenure >= 1 month to avoid division by zero.

Format: Round tenure_months to 0 decimals, estimated_clv to 2 decimals.

Sort: Order by estimated_clv descending.

Query:
sql

SELECT 
    u.id AS customer_id,
    u.name,
    ROUND(DATEDIFF(CURDATE(), u.signup_date) / 30.42, 0) AS tenure_months,
    COUNT(s.id) AS total_transactions,
    ROUND(
        (COUNT(s.id) / (DATEDIFF(CURDATE(), u.signup_date) / 30.42)) * 12 * 
        (AVG(s.confirmed_amount) * 0.001 / 100.0),
        2
    ) AS estimated_clv
FROM 
    users_customuser u
    LEFT JOIN savings_savingsaccount s ON u.id = s.owner_id
        AND s.confirmed_amount > 0
WHERE 
    DATEDIFF(CURDATE(), u.signup_date) / 30.42 >= 1
GROUP BY 
    u.id, u.name, u.signup_date
ORDER BY 
    estimated_clv DESC;

5. Data Cleaning Queries
Objective: Ensure data quality by handling missing values, duplicates, invalid data, outliers, and referential integrity.
Approach:
Missing Values:
Identify and handle NULLs in id, owner_id, name, signup_date, confirmed_amount, transaction_date, is_regular_savings, and is_a_fund.

Actions: Delete records with NULL PK/FK, set defaults (e.g., confirmed_amount = 0, name = 'Unknown').

Referential Integrity:
Check for orphaned owner_id in savings_savingsaccount and plans_plan.

Action: Delete orphaned records.

Duplicates:
Identify duplicates in users_customuser (by name and signup_date) and transactions (by owner_id, confirmed_amount, transaction_date).

Action: Keep record with lowest id and delete others.

Invalid Data:
Fix negative confirmed_amount or amount_withdrawn (set to 0).

Correct future or very old dates (e.g., set future dates to CURDATE()).

Ensure is_regular_savings and is_a_fund are 0 or 1.

Outliers:
Cap extreme confirmed_amount values (e.g., > 10M Naira in kobo).

Format Standardization:
Trim spaces and standardize case for name.

Business Logic:
Ensure funded plans (is_regular_savings = 1 or is_a_fund = 1) have confirmed_amount > 0.

Auditing:
Log changes to a data_cleaning_audit table for traceability.

Example Cleaning Query (Missing Values):
sql

-- Delete records with NULL id or owner_id
DELETE FROM savings_savingsaccount 
WHERE id IS NULL OR owner_id IS NULL;

-- Set defaults for NULL confirmed_amount and is_regular_savings
UPDATE savings_savingsaccount 
SET 
    confirmed_amount = 0,
    is_regular_savings = 0
WHERE 
    confirmed_amount IS NULL 
    OR is_regular_savings IS NULL;

Full Cleaning Queries: See the data_cleaning.sql file in the repository for all cleaning operations.
Challenges and Resolutions
Ambiguous Table Schema:
Challenge: The exact schema (e.g., column names, transaction record structure) was not fully specified, particularly whether savings_savingsaccount and plans_plan store individual transactions or account summaries.

Resolution: Assumed tables store individual transactions with confirmed_amount and transaction_date. Used COUNT and MAX for aggregations, ensuring flexibility for both transactional and summary data.

Handling NULLs and Division by Zero:
Challenge: NULL confirmed_amount or zero tenure in CLV calculations could cause errors or skewed results.

Resolution: Used COALESCE to handle NULLs (e.g., COALESCE(confirmed_amount, 0)) and filtered for tenure >= 1 month in Query 4 to avoid division by zero.

Defining Funded Plans:
Challenge: The definition of "funded" plans was unclear (e.g., single transaction vs. net balance).

Resolution: Assumed confirmed_amount > 0 indicates a funded plan, consistent with inflow transactions. Added data cleaning to ensure is_regular_savings = 1 or is_a_fund = 1 aligns with positive confirmed_amount.

Transaction Period for Frequency Analysis:
Challenge: Query 2 required average transactions per month, but the time frame was unspecified.

Resolution: Used a 12-month window (DATE_SUB(CURDATE(), INTERVAL 12 MONTH)) for relevance and calculated tenure from the earliest transaction date to normalize averages.

Performance with Large Datasets:
Challenge: Joins and aggregations (e.g., Query 1) could be slow on large datasets without indexes.

Resolution: Recommended indexes on owner_id, transaction_date, confirmed_amount, is_regular_savings, and is_a_fund in the cleaning section. Used DISTINCT sparingly to optimize performance.

Outlier Detection:
Challenge: Identifying outliers in confirmed_amount without specific business thresholds.

Resolution: Applied a simple threshold (10M Naira in kobo) for capping outliers. Suggested IQR-based methods for more robust detection if needed.

Data Cleaning Scope:
Challenge: Comprehensive cleaning required addressing multiple issues (NULLs, duplicates, outliers) without overwriting valid data.

Resolution: Structured cleaning in a logical order (NULLs → integrity → duplicates → invalid data → outliers → formats) and included an audit table to track changes.

Setup and Usage
Prerequisites:
MySQL 8.0 or later.

A database with the specified schema (users_customuser, savings_savingsaccount, plans_plan).

Setup:
Clone the repository:
bash

git clone https://github.com/your-username/customer-financial-analysis.git

Import the schema and sample data (if provided) into MySQL:
bash

mysql -u your_user -p your_database < schema.sql

Run data cleaning queries first:
bash

mysql -u your_user -p your_database < data_cleaning.sql

Running Queries:
Execute each query in queries.sql using a MySQL client (e.g., MySQL Workbench, command line).

Example:
bash

mysql -u your_user -p your_database -e "source queries.sql"

Output:
Queries produce results in the formats specified (e.g., owner_id, total_deposits for Query 1).

Export results to CSV if needed:
sql

SELECT * FROM (/* your query */) AS result
INTO OUTFILE '/path/to/output.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n';

Contributing
Contributions are welcome! To contribute:
Fork the repository.

Create a feature branch (git checkout -b feature/your-feature).

Commit changes (git commit -m "Add your feature").

Push to the branch (git push origin feature/your-feature).

Open a pull request.

