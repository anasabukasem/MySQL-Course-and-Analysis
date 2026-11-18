# CoffeeShop MySQL

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479a1?logo=mysql&logoColor=white)

A complete **MySQL course** and an **executive data analysis**, both built on one coffee shop database. Two SQL files, no tools and no libraries: everything is plain MySQL. Run the course file first, then the analysis file.

The course teaches MySQL step by step on the coffee shop. The analysis then treats the same database as a real business and answers the questions a managing director asks: when do we sell, what do we earn, who are our best customers, what will run out, and what should we do next.


## The database

Eight tables model the shop.

| Table | What it stores |
|---|---|
| `Employees` | Staff, role, hire date, salary |
| `Attendance` | Daily check-in and check-out of every employee |
| `Suppliers` | Companies that supply the shop |
| `Products` | Menu items with price, cost, stock and expiry date |
| `LoyaltyCards` | Customer cards and their points |
| `Orders` | One row per sale: who served it, when, dine-in or takeaway, which card, total |
| `Order_Details` | The lines of each order: product, quantity, unit price, discount |
| `Payments` | How each order was paid |

### Relationships

The database uses all three relationship types.

**One to many** (6 relationships): the foreign key sits on the "many" side.

| One | Many | Foreign key | Participation of the "many" side |
|---|---|---|---|
| `Employees` | `Attendance` | `Attendance.EmployeeID` | Mandatory |
| `Employees` | `Orders` | `Orders.EmployeeID` | Optional |
| `LoyaltyCards` | `Orders` | `Orders.LoyaltyCardID` | Optional (most customers have no card) |
| `Suppliers` | `Products` | `Products.SupplierID` | Optional |
| `Orders` | `Order_Details` | `Order_Details.OrderID` | Mandatory |
| `Products` | `Order_Details` | `Order_Details.ProductID` | Optional |

**One to one** (2 relationships): the foreign key is also `UNIQUE`.

| Table A | Table B | Foreign key | Meaning |
|---|---|---|---|
| `Orders` | `Payments` | `Payments.OrderID` (unique) | Every order has at most one payment: no instalments, no split payments |
| `Orders` | `Customer_Reviews` | `Customer_Reviews.OrderID` (unique) | An order can receive at most one review |

**Many to many** (1 relationship): solved with a junction table.

| Table A | Table B | Junction table | Meaning |
|---|---|---|---|
| `Orders` | `Products` | `Order_Details` | An order contains many products and a product appears in many orders. The junction table also carries the quantity, unit price and discount of each line. |

Foreign keys use `ON DELETE` and `ON UPDATE` rules: `CASCADE` when the child has no meaning without the parent (attendance, order lines, payments, reviews) and `SET NULL` when the child must survive (an order keeps existing if its employee, card or supplier is removed).

The analysis adds three tables, `Expenses`, `Sales_Targets` and `Customer_Reviews`, and the course creates three helper tables for its triggers and events: `Salary_History`, `Audit_Log` and `Daily_Sales_Summary`. The eight original tables keep their structure.

## Part 1: The course

File: `CoffeeShop_Complete_MySQL_Course.sql`, about 2,670 lines. Every section has a title and a one-line description, and the code is the explanation.

| # | Section | What you learn |
|:-:|---|---|
| 01 | Database | Create, show, use, alter, rename and drop databases; character sets and collations |
| 02 | Tables, data types and keys | Every data type, constraints, primary keys, foreign keys, `ON DELETE` and `ON UPDATE`; builds the eight tables |
| 03 | ALTER TABLE | Add, drop, modify and rename columns; add and drop constraints; table options |
| 04 | INSERT and sample data | Every form of `INSERT`, and the coffee shop data |
| 05 | SELECT | Columns, aliases, expressions, clause order, the types of `SELECT` |
| 06 | WHERE and operators | Comparison, logical, `BETWEEN`, `IN`, `LIKE`, `REGEXP`, `NULL` handling, dates |
| 07 | ORDER BY, LIMIT, DISTINCT | Sorting, top N, pagination, removing duplicates |
| 08 | Functions | Numeric, string, date and time, `IF`, `CASE`, `CAST`, JSON, hashing |
| 09 | Aggregate functions | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `GROUP_CONCAT`, statistics |
| 10 | GROUP BY and HAVING | Grouping, `WHERE` vs `HAVING`, `WITH ROLLUP` |
| 11 | Subqueries | Scalar, `IN`, `ANY` / `ALL`, `EXISTS`, correlated, derived tables |
| 12 | JOINS | Inner, left, right, full, cross, self, natural, `USING`, `LATERAL`, multi-table joins |
| 13 | Set operators | `UNION`, `UNION ALL`, `INTERSECT`, `EXCEPT` |
| 14 | Window functions | `ROW_NUMBER`, `RANK`, `NTILE`, `LAG`, `LEAD`, running totals, moving averages |
| 15 | CTE and recursive CTE | `WITH`, number series, calendars, hierarchies |
| 16 | UPDATE and DELETE | Changing and removing rows, and what the foreign key rules do in practice |
| 17 | Transactions and locking | `COMMIT`, `ROLLBACK`, `SAVEPOINT`, isolation levels, row and table locks |
| 18 | Copying tables and advanced INSERT | `CREATE TABLE ... AS`, `LIKE`, temporary tables, upsert, `TRUNCATE` |
| 19 | Views | Simple, joined and aggregated views, updatable views, `WITH CHECK OPTION` |
| 20 | Indexes and EXPLAIN | Index types, `FULLTEXT`, reading execution plans |
| 21 | Variables and prepared statements | User and system variables, dynamic SQL |
| 22 | Stored procedures, functions, cursors | Parameters, loops, error handling, `SIGNAL`, cursors, stored functions |
| 23 | Triggers and events | `BEFORE` / `AFTER` triggers, audit logs, scheduled events |
| 24 | Users, privileges, backup, metadata | `GRANT`, roles, `mysqldump`, generated columns, partitioning, `information_schema` |
| 25 | Final practice | 18 business reports for the coffee shop |


## Part 2: The analysis project

File: `CoffeeShop_Executive_Data_Analysis.sql`, about 1,290 lines. It turns the course database into a business case.

**Step 1: the data.** Part 0 of the file adds six months of trading (October 2025 to March 2026): about 23,000 orders with payments, 600 loyalty cards, 5 new products, attendance for every shift, monthly expenses, monthly sales targets and customer reviews. The data follows real business patterns: growth, weekday and hour rhythms, seasonal drinks, a price rise, a promotion, and Ramadan.

**Step 2: the analytical layer.** Two views, `v_FactOrders` and `v_FactLines`, hold completed sales only, so every report is short and uses the same definition of a sale.

**Step 3: 17 sections of analysis.**

| # | Section | The question it answers |
|:-:|---|---|
| 01 | Executive scorecard | How did this quarter compare with the last one? |
| 02 | Revenue trends and seasonality | When do we sell: by month, week, weekday and hour? |
| 03 | Ramadan impact | How did Ramadan change when and what customers buy? |
| 04 | Menu and product performance | Which products to protect, re-price or drop? (ABC analysis, menu engineering) |
| 05 | Pricing and promotion impact | Did the +1 AED price rise hurt volume? Did the cake promotion pay for itself? |
| 06 | Basket analysis and loyalty | What is bought together? Who are the best and the at-risk customers? (lift, RFM, cohorts) |
| 07 | Operations and staff | Who sells most, who is on time, does staffing follow demand? |
| 08 | Payments and cash-flow leakage | How do customers pay and how much revenue is lost to unfinished orders? |
| 09 | Inventory and expiry risk | What must be reordered today and what will expire unsold? |
| 10 | Suppliers | How dependent is the shop on each supplier? |
| 11 | Profit and loss, targets, break-even | Gross profit, payroll, expenses, net profit, targets, daily break-even |
| 12 | Forecast | What revenue to expect in the coming weeks? (trend model with a range) |
| 13 | Customer satisfaction | What do customers say and where does service fall short? |
| 14 | Anomaly detection | Which days broke the normal pattern? |
| 15 | What-if scenarios | What is each business decision worth in profit? |
| 16 | Data audit and governance | Can the numbers be trusted? |
| 17 | Executive findings and action plan | The story for the board, written by SQL from the data |

**The findings and the action plan are calculated, not typed.** Section 17 builds every sentence with SQL from the views and tables. Change the data and the numbers and the sentences change with it. Each action in the plan carries its own evidence.

### Example findings

- Revenue of **AED 728K** over six months, **+22.6%** from Q4 2025 to Q1 2026
- Gross margin **67.1%** and net profit **AED 78.9K (10.8%)** after payroll and expenses
- In Ramadan, orders after 7 pm jumped from **14.6% to 50.8%** of the day
- A 15% cake promotion raised volume by **74%** and paid for itself
- **144** "Champion" loyalty cards bring **58%** of loyalty revenue, and **117** good customers are at risk of leaving
- One supplier provides **56.7%** of the cost of goods
- Customers rate the shop **4.23 / 5**, but only **3.88** during the 07:00-09:00 rush


## Highlights

- **One database, two files.** Learn on the coffee shop, then analyse the same shop.
- **Findings written by SQL.** The executive summary and the action plan are built from the data with queries, not typed by hand.
- **Real business methods.** ABC analysis, menu engineering, basket lift, RFM segmentation, cohort retention, a price-rise test against a control group, a trend forecast with a range, and what-if scenarios.
- **Generated and repeatable.** The new data comes from deterministic rules (CRC32 hashes, no `RAND()`), so every run gives the same numbers.
- **Safe to re-run.** The analysis adds its data once and deletes nothing. The eight original tables keep their structure.
- **Built-in checks.** Integrity checks and a data audit run before the numbers are used.

## MySQL support

MySQL 8.0 or newer, tested on 8.0.46. A few features need a minimum version: `CHECK` constraints 8.0.16, `LATERAL` 8.0.14, `DROP CONSTRAINT` 8.0.19, `INTERSECT` and `EXCEPT` 8.0.31.
