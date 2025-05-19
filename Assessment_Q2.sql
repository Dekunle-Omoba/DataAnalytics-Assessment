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