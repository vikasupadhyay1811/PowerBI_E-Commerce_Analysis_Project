-- 14. Identify the top 5 most valuable customers using a composite score that combines three key metrics: (SQL)
-- a.	Total Revenue (50% weight): The total amount of money spent by the customer.
-- b.	Order Frequency (30% weight): The number of orders placed by the customer, indicating their loyalty and engagement.
-- c.	Average Order Value (20% weight): The average value of each order placed by the customer, reflecting the typical transaction size.

select * from customers;
select * from orders;
-- alter table orders change `Sale Price` SalePrice text


WITH CustomerMetrics AS (
    SELECT 
        o.CustomerID,
        SUM(o.SalePrice) AS TotalRevenue,
        COUNT(o.OrderID) AS OrderFrequency,
        AVG(o.SalePrice) AS AvgOrderValue
    FROM 
        orders o
    GROUP BY 
        o.CustomerID
),
NormalizedMetrics AS (
    SELECT 
        cm.CustomerID,
        cm.TotalRevenue,
        cm.OrderFrequency,
        cm.AvgOrderValue,
        cm.TotalRevenue / (SELECT MAX(TotalRevenue) FROM CustomerMetrics) AS NormalizedRevenue,
        cm.OrderFrequency / (SELECT MAX(OrderFrequency) FROM CustomerMetrics) AS NormalizedFrequency,
        cm.AvgOrderValue / (SELECT MAX(AvgOrderValue) FROM CustomerMetrics) AS NormalizedValue
    FROM 
        CustomerMetrics cm
),
CompositeScores AS (
    SELECT 
        nm.CustomerID,
        (nm.NormalizedRevenue * 0.50) + 
        (nm.NormalizedFrequency * 0.30) + 
        (nm.NormalizedValue * 0.20) AS CompositeScore
    FROM 
        NormalizedMetrics nm
)
SELECT 
    cs.CustomerID,
    cs.CompositeScore
FROM 
    CompositeScores cs
ORDER BY 
    cs.CompositeScore DESC
LIMIT 5;

-- 15. Calculate the month-over-month growth rate in total revenue across the entire dataset. (SQL)

--  SELECT 
--         OrderDate,
--         -- substr(OrderDate,),
--         str_to_date(OrderDate,'%d/%m/%Y') as dt,
--         DATE_FORMAT(str_to_date(OrderDate,'%d/%m/%Y'), '%Y-%m') AS YearMonth
--     FROM 
--         orders

WITH MonthlyRevenue AS (
    SELECT 
        DATE_FORMAT(str_to_date(OrderDate,'%d/%m/%Y'), '%Y-%m') AS YearMonth,
        SUM(SalePrice) AS TotalRevenue
    FROM 
        orders
    GROUP BY 
        YearMonth
    ORDER BY 
        YearMonth
),
RevenueGrowth AS (
    SELECT 
        mr.YearMonth,
        mr.TotalRevenue,
        LAG(mr.TotalRevenue) OVER (ORDER BY mr.YearMonth) AS PreviousMonthRevenue,
        CASE 
            WHEN LAG(mr.TotalRevenue) OVER (ORDER BY mr.YearMonth) IS NOT NULL THEN
                ((mr.TotalRevenue - LAG(mr.TotalRevenue) OVER (ORDER BY mr.YearMonth)) /
                LAG(mr.TotalRevenue) OVER (ORDER BY mr.YearMonth)) * 100
            ELSE 
                NULL
        END AS MoMGrowthRate
    FROM 
        MonthlyRevenue mr
)
SELECT 
    ROUND(YearMonth,2) AS YearMonth,
    ROUND(TotalRevenue,2) AS TotalRevenue,
    ROUND(PreviousMonthRevenue,2) AS PreviousMonthRevenue,
    ROUND(MoMGrowthRate,2) AS MoMGrowthRate
FROM 
    RevenueGrowth
ORDER BY 
    YearMonth;
    

-- 16.	Calculate the rolling 3-month average revenue for each product category. (SQL)


WITH MonthlyCategoryRevenue AS (
    SELECT 
        DATE_FORMAT(str_to_date(OrderDate,'%d/%m/%Y'), '%Y-%m') AS YearMonth,
        ProductCategory,
        SUM(SalePrice) AS TotalRevenue
    FROM 
        orders
    GROUP BY 
        YearMonth, ProductCategory
    ORDER BY 
        YearMonth
)

SELECT 
    mcr.YearMonth,
    mcr.ProductCategory,
    mcr.TotalRevenue,
    AVG(mcr.TotalRevenue) OVER (
        PARTITION BY mcr.ProductCategory 
        ORDER BY mcr.YearMonth 
        ROWS 2 PRECEDING
    ) AS Rolling3MonthAvgRevenue
FROM 
    MonthlyCategoryRevenue mcr
ORDER BY 
    mcr.ProductCategory, mcr.YearMonth; 
    
-- 17.	Update the orders table to apply a 15% discount on the `Sale Price` for orders
-- placed by customers who have made at least 10 orders. (SQL)

SET SQL_SAFE_UPDATES = 0;

WITH FrequentCustomers AS (
    SELECT 
        CustomerID
    FROM 
        orders
    GROUP BY 
        CustomerID
    HAVING 
        COUNT(OrderID) >= 1
)
UPDATE orders
SET SalePrice = SalePrice * 0.85 WHERE CustomerID IN 
(SELECT CustomerID FROM FrequentCustomers); 

SET SQL_SAFE_UPDATES = 1;

-- 18.	Calculate the average number of days between consecutive orders for customers
-- who have placed at least five orders. 


WITH EligibleCustomers AS (
    SELECT 
        CustomerID
    FROM 
        orders
    GROUP BY 
        CustomerID
    HAVING 
        COUNT(OrderID) >= 5
),
OrderIntervals AS (
    SELECT 
        o.CustomerID,
        o.OrderDate,
        DATEDIFF(o.OrderDate, LAG(o.OrderDate) OVER (
            PARTITION BY o.CustomerID ORDER BY o.OrderDate
        )) AS DaysBetweenOrders
    FROM 
        orders o
    WHERE 
        o.CustomerID IN (SELECT CustomerID FROM EligibleCustomers)
),
AverageDaysPerCustomer AS (
    SELECT 
        CustomerID,
        AVG(DaysBetweenOrders) AS AvgDaysBetweenOrders
    FROM 
        OrderIntervals
    WHERE 
        DaysBetweenOrders IS NOT NULL
    GROUP BY 
        CustomerID
)
SELECT 
    AVG(AvgDaysBetweenOrders) AS OverallAvgDaysBetweenOrders
FROM 
    AverageDaysPerCustomer; 
    

-- 19.	Identify customers who have generated revenue that is more than 30% higher than
-- the average revenue per customer. 


WITH CustomerRevenue AS (
    SELECT 
        CustomerID,
        SUM(SalePrice) AS TotalRevenue
    FROM 
        orders
    GROUP BY 
        CustomerID
),
AverageRevenue AS (
    SELECT 
        AVG(TotalRevenue) AS AvgRevenue
    FROM 
        CustomerRevenue
)
SELECT 
    cr.CustomerID,
    ROUND(cr.TotalRevenue,2) AS TotalRevenue,
    ROUND(ar.AvgRevenue,2) AS AvgRevenue,
    ROUND((cr.TotalRevenue - ar.AvgRevenue),2) AS ExcessRevenue
FROM 
    CustomerRevenue cr
CROSS JOIN 
    AverageRevenue ar
WHERE 
    cr.TotalRevenue > ar.AvgRevenue * 1.3
ORDER BY 
    cr.TotalRevenue DESC; 
    
 
-- 20.	Determine the top 3 product categories that have shown the highest increase
-- in sales over the past year compared to the previous year.  

SELECT OrderDate,DATE_FORMAT(str_to_date(OrderDate,'%d/%m/%Y'), '%Y') TT FROM orders


WITH YearlyCategorySales AS (
    SELECT 
        DATE_FORMAT(str_to_date(OrderDate,'%d/%m/%Y'), '%Y') AS SalesYear,
        ProductCategory,
        SUM(SalePrice) AS TotalSales
    FROM 
        orders
    GROUP BY 
        SalesYear, ProductCategory
),
CategorySalesGrowth AS (
    SELECT 
        ycs.ProductCategory,
        ycs.SalesYear,
        ycs.TotalSales,
        LAG(ycs.TotalSales) OVER (PARTITION BY ycs.ProductCategory ORDER BY ycs.SalesYear) AS PreviousYearSales,
        (ycs.TotalSales - LAG(ycs.TotalSales) OVER (PARTITION BY ycs.ProductCategory ORDER BY ycs.SalesYear)) AS SalesIncrease
    FROM 
        YearlyCategorySales ycs
),
RankedCategories AS (
    SELECT 
        csg.ProductCategory,
        csg.SalesYear,
        csg.TotalSales,
        csg.PreviousYearSales,
        csg.SalesIncrease,
        DENSE_RANK() OVER (ORDER BY csg.SalesIncrease DESC) AS `Rank`
    FROM 
        CategorySalesGrowth csg
    WHERE 
        csg.SalesYear = (SELECT MAX(SalesYear) FROM orders)
)
SELECT 
    ProductCategory,
    SalesYear,
    ROUND(TotalSales,2) AS TotalSales,
    ROUND(PreviousYearSales,2) AS PreviousYearSales,
    ROUND(SalesIncrease,2) AS SalesIncrease
FROM 
    RankedCategories
WHERE 
    `Rank` <= 3
ORDER BY 
    SalesIncrease DESC;







    
    






