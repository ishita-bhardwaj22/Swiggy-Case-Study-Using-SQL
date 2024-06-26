-----
--1. How many customers have not placed any orders?
select user_id from users
where user_id not in (
    select distinct user_id from orders
    where user_id is not null
);

--2a. What is the average price of each food type?
 with food_details as(
    select * from food f
    inner join menu m
    on f.f_id = m.f_id
)
select type, round(avg(price),2) as "Average Price",
median(price) as "Median Price",
stats_mode(price) as "Mode Price"
from food_details
group by type
order by "Average Price" desc;

--2b. What is the average price of food for each restaurant?
with restaurant_details as (
    select * from restaurants r
    inner join orders o
    on r.r_id = o.r_id
    inner join menu m
    on r.r_id = m.r_id
)
select R_Name as "Restaurant Name", '$ '||round(avg(price),2) as  "Average Price"
from restaurant_details
group by R_Name
order by R_Name;

--3. Find the top restaurant in terms of the number of orders for all months
with res as (
select * from orders o
inner join restaurants r
on o.r_id = r.r_id
),
res_grouped as (
select to_char(order_date,'month') as order_month, r_name,
count(1) as order_count from res
group by extract(month from order_date),to_char(order_date,'month'),r_name
order by extract(month from order_date)
),
res_ranking as (
select order_month,r_name,
rank() over(partition by order_month order by order_count desc) as res_rank
from res_grouped
)
select ORDER_MONTH, R_NAME from res_ranking
where res_rank = 1
;

----- OPTIMIZED QUERY
WITH res AS (
    SELECT TO_CHAR(o.order_date, 'Month') AS order_month, 
    r.r_name, COUNT(*) AS order_count
    FROM orders o
    INNER JOIN restaurants r 
    ON o.r_id = r.r_id
    GROUP BY EXTRACT(month FROM o.order_date), TO_CHAR(o.order_date, 'Month'), r.r_name
)
SELECT order_month, r_name
FROM (
    SELECT order_month, r_name, 
    RANK() OVER (PARTITION BY order_month ORDER BY order_count DESC) AS res_rank
    FROM res
)
WHERE res_rank = 1
ORDER BY EXTRACT(month FROM TO_DATE(order_month, 'Month'));


--4. Find the top restaurant in terms of the number of orders for the month of June
SELECT *
FROM restaurants r
INNER JOIN orders o
ON r.r_id = o.r_id
WHERE TRIM(TO_CHAR(o.ORDER_DATE, 'Month')) = 'June';

Note : The reason we use TRIM function is because TO_CHAR() takes the trailing spaces. So TRIM is used to remove any unecessary space.

--5. Restaurants with monthly revenue greater than 500.
with res as (
SELECT to_char(o.order_date,'Month') as order_month ,r.r_name, sum(m.price) as price
FROM restaurants r
INNER JOIN orders o ON r.r_id = o.r_id
INNER JOIN menu m ON o.r_id = m.r_id
GROUP BY to_char(o.order_date,'Month'),r.r_name
having sum(m.price) >= 500
)
select * from res
order by extract(month from to_date(order_month,'Month')) asc;

Note : You can do ORDER BY on a column that is not mentioned in GROUP BY. Thats why we performed ORDER BY by using a CTE.
--order by o.order_date asc;


--6. Show all orders with order details for a particular customer in a particular date range (15th May 2022 to 15th June 2022)
select * from users u
inner join orders o
on u.user_id = o.user_id
where u.user_id = 1 and 
o.order_date between to_date('15-05-22','DD-MM-YY') and to_date('15-06-22','DD-MM-YY');

--7. Which restaurant has the highest number of repeat customers?
with repeated_cust as (
select r.r_name,o.user_id,count(*) as order_count from restaurants r
inner join orders o
on r.r_id = o.r_id
group by r.r_name,o.user_id
having count(*)>1
), loyal_cust as(
select r_name,count(user_id) as "Repeated_customers" from repeated_cust
group by r_name
order by count(user_id) desc
)
select * from loyal_cust
where rownum = 1;

--8. Month over month revenue growth of swiggy
with month_rev as (
select to_char(o.order_date,'Month') as order_month ,sum(price) as monthly_rev
from orders o
inner join menu m
on o.r_id = m.r_id
group by to_char(o.order_date,'Month')
)
select order_month,
sum(monthly_rev) over(order by extract(month from to_date(order_month,'Month'))) as Rolling_Monthly_Rev
from month_rev
;


--9. Find the top 3 most ordered dish

--Using FETCH
select F_NAME,count(*) as order_count from order_details od
inner join food f
on f.f_id = od.f_id
group by F_NAME
order by order_count desc
FETCH FIRST 3 ROWS ONLY;

--Using ROWNUM
select F_name,order_count from (
select F_NAME,count(*) as order_count from order_details od
inner join food f
on f.f_id = od.f_id
group by F_NAME
order by order_count desc
)
where rownum <= 3
;


--10. Month over month revenue growth of each restaurant.
with res_grouped as (
select r.r_name, to_char(order_date,'Month') as order_month, sum(m.price) as price
from orders o
inner join restaurants r on o.r_id = r.r_id
inner join menu m on o.r_id = m.r_id
group by r.r_name, to_char(order_date,'Month')
)
select r_name,order_month,
sum(price) over(
    partition by r_name
    order by extract(Month from to_date(order_month,'Month')) asc
    ) as res_rolling__month_rev
from res_grouped
;

--11. What is the overall revenue generated by the platform during a specific time period?
select sum(amount) as total_revenue
from orders
where order_date between to_date('01-05-22','DD-MM-YY') and to_date('01-06-22','DD-MM-YY');

--12. What is the average order value per user?
select avg(amount) as avg_order_value
from orders
group by user_id;

--13. What is the average delivery time for each restaurant, and how does it affect customer satisfaction?
select r.r_name, round(avg(o.delivery_time),2) as avg_delivery_time, round(avg(o.delivery_rating),2) as avg_delivery_rating
from orders o
join restaurants r on o.r_id = r.r_id
group by r.r_name;

--14. What is the average rating for each restaurant and delivery partner?
select r.r_name, round(avg(o.restaurant_rating),2) as avg_restaurant_rating
from orders o
join restaurants r on o.r_id = r.r_id
group by r.r_name;

select dp.partner_name, round(avg(o.delivery_rating),2) as avg_delivery_rating
from orders o
join delivery_partner dp on o.partner_id = dp.partner_id
group by dp.partner_name;

--15. How do the ratings for restaurants and delivery partners correlate with customer retention?
with group_1 as (
select r.r_name, count(distinct o.user_id) as unique_users, avg(o.restaurant_rating) as avg_restaurant_rating
from orders o
join restaurants r on o.r_id = r.r_id
group by r.r_name
), group_2 as(
select dp.partner_name, count(distinct o.user_id) as unique_users, avg(o.delivery_rating) as avg_delivery_rating
from orders o
join delivery_partner dp on o.partner_id = dp.partner_id
group by dp.partner_name
)
select CORR(AVG_RESTAURANT_RATING,AVG_DELIVERY_RATING) from group_1 g1
inner join group_2 g2
on g1.UNIQUE_USERS = g2.UNIQUE_USERS
;

--16. Which days and times see the highest order volume, and are there any patterns in user behavior?
SELECT TO_CHAR(order_date, 'DAY') AS order_day, 
       TO_CHAR(order_date, 'HH24') AS order_hour, 
       COUNT(order_id) AS order_count
FROM orders
GROUP BY TO_CHAR(order_date, 'DAY'), TO_CHAR(order_date, 'HH24')
ORDER BY order_count DESC;

--17. How many orders were delivered by each delivery partner and what is their average delivery rating?
SELECT DP.PARTNER_ID, DP.PARTNER_NAME, COUNT(*) AS DELIVERY_COUNT, AVG(O.DELIVERY_RATING) AS AVG_DELIVERY_RATING
FROM ORDERS O
JOIN DELIVERY_PARTNER DP ON O.PARTNER_ID = DP.PARTNER_ID
GROUP BY DP.PARTNER_ID, DP.PARTNER_NAME;

--18. What is the distribution of delivery partners in the Delivery_Partner table?
SELECT PARTNER_NAME, COUNT(*) AS PARTNER_COUNT 
FROM DELIVERY_PARTNER 
GROUP BY PARTNER_NAME 
ORDER BY PARTNER_COUNT DESC;
