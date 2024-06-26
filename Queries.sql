-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT DISTINCT
    market
FROM
    dim_customer
WHERE
    customer = 'Atliq Exclusive'
        AND region = 'APAC'
ORDER BY market;

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg

with cte1 as(
select count(distinct(product_code)) as unique_products_2020
from fact_sales_monthly
where fiscal_year=2020),
	 cte2 as(
select count(distinct(product_code)) as unique_products_2021
from fact_sales_monthly
where fiscal_year=2021)

select *,round(((unique_products_2021-unique_products_2020)/unique_products_2020)*100,2) as petcentage_chg
from cte1
cross join cte2;

-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. The final output contains 2 fields, segment product_count 

SELECT 
    segment, COUNT(DISTINCT (product_code)) AS product_count
FROM
    dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields: segment,product_count_2020,product_count_2021,difference

WITH cte1 AS(
SELECT 
    dp.segment,
    COUNT(DISTINCT (CASE
            WHEN fsm.fiscal_year = 2020 THEN dp.product_code
        END)) AS unique_products_2020,
    COUNT(DISTINCT (CASE
            WHEN fsm.fiscal_year = 2021 THEN dp.product_code
        END)) AS unique_products_2021
FROM
    dim_product dp
        JOIN
    fact_sales_monthly fsm ON fsm.product_code = dp.product_code
GROUP BY dp.segment)

SELECT 
    *,
    (unique_products_2021 - unique_products_2020) AS difference
FROM
    cte1
ORDER BY difference DESC;

-- 5. Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields, product_code product manufacturing_cost

SELECT 
    fmc.product_code, p.product, fmc.manufacturing_cost
FROM
    fact_manufacturing_cost fmc
        JOIN
    dim_product p ON fmc.product_code = p.product_code
WHERE
    manufacturing_cost IN (SELECT 
            MIN(manufacturing_cost)
        FROM
            fact_manufacturing_cost UNION SELECT 
            MAX(manufacturing_cost)
        FROM
            fact_manufacturing_cost)
ORDER BY manufacturing_cost DESC;

-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. The final output contains these fields, customer_code customer average_discount_percentage

WITH cte1 AS(
SELECT 
    c.customer_code,
    c.customer,
    AVG(fpid.pre_invoice_discount_pct) AS average_discount_percentage,
    dense_rank() over(order by  AVG(fpid.pre_invoice_discount_pct) desc) as drnk
FROM
    fact_pre_invoice_deductions fpid
        JOIN
    dim_customer c ON c.customer_code= fpid.customer_code
WHERE c.market="India" AND fpid.fiscal_year=2021
GROUP BY c.customer_code,c.customer
)

 SELECT 
    customer_code, customer, average_discount_percentage
FROM
    cte1
WHERE
    drnk <= 5


-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . This analysis helps to get an idea of low and high-performing months and take strategic decisions. The final report contains these columns: Month Year Gross sales Amount

SELECT 
    MONTH(sm.date) AS month,
    sm.fiscal_year AS year,
    SUM(gp.gross_price * sm.sold_quantity) AS gross_sales_amount
FROM
    fact_sales_monthly sm
        JOIN
    fact_gross_price gp ON sm.product_code = gp.product_code
        AND sm.fiscal_year = gp.fiscal_year
        JOIN
    dim_customer c ON sm.customer_code = c.customer_code
WHERE
    c.customer = 'Atliq Exclusive'
GROUP BY month , year
ORDER BY month , year;

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity
 
 with cte as(
 select *,
	 CASE
		WHEN month(date) in (9,10,11) THEN "Q1"
		WHEN month(date) in (1,2,12) THEN "Q2"
		WHEN month(date) in (3,4,5) THEN "Q3"
		ELSE "Q4"
	 END as quarter
 from fact_sales_monthly 
 where fiscal_year=2020
 )
 
 select quarter,count(sold_quantity) as total_sold_quantity
 from cte 
 group by quarter
 order by total_sold_quantity desc;

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? The final output contains these fields, channel gross_sales_mln percentage 

with cte1 as(
SELECT 
    c.channel,
    round(SUM((gp.gross_price * sm.sold_quantity) / 1000000),2) AS gross_sales_mln
FROM
    dim_customer c
        JOIN
    fact_sales_monthly sm ON c.customer_code = sm.customer_code
        JOIN
    fact_gross_price gp ON sm.fiscal_year = gp.fiscal_year
        AND sm.product_code = gp.product_code
WHERE
    sm.fiscal_year = 2021
GROUP BY c.channel
)
select *,concat(round((gross_sales_mln/sum(gross_sales_mln) over()*100),2),"%") as percentage
from cte1
order by percentage desc;

-- 10.Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these fields, division product_code product total_sold_quantity rank_order

with cte1 as(
select p.division,sm.product_code,p.product , sum(sm.sold_quantity) as total_sold_quantity, dense_rank() over(partition by p.division order by sum(sold_quantity) desc) as drnk from fact_sales_monthly sm
join dim_product p on sm.product_code=p.product_code
where sm.fiscal_year=2021
group by p.division,sm.product_code,p.product)

select * from cte1
where drnk<=3;
