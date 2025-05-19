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
GROUP BY u.id , u.name
HAVING savings_count >= 1
    AND investment_count >= 1
ORDER BY total_deposits DESC;