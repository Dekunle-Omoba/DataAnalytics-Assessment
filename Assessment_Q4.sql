SELECT 
    u.id AS customer_id,
    u.first_name,
    u.last_name,
    ROUND(DATEDIFF(CURDATE(), u.date_joined) / 30.42,
            0) AS tenure_months,
    COUNT(s.id) AS total_transactions,
    ROUND((COUNT(s.id) / (DATEDIFF(CURDATE(), u.date_joined) / 30.42)) * 12 * (AVG(s.confirmed_amount) * 0.001 / 100.0),
            2) AS estimated_clv
FROM
    users_customuser u
        LEFT JOIN
    savings_savingsaccount s ON u.id = s.owner_id
        AND s.confirmed_amount > 0
WHERE
    DATEDIFF(CURDATE(), u.date_joined) / 30.42 >= 1
GROUP BY u.id , u.name , u.date_joined
ORDER BY estimated_clv DESC;