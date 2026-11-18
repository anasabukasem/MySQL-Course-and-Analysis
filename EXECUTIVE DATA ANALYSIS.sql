-- ============================================================================
--            COFFEE SHOP  |  EXECUTIVE DATA ANALYSIS (MySQL 8.0)
--     Prepared for the Managing Director  |  Period: Oct 2025 - Mar 2026
-- ============================================================================
--  HOW TO USE
--   1. Run the course script first (it creates and fills the CoffeeShop database).
--   2. Run this file once from top to bottom (about 20 seconds). Part 0 adds six
--      months of realistic sales data; Sections 1 to 17 are the report.
--   3. To present, run any report on its own (Ctrl+Enter in MySQL Workbench).
--      Every section starts with a title row, so each result tab is one slide.
--      Open with Section 17 (executive findings and action plan).
--   4. Re-running is safe: the data is added only once and nothing is deleted.
--
--  WHAT IS ORIGINAL AND WHAT IS NEW
--   Original: the eight tables of the course and their data (nothing is dropped
--             and no column is changed).
--   New data: 5 products, 600 loyalty cards, about 23,000 orders with payments,
--             attendance for every shift, monthly expenses, monthly sales targets
--             and customer reviews. The new data is a deterministic simulation
--             (CRC32 hashes, no RAND), so every run gives the same numbers.
--   New tables: Expenses, Sales_Targets, Customer_Reviews, plus analysis views.
--
--  CONTENTS
--   0   Data expansion and quality checks     9  Inventory and expiry risk
--   1   Executive scorecard                  10  Suppliers
--   2   Revenue trends and seasonality       11  Profit and loss, targets, break-even
--   3   Ramadan impact                       12  Forecast
--   4   Menu and product performance         13  Customer satisfaction
--   5   Pricing and promotion impact         14  Anomaly detection
--   6   Basket analysis and loyalty          15  What-if scenarios
--   7   Operations and staff                 16  Data audit and governance
--   8   Payments and cash-flow leakage       17  Executive findings and action plan
-- ============================================================================

USE CoffeeShop;
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SQL_SAFE_UPDATES = 0;


-- ============================================================================
-- 0. DATA EXPANSION AND QUALITY CHECKS
-- Adds products, loyalty cards, orders, payments and attendance (no table changes)
-- ============================================================================

-- 0.1 Data quality fixes
-- Three employees had attendance and orders before their recorded hire date
UPDATE Employees SET HireDate = '2025-09-29 08:00:00' WHERE EmployeeID = 6 AND HireDate > '2025-09-29';
UPDATE Employees SET HireDate = '2025-09-30 08:00:00' WHERE EmployeeID IN (7, 10) AND HireDate > '2025-09-30';

-- 0.2 Data builder
-- Deterministic pseudo-random numbers (CRC32) so everyone gets the same dataset
DROP PROCEDURE IF EXISTS sp_BuildAnalyticsData;
DELIMITER //
CREATE PROCEDURE sp_BuildAnalyticsData()
proc: BEGIN
    DECLARE v_Base INT;

    IF EXISTS (SELECT 1 FROM Products WHERE ProductName = 'Karak Chai') THEN
        SELECT 'Analytics data already exists - nothing was added' AS Message;
        LEAVE proc;
    END IF;

    SET SESSION cte_max_recursion_depth = 10000;
    SET v_Base = (SELECT IFNULL(MAX(OrderID), 0) FROM Orders);

    DROP TEMPORARY TABLE IF EXISTS tmp_Days, tmp_Nums, tmp_Months, tmp_Base, tmp_PW, tmp_PWd, tmp_PWa, tmp_NewOrders,
        tmp_Staff, tmp_Pick, tmp_Cards, tmp_DayCards, tmp_CardPick, tmp_Pair, tmp_L1, tmp_L2, tmp_L3, tmp_L4, tmp_L5;

    -- New menu items (launched later, tracked by their first sale)
    INSERT INTO Products (ProductName, Category, SupplierID, Price, Cost, StockQuantity, ExpirationDate)
    VALUES ('Karak Chai',   'Drink',   (SELECT SupplierID FROM Suppliers WHERE CompanyName = 'Tea House LLC'),      8.00, 2.00, 100, NULL),
           ('Flat White',   'Drink',   (SELECT SupplierID FROM Suppliers WHERE CompanyName = 'Gulf Beans Trading'), 17.00, 5.20, 100, NULL),
           ('Date Cake',    'Dessert', (SELECT SupplierID FROM Suppliers WHERE CompanyName = 'Sweet Corner Bakery'), 20.00, 7.50, 30, '2026-04-03'),
           ('Luqaimat',     'Dessert', (SELECT SupplierID FROM Suppliers WHERE CompanyName = 'Sweet Corner Bakery'), 16.00, 5.00, 30, '2026-04-02'),
           ('Cold Brew',    'Drink',   (SELECT SupplierID FROM Suppliers WHERE CompanyName = 'Gulf Beans Trading'), 19.00, 6.00, 80, NULL);

    -- Loyalty cards issued gradually (600 new cards)
    INSERT INTO LoyaltyCards (CardNumber, Points, IssueDate)
    WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 600)
    SELECT CONCAT('LC-', 2000 + i), 0, DATE('2025-10-21') + INTERVAL FLOOR((i - 1) * 146 / 600) DAY FROM n;

    -- Calendar with the number of orders per day
    -- Growth, weekday pattern, Ramadan (18 Feb - 19 Mar 2026) and Eid (20-22 Mar)
    CREATE TEMPORARY TABLE tmp_Days AS
    WITH RECURSIVE d AS (SELECT DATE('2025-10-01') AS Day UNION ALL SELECT Day + INTERVAL 1 DAY FROM d WHERE Day < '2026-03-31')
    SELECT Day,
           GREATEST(4, ROUND((95 + 0.35 * DATEDIFF(Day, '2025-10-01'))
               * CASE WEEKDAY(Day) WHEN 0 THEN 0.95 WHEN 1 THEN 0.95 WHEN 2 THEN 1.0 WHEN 3 THEN 1.1 WHEN 4 THEN 1.25 WHEN 5 THEN 1.3 ELSE 1.0 END
               * CASE WHEN Day BETWEEN '2026-02-18' AND '2026-03-19' THEN 0.8 WHEN Day BETWEEN '2026-03-20' AND '2026-03-22' THEN 0.5 ELSE 1 END
               * (1 + (CAST(MOD(CRC32(CAST(Day AS CHAR)), 21) AS SIGNED) - 10) / 100))) AS N
    FROM d;
    CREATE TEMPORARY TABLE tmp_Nums AS
    WITH RECURSIVE x AS (SELECT 1 AS n UNION ALL SELECT n + 1 FROM x WHERE n < 300) SELECT n FROM x;

    -- Orders: time of day depends on the period (Ramadan shifts sales to the evening)
    CREATE TEMPORARY TABLE tmp_NewOrders AS
    SELECT ROW_NUMBER() OVER (ORDER BY Day, Slot) AS k, Day, Slot,
           TIMESTAMP(Day, MAKETIME(
               CASE WHEN Day BETWEEN '2026-02-18' AND '2026-03-19' THEN
                        CASE WHEN rh < 4 THEN 8 WHEN rh < 8 THEN 9 WHEN rh < 11 THEN 10 WHEN rh < 13 THEN 11 WHEN rh < 15 THEN 12
                             WHEN rh < 21 THEN 13 WHEN rh < 27 THEN 14 WHEN rh < 31 THEN 15 WHEN rh < 38 THEN 16 WHEN rh < 47 THEN 17
                             WHEN rh < 51 THEN 18 WHEN rh < 57 THEN 19 WHEN rh < 69 THEN 20 WHEN rh < 83 THEN 21 WHEN rh < 94 THEN 22 ELSE 23 END
                    ELSE
                        CASE WHEN rh < 9 THEN 7 WHEN rh < 20 THEN 8 WHEN rh < 29 THEN 9 WHEN rh < 35 THEN 10 WHEN rh < 40 THEN 11
                             WHEN rh < 48 THEN 12 WHEN rh < 56 THEN 13 WHEN rh < 62 THEN 14 WHEN rh < 67 THEN 15 WHEN rh < 73 THEN 16
                             WHEN rh < 79 THEN 17 WHEN rh < 85 THEN 18 WHEN rh < 91 THEN 19 WHEN rh < 96 THEN 20 ELSE 21 END
               END, rm, 0)) AS OrderDate,
           IF(MOD(CRC32(CONCAT(Day, '-', Slot, 't')), 100) < 55, 'Takeaway', 'Dine-in') AS OrderType,
           IF(MOD(CRC32(CONCAT(Day, '-', Slot, 'c')), 100) < 97, TRUE, FALSE) AS IsCompleted,
           MOD(CRC32(CONCAT(Day, '-', Slot, 'u')), 100) AS rCard
    FROM (SELECT d.Day, n.n AS Slot,
                 MOD(CRC32(CONCAT(d.Day, '-', n.n, 'h')), 100) AS rh,
                 MOD(CRC32(CONCAT(d.Day, '-', n.n, 'm')), 60) AS rm
          FROM tmp_Days d JOIN tmp_Nums n ON n.n <= d.N) t;

    -- Who served the order (only staff already hired; cashiers weigh more than baristas)
    CREATE TEMPORARY TABLE tmp_Staff AS
    SELECT e.EmployeeID, e.HireDate, s.n FROM Employees e JOIN tmp_Nums s ON s.n <= IF(e.Role = 'Cashier', 3, 1)
    WHERE e.Role IN ('Cashier', 'Barista');
    CREATE TEMPORARY TABLE tmp_Pick AS
    SELECT k, EmployeeID FROM (
        SELECT o.k, s.EmployeeID,
               ROW_NUMBER() OVER (PARTITION BY o.k ORDER BY MD5(CONCAT(o.k, '-', s.EmployeeID, '-', s.n))) AS rn
        FROM tmp_NewOrders o JOIN tmp_Staff s ON s.HireDate <= o.OrderDate) t
    WHERE rn = 1;

    -- Loyalty card on about 22 percent of orders, with a few very active cards
    CREATE TEMPORARY TABLE tmp_Cards AS
    SELECT CardID, IssueDate, ROW_NUMBER() OVER (ORDER BY IssueDate, CardID) AS rn FROM LoyaltyCards;
    CREATE TEMPORARY TABLE tmp_DayCards AS
    SELECT d.Day, (SELECT COUNT(*) FROM LoyaltyCards c WHERE c.IssueDate <= d.Day) AS cnt FROM tmp_Days d;
    CREATE TEMPORARY TABLE tmp_CardPick AS
    SELECT o.k, c.CardID
    FROM tmp_NewOrders o
    JOIN tmp_DayCards dc ON dc.Day = DATE(o.OrderDate) AND dc.cnt > 0
    JOIN tmp_Cards c ON c.rn = 1 + FLOOR(POW(MOD(CRC32(CONCAT(o.k, '-pick')), 10000) / 10000, 1.5) * dc.cnt)
    WHERE o.rCard < 22;

    INSERT INTO Orders (OrderID, EmployeeID, OrderDate, IsCompleted, OrderType, LoyaltyCardID, TotalAmount)
    SELECT v_Base + o.k, p.EmployeeID, o.OrderDate, o.IsCompleted, o.OrderType, cp.CardID, 0
    FROM tmp_NewOrders o JOIN tmp_Pick p ON p.k = o.k LEFT JOIN tmp_CardPick cp ON cp.k = o.k
    ORDER BY o.k;

    -- Product popularity by month (seasonality, launches, price effect)
    CREATE TEMPORARY TABLE tmp_Months AS
    SELECT DATE_FORMAT(Day, '%Y-%m') AS MonthKey, MIN(Day) AS MStart FROM tmp_Days GROUP BY DATE_FORMAT(Day, '%Y-%m');
    CREATE TEMPORARY TABLE tmp_Base (ProductName VARCHAR(100), w DECIMAL(6,2), Launch DATE);
    INSERT INTO tmp_Base VALUES
        ('Espresso', 10, '2025-10-01'), ('Cappuccino', 14, '2025-10-01'), ('Latte', 18, '2025-10-01'), ('Americano', 9, '2025-10-01'),
        ('Mocha', 8, '2025-10-01'), ('Iced Latte', 8, '2025-10-01'), ('Green Tea', 4, '2025-10-01'), ('Hot Chocolate', 4, '2025-10-01'),
        ('Chocolate Cake', 5, '2025-10-01'), ('Cheesecake', 4, '2025-10-01'), ('Brownie', 3, '2025-10-01'), ('Croissant', 9, '2025-10-01'),
        ('Chicken Sandwich', 5, '2025-10-01'), ('Bottled Water', 6, '2025-10-01'), ('Coffee Beans 250g', 2, '2025-10-01'),
        ('Reusable Cup', 0.5, '2025-10-01'), ('Karak Chai', 7, '2025-11-01'), ('Flat White', 7, '2025-12-01'),
        ('Date Cake', 4, '2025-12-01'), ('Luqaimat', 4, '2026-02-01'), ('Cold Brew', 6, '2026-03-01');
    CREATE TEMPORARY TABLE tmp_PW AS
    SELECT m.MonthKey, p.ProductID, p.Category,
           b.w * CASE b.ProductName
               WHEN 'Iced Latte'     THEN ELT(FIELD(MONTH(m.MStart), 10, 11, 12, 1, 2, 3), 2.0, 1.3, 0.7, 0.6, 0.6, 1.1)
               WHEN 'Cold Brew'      THEN ELT(FIELD(MONTH(m.MStart), 10, 11, 12, 1, 2, 3), 2.0, 1.3, 0.7, 0.6, 0.6, 1.1)
               WHEN 'Hot Chocolate'  THEN ELT(FIELD(MONTH(m.MStart), 10, 11, 12, 1, 2, 3), 0.4, 1.0, 2.0, 2.2, 2.0, 0.8)
               WHEN 'Karak Chai'     THEN ELT(FIELD(MONTH(m.MStart), 10, 11, 12, 1, 2, 3), 1.0, 1.0, 1.4, 1.6, 1.6, 1.2)
               WHEN 'Bottled Water'  THEN ELT(FIELD(MONTH(m.MStart), 10, 11, 12, 1, 2, 3), 2.0, 1.5, 1.0, 1.0, 1.0, 1.4)
               WHEN 'Luqaimat'      THEN 1
               WHEN 'Date Cake'     THEN 1
               WHEN 'Cappuccino'    THEN IF(m.MStart >= '2026-01-01', 0.93, 1)
               WHEN 'Latte'         THEN IF(m.MStart >= '2026-01-01', 0.93, 1)
               WHEN 'Mocha'         THEN IF(m.MStart >= '2026-01-01', 0.93, 1)
               ELSE 1 END AS w
    FROM tmp_Months m JOIN tmp_Base b ON m.MStart >= b.Launch JOIN Products p ON p.ProductName = b.ProductName;
    CREATE TEMPORARY TABLE tmp_PWd AS
    SELECT MonthKey, ProductID, SUM(w) OVER (PARTITION BY MonthKey ORDER BY ProductID) - w AS lo,
           SUM(w) OVER (PARTITION BY MonthKey ORDER BY ProductID) AS hi, SUM(w) OVER (PARTITION BY MonthKey) AS tot
    FROM tmp_PW WHERE Category = 'Drink';
    CREATE TEMPORARY TABLE tmp_PWa AS
    SELECT MonthKey, ProductID, SUM(w) OVER (PARTITION BY MonthKey ORDER BY ProductID) - w AS lo,
           SUM(w) OVER (PARTITION BY MonthKey ORDER BY ProductID) AS hi, SUM(w) OVER (PARTITION BY MonthKey) AS tot
    FROM tmp_PW;

    -- Line 1: every order contains a drink
    CREATE TEMPORARY TABLE tmp_L1 AS
    SELECT o.k, w.ProductID,
           CASE WHEN MOD(CRC32(CONCAT(o.k, '-q1')), 100) < 65 THEN 1 WHEN MOD(CRC32(CONCAT(o.k, '-q1')), 100) < 90 THEN 2 ELSE 3 END AS Qty
    FROM tmp_NewOrders o
    JOIN tmp_PWd w ON w.MonthKey = DATE_FORMAT(o.OrderDate, '%Y-%m')
                  AND MOD(CRC32(CONCAT(o.k, '-L1')), 100000) / 100000 * w.tot >= w.lo
                  AND MOD(CRC32(CONCAT(o.k, '-L1')), 100000) / 100000 * w.tot < w.hi;

    -- Line 2: a food item often goes with a specific drink
    CREATE TEMPORARY TABLE tmp_Pair AS
    SELECT d.ProductID AS DrinkID, f.ProductID AS FoodID, x.prob
    FROM (SELECT 'Cappuccino' AS dn, 'Croissant' AS fn, 45 AS prob UNION ALL SELECT 'Latte', 'Chocolate Cake', 30
          UNION ALL SELECT 'Mocha', 'Brownie', 40 UNION ALL SELECT 'Espresso', 'Croissant', 25
          UNION ALL SELECT 'Americano', 'Chicken Sandwich', 30 UNION ALL SELECT 'Iced Latte', 'Cheesecake', 20
          UNION ALL SELECT 'Green Tea', 'Brownie', 15 UNION ALL SELECT 'Hot Chocolate', 'Croissant', 30
          UNION ALL SELECT 'Karak Chai', 'Luqaimat', 35 UNION ALL SELECT 'Flat White', 'Date Cake', 30) x
    JOIN Products d ON d.ProductName = x.dn JOIN Products f ON f.ProductName = x.fn;
    CREATE TEMPORARY TABLE tmp_L2 AS
    SELECT l.k, pr.FoodID AS ProductID, 1 AS Qty
    FROM tmp_L1 l JOIN tmp_Pair pr ON pr.DrinkID = l.ProductID JOIN tmp_NewOrders o ON o.k = l.k
    JOIN Products fp ON fp.ProductID = pr.FoodID
    WHERE MOD(CRC32(CONCAT(l.k, '-pair')), 100) < pr.prob
      AND (fp.ProductName <> 'Luqaimat' OR o.OrderDate >= '2026-02-01')
      AND (fp.ProductName <> 'Date Cake' OR o.OrderDate >= '2025-12-01');

    -- Line 3: an extra random item in 25 percent of orders
    CREATE TEMPORARY TABLE tmp_L3 AS
    SELECT o.k, w.ProductID, IF(MOD(CRC32(CONCAT(o.k, '-q3')), 100) < 80, 1, 2) AS Qty
    FROM tmp_NewOrders o
    JOIN tmp_PWa w ON w.MonthKey = DATE_FORMAT(o.OrderDate, '%Y-%m')
                  AND MOD(CRC32(CONCAT(o.k, '-L3')), 100000) / 100000 * w.tot >= w.lo
                  AND MOD(CRC32(CONCAT(o.k, '-L3')), 100000) / 100000 * w.tot < w.hi
    WHERE MOD(CRC32(CONCAT(o.k, '-x3')), 100) < 25;

    -- Line 4: promotion (10-24 Jan 2026) pushes cakes and brownies
    CREATE TEMPORARY TABLE tmp_L4 AS
    SELECT o.k, p.ProductID, 1 AS Qty
    FROM tmp_NewOrders o
    JOIN Products p ON p.ProductName = ELT(1 + MOD(CRC32(CONCAT(o.k, '-pr')), 3), 'Cheesecake', 'Chocolate Cake', 'Brownie')
    WHERE DATE(o.OrderDate) BETWEEN '2026-01-10' AND '2026-01-24' AND MOD(CRC32(CONCAT(o.k, '-px')), 100) < 12;

    -- Line 5: Ramadan evenings (after 7 pm) bring Luqaimat and Date Cake
    CREATE TEMPORARY TABLE tmp_L5 AS
    SELECT o.k, p.ProductID, 1 AS Qty
    FROM tmp_NewOrders o
    JOIN Products p ON p.ProductName = IF(MOD(CRC32(CONCAT(o.k, '-rm')), 2) = 0, 'Luqaimat', 'Date Cake')
    WHERE DATE(o.OrderDate) BETWEEN '2026-02-18' AND '2026-03-19' AND HOUR(o.OrderDate) >= 19
      AND MOD(CRC32(CONCAT(o.k, '-rx')), 100) < 45;

    -- Order lines: price rise of +1 AED (1 Jan 2026) on Cappuccino, Latte, Mocha;
    -- 5 percent loyalty discount; 15 percent promotion discount
    INSERT INTO Order_Details (OrderID, ProductID, Quantity, UnitPrice, Discount)
    SELECT v_Base + u.k, u.ProductID, u.Qty,
           p.Price + IF(DATE(o.OrderDate) >= '2026-01-01' AND p.ProductName IN ('Cappuccino', 'Latte', 'Mocha'), 1, 0),
           GREATEST(IF(cp.CardID IS NOT NULL, 5, 0),
                    IF(DATE(o.OrderDate) BETWEEN '2026-01-10' AND '2026-01-24' AND p.ProductName IN ('Cheesecake', 'Chocolate Cake', 'Brownie'), 15, 0))
    FROM (SELECT k, ProductID, SUM(Qty) AS Qty
          FROM (SELECT * FROM tmp_L1 UNION ALL SELECT * FROM tmp_L2 UNION ALL SELECT * FROM tmp_L3 UNION ALL SELECT * FROM tmp_L4 UNION ALL SELECT * FROM tmp_L5) x
          GROUP BY k, ProductID) u
    JOIN tmp_NewOrders o ON o.k = u.k
    JOIN Products p ON p.ProductID = u.ProductID
    LEFT JOIN tmp_CardPick cp ON cp.k = u.k
    ORDER BY u.k, u.ProductID;

    -- Order totals
    UPDATE Orders o
    SET TotalAmount = (SELECT ROUND(SUM(d.Quantity * d.UnitPrice * (1 - d.Discount / 100)), 2) FROM Order_Details d WHERE d.OrderID = o.OrderID)
    WHERE o.OrderID > v_Base;

    -- Payments: cash declines and mobile pay grows month after month
    INSERT INTO Payments (OrderID, PaymentType, Amount, PaymentDate)
    SELECT OrderID,
           CASE WHEN r < c THEN 'Cash' WHEN r < c + (100 - c) * 0.6 THEN 'Card' ELSE 'MobilePay' END,
           TotalAmount, OrderDate + INTERVAL (1 + MOD(OrderID, 6)) MINUTE
    FROM (SELECT OrderID, TotalAmount, OrderDate,
                 MOD(CRC32(CONCAT(OrderID, '-pay')), 100) AS r,
                 32 - 3 * TIMESTAMPDIFF(MONTH, '2025-10-01', OrderDate) AS c
          FROM Orders WHERE OrderID > v_Base AND IsCompleted = TRUE) t
    ORDER BY OrderID;

    -- Attendance: 5 working days per week, small delays, overtime, a few missing check-outs
    INSERT INTO Attendance (EmployeeID, Date, CheckInTime, CheckOutTime)
    SELECT EmployeeID, Day,
           ADDTIME(BaseTime, SEC_TO_TIME(Offset * 60)),
           IF(MOD(CRC32(CONCAT(EmployeeID, Day, 'o')), 100) < 2, NULL,
              ADDTIME(BaseTime, SEC_TO_TIME((450 + MOD(CRC32(CONCAT(EmployeeID, Day, 'ot')), 31)) * 60)))
    FROM (SELECT e.EmployeeID, d.Day,
                 CASE e.Role WHEN 'Barista' THEN IF(MOD(e.EmployeeID, 2) = 0, '15:00:00', '07:00:00')
                             WHEN 'Cashier' THEN IF(MOD(e.EmployeeID, 2) = 0, '15:30:00', '07:30:00')
                             WHEN 'Manager' THEN '08:00:00' WHEN 'Cleaner' THEN '06:30:00' ELSE '09:00:00' END AS BaseTime,
                 CASE WHEN MOD(CRC32(CONCAT(e.EmployeeID, d.Day, 'l')), 100) < 70 THEN CAST(MOD(CRC32(CONCAT(e.EmployeeID, d.Day, 'l')), 9) AS SIGNED) - 5
                      WHEN MOD(CRC32(CONCAT(e.EmployeeID, d.Day, 'l')), 100) < 90 THEN 5 + MOD(CRC32(CONCAT(e.EmployeeID, d.Day, 'l2')), 21)
                      ELSE 25 + MOD(CRC32(CONCAT(e.EmployeeID, d.Day, 'l3')), 36) END AS Offset
          FROM tmp_Days d JOIN Employees e ON DATE(e.HireDate) <= d.Day
          WHERE d.Day >= '2025-10-06' AND MOD(e.EmployeeID + TO_DAYS(d.Day), 7) NOT IN (0, 1)) t;

    -- Price list, stock snapshot and expiry dates as of 31 March 2026
    UPDATE Products SET Price = Price + 1 WHERE ProductName IN ('Cappuccino', 'Latte', 'Mocha');
    UPDATE Products p
    LEFT JOIN (SELECT d.ProductID, SUM(d.Quantity) / 30 AS v
               FROM Order_Details d JOIN Orders o ON o.OrderID = d.OrderID
               WHERE o.OrderDate >= '2026-03-02' AND o.OrderDate < '2026-04-01' GROUP BY d.ProductID) s ON s.ProductID = p.ProductID
    SET p.StockQuantity = CEIL(IFNULL(s.v, 0.5) * (3 + MOD(p.ProductID * 7, 18)))
    WHERE p.ProductID > 0;
    UPDATE Products SET ExpirationDate = DATE('2026-03-31') + INTERVAL (1 + MOD(ProductID, 6)) DAY
    WHERE Category IN ('Dessert', 'Snack') AND ProductName NOT IN ('Date Cake', 'Luqaimat');
    UPDATE Products SET ExpirationDate = '2026-09-30' WHERE ProductName = 'Coffee Beans 250g';
    UPDATE Products SET ExpirationDate = '2026-12-31' WHERE ProductName = 'Bottled Water';

    DROP TEMPORARY TABLE IF EXISTS tmp_Days, tmp_Nums, tmp_Months, tmp_Base, tmp_PW, tmp_PWd, tmp_PWa, tmp_NewOrders,
        tmp_Staff, tmp_Pick, tmp_Cards, tmp_DayCards, tmp_CardPick, tmp_Pair, tmp_L1, tmp_L2, tmp_L3, tmp_L4, tmp_L5;
    SELECT 'Analytics data created' AS Message;
END //
DELIMITER ;

-- 0.3 Run the builder
CALL sp_BuildAnalyticsData();
DROP PROCEDURE sp_BuildAnalyticsData;

-- 0.4 Business tables: expenses, targets and customer reviews
CREATE TABLE IF NOT EXISTS Expenses (
    ExpenseID INT AUTO_INCREMENT PRIMARY KEY,
    ExpenseMonth DATE NOT NULL,
    Category VARCHAR(40) NOT NULL,
    Amount DECIMAL(10,2) NOT NULL CHECK (Amount >= 0),
    UNIQUE (ExpenseMonth, Category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS Sales_Targets (
    TargetMonth DATE PRIMARY KEY,
    TargetRevenue DECIMAL(10,2) NOT NULL CHECK (TargetRevenue > 0),
    TargetGrossMarginPct DECIMAL(5,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS Customer_Reviews (
    ReviewID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT NOT NULL UNIQUE,
    Rating TINYINT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    Topic ENUM('Praise','Speed','Taste','Price','Service','Cleanliness') NOT NULL,
    ReviewDate DATE NOT NULL,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Monthly expenses outside the menu cost and payroll
-- Rent, utilities (cooling in summer), marketing (Jan campaign), maintenance, insurance,
-- licences, packaging (0.45 AED per order) and card / mobile payment fees (1.5% and 1.2%)
INSERT INTO Expenses (ExpenseMonth, Category, Amount)
SELECT m.MonthStart, c.Category,
       CASE c.Category
           WHEN 'Rent' THEN 14000
           WHEN 'Utilities' THEN ROUND(3600 * ELT(FIELD(MONTH(m.MonthStart), 10, 11, 12, 1, 2, 3), 1.25, 1.10, 0.95, 0.90, 0.95, 1.10)
                                       * (0.97 + MOD(CRC32(CONCAT(m.MonthStart, 'u')), 7) / 100), 2)
           WHEN 'Marketing' THEN ELT(FIELD(MONTH(m.MonthStart), 10, 11, 12, 1, 2, 3), 2500, 2800, 3500, 5500, 3000, 3200)
           WHEN 'Maintenance' THEN 900 + MOD(CRC32(CONCAT(m.MonthStart, 'm')), 700)
           WHEN 'Insurance' THEN 700
           WHEN 'Licences' THEN 500
           WHEN 'Packaging' THEN ROUND(0.45 * (SELECT COUNT(*) FROM Orders o WHERE o.IsCompleted = TRUE
                                               AND o.OrderDate >= m.MonthStart AND o.OrderDate < m.MonthStart + INTERVAL 1 MONTH), 2)
           WHEN 'Payment fees' THEN ROUND((SELECT IFNULL(SUM(p.Amount * IF(p.PaymentType = 'Card', 0.015, IF(p.PaymentType = 'MobilePay', 0.012, 0))), 0)
                                           FROM Payments p WHERE p.PaymentDate >= m.MonthStart AND p.PaymentDate < m.MonthStart + INTERVAL 1 MONTH), 2)
       END
FROM (WITH RECURSIVE x AS (SELECT DATE('2025-10-01') AS MonthStart UNION ALL SELECT MonthStart + INTERVAL 1 MONTH FROM x WHERE MonthStart < '2026-03-01')
      SELECT MonthStart FROM x) m
CROSS JOIN (SELECT 'Rent' AS Category UNION ALL SELECT 'Utilities' UNION ALL SELECT 'Marketing' UNION ALL SELECT 'Maintenance'
            UNION ALL SELECT 'Insurance' UNION ALL SELECT 'Licences' UNION ALL SELECT 'Packaging' UNION ALL SELECT 'Payment fees') c
WHERE NOT EXISTS (SELECT 1 FROM Expenses);

-- Monthly targets set by management
INSERT IGNORE INTO Sales_Targets (TargetMonth, TargetRevenue, TargetGrossMarginPct)
VALUES ('2025-10-01', 100000, 66.50), ('2025-11-01', 105000, 66.50), ('2025-12-01', 118000, 66.50),
       ('2026-01-01', 140000, 66.50), ('2026-02-01', 130000, 66.50), ('2026-03-01', 142000, 66.50);

-- About one completed order in 25 leaves a review.
-- Rush hour (07-09) lowers the rating, the Chicken Sandwich lowers it more, loyalty members rate higher
INSERT INTO Customer_Reviews (OrderID, Rating, Topic, ReviewDate)
SELECT OrderID, Rating,
       CASE WHEN Rating >= 4 THEN 'Praise'
            WHEN HOUR(OrderDate) BETWEEN 7 AND 9 AND MOD(CRC32(CONCAT(OrderID, '-t')), 3) > 0 THEN 'Speed'
            WHEN HasChicken = 1 THEN 'Taste'
            ELSE ELT(1 + MOD(CRC32(CONCAT(OrderID, '-t2')), 4), 'Price', 'Service', 'Cleanliness', 'Taste') END,
       DATE(OrderDate)
FROM (SELECT o.OrderID, o.OrderDate,
             EXISTS (SELECT 1 FROM Order_Details d JOIN Products p ON p.ProductID = d.ProductID
                     WHERE d.OrderID = o.OrderID AND p.ProductName = 'Chicken Sandwich') AS HasChicken,
             GREATEST(1, LEAST(5, ROUND(4.35
                 - IF(HOUR(o.OrderDate) BETWEEN 7 AND 9, 0.5, 0)
                 - IF(EXISTS (SELECT 1 FROM Order_Details d JOIN Products p ON p.ProductID = d.ProductID
                              WHERE d.OrderID = o.OrderID AND p.ProductName = 'Chicken Sandwich'), 0.9, 0)
                 + IF(o.LoyaltyCardID IS NOT NULL, 0.2, 0)
                 + (CAST(MOD(CRC32(CONCAT(o.OrderID, '-rt')), 201) AS SIGNED) - 100) / 100))) AS Rating
      FROM Orders o
      WHERE o.IsCompleted = TRUE AND o.OrderDate >= '2025-10-01' AND o.OrderDate < '2026-04-01'
        AND MOD(CRC32(CONCAT(o.OrderID, '-rv')), 25) = 0) t
WHERE NOT EXISTS (SELECT 1 FROM Customer_Reviews);


-- 0.5 Analytical layer
-- Two views used by every report: completed sales only, Oct 2025 - Mar 2026
-- (orders created later by tests, for example by the course procedures, are excluded)
CREATE OR REPLACE VIEW v_FactLines AS
SELECT d.OrderDetailID, o.OrderID, o.OrderDate, DATE(o.OrderDate) AS SaleDate, DATE_FORMAT(o.OrderDate, '%Y-%m') AS SaleMonth,
       HOUR(o.OrderDate) AS SaleHour, WEEKDAY(o.OrderDate) AS WeekdayNo, DAYNAME(o.OrderDate) AS DayName,
       o.EmployeeID, o.LoyaltyCardID, o.OrderType, d.ProductID, p.ProductName, p.Category, p.SupplierID,
       d.Quantity, d.UnitPrice, d.Discount,
       ROUND(d.Quantity * d.UnitPrice, 2) AS GrossRevenue,
       ROUND(d.Quantity * d.UnitPrice * d.Discount / 100, 2) AS DiscountAmount,
       ROUND(d.Quantity * d.UnitPrice * (1 - d.Discount / 100), 2) AS NetRevenue,
       ROUND(d.Quantity * p.Cost, 2) AS CostAmount
FROM Order_Details d
JOIN Orders o ON o.OrderID = d.OrderID
JOIN Products p ON p.ProductID = d.ProductID
WHERE o.IsCompleted = TRUE AND o.OrderDate >= '2025-10-01' AND o.OrderDate < '2026-04-01';

CREATE OR REPLACE VIEW v_FactOrders AS
SELECT o.OrderID, o.OrderDate, DATE(o.OrderDate) AS SaleDate, DATE_FORMAT(o.OrderDate, '%Y-%m') AS SaleMonth,
       HOUR(o.OrderDate) AS SaleHour, WEEKDAY(o.OrderDate) AS WeekdayNo, DAYNAME(o.OrderDate) AS DayName,
       o.EmployeeID, o.LoyaltyCardID, o.OrderType, o.TotalAmount, pay.PaymentType,
       (SELECT SUM(d.Quantity) FROM Order_Details d WHERE d.OrderID = o.OrderID) AS Items
FROM Orders o
LEFT JOIN Payments pay ON pay.OrderID = o.OrderID
WHERE o.IsCompleted = TRUE AND o.OrderDate >= '2025-10-01' AND o.OrderDate < '2026-04-01';

-- 0.6 Integrity checks (every check should return 0)
SELECT 'Orders whose total differs from their lines' AS Check_Name, COUNT(*) AS Problems FROM (
    SELECT o.OrderID FROM Orders o JOIN Order_Details d ON d.OrderID = o.OrderID
    GROUP BY o.OrderID, o.TotalAmount
    HAVING o.TotalAmount <> ROUND(SUM(d.Quantity * d.UnitPrice * (1 - d.Discount / 100)), 2)) x
UNION ALL SELECT 'Completed orders without payment', COUNT(*) FROM Orders o LEFT JOIN Payments p ON p.OrderID = o.OrderID WHERE o.IsCompleted = TRUE AND p.PaymentID IS NULL
UNION ALL SELECT 'Payments that differ from the order total', COUNT(*) FROM Payments p JOIN Orders o ON o.OrderID = p.OrderID WHERE p.Amount <> o.TotalAmount
UNION ALL SELECT 'Orders without lines', COUNT(*) FROM Orders o WHERE NOT EXISTS (SELECT 1 FROM Order_Details d WHERE d.OrderID = o.OrderID)
UNION ALL SELECT 'Orders taken before the employee was hired', COUNT(*) FROM Orders o JOIN Employees e ON e.EmployeeID = o.EmployeeID WHERE o.OrderDate < e.HireDate
UNION ALL SELECT 'Check-out earlier than check-in', COUNT(*) FROM Attendance WHERE CheckOutTime < CheckInTime;

-- 0.7 Dataset overview
SELECT (SELECT COUNT(*) FROM v_FactOrders) AS CompletedOrders, (SELECT COUNT(*) FROM v_FactLines) AS SoldLines,
       (SELECT COUNT(DISTINCT SaleDate) FROM v_FactOrders) AS TradingDays, (SELECT MIN(SaleDate) FROM v_FactOrders) AS FirstDay,
       (SELECT MAX(SaleDate) FROM v_FactOrders) AS LastDay, (SELECT COUNT(*) FROM Products) AS Products,
       (SELECT COUNT(*) FROM Employees) AS Employees, (SELECT COUNT(*) FROM LoyaltyCards) AS LoyaltyCards;


-- ============================================================================
-- 1. EXECUTIVE SCORECARD
-- The numbers a director reads first: this quarter against the previous one
-- ============================================================================
SELECT 'SECTION 1 | EXECUTIVE SCORECARD' AS Section;

-- 1.1 Quarter scorecard
WITH o AS (
    SELECT IF(SaleDate < '2026-01-01', '2025 Q4', '2026 Q1') AS Period, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue,
           COUNT(DISTINCT SaleDate) AS TradingDays, AVG(Items) AS ItemsPerOrder, 100 * AVG(LoyaltyCardID IS NOT NULL) AS LoyaltyOrdersPct
    FROM v_FactOrders GROUP BY Period),
l AS (
    SELECT IF(SaleDate < '2026-01-01', '2025 Q4', '2026 Q1') AS Period, SUM(NetRevenue - CostAmount) AS GrossProfit,
           SUM(DiscountAmount) AS Discounts, SUM(GrossRevenue) AS GrossSales
    FROM v_FactLines GROUP BY Period),
k AS (
    SELECT o.Period, o.Orders, o.Revenue, o.Revenue / o.TradingDays AS DailyRevenue, o.Revenue / o.Orders AS AOV,
           o.ItemsPerOrder, l.GrossProfit, 100 * l.GrossProfit / o.Revenue AS MarginPct, 100 * l.Discounts / l.GrossSales AS DiscountPct,
           o.LoyaltyOrdersPct
    FROM o JOIN l USING (Period))
SELECT Period, Orders, ROUND(Revenue) AS Revenue, ROUND(DailyRevenue) AS RevenuePerDay, ROUND(AOV, 2) AS AvgOrderValue,
       ROUND(ItemsPerOrder, 2) AS ItemsPerOrder, ROUND(GrossProfit) AS GrossProfit, ROUND(MarginPct, 1) AS GrossMarginPct,
       ROUND(DiscountPct, 1) AS DiscountRatePct, ROUND(LoyaltyOrdersPct, 1) AS LoyaltyOrdersPct
FROM k
UNION ALL
SELECT 'Change (% or pts)', ROUND(100 * (a.Orders / b.Orders - 1), 1), ROUND(100 * (a.Revenue / b.Revenue - 1), 1),
       ROUND(100 * (a.DailyRevenue / b.DailyRevenue - 1), 1), ROUND(100 * (a.AOV / b.AOV - 1), 1),
       ROUND(100 * (a.ItemsPerOrder / b.ItemsPerOrder - 1), 1), ROUND(100 * (a.GrossProfit / b.GrossProfit - 1), 1),
       ROUND(a.MarginPct - b.MarginPct, 1), ROUND(a.DiscountPct - b.DiscountPct, 1), ROUND(a.LoyaltyOrdersPct - b.LoyaltyOrdersPct, 1)
FROM k a JOIN k b ON a.Period = '2026 Q1' AND b.Period = '2025 Q4';

-- 1.2 Six-month totals
SELECT COUNT(*) AS Orders, ROUND(SUM(TotalAmount)) AS Revenue, ROUND(AVG(TotalAmount), 2) AS AvgOrderValue,
       (SELECT ROUND(SUM(NetRevenue - CostAmount)) FROM v_FactLines) AS GrossProfit,
       (SELECT ROUND(100 * SUM(NetRevenue - CostAmount) / SUM(NetRevenue), 1) FROM v_FactLines) AS GrossMarginPct,
       (SELECT COUNT(DISTINCT LoyaltyCardID) FROM v_FactOrders) AS ActiveLoyaltyCards,
       (SELECT ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM Orders WHERE OrderDate >= '2025-10-01' AND OrderDate < '2026-04-01'), 1)
        FROM Orders WHERE IsCompleted = TRUE AND OrderDate >= '2025-10-01' AND OrderDate < '2026-04-01') AS CompletionRatePct
FROM v_FactOrders;


-- ============================================================================
-- 2. REVENUE TRENDS AND SEASONALITY
-- How sales move by month, week, weekday, hour and daypart
-- ============================================================================
SELECT 'SECTION 2 | REVENUE TRENDS AND SEASONALITY' AS Section;

-- 2.1 Monthly revenue and growth
WITH m AS (SELECT SaleMonth, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue, AVG(TotalAmount) AS AOV, COUNT(DISTINCT SaleDate) AS Days
           FROM v_FactOrders GROUP BY SaleMonth)
SELECT SaleMonth AS Month, Orders, ROUND(Revenue) AS Revenue, ROUND(Revenue / Days) AS RevenuePerDay, ROUND(AOV, 2) AS AvgOrderValue,
       ROUND(100 * (Revenue / LAG(Revenue) OVER (ORDER BY SaleMonth) - 1), 1) AS MoM_Growth_Pct,
       ROUND(100 * (Revenue / Days / (LAG(Revenue) OVER (ORDER BY SaleMonth) / LAG(Days) OVER (ORDER BY SaleMonth)) - 1), 1) AS PerDay_Growth_Pct,
       REPEAT('█', ROUND(Revenue / MAX(Revenue) OVER () * 30)) AS Chart
FROM m;

-- 2.2 Weekly revenue per trading day with a 4-week moving average
WITH w AS (SELECT SaleDate - INTERVAL WEEKDAY(SaleDate) DAY AS WeekStart, COUNT(DISTINCT SaleDate) AS Days, SUM(TotalAmount) AS Revenue, COUNT(*) AS Orders
           FROM v_FactOrders GROUP BY WeekStart)
SELECT WeekStart, Days, Orders, ROUND(Revenue) AS Revenue, ROUND(Revenue / Days) AS RevenuePerDay,
       ROUND(AVG(Revenue / Days) OVER (ORDER BY WeekStart ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)) AS MovingAvg4W,
       ROUND(100 * ((Revenue / Days) / LAG(Revenue / Days) OVER (ORDER BY WeekStart) - 1), 1) AS WoW_Pct,
       REPEAT('█', ROUND(Revenue / Days / MAX(Revenue / Days) OVER () * 30)) AS Chart
FROM w ORDER BY WeekStart;

-- 2.3 Weekday performance (index 100 = average day)
WITH d AS (SELECT SaleDate, WeekdayNo, DayName, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue FROM v_FactOrders GROUP BY SaleDate, WeekdayNo, DayName)
SELECT DayName, COUNT(*) AS Days, ROUND(AVG(Orders), 1) AS OrdersPerDay, ROUND(AVG(Revenue)) AS RevenuePerDay,
       ROUND(100 * AVG(Revenue) / (SELECT AVG(Revenue) FROM d)) AS DemandIndex,
       REPEAT('█', ROUND(AVG(Revenue) / (SELECT MAX(r) FROM (SELECT AVG(Revenue) AS r FROM d GROUP BY WeekdayNo) z) * 30)) AS Chart
FROM d GROUP BY WeekdayNo, DayName ORDER BY WeekdayNo;

-- 2.4 Hourly demand
SELECT SaleHour AS Hour, COUNT(*) AS Orders, ROUND(SUM(TotalAmount)) AS Revenue, ROUND(AVG(TotalAmount), 2) AS AvgOrderValue,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS SharePct,
       REPEAT('█', ROUND(COUNT(*) / MAX(COUNT(*)) OVER () * 30)) AS Chart
FROM v_FactOrders GROUP BY SaleHour ORDER BY SaleHour;

-- 2.5 Heat map: orders by hour and weekday
SELECT SaleHour AS Hour,
       SUM(WeekdayNo = 0) AS Mon, SUM(WeekdayNo = 1) AS Tue, SUM(WeekdayNo = 2) AS Wed, SUM(WeekdayNo = 3) AS Thu,
       SUM(WeekdayNo = 4) AS Fri, SUM(WeekdayNo = 5) AS Sat, SUM(WeekdayNo = 6) AS Sun, COUNT(*) AS Total
FROM v_FactOrders GROUP BY SaleHour ORDER BY SaleHour;

-- 2.6 Dayparts
SELECT CASE WHEN SaleHour < 12 THEN '1 Morning (until 12)' WHEN SaleHour < 15 THEN '2 Lunch (12-15)'
            WHEN SaleHour < 18 THEN '3 Afternoon (15-18)' ELSE '4 Evening (18+)' END AS Daypart,
       COUNT(*) AS Orders, ROUND(SUM(TotalAmount)) AS Revenue, ROUND(AVG(TotalAmount), 2) AS AvgOrderValue,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS OrdersSharePct, ROUND(100 * AVG(OrderType = 'Takeaway'), 1) AS TakeawayPct,
       ROUND(AVG(Items), 2) AS ItemsPerOrder
FROM v_FactOrders GROUP BY Daypart ORDER BY Daypart;

-- 2.7 Seasonality of drinks (units per month)
SELECT ProductName,
       SUM(IF(SaleMonth = '2025-10', Quantity, 0)) AS Oct25, SUM(IF(SaleMonth = '2025-11', Quantity, 0)) AS Nov25,
       SUM(IF(SaleMonth = '2025-12', Quantity, 0)) AS Dec25, SUM(IF(SaleMonth = '2026-01', Quantity, 0)) AS Jan26,
       SUM(IF(SaleMonth = '2026-02', Quantity, 0)) AS Feb26, SUM(IF(SaleMonth = '2026-03', Quantity, 0)) AS Mar26,
       CASE WHEN SUM(IF(SaleMonth = '2025-10', Quantity, 0)) = 0 THEN 'Launched after October'
            WHEN SUM(IF(SaleMonth IN ('2025-10', '2025-11'), Quantity, 0)) > 1.5 * SUM(IF(SaleMonth IN ('2026-01', '2026-02'), Quantity, 0)) THEN 'Warm-season product'
            WHEN SUM(IF(SaleMonth IN ('2026-01', '2026-02'), Quantity, 0)) > 1.5 * SUM(IF(SaleMonth IN ('2025-10', '2025-11'), Quantity, 0)) THEN 'Cold-season product'
            ELSE 'Stable' END AS Pattern
FROM v_FactLines WHERE Category = 'Drink' GROUP BY ProductID, ProductName ORDER BY ProductName;

-- 2.8 Best and worst trading days
(SELECT 'Best' AS Type, SaleDate, DayName, COUNT(*) AS Orders, ROUND(SUM(TotalAmount)) AS Revenue FROM v_FactOrders GROUP BY SaleDate, DayName ORDER BY Revenue DESC LIMIT 5)
UNION ALL
(SELECT 'Worst', SaleDate, DayName, COUNT(*), ROUND(SUM(TotalAmount)) FROM v_FactOrders GROUP BY SaleDate, DayName ORDER BY SUM(TotalAmount) LIMIT 5);


-- ============================================================================
-- 3. RAMADAN IMPACT
-- Ramadan 2026 (18 Feb - 19 Mar) changed when and how customers buy
-- ============================================================================
SELECT 'SECTION 3 | RAMADAN IMPACT' AS Section;

-- 3.1 Period comparison
SELECT CASE WHEN SaleDate BETWEEN '2026-01-21' AND '2026-02-17' THEN '1 Before Ramadan (4 weeks)'
            WHEN SaleDate BETWEEN '2026-02-18' AND '2026-03-19' THEN '2 Ramadan'
            WHEN SaleDate BETWEEN '2026-03-20' AND '2026-03-22' THEN '3 Eid (3 days)'
            ELSE '4 After Eid' END AS Period,
       COUNT(DISTINCT SaleDate) AS Days, ROUND(COUNT(*) / COUNT(DISTINCT SaleDate), 1) AS OrdersPerDay,
       ROUND(SUM(TotalAmount) / COUNT(DISTINCT SaleDate)) AS RevenuePerDay, ROUND(AVG(TotalAmount), 2) AS AvgOrderValue,
       ROUND(100 * AVG(SaleHour >= 19), 1) AS OrdersAfter7pmPct, ROUND(100 * AVG(SaleHour < 12), 1) AS OrdersBeforeNoonPct,
       ROUND(100 * AVG(OrderType = 'Takeaway'), 1) AS TakeawayPct
FROM v_FactOrders WHERE SaleDate >= '2026-01-21' GROUP BY Period ORDER BY Period;

-- 3.2 Demand shift by hour: before Ramadan against Ramadan
WITH h AS (
    SELECT SaleHour, SUM(SaleDate BETWEEN '2026-01-21' AND '2026-02-17') AS PreOrders, SUM(SaleDate BETWEEN '2026-02-18' AND '2026-03-19') AS RamadanOrders
    FROM v_FactOrders WHERE SaleDate BETWEEN '2026-01-21' AND '2026-03-19' GROUP BY SaleHour)
SELECT SaleHour AS Hour, ROUND(100 * PreOrders / SUM(PreOrders) OVER (), 1) AS BeforeSharePct,
       ROUND(100 * RamadanOrders / SUM(RamadanOrders) OVER (), 1) AS RamadanSharePct,
       ROUND(100 * RamadanOrders / SUM(RamadanOrders) OVER () - 100 * PreOrders / SUM(PreOrders) OVER (), 1) AS ShiftPts,
       REPEAT('█', ROUND(100 * RamadanOrders / SUM(RamadanOrders) OVER ())) AS RamadanChart
FROM h ORDER BY SaleHour;

-- 3.3 Products that gained or lost during Ramadan (units per day)
WITH p AS (
    SELECT ProductName,
           SUM(IF(SaleDate BETWEEN '2026-01-21' AND '2026-02-17', Quantity, 0)) / 28 AS PreUnitsPerDay,
           SUM(IF(SaleDate BETWEEN '2026-02-18' AND '2026-03-19', Quantity, 0)) / 30 AS RamadanUnitsPerDay
    FROM v_FactLines WHERE SaleDate BETWEEN '2026-01-21' AND '2026-03-19' GROUP BY ProductName)
SELECT ProductName, ROUND(PreUnitsPerDay, 1) AS BeforeUnitsPerDay, ROUND(RamadanUnitsPerDay, 1) AS RamadanUnitsPerDay,
       ROUND(100 * (RamadanUnitsPerDay / NULLIF(PreUnitsPerDay, 0) - 1), 1) AS Change_Pct,
       CASE WHEN PreUnitsPerDay = 0 AND RamadanUnitsPerDay > 0 THEN 'New item' WHEN PreUnitsPerDay = 0 THEN 'No sales'
            WHEN RamadanUnitsPerDay / PreUnitsPerDay > 1.2 THEN 'Strong gain' WHEN RamadanUnitsPerDay / PreUnitsPerDay > 0.95 THEN 'Resilient'
            WHEN RamadanUnitsPerDay / PreUnitsPerDay > 0.7 THEN 'Slight drop' ELSE 'Strong drop' END AS Reading
FROM p ORDER BY Change_Pct DESC;


-- ============================================================================
-- 4. MENU AND PRODUCT PERFORMANCE
-- What sells, what earns, what to keep, fix or drop
-- ============================================================================
SELECT 'SECTION 4 | MENU AND PRODUCT PERFORMANCE' AS Section;

-- 4.1 Product leaderboard
SELECT RANK() OVER (ORDER BY SUM(NetRevenue) DESC) AS Position, ProductName, Category, SUM(Quantity) AS Units,
       ROUND(SUM(NetRevenue)) AS Revenue, ROUND(100 * SUM(NetRevenue) / SUM(SUM(NetRevenue)) OVER (), 1) AS RevenueSharePct,
       ROUND(SUM(NetRevenue - CostAmount)) AS GrossProfit, ROUND(100 * SUM(NetRevenue - CostAmount) / SUM(NetRevenue), 1) AS MarginPct,
       REPEAT('█', ROUND(SUM(NetRevenue) / MAX(SUM(NetRevenue)) OVER () * 25)) AS Chart
FROM v_FactLines GROUP BY ProductID, ProductName, Category ORDER BY Revenue DESC;

-- 4.2 Category mix by month (share of revenue %)
SELECT Category,
       ROUND(100 * SUM(IF(SaleMonth = '2025-10', NetRevenue, 0)) / (SELECT SUM(NetRevenue) FROM v_FactLines WHERE SaleMonth = '2025-10'), 1) AS Oct25,
       ROUND(100 * SUM(IF(SaleMonth = '2025-11', NetRevenue, 0)) / (SELECT SUM(NetRevenue) FROM v_FactLines WHERE SaleMonth = '2025-11'), 1) AS Nov25,
       ROUND(100 * SUM(IF(SaleMonth = '2025-12', NetRevenue, 0)) / (SELECT SUM(NetRevenue) FROM v_FactLines WHERE SaleMonth = '2025-12'), 1) AS Dec25,
       ROUND(100 * SUM(IF(SaleMonth = '2026-01', NetRevenue, 0)) / (SELECT SUM(NetRevenue) FROM v_FactLines WHERE SaleMonth = '2026-01'), 1) AS Jan26,
       ROUND(100 * SUM(IF(SaleMonth = '2026-02', NetRevenue, 0)) / (SELECT SUM(NetRevenue) FROM v_FactLines WHERE SaleMonth = '2026-02'), 1) AS Feb26,
       ROUND(100 * SUM(IF(SaleMonth = '2026-03', NetRevenue, 0)) / (SELECT SUM(NetRevenue) FROM v_FactLines WHERE SaleMonth = '2026-03'), 1) AS Mar26
FROM v_FactLines GROUP BY Category ORDER BY Category;

-- 4.3 ABC analysis (Pareto): class A products make the first 70 percent of revenue
WITH p AS (SELECT ProductName, Category, SUM(NetRevenue) AS Revenue FROM v_FactLines GROUP BY ProductID, ProductName, Category),
c AS (SELECT ProductName, Category, Revenue, Revenue / SUM(Revenue) OVER () AS Share,
             SUM(Revenue) OVER (ORDER BY Revenue DESC) / SUM(Revenue) OVER () AS Cumulative FROM p)
SELECT ProductName, Category, ROUND(Revenue) AS Revenue, ROUND(100 * Share, 1) AS SharePct, ROUND(100 * Cumulative, 1) AS CumulativePct,
       CASE WHEN Cumulative - Share < 0.70 THEN 'A' WHEN Cumulative - Share < 0.90 THEN 'B' ELSE 'C' END AS Class
FROM c ORDER BY Revenue DESC;

-- 4.4 Menu engineering matrix (popularity against profit per unit)
-- Popularity uses units per day on the menu, so new products are treated fairly
CREATE OR REPLACE VIEW v_MenuMatrix AS
WITH p AS (
    SELECT ProductID, ProductName, Category, SUM(Quantity) AS Units,
           SUM(Quantity) / (DATEDIFF('2026-03-31', MIN(SaleDate)) + 1) AS UnitsPerDay,
           SUM(NetRevenue - CostAmount) / SUM(Quantity) AS ProfitPerUnit, SUM(NetRevenue - CostAmount) AS Profit
    FROM v_FactLines GROUP BY ProductID, ProductName, Category),
t AS (SELECT AVG(UnitsPerDay) AS AvgUnitsPerDay, SUM(Profit) / SUM(Units) AS AvgProfitPerUnit FROM p)
SELECT p.ProductName, p.Category, p.Units, ROUND(p.UnitsPerDay, 2) AS UnitsPerDay, ROUND(p.ProfitPerUnit, 2) AS ProfitPerUnit, ROUND(p.Profit) AS Profit,
       CASE WHEN p.UnitsPerDay >= 0.7 * t.AvgUnitsPerDay AND p.ProfitPerUnit >= t.AvgProfitPerUnit THEN 'STAR - protect and promote'
            WHEN p.UnitsPerDay >= 0.7 * t.AvgUnitsPerDay THEN 'PLOWHORSE - raise price or cut cost'
            WHEN p.ProfitPerUnit >= t.AvgProfitPerUnit THEN 'PUZZLE - push with promotion'
            ELSE 'DOG - review or remove' END AS Action
FROM p CROSS JOIN t ORDER BY p.Profit DESC;
SELECT * FROM v_MenuMatrix ORDER BY Profit DESC;

-- 4.5 New product launches
SELECT ProductName, MIN(SaleDate) AS FirstSale, DATEDIFF('2026-03-31', MIN(SaleDate)) + 1 AS DaysOnMenu, SUM(Quantity) AS Units,
       ROUND(SUM(Quantity) / (DATEDIFF('2026-03-31', MIN(SaleDate)) + 1), 2) AS UnitsPerDay, ROUND(SUM(NetRevenue)) AS Revenue,
       ROUND(SUM(NetRevenue - CostAmount)) AS GrossProfit,
       ROUND(100 * SUM(IF(SaleMonth = '2026-03', NetRevenue, 0)) / (SELECT SUM(NetRevenue) FROM v_FactLines WHERE SaleMonth = '2026-03'), 1) AS Share_Of_March_Pct
FROM v_FactLines GROUP BY ProductID, ProductName HAVING MIN(SaleDate) > '2025-10-15' ORDER BY FirstSale;


-- ============================================================================
-- 5. PRICING AND PROMOTION IMPACT
-- Did the price rise hurt volume? Did the cake promotion pay for itself?
-- ============================================================================
SELECT 'SECTION 5 | PRICING AND PROMOTION IMPACT' AS Section;

-- 5.1 Price increase of +1 AED on 1 Jan 2026 (4 weeks before against 4 weeks after)
WITH x AS (
    SELECT IF(ProductName IN ('Cappuccino', 'Latte', 'Mocha'), '1 Price +1 AED (Cappuccino, Latte, Mocha)', '2 Control (Espresso, Americano, Green Tea)') AS ProductGroup,
           IF(SaleDate < '2026-01-01', 'Before', 'After') AS Period,
           SUM(Quantity) / 28 AS UnitsPerDay, SUM(NetRevenue) / 28 AS RevenuePerDay, SUM(NetRevenue) / SUM(Quantity) AS AvgPrice
    FROM v_FactLines
    WHERE SaleDate BETWEEN '2025-12-04' AND '2026-01-28' AND ProductName IN ('Cappuccino', 'Latte', 'Mocha', 'Espresso', 'Americano', 'Green Tea')
    GROUP BY ProductGroup, Period)
SELECT ProductGroup,
       ROUND(MAX(IF(Period = 'Before', UnitsPerDay, 0)), 1) AS UnitsPerDay_Before, ROUND(MAX(IF(Period = 'After', UnitsPerDay, 0)), 1) AS UnitsPerDay_After,
       ROUND(100 * (MAX(IF(Period = 'After', UnitsPerDay, 0)) / MAX(IF(Period = 'Before', UnitsPerDay, 0)) - 1), 1) AS UnitsChange_Pct,
       ROUND(MAX(IF(Period = 'Before', AvgPrice, 0)), 2) AS AvgPrice_Before, ROUND(MAX(IF(Period = 'After', AvgPrice, 0)), 2) AS AvgPrice_After,
       ROUND(100 * (MAX(IF(Period = 'After', RevenuePerDay, 0)) / MAX(IF(Period = 'Before', RevenuePerDay, 0)) - 1), 1) AS RevenueChange_Pct
FROM x GROUP BY ProductGroup ORDER BY ProductGroup;

-- 5.2 Price increase by product
SELECT ProductName,
       ROUND(SUM(IF(SaleDate < '2026-01-01', Quantity, 0)) / 28, 2) AS UnitsPerDay_Before, ROUND(SUM(IF(SaleDate >= '2026-01-01', Quantity, 0)) / 28, 2) AS UnitsPerDay_After,
       ROUND(100 * (SUM(IF(SaleDate >= '2026-01-01', Quantity, 0)) / SUM(IF(SaleDate < '2026-01-01', Quantity, 0)) - 1), 1) AS UnitsChange_Pct,
       ROUND(SUM(IF(SaleDate < '2026-01-01', GrossRevenue, 0)) / SUM(IF(SaleDate < '2026-01-01', Quantity, 0)), 2) AS ListPrice_Before,
       ROUND(SUM(IF(SaleDate >= '2026-01-01', GrossRevenue, 0)) / SUM(IF(SaleDate >= '2026-01-01', Quantity, 0)), 2) AS ListPrice_After,
       ROUND(SUM(IF(SaleDate >= '2026-01-01', NetRevenue - CostAmount, 0)) / 28 - SUM(IF(SaleDate < '2026-01-01', NetRevenue - CostAmount, 0)) / 28, 2) AS ProfitPerDay_Change
FROM v_FactLines
WHERE SaleDate BETWEEN '2025-12-04' AND '2026-01-28' AND ProductName IN ('Cappuccino', 'Latte', 'Mocha')
GROUP BY ProductName;

-- 5.3 Cake promotion: 15 percent off Cheesecake, Chocolate Cake and Brownie (10-24 Jan 2026)
WITH x AS (
    SELECT CASE WHEN SaleDate BETWEEN '2025-12-27' AND '2026-01-09' THEN '1 Before (14 days)'
                WHEN SaleDate BETWEEN '2026-01-10' AND '2026-01-24' THEN '2 Promotion (15 days)'
                ELSE '3 After (14 days)' END AS Period,
           CASE WHEN SaleDate BETWEEN '2025-12-27' AND '2026-01-09' THEN 14 WHEN SaleDate BETWEEN '2026-01-10' AND '2026-01-24' THEN 15 ELSE 14 END AS Days,
           Quantity, NetRevenue, NetRevenue - CostAmount AS Profit, DiscountAmount
    FROM v_FactLines
    WHERE SaleDate BETWEEN '2025-12-27' AND '2026-02-07' AND ProductName IN ('Cheesecake', 'Chocolate Cake', 'Brownie'))
SELECT Period, ROUND(SUM(Quantity) / MAX(Days), 2) AS UnitsPerDay, ROUND(SUM(NetRevenue) / MAX(Days), 1) AS RevenuePerDay,
       ROUND(SUM(Profit) / MAX(Days), 1) AS ProfitPerDay, ROUND(SUM(DiscountAmount) / MAX(Days), 1) AS DiscountPerDay,
       ROUND(100 * SUM(DiscountAmount) / (SUM(NetRevenue) + SUM(DiscountAmount)), 1) AS DiscountRatePct
FROM x GROUP BY Period ORDER BY Period;

-- 5.4 Promotion verdict: extra profit against the three weeks around it
WITH x AS (
    SELECT SUM(IF(SaleDate BETWEEN '2025-12-27' AND '2026-01-09', NetRevenue - CostAmount, 0)) / 14 AS BeforeProfitPerDay,
           SUM(IF(SaleDate BETWEEN '2026-01-10' AND '2026-01-24', NetRevenue - CostAmount, 0)) / 15 AS PromoProfitPerDay,
           SUM(IF(SaleDate BETWEEN '2026-01-10' AND '2026-01-24', DiscountAmount, 0)) AS DiscountGiven,
           SUM(IF(SaleDate BETWEEN '2026-01-10' AND '2026-01-24', Quantity, 0)) / 15 AS PromoUnitsPerDay,
           SUM(IF(SaleDate BETWEEN '2025-12-27' AND '2026-01-09', Quantity, 0)) / 14 AS BeforeUnitsPerDay
    FROM v_FactLines WHERE ProductName IN ('Cheesecake', 'Chocolate Cake', 'Brownie'))
SELECT ROUND(100 * (PromoUnitsPerDay / BeforeUnitsPerDay - 1)) AS VolumeUplift_Pct, ROUND(DiscountGiven) AS DiscountCost,
       ROUND((PromoProfitPerDay - BeforeProfitPerDay) * 15) AS ExtraProfit,
       IF(PromoProfitPerDay > BeforeProfitPerDay, 'Promotion paid for itself', 'Promotion lost money') AS Verdict
FROM x;

-- 5.5 Where the discounts go
SELECT CASE WHEN Discount = 0 THEN '1 No discount'
            WHEN SaleDate BETWEEN '2026-01-10' AND '2026-01-24' AND Discount >= 15 THEN '3 Promotion'
            WHEN LoyaltyCardID IS NOT NULL THEN '2 Loyalty card' ELSE '4 Other' END AS DiscountType,
       COUNT(*) AS SoldLines, ROUND(SUM(GrossRevenue)) AS GrossSales, ROUND(SUM(DiscountAmount)) AS DiscountGiven,
       ROUND(100 * SUM(DiscountAmount) / SUM(GrossRevenue), 1) AS DiscountPct, ROUND(100 * SUM(NetRevenue - CostAmount) / SUM(NetRevenue), 1) AS MarginAfterDiscountPct
FROM v_FactLines GROUP BY DiscountType ORDER BY DiscountType;


-- ============================================================================
-- 6. BASKET ANALYSIS AND LOYALTY CUSTOMERS
-- What customers buy together and who our best customers are
-- ============================================================================
SELECT 'SECTION 6 | BASKET ANALYSIS AND LOYALTY CUSTOMERS' AS Section;

-- 6.1 Products bought together (support, confidence, lift)
-- Lift above 1 means the two products are bought together more than by chance
WITH ob AS (SELECT DISTINCT OrderID, ProductID FROM v_FactLines),
n AS (SELECT COUNT(DISTINCT OrderID) AS Total FROM ob),
pc AS (SELECT ProductID, COUNT(*) AS Orders FROM ob GROUP BY ProductID),
pairs AS (SELECT a.ProductID AS A, b.ProductID AS B, COUNT(*) AS Together FROM ob a JOIN ob b ON a.OrderID = b.OrderID AND a.ProductID < b.ProductID GROUP BY a.ProductID, b.ProductID)
SELECT pa.ProductName AS ProductA, pb.ProductName AS ProductB, Together AS OrdersTogether,
       ROUND(100 * Together / Total, 2) AS SupportPct,
       ROUND(100 * Together / ca.Orders, 1) AS ConfidenceAtoB_Pct, ROUND(100 * Together / cb.Orders, 1) AS ConfidenceBtoA_Pct,
       ROUND((Together / Total) / ((ca.Orders / Total) * (cb.Orders / Total)), 2) AS Lift
FROM pairs JOIN n JOIN pc ca ON ca.ProductID = pairs.A JOIN pc cb ON cb.ProductID = pairs.B
JOIN Products pa ON pa.ProductID = pairs.A JOIN Products pb ON pb.ProductID = pairs.B
WHERE Together >= 100 ORDER BY Lift DESC LIMIT 12;

-- 6.2 Food attach rate by drink
WITH dr AS (SELECT DISTINCT OrderID, ProductName FROM v_FactLines WHERE Category = 'Drink'),
fd AS (SELECT DISTINCT OrderID FROM v_FactLines WHERE Category IN ('Dessert', 'Snack'))
SELECT dr.ProductName AS Drink, COUNT(*) AS Orders, SUM(fd.OrderID IS NOT NULL) AS OrdersWithFood,
       ROUND(100 * AVG(fd.OrderID IS NOT NULL), 1) AS FoodAttachPct, REPEAT('█', ROUND(100 * AVG(fd.OrderID IS NOT NULL) / 4)) AS Chart
FROM dr LEFT JOIN fd ON fd.OrderID = dr.OrderID GROUP BY dr.ProductName HAVING COUNT(*) >= 300 ORDER BY FoodAttachPct DESC;

-- 6.3 Basket size
SELECT CASE WHEN Items = 1 THEN '1 item' WHEN Items = 2 THEN '2 items' WHEN Items = 3 THEN '3 items' ELSE '4+ items' END AS BasketSize,
       COUNT(*) AS Orders, ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS OrdersSharePct, ROUND(AVG(TotalAmount), 2) AS AvgOrderValue,
       ROUND(100 * SUM(TotalAmount) / SUM(SUM(TotalAmount)) OVER (), 1) AS RevenueSharePct
FROM v_FactOrders GROUP BY BasketSize ORDER BY BasketSize;

-- 6.4 Loyalty customers against other customers
SELECT IF(LoyaltyCardID IS NULL, 'Without card', 'Loyalty card') AS Customer, COUNT(*) AS Orders,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS OrdersSharePct, ROUND(SUM(TotalAmount)) AS Revenue,
       ROUND(AVG(TotalAmount), 2) AS AvgOrderValue, ROUND(AVG(Items), 2) AS ItemsPerOrder
FROM v_FactOrders GROUP BY Customer;

-- 6.5 RFM segmentation of loyalty cards
-- Recency (days since last visit), Frequency (orders), Monetary (spend), each scored 1-4
CREATE OR REPLACE VIEW v_CardRFM AS
WITH c AS (
    SELECT LoyaltyCardID, DATEDIFF('2026-03-31', MAX(SaleDate)) AS Recency, COUNT(*) AS Frequency, SUM(TotalAmount) AS Monetary
    FROM v_FactOrders WHERE LoyaltyCardID IS NOT NULL GROUP BY LoyaltyCardID),
s AS (SELECT c.*, NTILE(4) OVER (ORDER BY Recency DESC) AS R, NTILE(4) OVER (ORDER BY Frequency) AS F, NTILE(4) OVER (ORDER BY Monetary) AS M FROM c)
SELECT s.*, CASE WHEN R >= 3 AND F >= 3 AND M >= 3 THEN '1 Champions'
                 WHEN F >= 3 AND R <= 2 THEN '3 At risk (good customers going quiet)'
                 WHEN F >= 3 THEN '2 Loyal'
                 WHEN R = 4 THEN '4 New or promising'
                 ELSE '5 Hibernating' END AS Segment
FROM s;
SELECT Segment, COUNT(*) AS Cards, ROUND(AVG(Recency)) AS AvgDaysSinceVisit, ROUND(AVG(Frequency), 1) AS AvgOrders, ROUND(SUM(Monetary)) AS Revenue,
       ROUND(100 * SUM(Monetary) / SUM(SUM(Monetary)) OVER (), 1) AS RevenueSharePct
FROM v_CardRFM GROUP BY Segment ORDER BY Segment;

-- 6.6 Top 10 loyalty customers
SELECT lc.CardNumber, COUNT(*) AS Orders, ROUND(SUM(o.TotalAmount)) AS Spent, ROUND(AVG(o.TotalAmount), 2) AS AvgOrderValue,
       MAX(o.SaleDate) AS LastVisit, DATEDIFF('2026-03-31', MAX(o.SaleDate)) AS DaysSinceVisit
FROM v_FactOrders o JOIN LoyaltyCards lc ON lc.CardID = o.LoyaltyCardID
GROUP BY lc.CardID, lc.CardNumber ORDER BY Spent DESC LIMIT 10;

-- 6.7 Cohort retention: cards grouped by the month they were issued
WITH act AS (
    SELECT c.CardID, DATE_FORMAT(c.IssueDate, '%Y-%m') AS Cohort,
           TIMESTAMPDIFF(MONTH, DATE_FORMAT(c.IssueDate, '%Y-%m-01'), DATE_FORMAT(o.OrderDate, '%Y-%m-01')) AS MonthsAfter
    FROM LoyaltyCards c JOIN v_FactOrders o ON o.LoyaltyCardID = c.CardID
    GROUP BY c.CardID, Cohort, MonthsAfter)
SELECT a.Cohort, (SELECT COUNT(*) FROM LoyaltyCards c WHERE DATE_FORMAT(c.IssueDate, '%Y-%m') = a.Cohort) AS CardsIssued,
       COUNT(DISTINCT IF(MonthsAfter = 0, CardID, NULL)) AS Active_M0, COUNT(DISTINCT IF(MonthsAfter = 1, CardID, NULL)) AS Active_M1,
       COUNT(DISTINCT IF(MonthsAfter = 2, CardID, NULL)) AS Active_M2, COUNT(DISTINCT IF(MonthsAfter = 3, CardID, NULL)) AS Active_M3,
       IF(a.Cohort >= '2026-03', NULL, ROUND(100 * COUNT(DISTINCT IF(MonthsAfter = 1, CardID, NULL)) / (SELECT COUNT(*) FROM LoyaltyCards c WHERE DATE_FORMAT(c.IssueDate, '%Y-%m') = a.Cohort))) AS Active_M1_PctOfIssued
FROM act a GROUP BY a.Cohort ORDER BY a.Cohort;

-- 6.8 Loyalty points: tiers and outstanding liability
-- Rule used by the shop: 1 point per AED spent, 100 points are worth 5 AED
WITH p AS (SELECT LoyaltyCardID, SUM(FLOOR(TotalAmount)) AS Points FROM v_FactOrders WHERE LoyaltyCardID IS NOT NULL GROUP BY LoyaltyCardID)
SELECT CASE WHEN Points >= 500 THEN '3 Gold (500+)' WHEN Points >= 250 THEN '2 Silver (250-499)' ELSE '1 Bronze (<250)' END AS Tier,
       COUNT(*) AS Cards, SUM(Points) AS PointsEarned, ROUND(SUM(Points) * 0.05) AS LiabilityAED, ROUND(AVG(Points)) AS AvgPoints
FROM p GROUP BY Tier ORDER BY Tier;


-- ============================================================================
-- 7. OPERATIONS AND STAFF
-- Who sells, who is on time, and whether staffing follows demand
-- ============================================================================
SELECT 'SECTION 7 | OPERATIONS AND STAFF' AS Section;

-- 7.1 Order-taker leaderboard
-- Two employees are named Abdullah Mohammed: the EmployeeID tells them apart
SELECT RANK() OVER (ORDER BY o.Revenue DESC) AS Position, e.EmployeeID, CONCAT(e.FirstName, ' ', e.LastName) AS Employee, e.Role,
       o.Orders, ROUND(o.Revenue) AS Revenue, ROUND(o.AOV, 2) AS AvgOrderValue, ROUND(o.ItemsPerOrder, 2) AS ItemsPerOrder,
       ROUND(o.CardPct, 1) AS LoyaltyCardPct, a.Days AS DaysWorked, ROUND(o.Orders / a.Days, 1) AS OrdersPerShift
FROM Employees e
JOIN (SELECT EmployeeID, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue, AVG(TotalAmount) AS AOV, AVG(Items) AS ItemsPerOrder,
             100 * AVG(LoyaltyCardID IS NOT NULL) AS CardPct
      FROM v_FactOrders WHERE EmployeeID IS NOT NULL GROUP BY EmployeeID) o ON o.EmployeeID = e.EmployeeID
LEFT JOIN (SELECT EmployeeID, COUNT(*) AS Days FROM Attendance WHERE Date BETWEEN '2025-10-01' AND '2026-03-31' GROUP BY EmployeeID) a ON a.EmployeeID = e.EmployeeID
ORDER BY Revenue DESC;

-- 7.2 Attendance quality
-- Late = check-in more than 5 minutes after the scheduled start of the shift
CREATE OR REPLACE VIEW v_AttendanceQuality AS
WITH a AS (
    SELECT a.EmployeeID, a.Date, a.CheckInTime, a.CheckOutTime,
           CASE e.Role WHEN 'Barista' THEN IF(MOD(e.EmployeeID, 2) = 0, '15:00:00', '07:00:00')
                       WHEN 'Cashier' THEN IF(MOD(e.EmployeeID, 2) = 0, '15:30:00', '07:30:00')
                       WHEN 'Manager' THEN '08:00:00' WHEN 'Cleaner' THEN '06:30:00' ELSE '09:00:00' END AS Scheduled
    FROM Attendance a JOIN Employees e ON e.EmployeeID = a.EmployeeID
    WHERE a.Date BETWEEN '2025-10-06' AND '2026-03-31')
SELECT a.EmployeeID, CONCAT(e.FirstName, ' ', e.LastName) AS Employee, e.Role, COUNT(*) AS Days,
       ROUND(100 * AVG(TIME_TO_SEC(TIMEDIFF(CheckInTime, Scheduled)) <= 300), 1) AS OnTimePct,
       ROUND(AVG(IF(TIME_TO_SEC(TIMEDIFF(CheckInTime, Scheduled)) > 300, TIME_TO_SEC(TIMEDIFF(CheckInTime, Scheduled)) / 60, NULL)), 1) AS AvgMinutesWhenLate,
       ROUND(AVG(TIME_TO_SEC(TIMEDIFF(CheckOutTime, CheckInTime)) / 3600), 2) AS AvgHoursPerShift,
       ROUND(SUM(GREATEST(0, TIME_TO_SEC(TIMEDIFF(CheckOutTime, CheckInTime)) / 3600 - 7.5)), 1) AS OvertimeHours,
       SUM(CheckOutTime IS NULL) AS MissingCheckOuts
FROM a JOIN Employees e ON e.EmployeeID = a.EmployeeID
GROUP BY a.EmployeeID, e.FirstName, e.LastName, e.Role ORDER BY OnTimePct DESC;
SELECT * FROM v_AttendanceQuality ORDER BY OnTimePct DESC;

-- 7.3 Staffing against demand by weekday
WITH s AS (SELECT Date AS SaleDate, COUNT(*) AS StaffOnDuty FROM Attendance WHERE Date BETWEEN '2025-10-06' AND '2026-03-31' GROUP BY Date),
d AS (SELECT SaleDate, WeekdayNo, DayName, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue FROM v_FactOrders WHERE SaleDate >= '2025-10-06' GROUP BY SaleDate, WeekdayNo, DayName)
SELECT d.DayName, ROUND(AVG(s.StaffOnDuty), 1) AS AvgStaffOnDuty, ROUND(AVG(d.Orders)) AS OrdersPerDay,
       ROUND(AVG(d.Orders / s.StaffOnDuty), 1) AS OrdersPerStaff, ROUND(AVG(d.Revenue / s.StaffOnDuty)) AS RevenuePerStaff,
       CASE WHEN AVG(d.Orders / s.StaffOnDuty) > (SELECT AVG(d2.Orders / s2.StaffOnDuty) FROM d d2 JOIN s s2 ON s2.SaleDate = d2.SaleDate) * 1.08 THEN 'Add staff'
            WHEN AVG(d.Orders / s.StaffOnDuty) < (SELECT AVG(d2.Orders / s2.StaffOnDuty) FROM d d2 JOIN s s2 ON s2.SaleDate = d2.SaleDate) * 0.92 THEN 'Overstaffed'
            ELSE 'Balanced' END AS Reading
FROM d JOIN s ON s.SaleDate = d.SaleDate GROUP BY d.WeekdayNo, d.DayName ORDER BY d.WeekdayNo;


-- ============================================================================
-- 8. PAYMENTS AND CASH-FLOW LEAKAGE
-- How customers pay and how much revenue is lost to unfinished orders
-- ============================================================================
SELECT 'SECTION 8 | PAYMENTS AND CASH-FLOW LEAKAGE' AS Section;

-- 8.1 Payment mix by month (share of revenue %)
SELECT SaleMonth AS Month, ROUND(100 * SUM(IF(PaymentType = 'Cash', TotalAmount, 0)) / SUM(TotalAmount), 1) AS Cash_Pct,
       ROUND(100 * SUM(IF(PaymentType = 'Card', TotalAmount, 0)) / SUM(TotalAmount), 1) AS Card_Pct,
       ROUND(100 * SUM(IF(PaymentType = 'MobilePay', TotalAmount, 0)) / SUM(TotalAmount), 1) AS MobilePay_Pct,
       REPEAT('█', ROUND(SUM(IF(PaymentType = 'Cash', TotalAmount, 0)) / SUM(TotalAmount) * 50)) AS CashChart
FROM v_FactOrders GROUP BY SaleMonth ORDER BY SaleMonth;

-- 8.2 Payment type profile
SELECT PaymentType, COUNT(*) AS Payments, ROUND(SUM(TotalAmount)) AS Revenue, ROUND(100 * SUM(TotalAmount) / SUM(SUM(TotalAmount)) OVER (), 1) AS RevenueSharePct,
       ROUND(AVG(TotalAmount), 2) AS AvgTicket, ROUND(AVG(Items), 2) AS ItemsPerOrder
FROM v_FactOrders GROUP BY PaymentType ORDER BY Revenue DESC;

-- 8.3 Unfinished orders (never paid) by month
SELECT DATE_FORMAT(OrderDate, '%Y-%m') AS Month, COUNT(*) AS Orders, SUM(IsCompleted = FALSE) AS Unfinished,
       ROUND(100 * AVG(IsCompleted = FALSE), 2) AS UnfinishedPct, ROUND(SUM(IF(IsCompleted = FALSE, TotalAmount, 0))) AS RevenueLost
FROM Orders WHERE OrderDate >= '2025-10-01' AND OrderDate < '2026-04-01' GROUP BY Month WITH ROLLUP;

-- 8.4 Unfinished orders by weekday and hour band (where the leakage happens)
SELECT DAYNAME(OrderDate) AS Day, COUNT(*) AS Orders, SUM(IsCompleted = FALSE) AS Unfinished, ROUND(100 * AVG(IsCompleted = FALSE), 2) AS UnfinishedPct
FROM Orders WHERE OrderDate >= '2025-10-01' AND OrderDate < '2026-04-01' GROUP BY DAYNAME(OrderDate), WEEKDAY(OrderDate) ORDER BY WEEKDAY(OrderDate);


-- ============================================================================
-- 9. INVENTORY AND EXPIRY RISK
-- Stock position on 31 March 2026 against the last 30 days of sales
-- ============================================================================
SELECT 'SECTION 9 | INVENTORY AND EXPIRY RISK' AS Section;

-- 9.1 Stock cover view
CREATE OR REPLACE VIEW v_StockCover AS
SELECT p.ProductID, p.ProductName, p.Category, IFNULL(s.CompanyName, 'No supplier') AS Supplier, p.StockQuantity, p.Cost, p.ExpirationDate,
       ROUND(IFNULL(v.Units, 0) / 30, 2) AS UnitsPerDay,
       ROUND(p.StockQuantity / NULLIF(IFNULL(v.Units, 0) / 30, 0), 1) AS DaysCover,
       CASE WHEN IFNULL(v.Units, 0) = 0 THEN 'No recent sales'
            WHEN p.StockQuantity / (v.Units / 30) < 5 THEN 'REORDER NOW'
            WHEN p.StockQuantity / (v.Units / 30) < 10 THEN 'Order this week'
            WHEN p.StockQuantity / (v.Units / 30) > 40 THEN 'Overstock' ELSE 'OK' END AS StockStatus,
       GREATEST(0, CEIL(IFNULL(v.Units, 0) / 30 * 14 - p.StockQuantity)) AS ReorderQty14Days,
       DATEDIFF(p.ExpirationDate, '2026-03-31') AS DaysToExpiry,
       IF(p.ExpirationDate IS NULL, 0, GREATEST(0, CEIL(p.StockQuantity - IFNULL(v.Units, 0) / 30 * DATEDIFF(p.ExpirationDate, '2026-03-31')))) AS AtRiskUnits
FROM Products p
LEFT JOIN Suppliers s ON s.SupplierID = p.SupplierID
LEFT JOIN (SELECT ProductID, SUM(Quantity) AS Units FROM v_FactLines WHERE SaleDate >= '2026-03-02' GROUP BY ProductID) v ON v.ProductID = p.ProductID;

SELECT ProductName, Category, Supplier, StockQuantity AS Stock, UnitsPerDay, DaysCover, StockStatus, ReorderQty14Days,
       ROUND(ReorderQty14Days * Cost, 2) AS ReorderCost
FROM v_StockCover ORDER BY FIELD(StockStatus, 'REORDER NOW', 'Order this week', 'OK', 'Overstock', 'No recent sales'), DaysCover;

-- 9.2 Expiry risk: stock that will not be sold before its expiry date
SELECT ProductName, ExpirationDate, DaysToExpiry, StockQuantity AS Stock, UnitsPerDay, ROUND(UnitsPerDay * DaysToExpiry, 1) AS ExpectedSales,
       AtRiskUnits, ROUND(AtRiskUnits * Cost, 2) AS AtRiskValue,
       CASE WHEN AtRiskUnits = 0 THEN 'Safe' WHEN DaysToExpiry <= 2 THEN 'Discount 30 percent today' ELSE 'Bundle with a drink' END AS Action
FROM v_StockCover WHERE ExpirationDate IS NOT NULL AND Category IN ('Dessert', 'Snack') ORDER BY AtRiskValue DESC;

-- 9.3 Inventory summary
SELECT COUNT(*) AS Products, SUM(StockStatus = 'REORDER NOW') AS ReorderNow, SUM(StockStatus = 'Order this week') AS OrderThisWeek,
       ROUND(SUM(StockQuantity * Cost)) AS StockValueAtCost, ROUND(SUM(ReorderQty14Days * Cost)) AS ReorderBudget14Days,
       ROUND(SUM(AtRiskUnits * Cost)) AS ExpiryRiskValue
FROM v_StockCover;


-- ============================================================================
-- 10. SUPPLIERS
-- Dependency, profitability and stock value by supplier
-- ============================================================================
SELECT 'SECTION 10 | SUPPLIERS' AS Section;

CREATE OR REPLACE VIEW v_SupplierScore AS
SELECT IFNULL(s.CompanyName, 'No supplier') AS Supplier, COUNT(DISTINCT p.ProductID) AS Products,
       IFNULL(SUM(l.Units), 0) AS Units, ROUND(IFNULL(SUM(l.Revenue), 0)) AS Revenue, ROUND(IFNULL(SUM(l.Cogs), 0)) AS Cogs,
       ROUND(IFNULL(SUM(l.Revenue - l.Cogs), 0)) AS GrossProfit,
       ROUND(100 * SUM(l.Revenue - l.Cogs) / NULLIF(SUM(l.Revenue), 0), 1) AS MarginPct,
       ROUND(100 * SUM(l.Cogs) / SUM(SUM(l.Cogs)) OVER (), 1) AS CogsSharePct,
       ROUND(SUM(p.StockQuantity * p.Cost)) AS StockValue
FROM Products p
LEFT JOIN Suppliers s ON s.SupplierID = p.SupplierID
LEFT JOIN (SELECT ProductID, SUM(Quantity) AS Units, SUM(NetRevenue) AS Revenue, SUM(CostAmount) AS Cogs FROM v_FactLines GROUP BY ProductID) l ON l.ProductID = p.ProductID
GROUP BY s.SupplierID, s.CompanyName;
SELECT *, CASE WHEN CogsSharePct >= 40 THEN 'High dependency - find a second source' WHEN Products = 0 THEN 'No products' ELSE 'Acceptable' END AS Risk
FROM v_SupplierScore ORDER BY Revenue DESC;

-- 10.1 Suppliers without products (candidates to review)
SELECT s.SupplierID, s.CompanyName, s.ProductType FROM Suppliers s LEFT JOIN Products p ON p.SupplierID = s.SupplierID WHERE p.ProductID IS NULL;


-- ============================================================================
-- 11. PROFIT AND LOSS, TARGETS AND BREAK-EVEN
-- Gross profit, payroll and operating expenses month by month against management targets
-- ============================================================================
SELECT 'SECTION 11 | PROFIT AND LOSS, TARGETS AND BREAK-EVEN' AS Section;

CREATE OR REPLACE VIEW v_Monthly_PnL AS
SELECT t.*, ROUND(t.GrossProfit - t.Payroll - t.OtherOpex) AS NetProfit
FROM (
    WITH m AS (SELECT SaleMonth, SUM(NetRevenue) AS Revenue, SUM(CostAmount) AS Cogs, COUNT(DISTINCT SaleDate) AS Days FROM v_FactLines GROUP BY SaleMonth)
    SELECT m.SaleMonth AS Month, ROUND(m.Revenue) AS Revenue, ROUND(m.Cogs) AS Cogs, ROUND(m.Revenue - m.Cogs) AS GrossProfit,
           ROUND(100 * (m.Revenue - m.Cogs) / m.Revenue, 1) AS GrossMarginPct,
           (SELECT SUM(e.Salary) FROM Employees e WHERE DATE(e.HireDate) <= LAST_DAY(STR_TO_DATE(CONCAT(m.SaleMonth, '-01'), '%Y-%m-%d'))) AS Payroll,
           (SELECT IFNULL(SUM(x.Amount), 0) FROM Expenses x WHERE DATE_FORMAT(x.ExpenseMonth, '%Y-%m') = m.SaleMonth) AS OtherOpex,
           m.Days
    FROM m) t;

-- 11.1 Monthly profit and loss with growth and target tracking
-- Break-even revenue treats payroll and all other expenses as fixed
WITH p AS (
    SELECT v.*, (SELECT COUNT(*) FROM v_FactOrders o WHERE o.SaleMonth = v.Month) AS Orders, t.TargetRevenue
    FROM v_Monthly_PnL v LEFT JOIN Sales_Targets t ON DATE_FORMAT(t.TargetMonth, '%Y-%m') = v.Month)
SELECT Month, Orders, Revenue, Cogs, GrossProfit, GrossMarginPct, Payroll, OtherOpex, NetProfit, ROUND(100 * NetProfit / Revenue, 1) AS NetMarginPct,
       ROUND(100 * (Revenue / LAG(Revenue) OVER (ORDER BY Month) - 1), 1) AS GrowthVsPrevMonthPct,
       TargetRevenue, ROUND(100 * Revenue / TargetRevenue, 1) AS TargetAchievedPct, IF(Revenue >= TargetRevenue, 'ACHIEVED', 'MISSED') AS TargetStatus,
       ROUND((Payroll + OtherOpex) / (GrossMarginPct / 100) / Days) AS BreakEvenPerDay, ROUND(Revenue / Days) AS ActualPerDay
FROM p
UNION ALL
SELECT 'TOTAL', SUM(Orders), SUM(Revenue), SUM(Cogs), SUM(GrossProfit), ROUND(100 * SUM(GrossProfit) / SUM(Revenue), 1), SUM(Payroll), SUM(OtherOpex), SUM(NetProfit),
       ROUND(100 * SUM(NetProfit) / SUM(Revenue), 1), NULL, SUM(TargetRevenue), ROUND(100 * SUM(Revenue) / SUM(TargetRevenue), 1),
       IF(SUM(Revenue) >= SUM(TargetRevenue), 'ACHIEVED', 'MISSED'), ROUND(SUM(Payroll + OtherOpex) / (SUM(GrossProfit) / SUM(Revenue)) / SUM(Days)), ROUND(SUM(Revenue) / SUM(Days))
FROM p;

-- 11.2 Where every 100 AED of revenue goes
WITH rev AS (SELECT SUM(Revenue) AS Total FROM v_Monthly_PnL),
items AS (
    SELECT 1 AS Ord, 'Revenue' AS Item, SUM(Revenue) AS Amount FROM v_Monthly_PnL
    UNION ALL SELECT 2, 'Cost of goods (ingredients)', SUM(Cogs) FROM v_Monthly_PnL
    UNION ALL SELECT 3, 'Payroll', SUM(Payroll) FROM v_Monthly_PnL
    UNION ALL SELECT 4, CONCAT('Expense: ', Category), SUM(Amount) FROM Expenses GROUP BY Category
    UNION ALL SELECT 5, 'NET PROFIT', SUM(NetProfit) FROM v_Monthly_PnL)
SELECT Item, ROUND(Amount) AS Amount, ROUND(100 * Amount / Total, 1) AS PctOfRevenue, REPEAT('█', GREATEST(0, ROUND(100 * Amount / Total / 2))) AS Bar
FROM items CROSS JOIN rev ORDER BY Ord, Amount DESC;

-- 11.3 Expenses by category and month
SELECT Category,
       SUM(IF(ExpenseMonth = '2025-10-01', Amount, 0)) AS Oct25, SUM(IF(ExpenseMonth = '2025-11-01', Amount, 0)) AS Nov25,
       SUM(IF(ExpenseMonth = '2025-12-01', Amount, 0)) AS Dec25, SUM(IF(ExpenseMonth = '2026-01-01', Amount, 0)) AS Jan26,
       SUM(IF(ExpenseMonth = '2026-02-01', Amount, 0)) AS Feb26, SUM(IF(ExpenseMonth = '2026-03-01', Amount, 0)) AS Mar26,
       ROUND(SUM(Amount)) AS Total
FROM Expenses GROUP BY Category ORDER BY Total DESC;

-- 11.4 Payroll by role
SELECT Role, COUNT(*) AS Staff, SUM(Salary) AS MonthlyPayroll, ROUND(100 * SUM(Salary) / SUM(SUM(Salary)) OVER (), 1) AS PayrollSharePct,
       ROUND(AVG(Salary)) AS AvgSalary, MIN(Salary) AS Lowest, MAX(Salary) AS Highest
FROM Employees GROUP BY Role ORDER BY MonthlyPayroll DESC;

-- 11.5 Profit by category and order type
SELECT Category, OrderType, SUM(Quantity) AS Units, ROUND(SUM(NetRevenue)) AS Revenue, ROUND(SUM(NetRevenue - CostAmount)) AS GrossProfit,
       ROUND(100 * SUM(NetRevenue - CostAmount) / SUM(NetRevenue), 1) AS MarginPct,
       ROUND(100 * SUM(NetRevenue - CostAmount) / SUM(SUM(NetRevenue - CostAmount)) OVER (), 1) AS ProfitSharePct
FROM v_FactLines GROUP BY Category, OrderType ORDER BY Category, OrderType;


-- ============================================================================
-- 12. FORECAST
-- A trend model for the coming weeks
-- ============================================================================
SELECT 'SECTION 12 | FORECAST' AS Section;

-- 12.1 Weekly revenue forecast (linear trend on normal weeks; Ramadan and Eid weeks are excluded)
CREATE OR REPLACE VIEW v_WeeklyForecast AS
WITH w AS (
    SELECT DATEDIFF(SaleDate - INTERVAL WEEKDAY(SaleDate) DAY, '2025-10-06') / 7 AS x, SUM(TotalAmount) AS y
    FROM v_FactOrders
    WHERE SaleDate >= '2025-10-06' AND SaleDate < '2026-03-30' AND NOT (SaleDate BETWEEN '2026-02-16' AND '2026-03-22')
    GROUP BY x),
st AS (SELECT COUNT(*) AS n, SUM(x) AS sx, SUM(y) AS sy, SUM(x * y) AS sxy, SUM(x * x) AS sxx, SUM(y * y) AS syy FROM w),
cf AS (SELECT n, (n * sxy - sx * sy) / (n * sxx - sx * sx) AS b, (sy - (n * sxy - sx * sy) / (n * sxx - sx * sx) * sx) / n AS a,
              POW(n * sxy - sx * sy, 2) / ((n * sxx - sx * sx) * (n * syy - sy * sy)) AS r2 FROM st),
rs AS (SELECT SQRT(SUM(POW(w.y - (cf.a + cf.b * w.x), 2)) / (MAX(cf.n) - 2)) AS sigma FROM w CROSS JOIN cf),
f AS (SELECT 25 AS x UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL SELECT 28)
SELECT DATE('2025-10-06') + INTERVAL f.x WEEK AS WeekStart, ROUND(cf.a + cf.b * f.x) AS ForecastRevenue,
       ROUND(cf.a + cf.b * f.x - 1.28 * rs.sigma) AS LowEnd, ROUND(cf.a + cf.b * f.x + 1.28 * rs.sigma) AS HighEnd,
       ROUND(cf.b) AS TrendPerWeek, ROUND(cf.r2, 3) AS R2, cf.n AS WeeksUsed
FROM f CROSS JOIN cf CROSS JOIN rs;
SELECT * FROM v_WeeklyForecast ORDER BY WeekStart;

-- 12.2 Daily forecast for 1-7 April 2026 (weekly trend multiplied by the weekday pattern)
WITH dd AS (SELECT SaleDate, WeekdayNo, SUM(TotalAmount) AS Rev FROM v_FactOrders
            WHERE SaleDate >= '2025-10-06' AND SaleDate < '2026-03-30' AND NOT (SaleDate BETWEEN '2026-02-16' AND '2026-03-22') GROUP BY SaleDate, WeekdayNo),
wi AS (SELECT WeekdayNo, AVG(Rev) / (SELECT AVG(Rev) FROM dd) AS WeekdayIndex FROM dd GROUP BY WeekdayNo),
days AS (SELECT DATE('2026-04-01') + INTERVAL n DAY AS D FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6) t)
SELECT days.D AS ForecastDate, DAYNAME(days.D) AS DayName, ROUND(wf.ForecastRevenue / 7 * wi.WeekdayIndex) AS ForecastRevenue,
       ROUND(wf.LowEnd / 7 * wi.WeekdayIndex) AS LowEnd, ROUND(wf.HighEnd / 7 * wi.WeekdayIndex) AS HighEnd
FROM days JOIN wi ON wi.WeekdayNo = WEEKDAY(days.D) JOIN v_WeeklyForecast wf ON wf.WeekStart = days.D - INTERVAL WEEKDAY(days.D) DAY
ORDER BY days.D;


-- ============================================================================
-- 13. CUSTOMER SATISFACTION
-- What customers say, where service falls short and who earns the best ratings
-- ============================================================================
SELECT 'SECTION 13 | CUSTOMER SATISFACTION' AS Section;

-- 13.1 Satisfaction scorecard
SELECT COUNT(*) AS Reviews, ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM v_FactOrders), 1) AS ReviewRatePct, ROUND(AVG(r.Rating), 2) AS AvgRating,
       ROUND(100 * AVG(r.Rating >= 4), 1) AS PositivePct, ROUND(100 * AVG(r.Rating <= 2), 1) AS NegativePct,
       ROUND(100 * (AVG(r.Rating >= 4) - AVG(r.Rating <= 2))) AS NetSatisfactionScore
FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID;

-- 13.2 Rating by month
SELECT o.SaleMonth AS Month, COUNT(*) AS Reviews, ROUND(AVG(r.Rating), 2) AS AvgRating, ROUND(100 * AVG(r.Rating >= 4), 1) AS PositivePct,
       REPEAT('█', ROUND(AVG(r.Rating) * 8)) AS Chart
FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID GROUP BY o.SaleMonth ORDER BY o.SaleMonth;

-- 13.3 Rating distribution
SELECT CONCAT(r.Rating, ' stars') AS Stars, COUNT(*) AS Reviews, ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS SharePct,
       REPEAT('█', ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER () / 2)) AS Chart
FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID GROUP BY r.Rating ORDER BY r.Rating DESC;

-- 13.4 Rating by product (orders that contained the product)
WITH overall AS (SELECT AVG(r.Rating) AS Avg FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID)
SELECT l.ProductName, l.Category, COUNT(*) AS Reviews, ROUND(AVG(r.Rating), 2) AS AvgRating, ROUND(AVG(r.Rating) - overall.Avg, 2) AS VsAverage,
       CASE WHEN AVG(r.Rating) - overall.Avg <= -0.3 THEN 'WEAK - investigate' WHEN AVG(r.Rating) - overall.Avg >= 0.1 THEN 'Strong' ELSE 'Normal' END AS Reading
FROM Customer_Reviews r JOIN v_FactLines l ON l.OrderID = r.OrderID CROSS JOIN overall
GROUP BY l.ProductID, l.ProductName, l.Category, overall.Avg HAVING COUNT(*) >= 25 ORDER BY AvgRating;

-- 13.5 Rating by daypart (does the rush hour hurt service?)
SELECT CASE WHEN o.SaleHour BETWEEN 7 AND 9 THEN '1 Rush hour (07-09)' WHEN o.SaleHour < 12 THEN '2 Late morning'
            WHEN o.SaleHour < 18 THEN '3 Afternoon' ELSE '4 Evening (18+)' END AS Daypart,
       COUNT(*) AS Reviews, ROUND(AVG(r.Rating), 2) AS AvgRating, ROUND(100 * AVG(r.Topic = 'Speed'), 1) AS SpeedComplaintsPct
FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID GROUP BY Daypart ORDER BY Daypart;

-- 13.6 Rating by the employee who served the order
SELECT CONCAT(e.FirstName, ' ', e.LastName, ' (#', e.EmployeeID, ')') AS Employee, e.Role, COUNT(*) AS Reviews, ROUND(AVG(r.Rating), 2) AS AvgRating,
       ROUND(100 * AVG(r.Rating >= 4), 1) AS PositivePct
FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID JOIN Employees e ON e.EmployeeID = o.EmployeeID
GROUP BY e.EmployeeID, e.FirstName, e.LastName, e.Role HAVING COUNT(*) >= 40 ORDER BY AvgRating DESC;

-- 13.7 What unhappy customers complain about (rating 3 or lower)
SELECT r.Topic AS Complaint, COUNT(*) AS Reviews, ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS SharePct, ROUND(AVG(r.Rating), 2) AS AvgRating,
       REPEAT('█', ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER () / 2)) AS Chart
FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID WHERE r.Rating <= 3 GROUP BY r.Topic ORDER BY Reviews DESC;

-- 13.8 Loyalty members against other customers
SELECT IF(o.LoyaltyCardID IS NULL, 'Without card', 'Loyalty card') AS Customer, COUNT(*) AS Reviews, ROUND(AVG(r.Rating), 2) AS AvgRating,
       ROUND(100 * AVG(r.Rating >= 4), 1) AS PositivePct
FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID GROUP BY Customer;

-- 13.9 Does satisfaction follow spend?
SELECT CASE WHEN r.Rating >= 4 THEN '1 Happy (4-5)' WHEN r.Rating = 3 THEN '2 Neutral (3)' ELSE '3 Unhappy (1-2)' END AS Group_,
       COUNT(*) AS Reviews, ROUND(AVG(o.TotalAmount), 2) AS AvgOrderValue, ROUND(AVG(o.Items), 2) AS ItemsPerOrder
FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID GROUP BY Group_ ORDER BY Group_;


-- ============================================================================
-- 14. ANOMALY DETECTION
-- Days whose revenue broke the normal pattern of the same weekday (z-score of 2.5 or more and a gap of 15% or more)
-- ============================================================================
SELECT 'SECTION 14 | ANOMALY DETECTION' AS Section;

CREATE OR REPLACE VIEW v_Anomalies AS
WITH d AS (SELECT SaleDate, WeekdayNo, DayName, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue FROM v_FactOrders GROUP BY SaleDate, WeekdayNo, DayName),
s AS (SELECT d.*, AVG(Revenue) OVER w AS Expected, STDDEV_SAMP(Revenue) OVER w AS Sd, COUNT(*) OVER w AS PriorWeeks
      FROM d WINDOW w AS (PARTITION BY WeekdayNo ORDER BY SaleDate ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING))
SELECT SaleDate, DayName, Orders, ROUND(Revenue) AS Revenue, ROUND(Expected) AS ExpectedRevenue,
       ROUND(100 * (Revenue / Expected - 1), 1) AS VsExpectedPct, ROUND((Revenue - Expected) / Sd, 1) AS ZScore,
       CASE WHEN SaleDate BETWEEN '2026-03-20' AND '2026-03-22' THEN 'Eid al-Fitr'
            WHEN SaleDate BETWEEN '2026-02-18' AND '2026-02-24' THEN 'Start of Ramadan'
            WHEN SaleDate BETWEEN '2026-02-25' AND '2026-03-19' THEN 'Ramadan'
            WHEN SaleDate BETWEEN '2026-03-23' AND '2026-03-29' THEN 'After Eid'
            WHEN SaleDate BETWEEN '2026-01-10' AND '2026-01-24' THEN 'Cake promotion'
            WHEN SaleDate BETWEEN '2026-01-01' AND '2026-01-07' THEN 'New Year and price rise'
            ELSE 'No known cause - investigate' END AS KnownEvent
FROM s WHERE PriorWeeks >= 4 AND Sd > 0 AND ABS((Revenue - Expected) / Sd) >= 2.5 AND ABS(Revenue / Expected - 1) >= 0.15;

-- 14.1 The most unusual days
SELECT SaleDate, DayName, Orders, Revenue, ExpectedRevenue, VsExpectedPct, ZScore, KnownEvent, IF(ZScore > 0, 'ABOVE normal', 'BELOW normal') AS Direction
FROM v_Anomalies ORDER BY ABS(ZScore) DESC LIMIT 15;

-- 14.2 Anomalies by cause
SELECT KnownEvent, COUNT(*) AS Days, SUM(ZScore > 0) AS AboveNormal, SUM(ZScore < 0) AS BelowNormal, ROUND(AVG(VsExpectedPct), 1) AS AvgVsExpectedPct
FROM v_Anomalies GROUP BY KnownEvent ORDER BY Days DESC;


-- ============================================================================
-- 15. WHAT-IF SCENARIOS
-- Estimated gross profit effect over the same six months (annualised = two times)
-- ============================================================================
SELECT 'SECTION 15 | WHAT-IF SCENARIOS' AS Section;

CREATE OR REPLACE VIEW v_WhatIf AS
SELECT Scenario, Assumption, ExtraGrossProfit_6M, ROUND(ExtraGrossProfit_6M * 2) AS ExtraGrossProfit_Year,
       CASE WHEN ExtraGrossProfit_6M >= 1000 THEN 'DO IT - clear gain' WHEN ExtraGrossProfit_6M > 0 THEN 'Small gain' ELSE 'DO NOT DO - loses profit' END AS Verdict
FROM (
    SELECT 'A. Raise price by 5% on the 5 best sellers' AS Scenario, 'Demand falls 3% (elasticity -0.6)' AS Assumption,
           ROUND(SUM(Rev * 0.0185 + Cost * 0.03)) AS ExtraGrossProfit_6M
    FROM (SELECT SUM(NetRevenue) AS Rev, SUM(CostAmount) AS Cost FROM v_FactLines GROUP BY ProductID ORDER BY Rev DESC LIMIT 5) t
    UNION ALL
    SELECT 'B. Halve all discounts', '15% of the discounted volume is lost',
           ROUND(0.85 * SUM(DiscountAmount) / 2 - 0.15 * SUM(NetRevenue - CostAmount)) FROM v_FactLines WHERE Discount > 0
    UNION ALL
    SELECT 'C. Win back 25% of at-risk loyalty customers', 'They return for 3 months at their past monthly spend',
           ROUND(0.25 * SUM(Monetary) / 6 * 3 * (SELECT SUM(NetRevenue - CostAmount) / SUM(NetRevenue) FROM v_FactLines)) FROM v_CardRFM WHERE Segment LIKE '3%'
    UNION ALL
    SELECT 'D. Put food in 7 more orders out of every 100', 'Combo offers and counter display; average food profit per order',
           ROUND((SELECT COUNT(*) FROM v_FactOrders) * 0.07 * (SELECT SUM(NetRevenue - CostAmount) / COUNT(DISTINCT OrderID) FROM v_FactLines WHERE Category IN ('Dessert', 'Snack')))
    UNION ALL
    (SELECT 'E. Negotiate 5% lower cost with the largest supplier', 'Same volume at a lower unit cost', ROUND(0.05 * Cogs) FROM v_SupplierScore ORDER BY CogsSharePct DESC LIMIT 1)
) x;
SELECT * FROM v_WhatIf ORDER BY ExtraGrossProfit_6M DESC;


-- ============================================================================
-- 16. DATA AUDIT AND GOVERNANCE
-- What a good analyst checks before the numbers go to the board
-- ============================================================================
SELECT 'SECTION 16 | DATA AUDIT AND GOVERNANCE' AS Section;

SELECT CheckName, IssueCount, IF(IssueCount = 0, 'PASS', 'REVIEW') AS Result, WhyItMatters FROM (
    SELECT 'Orders taken before the employee was hired' AS CheckName, COUNT(*) AS IssueCount, 'Wrong employee or wrong hire date: sales credited to the wrong person' AS WhyItMatters
    FROM Orders o JOIN Employees e ON e.EmployeeID = o.EmployeeID WHERE o.OrderDate < e.HireDate
    UNION ALL SELECT 'Orders with no employee', COUNT(*), 'Staff performance cannot be measured for these sales'
    FROM Orders WHERE EmployeeID IS NULL AND OrderDate >= '2025-10-01' AND OrderDate < '2026-04-01'
    UNION ALL SELECT 'Salary more than 2x the average of the same role', COUNT(*), 'Possible typo or unapproved pay: review the payroll file'
    FROM Employees e WHERE Salary > 2 * (SELECT AVG(x.Salary) FROM Employees x WHERE x.Role = e.Role)
    UNION ALL SELECT 'Employees sharing the same full name', COUNT(*), 'Risk of mixing two people in reports: always report by EmployeeID'
    FROM (SELECT 1 FROM Employees GROUP BY FirstName, LastName HAVING COUNT(*) > 1) t
    UNION ALL SELECT 'Attendance records without a clock-out', COUNT(*), 'Hours worked are understated: remind staff to clock out'
    FROM Attendance WHERE CheckOutTime IS NULL
    UNION ALL SELECT 'Orders that were never completed', COUNT(*), 'Revenue lost or orders not closed correctly'
    FROM Orders WHERE IsCompleted = FALSE AND OrderDate >= '2025-10-01' AND OrderDate < '2026-04-01'
    UNION ALL SELECT 'Loyalty cards that never bought anything', COUNT(*), 'Cards issued but unused: activation campaign opportunity'
    FROM LoyaltyCards c WHERE NOT EXISTS (SELECT 1 FROM Orders o WHERE o.LoyaltyCardID = c.CardID)
    UNION ALL SELECT 'Products with no sales in the last 30 days', COUNT(*), 'Dead stock or a menu item nobody wants'
    FROM v_StockCover WHERE UnitsPerDay = 0
    UNION ALL SELECT 'Products priced below their cost', COUNT(*), 'Every sale loses money'
    FROM Products WHERE Price < Cost
    UNION ALL SELECT 'Completed orders without a payment', COUNT(*), 'Revenue not backed by cash'
    FROM Orders o LEFT JOIN Payments p ON p.OrderID = o.OrderID WHERE o.IsCompleted = TRUE AND p.PaymentID IS NULL
    UNION ALL SELECT 'Payments that differ from the order total', COUNT(*), 'Cash reconciliation problem'
    FROM Payments p JOIN Orders o ON o.OrderID = p.OrderID WHERE p.Amount <> o.TotalAmount
    UNION ALL SELECT 'Order totals that are zero', COUNT(*), 'Orders without lines distort order counts'
    FROM Orders WHERE TotalAmount = 0
    UNION ALL SELECT 'Expired stock still on the shelf', COUNT(*), 'Food safety and waste'
    FROM Products WHERE ExpirationDate < '2026-03-31' AND StockQuantity > 0
    UNION ALL SELECT 'Sales outside opening hours (before 06:00)', COUNT(*), 'Wrong timestamps or unauthorised trading'
    FROM Orders WHERE HOUR(OrderDate) < 6
) a ORDER BY Result DESC, IssueCount DESC;


-- ============================================================================
-- 17. EXECUTIVE FINDINGS AND ACTION PLAN
-- The story for the board, calculated from the data (open the meeting with this section)
-- ============================================================================
SELECT 'SECTION 17 | EXECUTIVE FINDINGS AND ACTION PLAN' AS Section;

-- 17.1 Executive findings
SELECT n AS No, Finding FROM (
    SELECT 1 AS n, (SELECT CONCAT('GROWTH: revenue rose ', ROUND(100 * (q1.r / q4.r - 1), 1), '% from Q4 2025 (AED ', FORMAT(q4.r, 0), ') to Q1 2026 (AED ', FORMAT(q1.r, 0),
           '). Per trading day the rise is ', ROUND(100 * ((q1.r / q1.d) / (q4.r / q4.d) - 1), 1), '%.')
           FROM (SELECT SUM(TotalAmount) AS r, COUNT(DISTINCT SaleDate) AS d FROM v_FactOrders WHERE SaleDate < '2026-01-01') q4,
                (SELECT SUM(TotalAmount) AS r, COUNT(DISTINCT SaleDate) AS d FROM v_FactOrders WHERE SaleDate >= '2026-01-01') q1) AS Finding
    UNION ALL SELECT 2, (SELECT CONCAT('PROFIT: net profit is AED ', FORMAT(SUM(NetProfit), 0), ' over six months, a net margin of ', ROUND(100 * SUM(NetProfit) / SUM(Revenue), 1),
           '%. Gross margin is ', ROUND(100 * SUM(GrossProfit) / SUM(Revenue), 1), '%; payroll takes ', ROUND(100 * SUM(Payroll) / SUM(Revenue), 1), '% and other expenses ',
           ROUND(100 * SUM(OtherOpex) / SUM(Revenue), 1), '% of revenue.') FROM v_Monthly_PnL)
    UNION ALL SELECT 3, (SELECT CONCAT('TARGETS: the revenue target was met in ', SUM(p.Revenue >= t.TargetRevenue), ' of ', COUNT(*), ' months (', ROUND(100 * SUM(p.Revenue) / SUM(t.TargetRevenue), 1),
           '% of the six-month target); weakest month: ', (SELECT p2.Month FROM v_Monthly_PnL p2 JOIN Sales_Targets t2 ON DATE_FORMAT(t2.TargetMonth, '%Y-%m') = p2.Month ORDER BY p2.Revenue / t2.TargetRevenue LIMIT 1), '.')
           FROM v_Monthly_PnL p JOIN Sales_Targets t ON DATE_FORMAT(t.TargetMonth, '%Y-%m') = p.Month)
    UNION ALL SELECT 4, (SELECT CONCAT('DEMAND PATTERN: ', b.DayName, ' is the strongest day (AED ', FORMAT(b.a, 0), ' on average) and ', w.DayName, ' the weakest (AED ', FORMAT(w.a, 0), ').')
           FROM (SELECT DayName, AVG(r) AS a FROM (SELECT SaleDate, DayName, SUM(TotalAmount) AS r FROM v_FactOrders GROUP BY SaleDate, DayName) x GROUP BY DayName ORDER BY a DESC LIMIT 1) b,
                (SELECT DayName, AVG(r) AS a FROM (SELECT SaleDate, DayName, SUM(TotalAmount) AS r FROM v_FactOrders GROUP BY SaleDate, DayName) x GROUP BY DayName ORDER BY a LIMIT 1) w)
    UNION ALL SELECT 5, (SELECT CONCAT('PEAK HOURS: the busiest hour is ', LPAD(SaleHour, 2, '0'), ':00 with ', ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM v_FactOrders), 1), '% of all orders.')
           FROM v_FactOrders GROUP BY SaleHour ORDER BY COUNT(*) DESC LIMIT 1)
    UNION ALL SELECT 6, (SELECT CONCAT('MENU: ', t.ProductName, ' is the top seller (', ROUND(100 * t.r / tot.r, 1), '% of revenue). The top 3 products bring ',
           ROUND(100 * (SELECT SUM(r) FROM (SELECT SUM(NetRevenue) AS r FROM v_FactLines GROUP BY ProductID ORDER BY r DESC LIMIT 3) z) / tot.r, 1), '% of revenue.')
           FROM (SELECT ProductName, SUM(NetRevenue) AS r FROM v_FactLines GROUP BY ProductID, ProductName ORDER BY r DESC LIMIT 1) t,
                (SELECT SUM(NetRevenue) AS r FROM v_FactLines) tot)
    UNION ALL SELECT 7, (SELECT CONCAT('MENU ENGINEERING: stars are ', IFNULL(GROUP_CONCAT(ProductName ORDER BY Profit DESC SEPARATOR ', '), 'none'), '.') FROM v_MenuMatrix WHERE Action LIKE 'STAR%')
    UNION ALL SELECT 8, (SELECT CONCAT('RAMADAN: revenue per day moved ', ROUND(100 * (r.v / p.v - 1), 1), '% against the four weeks before; orders after 7 pm rose from ',
           p.e, '% to ', r.e, '% of the day.')
           FROM (SELECT SUM(TotalAmount) / COUNT(DISTINCT SaleDate) AS v, ROUND(100 * AVG(SaleHour >= 19), 1) AS e FROM v_FactOrders WHERE SaleDate BETWEEN '2026-01-21' AND '2026-02-17') p,
                (SELECT SUM(TotalAmount) / COUNT(DISTINCT SaleDate) AS v, ROUND(100 * AVG(SaleHour >= 19), 1) AS e FROM v_FactOrders WHERE SaleDate BETWEEN '2026-02-18' AND '2026-03-19') r)
    UNION ALL SELECT 9, (SELECT CONCAT('PRICE RISE (+1 AED, 1 Jan): units per day of the three raised drinks changed ', ROUND(100 * (a1 / b1 - 1), 1), '% while the control drinks changed ',
           ROUND(100 * (a2 / b2 - 1), 1), '%, a relative effect of ', ROUND(100 * ((a1 / b1) / (a2 / b2) - 1), 1), '%. Revenue per unit rose by about AED 1.')
           FROM (SELECT SUM(IF(ProductName IN ('Cappuccino', 'Latte', 'Mocha') AND SaleDate < '2026-01-01', Quantity, 0)) AS b1,
                        SUM(IF(ProductName IN ('Cappuccino', 'Latte', 'Mocha') AND SaleDate >= '2026-01-01', Quantity, 0)) AS a1,
                        SUM(IF(ProductName IN ('Espresso', 'Americano', 'Green Tea') AND SaleDate < '2026-01-01', Quantity, 0)) AS b2,
                        SUM(IF(ProductName IN ('Espresso', 'Americano', 'Green Tea') AND SaleDate >= '2026-01-01', Quantity, 0)) AS a2
                 FROM v_FactLines WHERE SaleDate BETWEEN '2025-12-04' AND '2026-01-28') t)
    UNION ALL SELECT 10, (SELECT CONCAT('PROMOTION (15 percent off cakes): volume changed ', ROUND(100 * (u2 / u1 - 1)), '% and profit per day changed AED ', ROUND(p2 - p1, 1),
           ' per day; verdict: ', IF(p2 > p1, 'it paid for itself.', 'it lost money.'))
           FROM (SELECT SUM(IF(SaleDate BETWEEN '2025-12-27' AND '2026-01-09', Quantity, 0)) / 14 AS u1, SUM(IF(SaleDate BETWEEN '2026-01-10' AND '2026-01-24', Quantity, 0)) / 15 AS u2,
                        SUM(IF(SaleDate BETWEEN '2025-12-27' AND '2026-01-09', NetRevenue - CostAmount, 0)) / 14 AS p1,
                        SUM(IF(SaleDate BETWEEN '2026-01-10' AND '2026-01-24', NetRevenue - CostAmount, 0)) / 15 AS p2
                 FROM v_FactLines WHERE ProductName IN ('Cheesecake', 'Chocolate Cake', 'Brownie')) t)
    UNION ALL SELECT 11, (SELECT CONCAT('BASKET: the strongest pairing is ', pa.ProductName, ' with ', pb.ProductName, ' (lift ', ROUND((Together / Total) / ((ca / Total) * (cb / Total)), 1),
           '). ', ROUND(100 * (SELECT COUNT(DISTINCT OrderID) FROM v_FactLines WHERE Category IN ('Dessert', 'Snack')) / Total, 1), '% of orders include food.')
           FROM (SELECT a.ProductID AS A, b.ProductID AS B, COUNT(*) AS Together
                 FROM (SELECT DISTINCT OrderID, ProductID FROM v_FactLines) a JOIN (SELECT DISTINCT OrderID, ProductID FROM v_FactLines) b ON a.OrderID = b.OrderID AND a.ProductID < b.ProductID
                 GROUP BY a.ProductID, b.ProductID HAVING COUNT(*) >= 100) pr
           JOIN (SELECT COUNT(DISTINCT OrderID) AS Total FROM v_FactLines) n
           JOIN (SELECT ProductID, COUNT(DISTINCT OrderID) AS ca FROM v_FactLines GROUP BY ProductID) x ON x.ProductID = pr.A
           JOIN (SELECT ProductID, COUNT(DISTINCT OrderID) AS cb FROM v_FactLines GROUP BY ProductID) y ON y.ProductID = pr.B
           JOIN Products pa ON pa.ProductID = pr.A JOIN Products pb ON pb.ProductID = pr.B
           ORDER BY (Together / Total) / ((ca / Total) * (cb / Total)) DESC LIMIT 1)
    UNION ALL SELECT 12, (SELECT CONCAT('LOYALTY: ', ROUND(100 * AVG(LoyaltyCardID IS NOT NULL), 1), '% of orders carry a card. Champions are ', (SELECT COUNT(*) FROM v_CardRFM WHERE Segment = '1 Champions'),
           ' cards and bring ', (SELECT ROUND(100 * SUM(IF(Segment = '1 Champions', Monetary, 0)) / SUM(Monetary)) FROM v_CardRFM), '% of loyalty revenue; ',
           (SELECT COUNT(*) FROM v_CardRFM WHERE Segment LIKE '3%'), ' good customers are at risk of leaving.') FROM v_FactOrders)
    UNION ALL SELECT 13, (SELECT CONCAT('SATISFACTION: customers rate the shop ', ROUND(AVG(r.Rating), 2), ' out of 5 (', COUNT(*), ' reviews, ', ROUND(100 * AVG(r.Rating >= 4)), '% positive). Rush hour (07-09) scores ',
           ROUND(AVG(IF(o.SaleHour BETWEEN 7 AND 9, r.Rating, NULL)), 2), ' against ', ROUND(AVG(IF(o.SaleHour NOT BETWEEN 7 AND 9, r.Rating, NULL)), 2), ' for the rest of the day; weakest product: ',
           (SELECT l.ProductName FROM Customer_Reviews r2 JOIN v_FactLines l ON l.OrderID = r2.OrderID GROUP BY l.ProductID, l.ProductName HAVING COUNT(*) >= 25 ORDER BY AVG(r2.Rating) LIMIT 1), '.')
           FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID)
    UNION ALL SELECT 14, (SELECT CONCAT('PAYMENTS: cash fell from ', ROUND(100 * SUM(IF(SaleMonth = '2025-10' AND PaymentType = 'Cash', TotalAmount, 0)) / SUM(IF(SaleMonth = '2025-10', TotalAmount, 0)), 1),
           '% of revenue in October to ', ROUND(100 * SUM(IF(SaleMonth = '2026-03' AND PaymentType = 'Cash', TotalAmount, 0)) / SUM(IF(SaleMonth = '2026-03', TotalAmount, 0)), 1), '% in March.') FROM v_FactOrders)
    UNION ALL SELECT 15, (SELECT CONCAT('LEAKAGE: ', COUNT(*) - SUM(IsCompleted), ' orders (AED ', FORMAT(SUM(IF(IsCompleted = FALSE, TotalAmount, 0)), 0), ') were never completed, ',
           ROUND(100 * (1 - AVG(IsCompleted)), 1), '% of all orders.') FROM Orders WHERE OrderDate >= '2025-10-01' AND OrderDate < '2026-04-01')
    UNION ALL SELECT 16, (SELECT CONCAT('BREAK-EVEN: in March payroll was ', ROUND(100 * Payroll / Revenue, 1), '% of revenue; with all expenses the shop needs about AED ',
           FORMAT((Payroll + OtherOpex) / (GrossMarginPct / 100) / Days, 0), ' per day to break even against AED ', FORMAT(Revenue / Days, 0), ' achieved.') FROM v_Monthly_PnL WHERE Month = '2026-03')
    UNION ALL SELECT 17, (SELECT CONCAT('INVENTORY: ', SUM(StockStatus = 'REORDER NOW'), ' products have less than 5 days of stock (', IFNULL(GROUP_CONCAT(IF(StockStatus = 'REORDER NOW', ProductName, NULL) SEPARATOR ', '), '-'),
           '); AED ', FORMAT(SUM(AtRiskUnits * Cost), 0), ' of perishable stock is at risk of expiring unsold.') FROM v_StockCover)
    UNION ALL SELECT 18, (SELECT CONCAT('SUPPLIERS: ', Supplier, ' supplies ', CogsSharePct, '% of the cost of goods sold.') FROM v_SupplierScore ORDER BY CogsSharePct DESC LIMIT 1)
    UNION ALL SELECT 19, (SELECT CONCAT('ANOMALIES: ', COUNT(*), ' days broke the weekday pattern; ', SUM(KnownEvent LIKE 'No known cause%'), ' of them have no known cause and need investigation.') FROM v_Anomalies)
    UNION ALL SELECT 20, (SELECT CONCAT('BEST WHAT-IF: ', Scenario, ' adds about AED ', FORMAT(ExtraGrossProfit_Year, 0), ' of gross profit per year.') FROM v_WhatIf ORDER BY ExtraGrossProfit_6M DESC LIMIT 1)
    UNION ALL SELECT 21, (SELECT CONCAT('OUTLOOK: the trend model expects about AED ', FORMAT(ForecastRevenue, 0), ' in the week of ', WeekStart, ' (range ', FORMAT(LowEnd, 0), ' to ', FORMAT(HighEnd, 0),
           '), with weekly growth of about AED ', FORMAT(TrendPerWeek, 0), '.') FROM v_WeeklyForecast ORDER BY WeekStart LIMIT 1)
) f ORDER BY n;

-- 17.2 Action plan for the next 30 days (each action carries its evidence)
SELECT n AS No, Priority, Action, Evidence FROM (
    SELECT 1 AS n, 'HIGH' AS Priority, 'Protect availability of best sellers' AS Action,
           (SELECT CONCAT('Under 5 days of stock: ', IFNULL(GROUP_CONCAT(ProductName SEPARATOR ', '), 'none'), '; budget AED ', FORMAT(IFNULL(SUM(ReorderQty14Days * Cost), 0), 0), ' for 14 days of cover.')
            FROM v_StockCover WHERE StockStatus = 'REORDER NOW') AS Evidence
    UNION ALL SELECT 2, 'HIGH', 'Sell or bundle short-life items before they expire',
           (SELECT CONCAT('At risk of expiring unsold: ', IFNULL(GROUP_CONCAT(ProductName SEPARATOR ', '), 'none'), ' (AED ', FORMAT(IFNULL(SUM(AtRiskUnits * Cost), 0), 0), ' at cost).') FROM v_StockCover WHERE AtRiskUnits > 0)
    UNION ALL SELECT 3, 'HIGH', 'Launch a win-back campaign for valuable lapsed loyalty members',
           (SELECT CONCAT(COUNT(*), ' at-risk cards worth AED ', FORMAT(IFNULL(SUM(Monetary), 0), 0), ' of past spend; winning back 25% adds about AED ',
                          FORMAT((SELECT ExtraGrossProfit_6M FROM v_WhatIf WHERE Scenario LIKE 'C.%'), 0), ' of gross profit.') FROM v_CardRFM WHERE Segment LIKE '3%')
    UNION ALL SELECT 4, 'HIGH', 'Staff the peak and speed up rush-hour service',
           (SELECT CONCAT('Busiest hour ', LPAD(MAX(h.SaleHour), 2, '0'), ':00; ratings at 07-09 are ', ROUND(AVG(IF(o.SaleHour BETWEEN 7 AND 9, r.Rating, NULL)), 2), ' against ',
                          ROUND(AVG(IF(o.SaleHour NOT BETWEEN 7 AND 9, r.Rating, NULL)), 2), ' for the rest of the day, with speed the main complaint.')
            FROM Customer_Reviews r JOIN v_FactOrders o ON o.OrderID = r.OrderID,
                 (SELECT SaleHour FROM v_FactOrders GROUP BY SaleHour ORDER BY COUNT(*) DESC LIMIT 1) h)
    UNION ALL SELECT 5, 'MEDIUM', 'Raise price or cut cost on popular low-margin items',
           (SELECT CONCAT(IFNULL(GROUP_CONCAT(ProductName SEPARATOR ', '), 'none'), '. For comparison, scenario A (5% rise on the 5 best sellers) adds about AED ', FORMAT((SELECT ExtraGrossProfit_Year FROM v_WhatIf WHERE Scenario LIKE 'A.%'), 0), ' per year.')
            FROM v_MenuMatrix WHERE Action LIKE 'PLOWHORSE%')
    UNION ALL SELECT 6, 'MEDIUM', 'Rework or drop the DOG items on the menu',
           (SELECT CONCAT('Low sales and low profit per unit: ', IFNULL(GROUP_CONCAT(ProductName SEPARATOR ', '), 'none'), '.') FROM v_MenuMatrix WHERE Action LIKE 'DOG%')
    UNION ALL SELECT 7, 'MEDIUM', 'Fix punctuality at the top of the late list',
           (SELECT CONCAT(CONCAT(Employee, ' (#', EmployeeID, ')'), ' is on time in only ', OnTimePct, '% of shifts; average delay ', AvgMinutesWhenLate, ' minutes when late.') FROM v_AttendanceQuality ORDER BY OnTimePct LIMIT 1)
    UNION ALL SELECT 8, 'MEDIUM', 'Review the salary outlier',
           (SELECT IFNULL((SELECT CONCAT(e.FirstName, ' ', e.LastName, ' (#', e.EmployeeID, ') earns AED ', FORMAT(e.Salary, 0), ' while the average for ', e.Role, ' is AED ',
                           FORMAT((SELECT AVG(x.Salary) FROM Employees x WHERE x.Role = e.Role), 0), '.')
                           FROM Employees e ORDER BY e.Salary / (SELECT AVG(x.Salary) FROM Employees x WHERE x.Role = e.Role) DESC LIMIT 1), 'No outlier found.'))
    UNION ALL SELECT 9, 'MEDIUM', 'Reduce dependence on the largest supplier',
           (SELECT CONCAT(Supplier, ' supplies ', CogsSharePct, '% of cost of goods; a 5% better price would add about AED ', FORMAT((SELECT ExtraGrossProfit_Year FROM v_WhatIf WHERE Scenario LIKE 'E.%'), 0), ' per year.')
            FROM v_SupplierScore ORDER BY CogsSharePct DESC LIMIT 1)
    UNION ALL SELECT 10, 'MEDIUM', 'Investigate the lowest-rated product',
           (SELECT CONCAT(l.ProductName, ' has the weakest rating (', ROUND(AVG(r.Rating), 2), ' from ', COUNT(*), ' reviews): check recipe, freshness and supplier.')
            FROM Customer_Reviews r JOIN v_FactLines l ON l.OrderID = r.OrderID GROUP BY l.ProductID, l.ProductName HAVING COUNT(*) >= 25 ORDER BY AVG(r.Rating) LIMIT 1)
    UNION ALL SELECT 11, 'LOW', 'Close the leakage of unfinished orders',
           (SELECT CONCAT(COUNT(*) - SUM(IsCompleted), ' orders worth AED ', FORMAT(SUM(IF(IsCompleted = FALSE, TotalAmount, 0)), 0), ' were never completed; add a daily close-out check.')
            FROM Orders WHERE OrderDate >= '2025-10-01' AND OrderDate < '2026-04-01')
    UNION ALL SELECT 12, 'LOW', 'Plan evening shifts for the next Ramadan',
           (SELECT CONCAT(ROUND(100 * AVG(SaleHour >= 19), 1), '% of Ramadan orders came after 7 pm against ', (SELECT ROUND(100 * AVG(SaleHour >= 19), 1) FROM v_FactOrders WHERE SaleDate BETWEEN '2026-01-21' AND '2026-02-17'), '% normally.')
            FROM v_FactOrders WHERE SaleDate BETWEEN '2026-02-18' AND '2026-03-19')
    UNION ALL SELECT 13, 'LOW', 'Reset monthly targets using the seasonal pattern',
           (SELECT CONCAT('Targets were missed in ', SUM(p.Revenue < t.TargetRevenue), ' of ', COUNT(*), ' months; Ramadan and weekday patterns should be built into the target.')
            FROM v_Monthly_PnL p JOIN Sales_Targets t ON DATE_FORMAT(t.TargetMonth, '%Y-%m') = p.Month)
) a ORDER BY n;

-- ============================================================================
-- END OF ANALYSIS
-- ============================================================================
SELECT 'Executive analysis completed' AS Status;
SET SQL_SAFE_UPDATES = 1;
