----The company is specifically interested in how it can improve revenue. 
----We will dive into product data such as pricing, reviews, descriptions, and ratings, 
----as well as revenue and website traffic, to produce recommendations for its marketing and sales teams.

----1. Finding out how complete the data is

--Count the total number of products, along with the number of non-missing values in description, 
--listing_price, and last_visited.

SELECT 
    COUNT (*) as total_rows, --count all columns from the info table as total_rows
    COUNT (info.description) as count_description, --count the number of non-missing values
    COUNT (finance.listing_price) as count_listing_price, 
    COUNT (traffic.last_visited) as count_last_visited
FROM ProjectPortfolio..info as info
INNER JOIN ProjectPortfolio..finance as finance --Join the info table with finance
ON info.product_id = finance.product_id
INNER JOIN ProjectPortfolio..traffic as traffic --Join the info table with traffic
ON info.product_id = traffic.product_id;

--We can see the database contains 3,179 products in total. 
--Of the columns we previewed, only one last_visited is missing more than five percent of its values

-- 2. Nike vs. Addidas pricing

-- We'll start to explore the price between Nike and Addidas so we will create a temporary table

DROP Table if exists price
Create Table price 
 (
	product_id NVARCHAR(11) PRIMARY KEY,
	brand VARCHAR(7),
	listing_price INTEGER,
	revenue INTEGER
  );

INSERT INTO price 
SELECT brands.product_id, 
	brands.brand,
	finance.listing_price,
	finance.revenue
FROM ProjectPortfolio..brands as brands
JOIN ProjectPortfolio..finance as finance
	ON brands.product_id = finance.product_id;

SELECT * FROM price

--How do the price points of Nike and Adidas products differ? 
--Answering this question can help us build a picture of the company's stock range and customer market
--We will run a query to produce a distribution of the listing_price and the count for each price, grouped by brand


-- Select the brand, listing_price, and a count of all products
SELECT brand,
    ROUND(listing_price,-1),
    COUNT (product_id)
FROM price
WHERE listing_price > 0 -- Filter for products with a listing_price more than zero
GROUP BY brand,listing_price
ORDER BY listing_price DESC;
 
 --It turns out there are 77 unique prices for the products in our database, 
 --which makes the output of our last query quite difficult to analyze.

 -- 3. Labeling price ranges

 -- Let's build on our previous query by assigning labels to different price ranges, 
 -- grouping by brand and label. We will also include the total revenue for each price range and brand.

DROP Table if exists listingprice;
WITH listingprice as
( 
	SELECT brand,
		revenue,
		CASE  -- Create four labels for products based on their price range
			WHEN listing_price < 42 THEN 'Budget'
			WHEN listing_price >= 42 AND listing_price <74 THEN 'Average'
			WHEN listing_price >=74 AND listing_price <129 THEN 'Expensive'
			ELSE 'Elite'
		END as price_category
	FROM price
	WHERE brand IS NOT NULL
	AND listing_price > 0
	AND revenue > 0 -- filter out products missing a value for brand
)

SELECT brand,
	price_category,
    COUNT(*) as total_products, -- count all products 
    SUM (CAST(revenue as int)) as total_revenue
FROM listingprice
GROUP BY brand, price_category
ORDER BY total_revenue DESC;

--grouping products by brand and price range allows us to see that Adidas items generate more total revenue regardless of price category! 
--Specifically, "Elite" Adidas products priced $129 or more typically generate the highest revenue, so the company can potentially increase revenue by shifting their stock to have a larger proportion of these products!


-- How many products were sold in each price category? What's the average discount of these?
-- add a new column to calculate the unit sold for each product -> save as new table as units-sold

--SELECT brands.brand,
--	brands.product_id,
--	ROUND (
--		CAST(finance.revenue as int) / CAST(finance.listing_price as int)
--		,0) as units,
--	finance.revenue,
--	finance.listing_price,
--	finance.discount
--FROM ProjectPortfolio..brands as brands
--JOIN ProjectPortfolio..finance as finance
--	ON brands.product_id = finance.product_id
--WHERE finance.revenue > 0 AND finance.listing_price > 0;

-- calculate total units sold for each price_category, avg discount for each price_category

WITH pricecategory as
( 
	SELECT brand,
		revenue,
		units,
		discount,
		CASE  -- Create four labels for products based on their price range
			WHEN listing_price < 42 THEN 'Budget'
			WHEN listing_price >= 42 AND listing_price <74 THEN 'Average'
			WHEN listing_price >=74 AND listing_price <129 THEN 'Expensive'
			ELSE 'Elite'
		END as price_category
	FROM ProjectPortfolio..units 
	WHERE brand IS NOT NULL
	AND listing_price IS NOT NULL
	AND revenue IS NOT NULL-- filter out products missing a value for brand
)

SELECT brand,
	price_category,
    COUNT(*) as total_products, -- count all products 
    SUM (CAST(revenue as int)) as total_revenue,
	SUM (units) as total_units,
	ROUND ((AVG (discount) * 100),2) as avg_discount
FROM pricecategory
GROUP BY brand, price_category
ORDER BY total_revenue DESC;


-- 4. Average discount by brand

--we have been looking at listing_price so far, but the listing_price may not be the price that the product is ultimately sold for
-- let's take a look at the discount, which is the percent reduction in the listing_price when the product is actually sold
-- We would like to know whether there is a difference in the amount of discount offered between brands, as this could be influencing revenue


SELECT brands.brand, 
	AVG(finance.discount) * 100 AS average_discount -- select average_discount as a percentage
FROM ProjectPortfolio..brands AS brands 
INNER JOIN ProjectPortfolio..finance AS finance -- Join brands to finance on product_id
    ON brands.product_id = finance.product_id
GROUP BY brands.brand -- Aggregate by brand
HAVING brands.brand IS NOT NULL -- Filter for products without missing values for brand
ORDER BY average_discount;


-- create table price_category

	--SELECT product_id,
	--	brand,
	--	revenue,
	--	units,
	--	discount,
	--	listing_price,
	--	CASE  -- Create four labels for products based on their price range
	--		WHEN listing_price < 42 THEN 'Budget'
	--		WHEN listing_price >= 42 AND listing_price <74 THEN 'Average'
	--		WHEN listing_price >=74 AND listing_price <129 THEN 'Expensive'
	--		ELSE 'Elite'
	--	END as price_category
	--FROM ProjectPortfolio..units 
	--WHERE brand IS NOT NULL
	--AND listing_price IS NOT NULL
	--AND revenue IS NOT NULL-- filter out products missing a value for brand



-- correlation between revenue and discount in Adidas
SELECT 
    (Avg(pricecategory.revenue * pricecategory.discount) - (Avg(pricecategory.revenue) * Avg(pricecategory.discount))) 
	/ (StDevP(pricecategory.revenue) * StDevP(pricecategory.discount)) AS Pearsons_r -- if using PostgreSQL you can simply use corr()
FROM ProjectPortfolio..pricecategory as pricecategory
WHERE brand = 'Adidas';

-- -> negative correlation

-- calculate frequency of discount vs revenue + units sold
SELECT discount,
	ROUND(SUM(revenue),0) as total_revenue,
	SUM(units) as total_units
FROM ProjectPortfolio..pricecategory
WHERE brand = 'Adidas' and price_category = 'Expensive'
GROUP BY discount
ORDER BY total_revenue DESC, total_units DESC;


SELECT discount,
	ROUND(SUM(revenue),0) as total_revenue,
	SUM(units) as total_units
FROM ProjectPortfolio..pricecategory
WHERE brand = 'Adidas' and price_category = 'Average'
GROUP BY discount
ORDER BY total_revenue DESC, total_units DESC;


-- 5. Correlation between revenue and reviews
-- Now explore whether relationships exist between the columns in our database. 
-- We will check the strength and direction of a correlation between revenue and reviews.

-- Calculate the Pearson correlation between reviews and revenue as review_revenue_corr


SELECT 
    (Avg(finance.revenue * reviews.reviews) - (Avg(finance.revenue) * Avg(reviews.reviews))) 
	/ (StDevP(finance.revenue) * StDevP(reviews.reviews)) AS Pearsons_r -- if using PostgreSQL you can simply use corr()
FROM ProjectPortfolio..reviews as reviews
INNER JOIN ProjectPortfolio..finance as finance
    ON reviews.product_id = finance.product_id;

-- there is a strong positive correlation between revenue and reviews. 


-- CORR between reviews and rating
SELECT 
    (Avg(reviews.rating * reviews.reviews) - (Avg(reviews.rating) * Avg(reviews.reviews))) 
	/ (StDevP(reviews.rating) * StDevP(reviews.reviews)) AS Pearsons_r -- if using PostgreSQL you can simply use corr()
FROM ProjectPortfolio..reviews as reviews;

-- very low positive correlation



-- 6. Reviews by month and brand

-- Count the number of reviews per brand per month


DROP TABLE if exists review_months;
WITH reviews_month as -- Create a CTE select brand, month from last_visited, reviews
(
	SELECT brand,
		DATEPART (month, traffic.last_visited) as month_r,
		reviews.reviews
	FROM ProjectPortfolio..brands as brands
	INNER JOIN ProjectPortfolio..traffic as traffic
		ON brands.product_id = traffic.product_id
	INNER JOIN ProjectPortfolio..reviews as reviews
		ON brands.product_id = reviews.product_id
	WHERE brands.brand IS NOT NULL -- filtering out missing values for brand and month
    AND DATEPART (month, traffic.last_visited) IS NOT NULL
)
SELECT brand,
	COUNT(*) as num_reviews, -- a count of all products in reviews aliased as num_reviews
	month_r
FROM reviews_month
GROUP BY brand, month_r
ORDER BY brand, month_r;

-- Looks like product reviews are highest in the first quarter of the calendar year, so there is scope to run experiments aiming to increase the volume of reviews in the other nine months!


-- 7.calculate the distribution of products of women, men, and unisex in the shop

-- create table for products categorized by gender

UPDATE ProjectPortfolio..info -- update all product_name to lowercase
SET product_name = LOWER (product_name);


SELECT *,
	CASE  -- Create four labels for products based on their gender
		WHEN product_name LIKE '%women%' THEN 'women'
		WHEN product_name LIKE '%men%' THEN 'men'
		WHEN product_name LIKE '%unisex%' THEN 'unisex'
		ELSE 'not specified'
	END as gender
FROM ProjectPortfolio..info
WHERE product_name IS NOT NULL



-- calculate the percentage of each gender products
SELECT 	gender.gender,
	COUNT(gender.product_id) as total_products,
	SUM (finance.revenue) as total_revenue
FROM ProjectPortfolio..gender as gender
INNER JOIN ProjectPortfolio..finance as finance
	ON gender.product_id = finance.product_id
GROUP BY gender.gender

-- calculcate median revenue of each gender category

WITH men AS -- Create the footwear CTE, containing description and revenue
(
    SELECT gender.gender,
		finance.revenue
    FROM ProjectPortfolio..gender as gender
    INNER JOIN ProjectPortfolio..finance as finance
        ON gender.product_id = finance.product_id
	WHERE gender.gender = 'men'
)
SELECT 
	COUNT(*) as num_men_products,
	(
		(SELECT MAX(revenue) FROM 
			(SELECT TOP 50 PERCENT revenue 
			 FROM men as finance ORDER BY revenue ) AS BottomHalf)
		+
		(SELECT MIN(revenue) FROM 
			(SELECT TOP 50 PERCENT revenue 
			 FROM men as finance ORDER BY revenue DESC) AS TopHalf)
	) / 2.0 AS median_men_revenue

FROM men




