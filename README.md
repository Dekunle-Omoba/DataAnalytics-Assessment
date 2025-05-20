# DataAnalytics-Assessment
Task response to Cowryrise assesmennt
Customer Financial Data Analysis with MySQL
This repository contains MySQL queries to analyze customer financial data for a business with savings and investment products. The queries address four business scenarios: identifying high-value customers with multiple products, analyzing transaction frequency, flagging inactive accounts, and estimating customer lifetime value (CLV). Comprehensive data cleaning queries ensure data quality. This README explains the approach for each query, challenges encountered, and their resolutions.
Table of Contents
Project Overview 

Database Schema 

Query Explanations 
1. High-Value Customers with Multiple Products 

2. Transaction Frequency Analysis 

3. Account Inactivity Alert 

4. Customer Lifetime Value (CLV) Estimation 

5. Data Cleaning Queries 

Challenges and Resolutions 

Setup and Usage

Contributing

License 

Project Overview
The project involves MySQL queries to extract insights from a financial database with three tables: users_customuser, savings_savingsaccount, and plans_plan. The queries support business goals such as identifying cross-selling opportunities, segmenting customers by transaction frequency, flagging inactive accounts, and estimating CLV. Data cleaning ensures reliable results by addressing missing values, duplicates, and inconsistencies.
Database Schema
The following tables are used:
users_customuser:
id (PK): Unique user identifier.

first_name: Customer's first name.

last_name: Customer's last name.

date_joined: Date of user registration.

savings_savingsaccount:
id (PK): Unique account identifier.

owner_id (FK): References users_customuser.id.

confirmed_amount: Inflow amount (in kobo).

transaction_date: Date of transaction.

verification_status_id: Indicates verified savings plan (1 = verified).

plans_plan:
id (PK): Unique plan identifier.

owner_id (FK): References users_customuser.id.

amount: Inflow amount (in kobo).

last_charge_date: Date of last transaction.

is_a_fund: Boolean (1 = investment plan, 0 = otherwise).

Notes:
All amounts are in kobo (1 Naira = 100 kobo).

confirmed_amount (savings) and amount (plans) represent inflows.

verification_status_id = 1 indicates a verified savings plan, while is_a_fund = 1 indicates an investment plan.

Query Explanations
1. High-Value Customers with Multiple Products
Objective: Identify customers with at least one verified savings plan (verification_status_id = 1) and one funded investment plan (is_a_fund = 1), sorted by total savings deposits (in Naira).
Approach:
Join Tables: Use INNER JOINs between users_customuser, savings_savingsaccount, and plans_plan on owner_id to ensure customers have both plan types.

Filter Funded Plans: Select records where verification_status_id = 1, is_a_fund = 1, and confirmed_amount > 0 (savings only).

Aggregate Metrics:
Count distinct savings plans (COUNT(DISTINCT s.id)).

Count distinct investment plans (COUNT(DISTINCT p.id)).

Sum confirmed_amount from savings (converted to Naira: / 100.0).

Ensure Multiple Products: Use HAVING to filter for savings_count >= 1 and investment_count >= 1.

Sort: Order by total_deposits descending.

Query:
sql

SELECT 
    u.id AS owner_id,
    u.first_name,
    u.last_name,
    COUNT(DISTINCT s.id) AS savings_count,
    COUNT(DISTINCT p.id) AS investment_count,
    SUM(COALESCE(s.confirmed_amount, 0)) / 100.0 AS total_deposits
FROM
    users_customuser u
        INNER JOIN
    savings_savingsaccount s ON u.id = s.owner_id
        INNER JOIN
    plans_plan p ON u.id = p.owner_id
WHERE
    s.verification_status_id = 1
        AND p.is_a_fund = 1
        AND s.confirmed_amount > 0
GROUP BY u.id, u.first_name, u.last_name
HAVING savings_count >= 1
    AND investment_count >= 1
ORDER BY total_deposits DESC;

Notes:
Only confirmed_amount from savings is summed, per the query.

COALESCE handles NULL confirmed_amount values.

2. Transaction Frequency Analysis
Objective: Calculate the average number of transactions per customer per month and categorize as High (≥10), Medium (3-9), or Low (≤2) frequency.
Approach:
Use CTE: Compute average transactions per month in a CTE (TransactionCounts):
Count transactions (confirmed_amount > 0) in the last 12 months.

Calculate tenure using DATEDIFF / 30.42 (average days per month).

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
Objective: Identify verified savings (verification_status_id = 1) or investment (is_a_fund = 1) accounts with no inflow transactions in the last 365 days.
Approach:
Union Tables: Combine results from savings_savingsaccount and plans_plan using UNION.

Filter Active Plans: Select savings with verification_status_id = 1 and confirmed_amount > 0, and investments with is_a_fund = 1 and amount > 0.

Calculate Inactivity:
For savings, use MAX(transaction_date).

For investments, use MAX(last_charge_date).

Compute inactivity_days with DATEDIFF.

Filter Inactive: Use HAVING inactivity_days > 365.

Label Type: Assign 'Savings' or 'Investment'.

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
    s.verification_status_id = 1
        AND s.confirmed_amount > 0
GROUP BY s.id, s.owner_id
HAVING inactivity_days > 365 
UNION 
SELECT 
    p.id AS plan_id,
    p.owner_id,
    'Investment' AS type,
    MAX(p.last_charge_date) AS last_transaction_date,
    DATEDIFF(CURDATE(), MAX(p.last_charge_date)) AS inactivity_days
FROM
    plans_plan p
WHERE
    p.is_a_fund = 1 
    AND p.amount > 0
GROUP BY p.id, p.owner_id
HAVING inactivity_days > 365
ORDER BY inactivity_days DESC;

4. Customer Lifetime Value (CLV) Estimation
Objective: Estimate CLV based on account tenure, total transactions, and profit per transaction (0.1% of transaction value).
Approach:
Join Tables: Left join users_customuser with savings_savingsaccount to include all customers.

Calculate Metrics:
Tenure: DATEDIFF(CURDATE(), date_joined) / 30.42 (months).

Total transactions: COUNT(s.id) where confirmed_amount > 0.

CLV: (total_transactions / tenure) * 12 * (AVG(confirmed_amount) * 0.001 / 100.0).

Filter Valid Tenure: Ensure tenure >= 1 month to avoid division by zero.

Format: Round tenure_months to 0 decimals, estimated_clv to 2 decimals.

Sort: Order by estimated_clv descending.

Query:
sql

SELECT 
    u.id AS customer_id,
    u.first_name,
    u.last_name,
    ROUND(DATEDIFF(CURDATE(), u.date_joined) / 30.42, 0) AS tenure_months,
    COUNT(s.id) AS total_transactions,
    ROUND((COUNT(s.id) / (DATEDIFF(CURDATE(), u.date_joined) / 30.42)) * 12 * 
          (AVG(s.confirmed_amount) * 0.001 / 100.0), 2) AS estimated_clv
FROM
    users_customuser u
        LEFT JOIN
    savings_savingsaccount s ON u.id = s.owner_id
        AND s.confirmed_amount > 0
WHERE
    DATEDIFF(CURDATE(), u.date_joined) / 30.42 >= 1
GROUP BY u.id, u.first_name, u.last_name, u.date_joined
ORDER BY estimated_clv DESC;

5. Data Cleaning Queries
Objective: Ensure data quality by handling missing values, duplicates, invalid data, outliers, and referential integrity.
Approach:
Missing Values:
Delete records with NULL id or owner_id.

Set NULL confirmed_amount or amount to 0.

Set NULL first_name, last_name to 'Unknown'.

Set NULL date_joined, transaction_date, or last_charge_date to a default (e.g., '2000-01-01').

Referential Integrity:
Delete owner_id records not in users_customuser.id.

Duplicates:
Remove duplicate users (by first_name, last_name, date_joined).

Remove duplicate transactions (by owner_id, confirmed_amount, transaction_date or last_charge_date).

Invalid Data:
Set negative confirmed_amount or amount to 0.

Correct future dates or dates before 1900-01-01.

Ensure verification_status_id and is_a_fund are valid (e.g., verification_status_id = 1 for savings).

Outliers:
Cap confirmed_amount or amount at 1 billion kobo (10M Naira).

Format Standardization:
Trim and standardize case for first_name, last_name.

Business Logic:
Ensure verified savings (verification_status_id = 1) have confirmed_amount > 0.

Ensure investment plans (is_a_fund = 1) have amount > 0.

Auditing:
Log changes to a data_cleaning_audit table.

Example Cleaning Query:
sql

-- Delete invalid records
DELETE FROM savings_savingsaccount WHERE id IS NULL OR owner_id IS NULL;
DELETE FROM plans_plan WHERE id IS NULL OR owner_id IS NULL;

-- Set defaults for NULL amounts
UPDATE savings_savingsaccount SET confirmed_amount = 0 WHERE confirmed_amount IS NULL;
UPDATE plans_plan SET amount = 0 WHERE amount IS NULL;

-- Remove orphaned records
DELETE FROM savings_savingsaccount WHERE owner_id NOT IN (SELECT id FROM users_customuser);
DELETE FROM plans_plan WHERE owner_id NOT IN (SELECT id FROM users_customuser);

Full Cleaning Queries: See data_cleaning.sql in the repository.
Challenges and Resolutions
Updated Column Names:
Challenge: Initial queries used incorrect column names (e.g., name instead of first_name, last_name; is_regular_savings instead of verification_status_id).

Resolution: Updated queries to use correct columns (first_name, last_name, verification_status_id, last_charge_date, amount) based on provided queries.

Inconsistent Amount Fields:
Challenge: Query 1 sums only confirmed_amount from savings, not investments, which was unexpected.

Resolution: Followed the provided query exactly, assuming business intent to focus on savings deposits. Noted this in the explanation for clarity.

Different Date Columns:
Challenge: Query 3 uses transaction_date for savings but last_charge_date for investments, which wasn’t initially clear.

Resolution: Incorporated last_charge_date for investments, ensuring accurate inactivity calculations.

NULL Handling:
Challenge: NULL confirmed_amount or amount could skew aggregates.

Resolution: Used COALESCE in Query 1 and included cleaning steps to set NULL amounts to 0.

Performance Concerns:
Challenge: Joins and aggregations (e.g., Query 1) could be slow on large datasets.

Resolution: Recommended indexes on owner_id, verification_status_id, is_a_fund, confirmed_amount, amount, transaction_date, and last_charge_date.

Ambiguous Funded Definition:
Challenge: Definition of "funded" varied (e.g., confirmed_amount > 0 for savings, amount > 0 for investments).

Resolution: Aligned with provided queries, using respective conditions, and added cleaning to enforce consistency.

Data Cleaning Scope:
Challenge: Ensuring cleaning didn’t overwrite valid data while addressing all issues.

Resolution: Structured cleaning in a logical order (NULLs → integrity → duplicates → invalid data → outliers) and proposed an audit table.

Setup and Usage
Prerequisites:
MySQL 8.0 or later.

A database with the specified schema.

Setup:
Clone the repository:
bash

git clone https://github.com/your-username/customer-financial-analysis.git

Import the schema and sample data (if available):
bash

mysql -u your_user -p your_database < schema.sql

Run data cleaning queries:
bash

mysql -u your_user -p your_database < data_cleaning.sql

Running Queries:
Execute queries in queries.sql using a MySQL client:
bash

mysql -u your_user -p your_database -e "source queries.sql"

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

Please include tests or example outputs for new queries and update the README.


