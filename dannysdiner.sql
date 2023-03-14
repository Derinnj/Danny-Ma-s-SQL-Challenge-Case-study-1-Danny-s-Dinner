--CREATE SCHEMA dannys_diner;
--SET search_path = dannys_diner;

--CREATE TABLE sales (
--  "customer_id" VARCHAR(1),
--  "order_date" DATE,
--  "product_id" INTEGER
--);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" [DATE]
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------CREATE A NEW TABLE WITH FULL MEMBER DETAILS


INSERT INTO Dannys_FullMember
SELECT S.customer_id, S.order_date, Mn.product_name, Mn.price,
	CASE WHEN S.customer_id NOT IN (SELECT customer_id FROM members) THEN 'N' 
		WHEN Mm.join_date > S.order_date THEN 'N' ELSE 'Y' 
		END AS members		 
FROM sales S
LEFT JOIN menu Mn
	ON S.product_id = Mn.product_id
LEFT JOIN members Mm
	ON S.customer_id = Mm.customer_id

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---1. What is the total amount each customer spent at the restaurant?

SELECT customer_id, SUM(price)
FROM Dannys_FullMember
GROUP BY customer_id;


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT [order_date]) 
FROM Dannys_FullMember
GROUP BY customer_id


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---3. What was the first item from the menu purchased by each customer?

WITH R_ord AS (
SELECT customer_id,product_name, MIN(order_date) order_date, DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY MIN(order_date)) AS ranked_order 
FROM Dannys_FullMember
GROUP BY customer_id, product_name
)

SELECT customer_id, product_name, order_date
FROM R_ord
WHERE ranked_order = 1
--GROUP BY customer_id, product_name 
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT M.product_name, COUNT(M.product_id) Num_sales
FROM sales S
JOIN menu M
	ON S.product_id = M.product_id
GROUP BY  M.product_name
order by Num_sales DESC

SELECT S.customer_id, M.product_name, COUNT(S.product_id) Num_purchase
FROM sales S
JOIN menu M
	ON S.product_id = M.product_id
WHERE product_name = 'ramen'
GROUP BY S.customer_id, M.product_name
ORDER BY Num_purchase DESC

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---5. Which item was the most popular for each customer?

SELECT customer_id, product_name, COUNT(product_name) [count]
FROM Dannys_FullMember
GROUP BY customer_id, product_name 
ORDER BY customer_id, [count] DESC;


SELECT customer_id, product_name, total_orders
FROM (
  SELECT customer_id, product_id, COUNT(*) AS total_orders,
    RANK () OVER (PARTITION BY customer_id ORDER BY COUNT(*) DESC) AS rank
  FROM sales
  GROUP BY customer_id, product_id
) AS order_counts
JOIN menu
  ON order_counts.product_id = menu.product_id
  AND order_counts.rank = 1

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---6. Which item was purchased first by the customer after they became a member?
WITH Fst_ord AS (
	SELECT Mm.customer_id, MIN(S.order_date) First_order
	FROM members Mm
	JOIN sales S
		ON S.customer_id = Mm.customer_id
	JOIN menu M 
		ON M.product_id = S.product_id
	WHERE S.order_date >= join_date
	GROUP BY Mm.customer_id
)
SELECT Fo.customer_id, Fo.First_order, M.product_name
FROM Fst_ord Fo
JOIN sales S 
	ON S.order_date = Fo.First_order
JOIN menu M 
	ON M.product_id = S.product_id
GROUP BY Fo.customer_id, First_order, product_name

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--7. Which item was purchased just before the customer became a member?

WITH lst_ord AS (SELECT S.customer_id, S.order_date, RANK() OVER(PARTITION BY S.customer_id ORDER BY order_date DESC) [Rank]
	FROM members Mm
	JOIN sales S
		ON S.customer_id = Mm.customer_id
	JOIN menu M 
		ON M.product_id = S.product_id
	WHERE S.order_date <= join_date 
	GROUP BY S.customer_id, S.order_date)

SELECT L.customer_id, L.order_date, M.product_name
FROM lst_ord L
JOIN sales S 
	ON S.order_date = L.order_date
JOIN menu M 
	ON M.product_id = S.product_id
WHERE [Rank] = 1
GROUP BY L.customer_id, L.order_date, product_name;

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- 8 What is the total items and amount spent for each member before they became a member?
SELECT customer_id, SUM(price) Total_amt
FROM Dannys_FullMember
WHERE members = 'N'
GROUP BY customer_id;

SELECT *
FROM Dannys_FullMember


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT customer_id, 
       SUM(CASE WHEN product_name = 'sushi' THEN price*2 ELSE price END) AS total_amount,
       SUM(CASE WHEN product_name = 'sushi' THEN price*2*10 ELSE price*10 END) AS total_points
FROM Dannys_FullMember
GROUP BY customer_id;

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT 
    SUM(CASE 
            WHEN order_date <= DATEADD(WEEK, 1, members.join_date) THEN price * 20 
            WHEN product_name = 'sushi' THEN price * 20 
            ELSE price * 10 
        END) AS total_points 
FROM Dannys_FullMember 
JOIN members
	ON Dannys_FullMember.customer_id = members.customer_id
WHERE Dannys_FullMember.customer_id = 'A' AND order_date < '2022-02-01';

SELECT 
    SUM(CASE 
            WHEN order_date <= DATEADD(WEEK, 1, members.join_date) THEN price * 20 
            WHEN product_name = 'sushi' THEN price * 20 
            ELSE price * 10 
        END) AS total_points 
FROM Dannys_FullMember 
JOIN members
	ON Dannys_FullMember.customer_id = members.customer_id
WHERE Dannys_FullMember.customer_id = 'B' AND order_date < '2022-02-01'



-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT customer_id, order_date, product_name, price, members,
		CASE WHEN members = 'Y' THEN RANK() OVER(PARTITION BY customer_id ORDER BY order_date)
		ELSE null
		END AS ranking
FROM Dannys_FullMember;





