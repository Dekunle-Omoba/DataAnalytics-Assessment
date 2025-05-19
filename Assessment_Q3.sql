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
GROUP BY s.id , s.owner_id
HAVING inactivity_days > 365 
UNION SELECT 
    p.id AS plan_id,
    p.owner_id,
    'Investment' AS type,
    MAX(p.last_charge_date) AS last_transaction_date,
    DATEDIFF(CURDATE(), MAX(p.last_charge_date)) AS inactivity_days
FROM
    plans_plan p
WHERE
    p.is_a_fund = 1 AND p.amount > 0
GROUP BY p.id , p.owner_id
HAVING inactivity_days > 365
ORDER BY inactivity_days DESC;