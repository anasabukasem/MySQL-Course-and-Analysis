-- ============================================================================
--                    COFFEE SHOP  |  COMPLETE MySQL COURSE
--          One script: from creating the database to advanced topics
--                  Tested on MySQL 8.0 (run top to bottom)
-- ============================================================================
--  CONTENTS
--   1   Database                      13  Set Operators (UNION, INTERSECT, EXCEPT)
--   2   Tables, Data Types, Keys      14  Window Functions
--   3   ALTER TABLE                   15  CTE (WITH) and Recursive CTE
--   4   INSERT and Sample Data        16  UPDATE and DELETE
--   5   SELECT                        17  Transactions and Locking
--   6   WHERE and Operators           18  Copying Tables and Advanced INSERT
--   7   ORDER BY, LIMIT, DISTINCT     19  Views
--   8   Functions                     20  Indexes and EXPLAIN
--   9   Aggregate Functions           21  Variables and Prepared Statements
--  10   GROUP BY and HAVING           22  Stored Procedures, Functions, Cursors
--  11   Subqueries                    23  Triggers and Events
--  12   JOINS                         24  Users, Privileges, Backup, Metadata
--                                     25  Final Practice: Business Reports
-- ============================================================================


-- ============================================================================
-- 1. DATABASE
-- Create, show, use, alter, rename and drop databases
-- ============================================================================

-- 1.1 Fresh start
-- Removes the database if it exists so the whole script can be re-run
DROP DATABASE IF EXISTS CoffeeShop;

-- 1.2 CREATE DATABASE
-- IF NOT EXISTS skips the command when the database is already there
CREATE DATABASE IF NOT EXISTS CoffeeShop
CHARACTER SET = utf8mb4
COLLATE = utf8mb4_unicode_ci;

-- 1.3 SHOW DATABASES
SHOW DATABASES;
SHOW SCHEMAS;
SHOW CREATE DATABASE CoffeeShop;

-- 1.4 USE
-- Every command after USE runs inside that database
USE CoffeeShop;
SELECT DATABASE();

-- Make the connection use the same character set and collation as the database
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 1.5 Working with several databases
CREATE DATABASE IF NOT EXISTS CandyShop;
CREATE DATABASE IF NOT EXISTS Supermarket;
SHOW DATABASES;

-- 1.6 DROP DATABASE
-- Deletes the database with everything inside it
DROP DATABASE Supermarket;
DROP DATABASE IF EXISTS Supermarket;

-- 1.7 Renaming a database
-- MySQL has no RENAME DATABASE: create a new one and move the tables
CREATE DATABASE IF NOT EXISTS SweetShop;
CREATE TABLE CandyShop.Candies (CandyID INT PRIMARY KEY, CandyName VARCHAR(50));
RENAME TABLE CandyShop.Candies TO SweetShop.Candies;
SHOW TABLES FROM SweetShop;
DROP DATABASE CandyShop;
DROP DATABASE SweetShop;

-- 1.8 ALTER DATABASE
ALTER DATABASE CoffeeShop CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- 1.9 Comments
# Hash comment
-- Double dash comment (a space is required after the dashes)
/* Multi-line comment
   ignored by MySQL */

-- 1.10 Naming rules
-- Max 64 characters, letters / digits / underscore only, no reserved words
-- A reserved word can be used only inside backticks, e.g. `order`

-- 1.11 Character set and collation
-- Character set = which characters can be stored (Arabic, emoji...)
-- Collation = how text is compared and sorted
SHOW CHARACTER SET LIKE 'utf8%';
SHOW COLLATION LIKE 'utf8mb4_unicode%';
SELECT 'a' = 'A';
SELECT 'a' = 'A' COLLATE utf8mb4_bin;

-- 1.12 Storage engines
SHOW ENGINES;


-- ============================================================================
-- 2. TABLES, DATA TYPES AND KEYS
-- Build the eight tables of the coffee shop
-- ============================================================================

-- 2.1 Data types overview
-- Numeric, text, date and time, binary, ENUM / SET, JSON
CREATE TABLE IF NOT EXISTS DataTypes_Demo (
    ID INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    TinyNum TINYINT,
    SmallNum SMALLINT,
    MediumNum MEDIUMINT,
    BigNum BIGINT,
    Price DECIMAL(10,2),
    Ratio FLOAT,
    Precise DOUBLE,
    Code CHAR(3),
    FullName VARCHAR(50),
    Notes TEXT,
    BirthDate DATE,
    StartTime TIME,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    BirthYear YEAR,
    IsActive BOOLEAN DEFAULT TRUE,
    Size ENUM('Small','Medium','Large') DEFAULT 'Medium',
    Extras SET('Sugar','Milk','Cinnamon','Ice'),
    Settings JSON,
    Photo BLOB
);
INSERT INTO DataTypes_Demo (TinyNum, SmallNum, MediumNum, BigNum, Price, Ratio, Precise, Code, FullName, Notes,
                            BirthDate, StartTime, BirthYear, Size, Extras, Settings)
VALUES (100, 30000, 8000000, 9000000000, 19.99, 1.5, 3.14159265358979, 'AE', 'Latte', 'Long text goes here',
        '2025-09-27', '08:30:00', 2025, 'Large', 'Sugar,Milk', '{"temperature": "hot", "shots": 2}');
SELECT * FROM DataTypes_Demo;
DESCRIBE DataTypes_Demo;
DROP TABLE DataTypes_Demo;

-- 2.2 CREATE TABLE
-- Columns, data types, constraints (NOT NULL, UNIQUE, CHECK, DEFAULT,
-- AUTO_INCREMENT), PRIMARY KEY, FOREIGN KEY with ON DELETE / ON UPDATE

-- 1) Employees
CREATE TABLE IF NOT EXISTS Employees (
    EmployeeID INT AUTO_INCREMENT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Role ENUM('Barista','Cashier','Manager','Cleaner','Other') NOT NULL,
    Email VARCHAR(100) UNIQUE,
    Phone VARCHAR(20) NOT NULL,
    HireDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Salary DECIMAL(10,2) NOT NULL CHECK (Salary >= 1000)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2) Attendance
CREATE TABLE IF NOT EXISTS Attendance (
    AttendanceID INT AUTO_INCREMENT PRIMARY KEY,
    EmployeeID INT NOT NULL,
    Date DATE NOT NULL DEFAULT (CURRENT_DATE),
    CheckInTime TIME NOT NULL,
    CheckOutTime TIME NULL,
    FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3) Suppliers
CREATE TABLE IF NOT EXISTS Suppliers (
    SupplierID INT AUTO_INCREMENT PRIMARY KEY,
    SupplierName VARCHAR(100) NOT NULL,
    CompanyName VARCHAR(100),
    Phone VARCHAR(20) NOT NULL,
    Email VARCHAR(100),
    ProductType VARCHAR(100) NOT NULL,
    Notes TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4) Products
CREATE TABLE IF NOT EXISTS Products (
    ProductID INT AUTO_INCREMENT PRIMARY KEY,
    ProductName VARCHAR(100) NOT NULL,
    Category ENUM('Drink','Dessert','Snack','Other') NOT NULL,
    SupplierID INT,
    Price DECIMAL(10,2) NOT NULL CHECK (Price > 0),
    Cost DECIMAL(10,2) CHECK (Cost >= 0),
    StockQuantity INT DEFAULT 0 CHECK (StockQuantity >= 0),
    ExpirationDate DATE,
    FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5) LoyaltyCards
CREATE TABLE IF NOT EXISTS LoyaltyCards (
    CardID INT AUTO_INCREMENT PRIMARY KEY,
    CardNumber VARCHAR(20) UNIQUE NOT NULL,
    Points INT DEFAULT 0 CHECK (Points >= 0),
    IssueDate DATE NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6) Orders
CREATE TABLE IF NOT EXISTS Orders (
    OrderID INT AUTO_INCREMENT PRIMARY KEY,
    EmployeeID INT,
    OrderDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    IsCompleted BOOLEAN DEFAULT FALSE,
    OrderType ENUM('Dine-in','Takeaway') DEFAULT 'Dine-in',
    LoyaltyCardID INT,
    TotalAmount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (TotalAmount >= 0),
    FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    FOREIGN KEY (LoyaltyCardID) REFERENCES LoyaltyCards(CardID)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7) Order_Details
CREATE TABLE IF NOT EXISTS Order_Details (
    OrderDetailID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT,
    Quantity INT NOT NULL DEFAULT 1 CHECK (Quantity > 0),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
    Discount DECIMAL(5,2) NOT NULL DEFAULT 0 CHECK (Discount >= 0),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8) Payments
CREATE TABLE IF NOT EXISTS Payments (
    PaymentID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT NOT NULL UNIQUE,
    PaymentType ENUM('Cash','Card','MobilePay') NOT NULL DEFAULT 'Cash',
    Amount DECIMAL(10,2) NOT NULL CHECK (Amount > 0),
    PaymentDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.3 Inspecting the structure
SHOW TABLES;
SHOW FULL TABLES;
DESCRIBE Employees;
DESC Orders;
SHOW COLUMNS FROM Payments;
SHOW CREATE TABLE Order_Details;
SHOW TABLE STATUS LIKE 'Orders';

-- 2.4 Relationships in this database
-- Employees  1:N Attendance     | Employees    1:N Orders
-- Suppliers  1:N Products       | LoyaltyCards 1:N Orders
-- Orders     1:N Order_Details  | Products     1:N Order_Details
-- Orders     1:1 Payments       | Orders / Products are M:N through Order_Details


-- ============================================================================
-- 3. ALTER TABLE
-- Change columns, constraints and table settings after creation
-- ============================================================================

-- 3.1 A practice table with deliberate problems
CREATE TABLE CustomerReviews (
    ReviewID INT,
    CustomerN VARCHAR(100),
    CustomerName INT,
    Comment TEXT
);

-- 3.2 ADD COLUMN
ALTER TABLE CustomerReviews ADD COLUMN Rating INT AFTER Comment;
ALTER TABLE CustomerReviews ADD COLUMN ReviewDate DATE NOT NULL DEFAULT (CURRENT_DATE) FIRST;

-- 3.3 DROP COLUMN
ALTER TABLE CustomerReviews DROP COLUMN CustomerName;

-- 3.4 MODIFY COLUMN
-- Changes the data type and constraints of a column
ALTER TABLE CustomerReviews MODIFY COLUMN CustomerN VARCHAR(200) NOT NULL;

-- 3.5 RENAME COLUMN
ALTER TABLE CustomerReviews RENAME COLUMN CustomerN TO CustomerName;

-- 3.6 CHANGE COLUMN
-- Rename and redefine a column in one command
ALTER TABLE CustomerReviews CHANGE COLUMN Comment ReviewText VARCHAR(500) NOT NULL;

-- 3.7 Several operations in one ALTER
ALTER TABLE CustomerReviews
    ADD COLUMN ProductID INT,
    MODIFY COLUMN Rating INT NOT NULL DEFAULT 5,
    DROP COLUMN ReviewDate;

-- 3.8 DEFAULT values
ALTER TABLE CustomerReviews ALTER COLUMN Rating SET DEFAULT 3;
ALTER TABLE CustomerReviews ALTER COLUMN Rating DROP DEFAULT;

-- 3.9 Constraints: ADD CONSTRAINT
-- Naming constraints makes them easy to drop later
ALTER TABLE CustomerReviews ADD CONSTRAINT PK_Review PRIMARY KEY (ReviewID);
ALTER TABLE CustomerReviews MODIFY ReviewID INT AUTO_INCREMENT;
ALTER TABLE CustomerReviews ADD CONSTRAINT UQ_Review_Text UNIQUE (ReviewText);
ALTER TABLE CustomerReviews ADD CONSTRAINT CHK_Rating CHECK (Rating BETWEEN 1 AND 5);
ALTER TABLE CustomerReviews
    ADD CONSTRAINT FK_Review_Product FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
        ON DELETE SET NULL
        ON UPDATE CASCADE;
SHOW CREATE TABLE CustomerReviews;

-- 3.10 Constraints: DROP
ALTER TABLE CustomerReviews DROP CONSTRAINT CHK_Rating;
ALTER TABLE CustomerReviews DROP FOREIGN KEY FK_Review_Product;
ALTER TABLE CustomerReviews DROP INDEX UQ_Review_Text;
ALTER TABLE CustomerReviews MODIFY ReviewID INT;
ALTER TABLE CustomerReviews DROP PRIMARY KEY;

-- 3.11 Table options
ALTER TABLE CustomerReviews AUTO_INCREMENT = 100;
ALTER TABLE CustomerReviews ENGINE = InnoDB;
ALTER TABLE CustomerReviews DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- 3.12 RENAME TABLE
ALTER TABLE CustomerReviews RENAME TO Reviews;
RENAME TABLE Reviews TO CustomerReviews;

-- 3.13 DROP TABLE
DROP TABLE CustomerReviews;
DROP TABLE IF EXISTS CustomerReviews;


-- ============================================================================
-- 4. INSERT AND SAMPLE DATA
-- Fill the tables with realistic coffee shop data
-- ============================================================================

-- 4.1 INSERT with a column list
-- EmployeeID is AUTO_INCREMENT, so it is skipped
INSERT INTO Employees (FirstName, LastName, Role, Email, Phone, HireDate, Salary)
VALUES ('Abdullah', 'Mohammed', 'Barista', 'abdullah.m1@coffeeshop.ae', '0501110001', '2025-09-27 08:00:00', 3500.00);

-- 4.2 INSERT several rows at once
INSERT INTO Employees (FirstName, LastName, Role, Email, Phone, HireDate, Salary)
VALUES
('Ahmed', 'Alhashimi', 'Manager', 'ahmed.h@coffeeshop.ae', '0501110002', '2025-09-27 08:00:00', 8000.00),
('Sara', 'Alketbi', 'Cashier', 'sara.k@coffeeshop.ae', '0501110003', '2025-09-28 09:00:00', 2800.00),
('Khalid', 'Almansoori', 'Cleaner', NULL, '0501110004', '2025-10-01 07:30:00', 1800.00),
('Abdullah', 'Mohammed', 'Barista', 'abdullah.m2@coffeeshop.ae', '0501110005', '2025-09-27 08:30:00', 9000.00),
('Aisha', 'Alzaabi', 'Barista', 'aisha.z@coffeeshop.ae', '0501110006', '2025-10-05 08:00:00', 3300.00),
('Omar', 'Hassan', 'Cashier', NULL, '0501110007', '2025-10-10 08:00:00', 2700.00),
('Layla', 'Nasser', 'Barista', 'layla.n@coffeeshop.ae', '0501110008', '2025-10-15 08:00:00', 3100.00),
('Yousef', 'Alali', 'Other', 'yousef.a@coffeeshop.ae', '0501110009', '2025-11-01 10:00:00', 2000.00),
('Mariam', 'Alsuwaidi', 'Cashier', 'mariam.s@coffeeshop.ae', '0501110010', '2025-11-03 09:00:00', 2900.00);

-- 4.3 INSERT without a column list
-- Values must follow the exact column order; NULL lets AUTO_INCREMENT generate the ID
INSERT INTO Employees
VALUES (NULL, 'Ali', 'Almheiri', 'Barista', 'ali.m@coffeeshop.ae', '0501110011', '2025-12-01 09:00:00', 3000.00);

-- 4.4 INSERT ... SET
INSERT INTO Employees
SET FirstName = 'Noura', LastName = 'Alshamsi', Role = 'Cleaner',
    Email = 'noura.s@coffeeshop.ae', Phone = '0501110012',
    HireDate = '2026-01-10 07:30:00', Salary = 1900.00;

-- 4.5 Suppliers
INSERT INTO Suppliers (SupplierName, CompanyName, Phone, Email, ProductType, Notes)
VALUES
('Khalid Alnuaimi', 'Gulf Beans Trading', '0502220001', 'info@gulfbeans.ae', 'Coffee Beans', 'Delivers every Sunday'),
('Fatima Alhosani', 'Fresh Dairy Co', '0502220002', 'sales@freshdairy.ae', 'Dairy', 'Cold chain delivery'),
('Rashid Almarzooqi', 'Sweet Corner Bakery', '0502220003', NULL, 'Desserts', 'Fresh delivery before 7 AM'),
('Hamad Alsaadi', 'Tea House LLC', '0502220004', 'hamad@teahouse.ae', 'Tea and Syrups', NULL),
('Maitha Alqubaisi', 'Packaging Plus', '0502220005', 'orders@packplus.ae', 'Packaging', NULL);

-- 4.6 Products
INSERT INTO Products (ProductName, Category, SupplierID, Price, Cost, StockQuantity, ExpirationDate)
VALUES
('Espresso', 'Drink', 1, 10.00, 3.00, 200, NULL),
('Cappuccino', 'Drink', 1, 16.00, 5.00, 150, NULL),
('Latte', 'Drink', 1, 18.00, 5.50, 150, NULL),
('Americano', 'Drink', 1, 12.00, 3.50, 180, NULL),
('Mocha', 'Drink', 1, 20.00, 7.00, 100, NULL),
('Iced Latte', 'Drink', 2, 19.00, 6.50, 90, NULL),
('Green Tea', 'Drink', 4, 11.00, 2.50, 120, NULL),
('Hot Chocolate', 'Drink', 2, 15.00, 5.00, 80, NULL),
('Chocolate Cake', 'Dessert', 3, 22.00, 9.00, 25, '2025-11-10'),
('Cheesecake', 'Dessert', 3, 24.00, 10.00, 20, '2025-11-08'),
('Brownie', 'Dessert', 3, 14.00, 5.00, 40, '2025-11-12'),
('Croissant', 'Snack', 3, 9.00, 3.00, 50, '2025-11-05'),
('Chicken Sandwich', 'Snack', 3, 21.00, 9.50, 18, '2025-11-03'),
('Bottled Water', 'Other', 4, 3.00, 1.00, 300, '2026-06-01'),
('Coffee Beans 250g', 'Other', 1, 45.00, 28.00, 40, '2026-03-01'),
('Reusable Cup', 'Other', NULL, 30.00, 12.00, 0, NULL);

-- 4.7 LoyaltyCards
INSERT INTO LoyaltyCards (CardNumber, Points, IssueDate)
VALUES
('LC-1001', 120, '2025-09-30'),
('LC-1002', 45, '2025-10-02'),
('LC-1003', 0, '2025-10-05'),
('LC-1004', 300, '2025-10-07'),
('LC-1005', 10, '2025-10-12'),
('LC-1006', 0, '2025-10-20');

-- 4.8 Attendance
INSERT INTO Attendance (EmployeeID, Date, CheckInTime, CheckOutTime)
VALUES
(1, '2025-10-01', '07:55:00', '16:30:00'),
(3, '2025-10-01', '08:00:00', '16:00:00'),
(5, '2025-10-01', '08:05:00', '16:00:00'),
(6, '2025-10-01', '08:20:00', NULL),
(7, '2025-10-01', '08:35:00', '16:00:00'),
(10, '2025-10-01', '07:50:00', '16:00:00'),
(1, '2025-10-02', '08:00:00', '16:00:00'),
(3, '2025-10-02', '08:05:00', '16:00:00'),
(5, '2025-10-02', '08:20:00', '16:30:00'),
(6, '2025-10-02', '08:35:00', '16:00:00'),
(7, '2025-10-02', '07:50:00', '16:00:00'),
(10, '2025-10-02', '07:55:00', '16:30:00'),
(1, '2025-10-03', '08:05:00', '16:00:00'),
(3, '2025-10-03', '08:20:00', '16:30:00'),
(5, '2025-10-03', '08:35:00', '16:00:00'),
(6, '2025-10-03', '07:50:00', '16:00:00'),
(7, '2025-10-03', '07:55:00', '16:30:00'),
(10, '2025-10-03', '08:00:00', '16:00:00'),
(1, '2025-10-04', '08:20:00', '16:30:00'),
(3, '2025-10-04', '08:35:00', '16:00:00'),
(5, '2025-10-04', '07:50:00', '16:00:00'),
(6, '2025-10-04', '07:55:00', '16:30:00'),
(7, '2025-10-04', '08:00:00', '16:00:00'),
(10, '2025-10-04', '08:05:00', '16:00:00'),
(1, '2025-10-05', '08:35:00', '16:00:00'),
(3, '2025-10-05', '07:50:00', '16:00:00'),
(5, '2025-10-05', '07:55:00', '16:30:00'),
(6, '2025-10-05', '08:00:00', NULL),
(7, '2025-10-05', '08:05:00', '16:00:00'),
(10, '2025-10-05', '08:20:00', '16:30:00'),
(2, '2025-10-01', '08:00:00', '17:00:00'),
(2, '2025-10-02', '08:10:00', '17:00:00');

-- 4.9 Orders
-- TotalAmount is left at its DEFAULT (0) and calculated below
INSERT INTO Orders (EmployeeID, OrderDate, IsCompleted, OrderType, LoyaltyCardID)
VALUES
(3,  '2025-10-01 08:15:00', TRUE,  'Dine-in',  1),
(3,  '2025-10-01 09:40:00', TRUE,  'Takeaway', NULL),
(7,  '2025-10-01 13:05:00', TRUE,  'Dine-in',  2),
(10, '2025-10-02 08:50:00', TRUE,  'Takeaway', 1),
(3,  '2025-10-02 12:30:00', TRUE,  'Dine-in',  NULL),
(7,  '2025-10-03 10:10:00', TRUE,  'Takeaway', 4),
(10, '2025-10-03 16:45:00', TRUE,  'Dine-in',  NULL),
(3,  '2025-10-04 09:00:00', TRUE,  'Dine-in',  2),
(7,  '2025-10-04 18:20:00', TRUE,  'Takeaway', NULL),
(1,  '2025-10-05 11:11:00', TRUE,  'Dine-in',  5),
(10, '2025-10-05 15:30:00', TRUE,  'Takeaway', 4),
(3,  '2025-10-06 08:05:00', TRUE,  'Dine-in',  NULL),
(7,  '2025-10-06 14:25:00', FALSE, 'Takeaway', NULL),
(10, '2025-10-07 09:15:00', FALSE, 'Dine-in',  1),
(3,  '2025-10-07 17:00:00', TRUE,  'Takeaway', 5),
(NULL, '2025-10-07 19:30:00', TRUE, 'Dine-in', NULL),
(3,  '2025-11-02 10:00:00', TRUE,  'Dine-in',  3),
(7,  '2025-11-03 12:00:00', TRUE,  'Takeaway', NULL);

-- 4.10 Order_Details
-- Discount is a percentage (10.00 = 10 percent)
INSERT INTO Order_Details (OrderID, ProductID, Quantity, UnitPrice, Discount)
VALUES
(1, 3, 2, 18.00, 0),  (1, 12, 1, 9.00, 0),
(2, 1, 1, 10.00, 0),
(3, 2, 1, 16.00, 0),  (3, 10, 1, 24.00, 10.00),
(4, 4, 2, 12.00, 0),  (4, 12, 2, 9.00, 0),
(5, 13, 2, 21.00, 0), (5, 14, 2, 3.00, 0),  (5, 3, 2, 18.00, 0),
(6, 5, 1, 20.00, 0),  (6, 9, 1, 22.00, 5.00),
(7, 6, 2, 19.00, 0),
(8, 2, 2, 16.00, 0),  (8, 12, 2, 9.00, 0),
(9, 1, 3, 10.00, 0),
(10, 3, 1, 18.00, 0), (10, 9, 1, 22.00, 0), (10, 7, 1, 11.00, 0),
(11, 15, 1, 45.00, 10.00),
(12, 4, 1, 12.00, 0), (12, 12, 1, 9.00, 0),
(13, 8, 2, 15.00, 0),
(14, 3, 1, 18.00, 0), (14, 10, 1, 24.00, 0),
(15, 2, 2, 16.00, 0), (15, 13, 1, 21.00, 0),
(16, 5, 2, 20.00, 0), (16, 10, 2, 24.00, 15.00),
(17, 6, 1, 19.00, 0), (17, 3, 1, 18.00, 0),  (17, 14, 1, 3.00, 0),
(18, 1, 2, 10.00, 0), (18, 2, 1, 16.00, 0);

-- 4.11 Calculated data: order totals
-- Safe update mode (MySQL Workbench default) blocks UPDATE without a key in WHERE, so turn it off
SET SQL_SAFE_UPDATES = 0;
-- UPDATE with a correlated subquery (explained in sections 11 and 16)
UPDATE Orders
SET TotalAmount = (
    SELECT ROUND(SUM(Quantity * UnitPrice * (1 - Discount / 100)), 2)
    FROM Order_Details
    WHERE Order_Details.OrderID = Orders.OrderID
);

-- 4.12 Calculated data: payments
-- INSERT ... SELECT copies rows from a query; ELT picks a payment type by position
INSERT INTO Payments (OrderID, PaymentType, Amount, PaymentDate)
SELECT OrderID,
       ELT(1 + OrderID MOD 3, 'Cash', 'Card', 'MobilePay'),
       TotalAmount,
       OrderDate + INTERVAL 5 MINUTE
FROM Orders
WHERE IsCompleted = TRUE;

-- 4.13 Checking the data
SELECT COUNT(*) AS Employees FROM Employees;
SELECT COUNT(*) AS Orders FROM Orders;
SELECT COUNT(*) AS Payments FROM Payments;


-- ============================================================================
-- 5. SELECT
-- Read data from tables: columns, aliases, expressions
-- ============================================================================

-- 5.1 All columns
SELECT * FROM Employees;

-- 5.2 Specific columns
SELECT FirstName, Role, Salary FROM Employees;

-- 5.3 SELECT without a table
SELECT 1 + 1;
SELECT 'Hello Coffee Shop' AS Greeting;
SELECT NOW();

-- 5.4 Column alias (AS)
-- Quotes are required when the alias contains a space
SELECT FirstName AS Name, Salary AS 'Monthly Salary' FROM Employees;

-- 5.5 Table alias
SELECT e.FirstName, e.Role FROM Employees AS e;

-- 5.6 Calculated columns
SELECT ProductName, Price, Cost,
       Price - Cost AS Profit,
       ROUND((Price - Cost) / Price * 100, 1) AS ProfitPercent
FROM Products;
SELECT FirstName, Salary, Salary * 12 AS YearlySalary FROM Employees;

-- 5.7 Fully qualified names
SELECT Employees.FirstName FROM CoffeeShop.Employees;

-- 5.8 SELECT INTO a variable
SELECT MAX(Salary) INTO @TopSalary FROM Employees;
SELECT @TopSalary;

-- 5.9 Clause order of a SELECT statement
-- SELECT > FROM > JOIN > WHERE > GROUP BY > HAVING > WINDOW > ORDER BY > LIMIT
-- MySQL executes them in this logical order:
-- FROM > JOIN > WHERE > GROUP BY > HAVING > SELECT > DISTINCT > ORDER BY > LIMIT

-- 5.10 Types of SELECT (each one is covered in its own section)
-- Simple SELECT ............. section 5
-- Filtered SELECT (WHERE) ... section 6
-- Sorted / limited / DISTINCT section 7
-- SELECT with functions ..... section 8
-- Aggregate SELECT .......... sections 9 and 10
-- Subquery SELECT ........... section 11
-- Join SELECT ............... section 12
-- Compound SELECT (UNION) ... section 13
-- Window SELECT ............. section 14
-- CTE SELECT (WITH) ......... section 15
-- Locking SELECT ............ section 17
-- INSERT ... SELECT ......... section 18


-- ============================================================================
-- 6. WHERE AND OPERATORS
-- Filter rows with comparison, logical, range, list, pattern and NULL tests
-- ============================================================================

-- 6.1 Comparison operators
SELECT * FROM Employees WHERE Salary > 3000;
SELECT * FROM Employees WHERE Salary >= 3000;
SELECT * FROM Employees WHERE Salary < 3000;
SELECT * FROM Employees WHERE Salary <= 3000;
SELECT * FROM Employees WHERE Role = 'Barista';
SELECT * FROM Employees WHERE Role <> 'Barista';
SELECT * FROM Employees WHERE Role != 'Barista';

-- 6.2 Logical operators: AND
-- Every condition must be true
SELECT * FROM Employees WHERE Role = 'Barista' AND Salary >= 3200;

-- 6.3 Logical operators: OR
-- At least one condition must be true
SELECT * FROM Employees WHERE Role = 'Barista' OR Salary >= 3000;

-- 6.4 Logical operators: XOR
-- Exactly one condition must be true
SELECT * FROM Employees WHERE Role = 'Barista' XOR Salary >= 3200;

-- 6.5 Logical operators: NOT
SELECT * FROM Employees WHERE NOT Role = 'Barista';
SELECT * FROM Employees WHERE Role = 'Barista' AND NOT Salary > 3300;

-- 6.6 Parentheses and precedence
-- AND is evaluated before OR
SELECT * FROM Employees WHERE Role = 'Barista' OR Role = 'Cashier' AND Salary > 3000;
SELECT * FROM Employees WHERE (Role = 'Barista' OR Role = 'Cashier') AND Salary > 3000;

-- 6.7 BETWEEN
-- Inclusive range for numbers, dates and text
SELECT * FROM Employees WHERE Salary BETWEEN 2000 AND 3500;
SELECT * FROM Employees WHERE Salary NOT BETWEEN 2000 AND 3500;
SELECT * FROM Orders WHERE OrderDate BETWEEN '2025-10-01' AND '2025-10-03 23:59:59';

-- 6.8 IN
-- Replaces many OR conditions
SELECT * FROM Employees WHERE Role IN ('Manager', 'Cashier', 'Barista');
SELECT * FROM Employees WHERE Role NOT IN ('Cleaner', 'Other');
SELECT * FROM Products WHERE ProductID IN (1, 3, 5);

-- 6.9 LIKE
-- % = any number of characters, _ = exactly one character
SELECT * FROM Employees WHERE FirstName LIKE 'A%';
SELECT * FROM Employees WHERE FirstName LIKE '%ah%';
SELECT * FROM Employees WHERE FirstName LIKE '%a';
SELECT * FROM Employees WHERE FirstName LIKE '_a%';
SELECT * FROM Employees WHERE FirstName LIKE '____';
SELECT * FROM Employees WHERE FirstName NOT LIKE 'A%';
SELECT * FROM Employees WHERE Email LIKE '%.m1@%' ESCAPE '|';
SELECT * FROM Products WHERE ProductName LIKE '%Latte%';

-- 6.10 REGEXP
-- Regular expression search
SELECT * FROM Employees WHERE FirstName REGEXP '^(Ab|Al)';
SELECT * FROM Employees WHERE LastName REGEXP 'i$';
SELECT * FROM Employees WHERE FirstName REGEXP '[xyz]';
SELECT * FROM Employees WHERE REGEXP_LIKE(Email, '^[a-z]+\\.[a-z]+@');

-- 6.11 NULL handling
-- NULL is not a value: = NULL never works, use IS NULL
SELECT * FROM Employees WHERE Email IS NULL;
SELECT * FROM Employees WHERE Email IS NOT NULL;
SELECT * FROM Employees WHERE Email = NULL;
SELECT NULL = NULL, NULL <=> NULL, 1 <=> NULL;
SELECT * FROM Products WHERE SupplierID IS NULL;
SELECT * FROM Orders WHERE EmployeeID IS NULL;

-- 6.12 Boolean columns
SELECT * FROM Orders WHERE IsCompleted = TRUE;
SELECT * FROM Orders WHERE IsCompleted IS FALSE;
SELECT TRUE, FALSE, TRUE + TRUE;

-- 6.13 Filtering dates
SELECT * FROM Orders WHERE DATE(OrderDate) = '2025-10-01';
SELECT * FROM Orders WHERE OrderDate >= '2025-10-05' AND OrderDate < '2025-10-06';
SELECT * FROM Orders WHERE MONTH(OrderDate) = 11 AND YEAR(OrderDate) = 2025;
SELECT * FROM Products WHERE ExpirationDate < '2025-11-06';

-- 6.14 Arithmetic operators
SELECT 10 + 3, 10 - 3, 10 * 3, 10 / 3, 10 DIV 3, 10 % 3, 10 MOD 3;
SELECT ProductName, Price, Price * 1.05 AS PriceWithTax FROM Products;
SELECT * FROM Products WHERE Price - Cost > 10;

-- 6.15 Bitwise operators
SELECT 5 & 3, 5 | 3, 5 ^ 3, ~5, 1 << 3, 16 >> 2;

-- 6.16 Operator precedence (high to low)
-- parentheses > * / DIV % > + - > comparisons > NOT > AND > XOR > OR > assignment

-- 6.17 Combining everything
SELECT FirstName, Salary, Email
FROM Employees
WHERE Salary BETWEEN 1000 AND 3500
  AND Role IN ('Barista', 'Cashier')
  AND FirstName LIKE 'A%'
  AND Email IS NOT NULL;


-- ============================================================================
-- 7. ORDER BY, LIMIT AND DISTINCT
-- Sort the result, return part of it, remove duplicates
-- ============================================================================

-- 7.1 ORDER BY
-- ASC is the default
SELECT FirstName, Salary FROM Employees ORDER BY Salary;
SELECT FirstName, Salary FROM Employees ORDER BY Salary DESC;
SELECT FirstName, LastName FROM Employees ORDER BY FirstName, LastName DESC;

-- 7.2 Several columns
SELECT Role, FirstName, Salary FROM Employees ORDER BY Role ASC, Salary DESC;

-- 7.3 ORDER BY position, alias and expression
SELECT FirstName, Salary FROM Employees ORDER BY 2 DESC;
SELECT FirstName, Salary * 12 AS Yearly FROM Employees ORDER BY Yearly DESC;
SELECT ProductName, Price - Cost AS Profit FROM Products ORDER BY Price - Cost DESC;

-- 7.4 Custom order with FIELD
SELECT FirstName, Role FROM Employees
ORDER BY FIELD(Role, 'Manager', 'Barista', 'Cashier', 'Cleaner', 'Other');

-- 7.5 NULL ordering
-- NULL comes first in ASC and last in DESC
SELECT FirstName, Email FROM Employees ORDER BY Email;
SELECT FirstName, Email FROM Employees ORDER BY Email IS NULL, Email;

-- 7.6 Random order
SELECT ProductName FROM Products ORDER BY RAND();

-- 7.7 LIMIT
SELECT * FROM Employees LIMIT 3;
SELECT FirstName, Salary FROM Employees ORDER BY Salary DESC LIMIT 3;
SELECT FirstName, Salary FROM Employees ORDER BY Salary LIMIT 1;

-- 7.8 LIMIT with offset
-- LIMIT offset, count  =  LIMIT count OFFSET offset
SELECT * FROM Employees ORDER BY EmployeeID LIMIT 3, 3;
SELECT * FROM Employees ORDER BY EmployeeID LIMIT 3 OFFSET 3;

-- 7.9 Pagination
-- Page size 4: page 1, page 2, page 3
SELECT ProductID, ProductName FROM Products ORDER BY ProductID LIMIT 4 OFFSET 0;
SELECT ProductID, ProductName FROM Products ORDER BY ProductID LIMIT 4 OFFSET 4;
SELECT ProductID, ProductName FROM Products ORDER BY ProductID LIMIT 4 OFFSET 8;

-- 7.10 DISTINCT
SELECT DISTINCT Role FROM Employees;
SELECT DISTINCT Category FROM Products;
SELECT DISTINCT OrderType FROM Orders;

-- 7.11 DISTINCT on several columns
-- The combination of columns must be unique
SELECT DISTINCT Role, FirstName FROM Employees;
SELECT DISTINCT Category, SupplierID FROM Products ORDER BY Category;

-- 7.12 DISTINCT with NULL and COUNT
SELECT DISTINCT SupplierID FROM Products;
SELECT COUNT(DISTINCT Role) AS RolesCount FROM Employees;


-- ============================================================================
-- 8. FUNCTIONS
-- Numeric, string, date and time, control flow, conversion, JSON, system
-- ============================================================================

-- 8.1 Numeric functions
SELECT ABS(-15), SIGN(-15), SIGN(0), SIGN(15);
SELECT CEIL(4.2), CEILING(4.2), FLOOR(4.8), ROUND(4.567), ROUND(4.567, 2), ROUND(1234.567, -2);
SELECT TRUNCATE(4.567, 2), TRUNCATE(1234.567, -2);
SELECT POWER(2, 3), POW(2, 3), SQRT(16), MOD(10, 3), EXP(1), LN(10), LOG10(1000), LOG2(8), PI();
SELECT GREATEST(3, 9, 5), LEAST(3, 9, 5);
SELECT RAND(), FLOOR(RAND() * 10) + 1;
SELECT ProductName, Price, ROUND(Price * 1.05, 1) AS WithTax, CEIL(Price) AS RoundedUp FROM Products;
SELECT FirstName, Salary, ROUND(Salary, -2) AS Rounded, MOD(Salary, 1000) AS Remainder FROM Employees;

-- 8.2 String functions
SELECT LENGTH('Hello'), CHAR_LENGTH('Hello'), LENGTH('قهوة'), CHAR_LENGTH('قهوة');
SELECT CONCAT('Cof', 'fee', ' ', 'Shop');
SELECT CONCAT_WS('-', '2025', '10', '01');
SELECT UPPER('latte'), LOWER('LATTE'), UCASE('a'), LCASE('A');
SELECT LEFT('Database', 4), RIGHT('Database', 4), SUBSTRING('Database', 5, 3), SUBSTR('Database', 5), MID('Database', 2, 3);
SELECT REPLACE('I like tea', 'tea', 'coffee');
SELECT TRIM('  Hello  '), LTRIM('  Hello'), RTRIM('Hello  '), TRIM(BOTH 'x' FROM 'xxHelloxx');
SELECT REVERSE('Hello'), REPEAT('ab', 3), SPACE(3), LPAD('7', 3, '0'), RPAD('7', 3, '0');
SELECT INSTR('Coffee', 'ff'), LOCATE('ff', 'Coffee'), POSITION('ff' IN 'Coffee');
SELECT SUBSTRING_INDEX('ali.m@coffeeshop.ae', '@', 1), SUBSTRING_INDEX('ali.m@coffeeshop.ae', '@', -1);
SELECT STRCMP('a', 'b'), STRCMP('b', 'a'), STRCMP('a', 'a');
SELECT FORMAT(1234567.891, 2), ASCII('A'), CHAR(72, 105), HEX('A'), INSERT('Coffee', 1, 3, 'Tea');
SELECT FIELD('b', 'a', 'b', 'c'), FIND_IN_SET('b', 'a,b,c'), ELT(2, 'a', 'b', 'c');
SELECT CONCAT(FirstName, ' ', LastName) AS FullName FROM Employees;
SELECT CONCAT('E', LPAD(EmployeeID, 3, '0')) AS EmployeeCode, UPPER(FirstName) AS Name FROM Employees;
SELECT FirstName, Email, SUBSTRING_INDEX(Email, '@', 1) AS UserName FROM Employees WHERE Email IS NOT NULL;
SELECT ProductName, LENGTH(ProductName) AS Len FROM Products ORDER BY Len DESC;

-- 8.3 Date and time: current values
SELECT NOW(), CURRENT_TIMESTAMP(), SYSDATE(), CURDATE(), CURRENT_DATE(), CURTIME(), CURRENT_TIME(), UTC_TIMESTAMP();

-- 8.4 Date and time: extracting parts
SELECT DATE(OrderDate) AS OrderDay, TIME(OrderDate) AS OrderTime FROM Orders LIMIT 3;
SELECT YEAR(NOW()), MONTH(NOW()), DAY(NOW()), HOUR(NOW()), MINUTE(NOW()), SECOND(NOW());
SELECT DAYNAME('2025-10-01'), MONTHNAME('2025-10-01'), DAYOFWEEK('2025-10-01'), DAYOFYEAR('2025-10-01'),
       WEEK('2025-10-01'), QUARTER('2025-10-01'), WEEKDAY('2025-10-01');
SELECT EXTRACT(YEAR FROM '2025-10-01'), EXTRACT(MONTH FROM '2025-10-01'), EXTRACT(HOUR FROM '2025-10-01 14:30:00');
SELECT OrderID, OrderDate, DAYNAME(OrderDate) AS DayName, HOUR(OrderDate) AS OrderHour FROM Orders;

-- 8.5 Date and time: calculations
SELECT DATEDIFF('2025-10-10', '2025-10-01');
SELECT TIMEDIFF('16:00:00', '08:00:00');
SELECT TIMESTAMPDIFF(DAY, '2025-09-27', '2025-10-27'), TIMESTAMPDIFF(MONTH, '2025-01-15', '2025-10-14'), TIMESTAMPDIFF(HOUR, '2025-10-01 08:00:00', '2025-10-02 10:00:00');
SELECT DATE_ADD('2025-10-01', INTERVAL 7 DAY), DATE_SUB('2025-10-01', INTERVAL 1 MONTH), '2025-10-01' + INTERVAL 1 YEAR;
SELECT ADDTIME('08:00:00', '01:30:00'), SUBTIME('08:00:00', '00:30:00'), TIME_TO_SEC('01:00:00'), SEC_TO_TIME(5400);
SELECT LAST_DAY('2025-02-10'), MAKEDATE(2025, 100), ADDDATE('2025-10-01', 10);
SELECT FirstName, HireDate, DATEDIFF(CURDATE(), HireDate) AS DaysWorking, TIMESTAMPDIFF(YEAR, HireDate, CURDATE()) AS YearsWorking FROM Employees;
SELECT ProductName, ExpirationDate, DATEDIFF(ExpirationDate, '2025-11-01') AS DaysLeft FROM Products WHERE ExpirationDate IS NOT NULL;
SELECT EmployeeID, Date, TIMEDIFF(CheckOutTime, CheckInTime) AS HoursWorked FROM Attendance;

-- 8.6 Date and time: formatting and parsing
SELECT DATE_FORMAT('2025-10-01 14:30:00', '%Y/%m/%d'), DATE_FORMAT('2025-10-01 14:30:00', '%W, %d %M %Y'),
       DATE_FORMAT('2025-10-01 14:30:00', '%h:%i %p'), TIME_FORMAT('14:30:00', '%H:%i');
SELECT STR_TO_DATE('01/10/2025', '%d/%m/%Y'), STR_TO_DATE('October 1, 2025', '%M %d, %Y');
SELECT OrderID, DATE_FORMAT(OrderDate, '%d-%m-%Y %H:%i') AS OrderTime FROM Orders;

-- 8.7 Control flow: IF, IFNULL, NULLIF, COALESCE
SELECT FirstName, Salary, IF(Salary >= 3000, 'High', 'Normal') AS SalaryLevel FROM Employees;
SELECT FirstName, IFNULL(Email, 'No email') AS Email FROM Employees;
SELECT ProductName, COALESCE(SupplierID, 0) AS Supplier FROM Products;
SELECT COALESCE(NULL, NULL, 'third'), NULLIF(5, 5), NULLIF(5, 3);
SELECT OrderID, IF(IsCompleted, 'Done', 'Pending') AS Status FROM Orders;

-- 8.8 Control flow: CASE
-- Searched CASE
SELECT FirstName, Role, Salary,
       CASE
           WHEN Salary >= 8000 THEN 'Top'
           WHEN Salary >= 3000 THEN 'Senior'
           WHEN Salary >= 2000 THEN 'Regular'
           ELSE 'Junior'
       END AS Level
FROM Employees;
-- Simple CASE
SELECT FirstName, Role,
       CASE Role
           WHEN 'Manager' THEN 'Office'
           WHEN 'Barista' THEN 'Bar'
           WHEN 'Cashier' THEN 'Counter'
           ELSE 'Support'
       END AS Department
FROM Employees;
-- CASE for a bonus
SELECT FirstName, Salary,
       CASE WHEN Role = 'Barista' THEN Salary * 0.10
            WHEN Role = 'Cashier' THEN Salary * 0.05
            ELSE 0 END AS Bonus
FROM Employees;
-- CASE inside ORDER BY and WHERE
SELECT ProductName, Category FROM Products ORDER BY CASE WHEN Category = 'Drink' THEN 0 ELSE 1 END, ProductName;

-- 8.9 Conversion: CAST and CONVERT
SELECT CAST('123' AS UNSIGNED), CAST(12.7 AS SIGNED), CAST('2025-10-01' AS DATE), CAST(123 AS CHAR);
SELECT CONVERT('45.5', DECIMAL(5,1)), CONVERT(NOW(), DATE), CONVERT('abc' USING utf8mb4);
SELECT '5' + 5, CONCAT(5, 5), '10' > '9', 10 > 9, CAST('10' AS UNSIGNED) > CAST('9' AS UNSIGNED);
SELECT FirstName, CAST(Salary AS SIGNED) AS WholeSalary FROM Employees;

-- 8.10 JSON functions
SELECT JSON_OBJECT('name', 'Latte', 'price', 18) AS Item;
SELECT JSON_ARRAY('Sugar', 'Milk', 'Ice');
SELECT JSON_EXTRACT('{"name": "Latte", "price": 18}', '$.name') AS Name,
       JSON_UNQUOTE(JSON_EXTRACT('{"name": "Latte", "price": 18}', '$.name')) AS NameClean;
-- The -> and ->> shortcuts work on JSON columns
SELECT Item -> '$.name' AS Name, Item ->> '$.name' AS NameClean, Item ->> '$.price' AS Price
FROM (SELECT '{"name": "Latte", "price": 18}' AS Item) AS t;
SELECT JSON_OBJECT('product', ProductName, 'price', Price) AS ProductJson FROM Products LIMIT 3;

-- 8.11 Encryption and hashing
SELECT MD5('coffee'), SHA1('coffee'), SHA2('coffee', 256), LENGTH(UUID()), TO_BASE64('coffee');

-- 8.12 System and information functions
SELECT DATABASE(), USER(), CURRENT_USER(), VERSION(), CONNECTION_ID();
SELECT LAST_INSERT_ID(), ROW_COUNT();
SELECT UUID();


-- ============================================================================
-- 9. AGGREGATE FUNCTIONS
-- Summarize many rows into one value
-- ============================================================================

-- 9.1 COUNT
SELECT COUNT(*) AS AllRows FROM Employees;
SELECT COUNT(EmployeeID) AS Employees FROM Employees;
SELECT COUNT(Email) AS EmployeesWithEmail FROM Employees;
SELECT COUNT(DISTINCT Role) AS DifferentRoles FROM Employees;
SELECT COUNT(*) AS ProductsWithoutSupplier FROM Products WHERE SupplierID IS NULL;

-- 9.2 SUM
SELECT SUM(Salary) AS TotalSalaries FROM Employees;
SELECT SUM(StockQuantity) AS TotalStock FROM Products;
SELECT SUM(StockQuantity * Cost) AS StockValue FROM Products;

-- 9.3 AVG
SELECT AVG(Salary) AS AverageSalary FROM Employees;
SELECT ROUND(AVG(Price), 2) AS AveragePrice FROM Products WHERE Category = 'Drink';

-- 9.4 MIN and MAX
SELECT MIN(Salary) AS LowestSalary, MAX(Salary) AS HighestSalary FROM Employees;
SELECT MIN(HireDate) AS FirstHired, MAX(HireDate) AS LastHired FROM Employees;
SELECT MIN(ProductName) AS FirstAlphabetically, MAX(ProductName) AS LastAlphabetically FROM Products;

-- 9.5 Several aggregates together
SELECT COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue, AVG(TotalAmount) AS AverageOrder,
       MIN(TotalAmount) AS SmallestOrder, MAX(TotalAmount) AS LargestOrder
FROM Orders
WHERE IsCompleted = TRUE;

-- 9.6 Aggregates and NULL
-- NULL values are ignored by every aggregate except COUNT(*)
SELECT COUNT(*) AS AllEmployees, COUNT(Email) AS WithEmail FROM Employees;
SELECT COUNT(*) AS AllProducts, COUNT(ExpirationDate) AS WithExpiry FROM Products;
SELECT AVG(Cost), SUM(Cost), COUNT(Cost) FROM Products;

-- 9.7 GROUP_CONCAT
SELECT GROUP_CONCAT(FirstName) AS Names FROM Employees WHERE Role = 'Barista';
SELECT GROUP_CONCAT(DISTINCT Role ORDER BY Role SEPARATOR ' | ') AS Roles FROM Employees;
SELECT GROUP_CONCAT(ProductName ORDER BY Price DESC SEPARATOR ', ') AS ProductsByPrice FROM Products WHERE Category = 'Dessert';

-- 9.8 Statistical functions
SELECT STDDEV(Salary), STDDEV_SAMP(Salary), VARIANCE(Salary), VAR_SAMP(Salary) FROM Employees;

-- 9.9 JSON aggregates
SELECT JSON_ARRAYAGG(ProductName) AS Drinks FROM Products WHERE Category = 'Drink';
SELECT JSON_OBJECTAGG(ProductName, Price) AS PriceList FROM Products WHERE Category = 'Dessert';

-- 9.10 Aggregate over calculated values
-- Revenue of all order lines after discount
SELECT SUM(Quantity * UnitPrice * (1 - Discount / 100)) AS LineRevenue FROM Order_Details;

-- 9.11 Conditional aggregation
SELECT COUNT(*) AS AllOrders,
       SUM(IsCompleted) AS Completed,
       SUM(CASE WHEN OrderType = 'Takeaway' THEN 1 ELSE 0 END) AS Takeaway,
       SUM(OrderType = 'Dine-in') AS DineIn
FROM Orders;


-- ============================================================================
-- 10. GROUP BY AND HAVING
-- Split rows into groups and filter the groups
-- ============================================================================

-- 10.1 GROUP BY
SELECT Role, COUNT(*) AS Employees FROM Employees GROUP BY Role;
SELECT Category, COUNT(*) AS Products, AVG(Price) AS AveragePrice FROM Products GROUP BY Category;
SELECT Role, SUM(Salary) AS TotalSalaries, AVG(Salary) AS AverageSalary, MAX(Salary) AS Highest FROM Employees GROUP BY Role;

-- 10.2 GROUP BY several columns
SELECT Role, FirstName, COUNT(*) AS Employees FROM Employees GROUP BY Role, FirstName;
SELECT OrderType, IsCompleted, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue FROM Orders GROUP BY OrderType, IsCompleted;

-- 10.3 GROUP BY an expression
SELECT DATE(OrderDate) AS OrderDay, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue
FROM Orders
GROUP BY DATE(OrderDate);
SELECT HOUR(OrderDate) AS HourOfDay, COUNT(*) AS Orders FROM Orders GROUP BY HOUR(OrderDate) ORDER BY HourOfDay;
SELECT DATE_FORMAT(OrderDate, '%Y-%m') AS Month, SUM(TotalAmount) AS Revenue FROM Orders GROUP BY DATE_FORMAT(OrderDate, '%Y-%m');
SELECT DAYNAME(OrderDate) AS Day, COUNT(*) AS Orders FROM Orders GROUP BY DAYNAME(OrderDate), DAYOFWEEK(OrderDate) ORDER BY DAYOFWEEK(OrderDate);

-- 10.4 HAVING
-- WHERE filters rows before grouping, HAVING filters groups after grouping
SELECT Role, COUNT(*) AS Employees FROM Employees GROUP BY Role HAVING COUNT(*) > 1;
SELECT Category, AVG(Price) AS AveragePrice FROM Products GROUP BY Category HAVING AveragePrice > 15;
SELECT SupplierID, COUNT(*) AS Products FROM Products WHERE SupplierID IS NOT NULL GROUP BY SupplierID HAVING Products >= 3;

-- 10.5 WHERE and HAVING together
SELECT Role, AVG(Salary) AS AverageSalary
FROM Employees
WHERE Salary > 1900
GROUP BY Role
HAVING AVG(Salary) > 3000
ORDER BY AverageSalary DESC;

-- 10.6 GROUP BY with ORDER BY and LIMIT
SELECT ProductID, SUM(Quantity) AS UnitsSold
FROM Order_Details
GROUP BY ProductID
ORDER BY UnitsSold DESC
LIMIT 3;

-- 10.7 WITH ROLLUP
-- Adds subtotal and grand total rows (GROUPING tells which rows are totals)
SELECT Category, COUNT(*) AS Products, SUM(StockQuantity) AS Stock FROM Products GROUP BY Category WITH ROLLUP;
SELECT IF(GROUPING(OrderType), 'All types', OrderType) AS OrderType, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue
FROM Orders GROUP BY OrderType WITH ROLLUP;

-- 10.8 ONLY_FULL_GROUP_BY
-- Every selected column must be grouped or aggregated
SELECT Role, ANY_VALUE(FirstName) AS AnyName, COUNT(*) FROM Employees GROUP BY Role;
SELECT @@sql_mode;

-- 10.9 Counting groups of groups
SELECT COUNT(*) AS RolesWithMoreThanOneEmployee
FROM (SELECT Role FROM Employees GROUP BY Role HAVING COUNT(*) > 1) AS t;


-- ============================================================================
-- 11. SUBQUERIES
-- A query inside another query
-- ============================================================================

-- 11.1 Scalar subquery in WHERE
SELECT * FROM Employees WHERE Salary > (SELECT AVG(Salary) FROM Employees);
SELECT * FROM Products WHERE Price = (SELECT MAX(Price) FROM Products);
SELECT * FROM Employees WHERE HireDate = (SELECT MIN(HireDate) FROM Employees);

-- 11.2 Scalar subquery in SELECT
SELECT FirstName, Salary, (SELECT AVG(Salary) FROM Employees) AS CompanyAverage,
       Salary - (SELECT AVG(Salary) FROM Employees) AS Difference
FROM Employees;

-- 11.3 IN and NOT IN
SELECT * FROM Products WHERE ProductID IN (SELECT ProductID FROM Order_Details);
SELECT * FROM Products WHERE ProductID NOT IN (SELECT ProductID FROM Order_Details WHERE ProductID IS NOT NULL);
SELECT * FROM Employees WHERE EmployeeID IN (SELECT EmployeeID FROM Orders WHERE EmployeeID IS NOT NULL);
SELECT * FROM LoyaltyCards WHERE CardID NOT IN (SELECT LoyaltyCardID FROM Orders WHERE LoyaltyCardID IS NOT NULL);

-- 11.4 ANY, SOME and ALL
SELECT * FROM Employees WHERE Salary > ALL (SELECT Salary FROM Employees WHERE Role = 'Cashier');
SELECT * FROM Employees WHERE Salary > ANY (SELECT Salary FROM Employees WHERE Role = 'Cashier');
SELECT * FROM Employees WHERE Salary > SOME (SELECT Salary FROM Employees WHERE Role = 'Barista');
SELECT * FROM Products WHERE Price = ANY (SELECT Price FROM Products WHERE Category = 'Dessert');
SELECT * FROM Employees WHERE EmployeeID <> ALL (SELECT EmployeeID FROM Orders WHERE EmployeeID IS NOT NULL);

-- 11.5 EXISTS and NOT EXISTS
SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM Orders o WHERE o.EmployeeID = e.EmployeeID);
SELECT * FROM Employees e WHERE NOT EXISTS (SELECT 1 FROM Orders o WHERE o.EmployeeID = e.EmployeeID);
SELECT * FROM Suppliers s WHERE NOT EXISTS (SELECT 1 FROM Products p WHERE p.SupplierID = s.SupplierID);

-- 11.6 Correlated subquery
-- The inner query uses a value from the outer query row by row
SELECT FirstName, Role, Salary FROM Employees e
WHERE Salary > (SELECT AVG(Salary) FROM Employees WHERE Role = e.Role);
SELECT ProductName, Category, Price FROM Products p
WHERE Price = (SELECT MAX(Price) FROM Products WHERE Category = p.Category);
SELECT OrderID, OrderDate, TotalAmount,
       (SELECT COUNT(*) FROM Order_Details d WHERE d.OrderID = o.OrderID) AS Items
FROM Orders o;

-- 11.7 Subquery in FROM (derived table)
SELECT Role, AverageSalary
FROM (SELECT Role, AVG(Salary) AS AverageSalary FROM Employees GROUP BY Role) AS RoleStats
WHERE AverageSalary > 2500;
SELECT AVG(DailyRevenue) AS AverageDailyRevenue
FROM (SELECT DATE(OrderDate) AS Day, SUM(TotalAmount) AS DailyRevenue FROM Orders GROUP BY DATE(OrderDate)) AS Daily;

-- 11.8 Row subquery
SELECT * FROM Products WHERE (Category, Price) IN (SELECT Category, MAX(Price) FROM Products GROUP BY Category);

-- 11.9 Nested subqueries
SELECT FirstName FROM Employees
WHERE EmployeeID IN (
    SELECT EmployeeID FROM Orders
    WHERE OrderID IN (SELECT OrderID FROM Order_Details WHERE ProductID = (SELECT ProductID FROM Products WHERE ProductName = 'Mocha'))
);

-- 11.10 Subqueries in other statements
-- UPDATE, DELETE and INSERT ... SELECT with subqueries are covered in sections 16 and 18


-- ============================================================================
-- 12. JOINS
-- Combine rows from several tables using the foreign keys
-- ============================================================================

-- 12.1 The problem
-- Orders only stores EmployeeID, not the employee name
SELECT OrderID, EmployeeID, TotalAmount FROM Orders;

-- 12.2 INNER JOIN
-- Returns only rows that have a match in both tables
SELECT o.OrderID, o.OrderDate, e.FirstName, e.Role, o.TotalAmount
FROM Orders o
INNER JOIN Employees e ON o.EmployeeID = e.EmployeeID;
SELECT o.OrderID, e.FirstName FROM Orders o JOIN Employees e ON o.EmployeeID = e.EmployeeID;
SELECT o.OrderID, e.FirstName FROM Orders o, Employees e WHERE o.EmployeeID = e.EmployeeID;

-- 12.3 JOIN with a filter and sorting
SELECT e.FirstName, o.OrderID, o.TotalAmount
FROM Employees e
JOIN Orders o ON o.EmployeeID = e.EmployeeID
WHERE o.IsCompleted = TRUE AND o.TotalAmount > 50
ORDER BY o.TotalAmount DESC;

-- 12.4 USING
-- Shortcut when both columns have the same name
SELECT e.FirstName, a.Date, a.CheckInTime FROM Employees e JOIN Attendance a USING (EmployeeID);

-- 12.5 NATURAL JOIN
-- Joins on all columns with the same name (risky, avoid in real projects)
SELECT ProductName, SupplierName FROM Products NATURAL JOIN Suppliers;

-- 12.6 LEFT JOIN
-- Every row of the left table, with NULL when there is no match
SELECT e.EmployeeID, e.FirstName, e.Role, o.OrderID, o.TotalAmount
FROM Employees e
LEFT JOIN Orders o ON o.EmployeeID = e.EmployeeID
ORDER BY e.EmployeeID;
SELECT e.FirstName, COUNT(o.OrderID) AS Orders, IFNULL(SUM(o.TotalAmount), 0) AS Revenue
FROM Employees e
LEFT JOIN Orders o ON o.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeID, e.FirstName
ORDER BY Revenue DESC;

-- 12.7 RIGHT JOIN
-- Every row of the right table, with NULL when there is no match
SELECT e.FirstName, o.OrderID, o.TotalAmount
FROM Employees e
RIGHT JOIN Orders o ON o.EmployeeID = e.EmployeeID;
SELECT s.SupplierName, p.ProductName FROM Products p RIGHT JOIN Suppliers s ON p.SupplierID = s.SupplierID;

-- 12.8 Finding rows without a match (anti join)
SELECT p.ProductID, p.ProductName
FROM Products p
LEFT JOIN Order_Details d ON d.ProductID = p.ProductID
WHERE d.OrderDetailID IS NULL;
SELECT s.SupplierName FROM Suppliers s LEFT JOIN Products p ON p.SupplierID = s.SupplierID WHERE p.ProductID IS NULL;
SELECT c.CardNumber FROM LoyaltyCards c LEFT JOIN Orders o ON o.LoyaltyCardID = c.CardID WHERE o.OrderID IS NULL;
SELECT o.OrderID, o.TotalAmount FROM Orders o LEFT JOIN Payments p ON p.OrderID = o.OrderID WHERE p.PaymentID IS NULL;

-- 12.9 FULL OUTER JOIN
-- MySQL has no FULL JOIN: combine LEFT JOIN and RIGHT JOIN with UNION
SELECT e.FirstName, o.OrderID
FROM Employees e LEFT JOIN Orders o ON o.EmployeeID = e.EmployeeID
UNION
SELECT e.FirstName, o.OrderID
FROM Employees e RIGHT JOIN Orders o ON o.EmployeeID = e.EmployeeID;

-- 12.10 CROSS JOIN
-- Every row with every row (Cartesian product)
SELECT r.Role, t.OrderType
FROM (SELECT DISTINCT Role FROM Employees) r
CROSS JOIN (SELECT DISTINCT OrderType FROM Orders) t;
SELECT COUNT(*) AS Combinations FROM Employees CROSS JOIN Products;
SELECT p.ProductName, pt.PaymentType
FROM Products p
CROSS JOIN (SELECT 'Cash' AS PaymentType UNION SELECT 'Card' UNION SELECT 'MobilePay') pt
WHERE p.Category = 'Dessert';

-- 12.11 SELF JOIN
-- A table joined to itself, using two different aliases
SELECT a.EmployeeID AS FirstID, b.EmployeeID AS SecondID, a.FirstName, a.LastName, a.Salary AS FirstSalary, b.Salary AS SecondSalary
FROM Employees a
JOIN Employees b ON a.FirstName = b.FirstName AND a.LastName = b.LastName AND a.EmployeeID < b.EmployeeID;
SELECT a.FirstName AS EmployeeA, b.FirstName AS EmployeeB, a.Role
FROM Employees a
JOIN Employees b ON a.Role = b.Role AND a.EmployeeID < b.EmployeeID
ORDER BY a.Role;
SELECT a.ProductName AS Product, b.ProductName AS CheaperProduct, a.Category
FROM Products a
JOIN Products b ON a.Category = b.Category AND b.Price < a.Price
WHERE a.Category = 'Dessert';
SELECT a.FirstName, a.Salary, COUNT(b.EmployeeID) AS EarnMore
FROM Employees a LEFT JOIN Employees b ON b.Salary > a.Salary
GROUP BY a.EmployeeID, a.FirstName, a.Salary;

-- 12.12 Joining three or more tables
SELECT o.OrderID, o.OrderDate, e.FirstName AS Cashier, p.ProductName, d.Quantity, d.UnitPrice, d.Discount
FROM Orders o
JOIN Order_Details d ON d.OrderID = o.OrderID
JOIN Products p ON p.ProductID = d.ProductID
LEFT JOIN Employees e ON e.EmployeeID = o.EmployeeID
ORDER BY o.OrderID;

-- 12.13 Joining all tables
SELECT o.OrderID, o.OrderDate, e.FirstName AS Employee, lc.CardNumber, p.ProductName,
       s.CompanyName AS Supplier, d.Quantity, pay.PaymentType, pay.Amount
FROM Orders o
LEFT JOIN Employees e ON e.EmployeeID = o.EmployeeID
LEFT JOIN LoyaltyCards lc ON lc.CardID = o.LoyaltyCardID
JOIN Order_Details d ON d.OrderID = o.OrderID
LEFT JOIN Products p ON p.ProductID = d.ProductID
LEFT JOIN Suppliers s ON s.SupplierID = p.SupplierID
LEFT JOIN Payments pay ON pay.OrderID = o.OrderID
ORDER BY o.OrderID;

-- 12.14 Many-to-many through Order_Details
-- Products and Orders are linked only by the middle table
SELECT p.ProductName, COUNT(DISTINCT d.OrderID) AS InOrders, SUM(d.Quantity) AS UnitsSold
FROM Products p
LEFT JOIN Order_Details d ON d.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY UnitsSold DESC;
SELECT o.OrderID, GROUP_CONCAT(p.ProductName ORDER BY p.ProductName SEPARATOR ', ') AS Items
FROM Orders o
JOIN Order_Details d ON d.OrderID = o.OrderID
JOIN Products p ON p.ProductID = d.ProductID
GROUP BY o.OrderID;

-- 12.15 JOIN with aggregation
SELECT p.Category, SUM(d.Quantity) AS UnitsSold, ROUND(SUM(d.Quantity * d.UnitPrice * (1 - d.Discount / 100)), 2) AS Revenue
FROM Order_Details d
JOIN Products p ON p.ProductID = d.ProductID
GROUP BY p.Category
ORDER BY Revenue DESC;
SELECT s.CompanyName, COUNT(p.ProductID) AS Products, SUM(p.StockQuantity) AS TotalStock
FROM Suppliers s LEFT JOIN Products p ON p.SupplierID = s.SupplierID
GROUP BY s.SupplierID, s.CompanyName;
SELECT lc.CardNumber, lc.Points, COUNT(o.OrderID) AS Orders, IFNULL(SUM(o.TotalAmount), 0) AS Spent
FROM LoyaltyCards lc LEFT JOIN Orders o ON o.LoyaltyCardID = lc.CardID
GROUP BY lc.CardID, lc.CardNumber, lc.Points;
SELECT pay.PaymentType, COUNT(*) AS Payments, SUM(pay.Amount) AS Total
FROM Payments pay GROUP BY pay.PaymentType;

-- 12.16 Join conditions that are not equality (non-equi join)
SELECT e.FirstName, e.Salary, b.Band
FROM Employees e
JOIN (SELECT 'Low' AS Band, 0 AS MinSalary, 2499 AS MaxSalary
      UNION ALL SELECT 'Medium', 2500, 3999
      UNION ALL SELECT 'High', 4000, 999999) b
  ON e.Salary BETWEEN b.MinSalary AND b.MaxSalary
ORDER BY e.Salary;

-- 12.17 Joining a subquery
SELECT e.FirstName, t.Orders, t.Revenue
FROM Employees e
JOIN (SELECT EmployeeID, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue FROM Orders GROUP BY EmployeeID) t
  ON t.EmployeeID = e.EmployeeID;

-- 12.18 LATERAL join (MySQL 8.0.14+)
-- The subquery on the right can use columns from the table on the left
SELECT c.Category, t.ProductName, t.Price
FROM (SELECT DISTINCT Category FROM Products) c
JOIN LATERAL (SELECT ProductName, Price FROM Products p WHERE p.Category = c.Category ORDER BY Price DESC LIMIT 2) t ON TRUE;

-- 12.19 Attendance and employees
SELECT e.FirstName, COUNT(a.AttendanceID) AS DaysPresent,
       SEC_TO_TIME(SUM(TIME_TO_SEC(TIMEDIFF(a.CheckOutTime, a.CheckInTime)))) AS TotalHours
FROM Employees e
LEFT JOIN Attendance a ON a.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeID, e.FirstName;

-- 12.20 Summary of join types
-- INNER ...... matching rows only
-- LEFT ....... all left rows + matches
-- RIGHT ...... all right rows + matches
-- FULL ....... LEFT UNION RIGHT (emulated)
-- CROSS ...... every combination
-- SELF ....... table with itself
-- NATURAL .... automatic join on same-name columns
-- LATERAL .... subquery that sees the left side


-- ============================================================================
-- 13. SET OPERATORS
-- Combine the results of several SELECT statements
-- ============================================================================

-- 13.1 UNION
-- Removes duplicate rows. Same number of columns and compatible types are required
SELECT FirstName AS Name, 'Employee' AS Type FROM Employees
UNION
SELECT SupplierName, 'Supplier' FROM Suppliers;

-- 13.2 UNION ALL
-- Keeps duplicates and is faster
SELECT Role FROM Employees WHERE Salary > 3000
UNION ALL
SELECT Role FROM Employees WHERE Role = 'Barista';
SELECT Role FROM Employees WHERE Salary > 3000
UNION
SELECT Role FROM Employees WHERE Role = 'Barista';

-- 13.3 UNION with ORDER BY and LIMIT
(SELECT ProductName, Price FROM Products ORDER BY Price DESC LIMIT 3)
UNION ALL
(SELECT ProductName, Price FROM Products ORDER BY Price LIMIT 3)
ORDER BY Price DESC;

-- 13.4 UNION for a total row
SELECT ProductName, Price FROM Products WHERE Category = 'Dessert'
UNION ALL
SELECT 'Total', SUM(Price) FROM Products WHERE Category = 'Dessert';

-- 13.5 Report of daily and overall revenue
SELECT DATE_FORMAT(OrderDate, '%Y-%m-%d') AS Day, SUM(TotalAmount) AS Revenue FROM Orders GROUP BY Day
UNION ALL
SELECT 'All days', SUM(TotalAmount) FROM Orders;

-- 13.6 INTERSECT (MySQL 8.0.31+)
-- Rows that exist in both results
SELECT EmployeeID FROM Orders WHERE EmployeeID IS NOT NULL
INTERSECT
SELECT EmployeeID FROM Attendance;

-- 13.7 EXCEPT (MySQL 8.0.31+)
-- Rows of the first result that are not in the second
SELECT EmployeeID FROM Employees
EXCEPT
SELECT EmployeeID FROM Orders WHERE EmployeeID IS NOT NULL;

-- 13.8 INTERSECT and EXCEPT for older versions
SELECT DISTINCT EmployeeID FROM Attendance WHERE EmployeeID IN (SELECT EmployeeID FROM Orders);
SELECT EmployeeID FROM Employees e WHERE NOT EXISTS (SELECT 1 FROM Orders o WHERE o.EmployeeID = e.EmployeeID);

-- 13.9 TABLE and VALUES statements (MySQL 8.0.19+)
TABLE Suppliers ORDER BY SupplierID LIMIT 2;
VALUES ROW(1, 'Cash'), ROW(2, 'Card'), ROW(3, 'MobilePay');


-- ============================================================================
-- 14. WINDOW FUNCTIONS
-- Calculations across related rows without collapsing them (MySQL 8.0+)
-- ============================================================================

-- 14.1 ROW_NUMBER
SELECT ROW_NUMBER() OVER (ORDER BY Salary DESC) AS Position, FirstName, Salary FROM Employees;

-- 14.2 PARTITION BY
-- Restarts the numbering inside each group
SELECT Role, FirstName, Salary, ROW_NUMBER() OVER (PARTITION BY Role ORDER BY Salary DESC) AS RankInRole FROM Employees;

-- 14.3 RANK, DENSE_RANK and ROW_NUMBER
SELECT ProductName, Category, Price,
       RANK() OVER (PARTITION BY Category ORDER BY Price DESC) AS PriceRank,
       DENSE_RANK() OVER (PARTITION BY Category ORDER BY Price DESC) AS DenseRank,
       ROW_NUMBER() OVER (PARTITION BY Category ORDER BY Price DESC) AS RowNum
FROM Products;

-- 14.4 Top N per group
SELECT * FROM (
    SELECT Category, ProductName, Price, ROW_NUMBER() OVER (PARTITION BY Category ORDER BY Price DESC) AS rn
    FROM Products
) t WHERE rn <= 2;

-- 14.5 NTILE
SELECT FirstName, Salary, NTILE(3) OVER (ORDER BY Salary DESC) AS SalaryGroup FROM Employees;

-- 14.6 Aggregates as window functions
SELECT FirstName, Role, Salary,
       SUM(Salary) OVER () AS TotalSalaries,
       AVG(Salary) OVER (PARTITION BY Role) AS RoleAverage,
       Salary - AVG(Salary) OVER (PARTITION BY Role) AS DifferenceFromRole,
       ROUND(Salary / SUM(Salary) OVER () * 100, 1) AS PercentOfPayroll
FROM Employees;

-- 14.7 Running total
SELECT OrderID, OrderDate, TotalAmount,
       SUM(TotalAmount) OVER (ORDER BY OrderDate, OrderID) AS RunningRevenue
FROM Orders WHERE IsCompleted = TRUE;

-- 14.8 Moving average
SELECT OrderID, TotalAmount,
       ROUND(AVG(TotalAmount) OVER (ORDER BY OrderID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS MovingAverage
FROM Orders;

-- 14.9 LAG and LEAD
SELECT OrderID, OrderDate, TotalAmount,
       LAG(TotalAmount) OVER (ORDER BY OrderID) AS PreviousOrder,
       LEAD(TotalAmount) OVER (ORDER BY OrderID) AS NextOrder,
       TotalAmount - LAG(TotalAmount, 1, 0) OVER (ORDER BY OrderID) AS ChangeFromPrevious
FROM Orders;

-- 14.10 FIRST_VALUE, LAST_VALUE and NTH_VALUE
SELECT Category, ProductName, Price,
       FIRST_VALUE(ProductName) OVER (PARTITION BY Category ORDER BY Price DESC) AS MostExpensive,
       LAST_VALUE(ProductName) OVER (PARTITION BY Category ORDER BY Price DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS Cheapest,
       NTH_VALUE(ProductName, 2) OVER (PARTITION BY Category ORDER BY Price DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS SecondMostExpensive
FROM Products;

-- 14.11 PERCENT_RANK and CUME_DIST
SELECT FirstName, Salary, ROUND(PERCENT_RANK() OVER (ORDER BY Salary), 2) AS PercentRank, ROUND(CUME_DIST() OVER (ORDER BY Salary), 2) AS CumulativeDist FROM Employees;

-- 14.12 Named windows
SELECT FirstName, Role, Salary,
       RANK() OVER w AS SalaryRank,
       SUM(Salary) OVER w AS RunningPayroll
FROM Employees
WINDOW w AS (PARTITION BY Role ORDER BY Salary DESC);

-- 14.13 Employee revenue ranking
SELECT e.FirstName, SUM(o.TotalAmount) AS Revenue, RANK() OVER (ORDER BY SUM(o.TotalAmount) DESC) AS RevenueRank
FROM Employees e JOIN Orders o ON o.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeID, e.FirstName;


-- ============================================================================
-- 15. CTE (WITH) AND RECURSIVE CTE
-- Named temporary result sets that make long queries readable
-- ============================================================================

-- 15.1 Simple CTE
WITH AverageSalary AS (SELECT AVG(Salary) AS Avg FROM Employees)
SELECT FirstName, Salary FROM Employees, AverageSalary WHERE Salary > Avg;

-- 15.2 Several CTEs
WITH DailyRevenue AS (
        SELECT DATE(OrderDate) AS Day, SUM(TotalAmount) AS Revenue FROM Orders WHERE IsCompleted = TRUE GROUP BY DATE(OrderDate)
     ),
     Stats AS (
        SELECT AVG(Revenue) AS AverageRevenue FROM DailyRevenue
     )
SELECT d.Day, d.Revenue, ROUND(s.AverageRevenue, 2) AS Average, IF(d.Revenue > s.AverageRevenue, 'Above', 'Below') AS Compared
FROM DailyRevenue d CROSS JOIN Stats s;

-- 15.3 CTE referencing another CTE
WITH ProductRevenue AS (
        SELECT ProductID, SUM(Quantity * UnitPrice * (1 - Discount / 100)) AS Revenue FROM Order_Details GROUP BY ProductID
     ),
     Ranked AS (
        SELECT ProductID, Revenue, RANK() OVER (ORDER BY Revenue DESC) AS Position FROM ProductRevenue
     )
SELECT p.ProductName, ROUND(r.Revenue, 2) AS Revenue, r.Position
FROM Ranked r JOIN Products p ON p.ProductID = r.ProductID
WHERE r.Position <= 5;

-- 15.4 Recursive CTE: number series
WITH RECURSIVE Numbers AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM Numbers WHERE n < 10
)
SELECT n, n * n AS Square FROM Numbers;

-- 15.5 Recursive CTE: calendar with revenue (days without orders still appear)
WITH RECURSIVE Calendar AS (
    SELECT DATE('2025-10-01') AS Day
    UNION ALL
    SELECT Day + INTERVAL 1 DAY FROM Calendar WHERE Day < '2025-10-10'
)
SELECT c.Day, COUNT(o.OrderID) AS Orders, IFNULL(SUM(o.TotalAmount), 0) AS Revenue
FROM Calendar c LEFT JOIN Orders o ON DATE(o.OrderDate) = c.Day
GROUP BY c.Day;

-- 15.6 Recursive CTE: hierarchy
-- Example with a small inline organization chart
WITH RECURSIVE Org AS (
    SELECT 1 AS ID, 'Owner' AS Title, NULL AS BossID, 0 AS Level
    UNION ALL SELECT 2, 'Manager', 1, 1
    UNION ALL SELECT 3, 'Barista', 2, 2
    UNION ALL SELECT 4, 'Cashier', 2, 2
),
Tree AS (
    SELECT ID, Title, BossID, Level, CAST(Title AS CHAR(200)) AS Path FROM Org WHERE BossID IS NULL
    UNION ALL
    SELECT o.ID, o.Title, o.BossID, t.Level + 1, CONCAT(t.Path, ' > ', o.Title) FROM Org o JOIN Tree t ON o.BossID = t.ID
)
SELECT * FROM Tree;


-- ============================================================================
-- 16. UPDATE AND DELETE
-- Change and remove existing rows (everything runs inside a transaction
-- and is rolled back, so the sample data stays unchanged)
-- ============================================================================

-- 16.1 Safe update mode
-- MySQL Workbench blocks UPDATE and DELETE without a key in WHERE
SET SQL_SAFE_UPDATES = 0;

START TRANSACTION;

-- 16.2 UPDATE one row
UPDATE Employees SET Salary = 3800 WHERE EmployeeID = 1;
SELECT EmployeeID, FirstName, Salary FROM Employees WHERE EmployeeID = 1;

-- 16.3 UPDATE several columns
UPDATE Employees SET Phone = '0509999999', Email = 'abdullah.new@coffeeshop.ae' WHERE EmployeeID = 1;

-- 16.4 UPDATE with expressions
UPDATE Employees SET Salary = Salary * 1.10 WHERE Role = 'Barista';
UPDATE Products SET Price = Price + 1 WHERE Category = 'Drink';
UPDATE Products SET StockQuantity = StockQuantity + 50, Cost = Cost * 1.02 WHERE ProductID IN (9, 10, 11);

-- 16.5 UPDATE with CASE
UPDATE Employees
SET Salary = CASE
        WHEN Role = 'Manager' THEN Salary + 500
        WHEN Role = 'Barista' THEN Salary + 200
        ELSE Salary + 100
    END;

-- 16.6 UPDATE with ORDER BY and LIMIT
UPDATE Products SET Price = Price * 0.9 ORDER BY ExpirationDate LIMIT 2;

-- 16.7 UPDATE with a subquery
UPDATE Employees SET Salary = (SELECT MAX(Salary) FROM (SELECT Salary FROM Employees WHERE Role = 'Barista') AS t) WHERE EmployeeID = 1;
UPDATE Products SET StockQuantity = 0 WHERE ProductID NOT IN (SELECT ProductID FROM Order_Details WHERE ProductID IS NOT NULL);

-- 16.8 UPDATE with JOIN
UPDATE Orders o
JOIN Employees e ON e.EmployeeID = o.EmployeeID
SET o.OrderType = 'Takeaway'
WHERE e.Role = 'Cashier' AND o.IsCompleted = FALSE;
UPDATE Products p
JOIN Suppliers s ON s.SupplierID = p.SupplierID
SET p.Cost = p.Cost * 1.05
WHERE s.CompanyName = 'Gulf Beans Trading';

-- 16.9 UPDATE NULL values
UPDATE Employees SET Email = CONCAT(LOWER(FirstName), '.', LOWER(LastName), '@coffeeshop.ae') WHERE Email IS NULL;
SELECT FirstName, Email FROM Employees;

-- 16.10 What happens without WHERE
UPDATE Products SET StockQuantity = 0;
SELECT SUM(StockQuantity) FROM Products;

ROLLBACK;
SELECT SUM(StockQuantity) AS StockAfterRollback FROM Products;

START TRANSACTION;

-- 16.11 DELETE
DELETE FROM Payments WHERE OrderID = 1;
DELETE FROM Attendance WHERE CheckOutTime IS NULL;
DELETE FROM Orders WHERE IsCompleted = FALSE;
SELECT ROW_COUNT();

-- 16.12 DELETE with ORDER BY and LIMIT
DELETE FROM Attendance ORDER BY Date, AttendanceID LIMIT 2;

-- 16.13 DELETE with a subquery
DELETE FROM LoyaltyCards WHERE CardID NOT IN (SELECT LoyaltyCardID FROM Orders WHERE LoyaltyCardID IS NOT NULL);

-- 16.14 DELETE with JOIN
DELETE a FROM Attendance a JOIN Employees e ON e.EmployeeID = a.EmployeeID WHERE e.Role = 'Manager';
DELETE o, d FROM Orders o JOIN Order_Details d ON d.OrderID = o.OrderID WHERE o.OrderID = 2;

-- 16.15 Foreign key actions in practice
-- Employees > Attendance uses ON DELETE CASCADE
SELECT COUNT(*) AS AttendanceBefore FROM Attendance WHERE EmployeeID = 3;
DELETE FROM Employees WHERE EmployeeID = 3;
SELECT COUNT(*) AS AttendanceAfter FROM Attendance WHERE EmployeeID = 3;
-- Employees > Orders uses ON DELETE SET NULL
SELECT OrderID, EmployeeID FROM Orders WHERE OrderID IN (1, 5, 8);
-- Suppliers > Products uses ON DELETE SET NULL
DELETE FROM Suppliers WHERE SupplierID = 3;
SELECT ProductName, SupplierID FROM Products WHERE Category IN ('Dessert', 'Snack');
-- Orders > Order_Details and Payments use ON DELETE CASCADE
DELETE FROM Orders WHERE OrderID = 3;
SELECT COUNT(*) AS DetailsOfOrder3 FROM Order_Details WHERE OrderID = 3;
-- ON UPDATE CASCADE
UPDATE Employees SET EmployeeID = 100 WHERE EmployeeID = 1;
SELECT OrderID, EmployeeID FROM Orders WHERE EmployeeID = 100;

ROLLBACK;
SELECT COUNT(*) AS EmployeesAfterRollback FROM Employees;

-- 16.16 TRUNCATE
-- Removes all rows and resets AUTO_INCREMENT (shown on a copy, see section 18)


-- ============================================================================
-- 17. TRANSACTIONS AND LOCKING
-- Group several statements into one all-or-nothing unit (InnoDB)
-- ============================================================================

-- 17.1 AUTOCOMMIT
SELECT @@autocommit;
SET autocommit = 0;
SET autocommit = 1;

-- 17.2 COMMIT
-- A complete sale: order, details, payment and stock update succeed together
START TRANSACTION;
INSERT INTO Orders (EmployeeID, OrderDate, IsCompleted, OrderType, LoyaltyCardID, TotalAmount)
VALUES (7, '2025-11-04 09:30:00', TRUE, 'Dine-in', 2, 34.00);
SET @NewOrder = LAST_INSERT_ID();
INSERT INTO Order_Details (OrderID, ProductID, Quantity, UnitPrice, Discount) VALUES (@NewOrder, 3, 1, 18.00, 0), (@NewOrder, 2, 1, 16.00, 0);
INSERT INTO Payments (OrderID, PaymentType, Amount) VALUES (@NewOrder, 'Card', 34.00);
UPDATE Products SET StockQuantity = StockQuantity - 1 WHERE ProductID IN (2, 3);
COMMIT;
SELECT * FROM Orders WHERE OrderID = @NewOrder;

-- 17.3 ROLLBACK
START TRANSACTION;
DELETE FROM Order_Details;
SELECT COUNT(*) AS DetailsInsideTransaction FROM Order_Details;
ROLLBACK;
SELECT COUNT(*) AS DetailsAfterRollback FROM Order_Details;

-- 17.4 SAVEPOINT
START TRANSACTION;
UPDATE Products SET Price = Price + 1 WHERE Category = 'Drink';
SAVEPOINT after_drinks;
UPDATE Products SET Price = Price + 1 WHERE Category = 'Dessert';
SELECT Category, Price FROM Products WHERE ProductID IN (1, 9);
ROLLBACK TO SAVEPOINT after_drinks;
SELECT Category, Price FROM Products WHERE ProductID IN (1, 9);
RELEASE SAVEPOINT after_drinks;
ROLLBACK;

-- 17.5 Constraint error inside a transaction
-- A CHECK violation (negative stock) fails; the transaction can then be rolled back
START TRANSACTION;
UPDATE Products SET StockQuantity = StockQuantity - 5 WHERE ProductID = 2;
-- UPDATE Products SET StockQuantity = StockQuantity - 1000 WHERE ProductID = 2;
ROLLBACK;

-- 17.6 Isolation levels
SELECT @@transaction_isolation;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- READ UNCOMMITTED | READ COMMITTED | REPEATABLE READ (default) | SERIALIZABLE

-- 17.7 Row locking
START TRANSACTION;
SELECT * FROM Products WHERE ProductID = 3 FOR UPDATE;
SELECT * FROM Products WHERE ProductID = 3 FOR SHARE;
SELECT * FROM Products WHERE ProductID = 4 FOR UPDATE SKIP LOCKED;
SELECT * FROM Products WHERE ProductID = 5 FOR UPDATE NOWAIT;
COMMIT;

-- 17.8 Table locking
LOCK TABLES Products READ;
SELECT COUNT(*) FROM Products;
UNLOCK TABLES;
LOCK TABLES Products WRITE, Order_Details READ;
UNLOCK TABLES;

-- 17.9 Statements that commit automatically
-- CREATE, ALTER, DROP, TRUNCATE and RENAME (DDL) end the current transaction


-- ============================================================================
-- 18. COPYING TABLES AND ADVANCED INSERT
-- Clone structure and data, temporary tables, upsert, TRUNCATE
-- ============================================================================

-- 18.1 CREATE TABLE ... AS SELECT
-- Copies data (not keys or constraints)
CREATE TABLE HighSalaryEmployees AS
SELECT EmployeeID, FirstName, LastName, Role, Salary FROM Employees WHERE Salary >= 3000;
SELECT * FROM HighSalaryEmployees;

-- 18.2 CREATE TABLE ... LIKE
-- Copies the structure including keys and constraints, without data
CREATE TABLE Employees_Backup LIKE Employees;
DESCRIBE Employees_Backup;

-- 18.3 INSERT ... SELECT
INSERT INTO Employees_Backup SELECT * FROM Employees;
SELECT COUNT(*) AS BackupRows FROM Employees_Backup;

-- 18.4 Full copy: structure first, then data
CREATE TABLE Products_Copy LIKE Products;
INSERT INTO Products_Copy SELECT * FROM Products;

-- 18.5 Copy between databases
CREATE DATABASE IF NOT EXISTS CoffeeShop_Archive;
CREATE TABLE CoffeeShop_Archive.Orders_2025 AS SELECT * FROM CoffeeShop.Orders WHERE YEAR(OrderDate) = 2025;
SELECT COUNT(*) FROM CoffeeShop_Archive.Orders_2025;
DROP DATABASE CoffeeShop_Archive;

-- 18.6 Temporary tables
-- Exist only in the current session and disappear automatically
CREATE TEMPORARY TABLE BestProducts AS
SELECT ProductID, SUM(Quantity) AS UnitsSold FROM Order_Details GROUP BY ProductID ORDER BY UnitsSold DESC LIMIT 5;
SELECT p.ProductName, b.UnitsSold FROM BestProducts b JOIN Products p ON p.ProductID = b.ProductID;
DROP TEMPORARY TABLE BestProducts;

-- 18.7 INSERT IGNORE
-- Skips rows that would raise an error (duplicate keys)
INSERT IGNORE INTO Employees_Backup (EmployeeID, FirstName, LastName, Role, Email, Phone, Salary)
VALUES (1, 'Duplicate', 'Row', 'Barista', 'dup@coffeeshop.ae', '0500000000', 3000);
SHOW WARNINGS;

-- 18.8 REPLACE
-- Deletes the old row with the same key, then inserts the new one
REPLACE INTO Employees_Backup (EmployeeID, FirstName, LastName, Role, Email, Phone, HireDate, Salary)
VALUES (1, 'Abdullah', 'Mohammed', 'Barista', 'abdullah.m1@coffeeshop.ae', '0501110001', '2025-09-27 08:00:00', 4000);

-- 18.9 INSERT ... ON DUPLICATE KEY UPDATE
-- Insert a new row or update the existing one (upsert)
INSERT INTO Employees_Backup (EmployeeID, FirstName, LastName, Role, Email, Phone, HireDate, Salary)
VALUES (1, 'Abdullah', 'Mohammed', 'Barista', 'abdullah.m1@coffeeshop.ae', '0501110001', '2025-09-27 08:00:00', 4200)
ON DUPLICATE KEY UPDATE Salary = VALUES(Salary);
SELECT EmployeeID, FirstName, Salary FROM Employees_Backup WHERE EmployeeID = 1;

-- 18.10 INSERT with DEFAULT values
-- HireDate is omitted, so CURRENT_TIMESTAMP is used
INSERT INTO Employees_Backup (FirstName, LastName, Role, Email, Phone, Salary)
VALUES ('Test', 'Employee', 'Other', 'test@coffeeshop.ae', '0500000001', 1500);
INSERT INTO Employees_Backup (FirstName, LastName, Role, Phone, HireDate, Salary)
VALUES ('Test', 'Default', DEFAULT, '0500000002', DEFAULT, 1500);
SELECT * FROM Employees_Backup ORDER BY EmployeeID DESC LIMIT 2;

-- 18.11 AUTO_INCREMENT behavior
SELECT LAST_INSERT_ID();
SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'CoffeeShop' AND TABLE_NAME = 'Employees_Backup';

-- 18.12 DELETE vs TRUNCATE vs DROP
-- DELETE removes rows (can be rolled back), TRUNCATE removes all rows and resets
-- AUTO_INCREMENT (DDL, cannot be rolled back), DROP removes the whole table
DELETE FROM Employees_Backup;
INSERT INTO Employees_Backup (FirstName, LastName, Role, Phone, Salary) VALUES ('After', 'Delete', 'Other', '0500000003', 1500);
SELECT EmployeeID FROM Employees_Backup;
TRUNCATE TABLE Employees_Backup;
INSERT INTO Employees_Backup (FirstName, LastName, Role, Phone, Salary) VALUES ('After', 'Truncate', 'Other', '0500000004', 1500);
SELECT EmployeeID FROM Employees_Backup;

-- 18.13 Cleanup of the practice copies
DROP TABLE IF EXISTS HighSalaryEmployees, Employees_Backup, Products_Copy;

-- 18.14 Turn safe update mode back on
SET SQL_SAFE_UPDATES = 1;


-- ============================================================================
-- 19. VIEWS
-- Saved queries that behave like virtual tables
-- ============================================================================

-- 19.1 Simple view
-- Hides the salary column from people who only need contact details
CREATE VIEW v_EmployeeDirectory AS
SELECT EmployeeID, CONCAT(FirstName, ' ', LastName) AS FullName, Role, Email, Phone
FROM Employees;
SELECT * FROM v_EmployeeDirectory;
SELECT * FROM v_EmployeeDirectory WHERE Role = 'Barista' ORDER BY FullName;

-- 19.2 View with a filter
CREATE VIEW v_LowStock AS
SELECT ProductID, ProductName, Category, StockQuantity
FROM Products
WHERE StockQuantity < 30;
SELECT * FROM v_LowStock;

-- 19.3 View with a JOIN
CREATE VIEW v_OrderSummary AS
SELECT o.OrderID, o.OrderDate, IFNULL(CONCAT(e.FirstName, ' ', e.LastName), 'Unknown') AS Employee,
       o.OrderType, o.TotalAmount, IFNULL(pay.PaymentType, 'Unpaid') AS PaymentType
FROM Orders o
LEFT JOIN Employees e ON e.EmployeeID = o.EmployeeID
LEFT JOIN Payments pay ON pay.OrderID = o.OrderID;
SELECT * FROM v_OrderSummary;

-- 19.4 View with aggregation
CREATE VIEW v_DailySales AS
SELECT DATE(OrderDate) AS SaleDate, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue, ROUND(AVG(TotalAmount), 2) AS AverageOrder
FROM Orders
WHERE IsCompleted = TRUE
GROUP BY DATE(OrderDate);
SELECT * FROM v_DailySales ORDER BY SaleDate;
SELECT * FROM v_DailySales WHERE Revenue > 100;

-- 19.5 View built on another view
CREATE VIEW v_BestDays AS SELECT * FROM v_DailySales ORDER BY Revenue DESC LIMIT 3;
SELECT * FROM v_BestDays;

-- 19.6 Using a view in joins and subqueries
SELECT s.OrderID, s.Employee, p.ProductName
FROM v_OrderSummary s
JOIN Order_Details d ON d.OrderID = s.OrderID
JOIN Products p ON p.ProductID = d.ProductID
WHERE s.PaymentType = 'Card';

-- 19.7 Updating a view
CREATE OR REPLACE VIEW v_LowStock AS
SELECT ProductID, ProductName, Category, StockQuantity, Price
FROM Products
WHERE StockQuantity < 30
ORDER BY StockQuantity;
ALTER VIEW v_LowStock AS
SELECT ProductID, ProductName, Category, StockQuantity, ExpirationDate
FROM Products
WHERE StockQuantity < 30
ORDER BY StockQuantity;

-- 19.8 Updatable views
-- Simple views (one table, no aggregates) accept UPDATE, INSERT and DELETE
CREATE VIEW v_Baristas AS
SELECT EmployeeID, FirstName, LastName, Role, Email, Phone, Salary
FROM Employees
WHERE Role = 'Barista'
WITH CHECK OPTION;
START TRANSACTION;
UPDATE v_Baristas SET Salary = Salary + 100 WHERE EmployeeID = 1;
SELECT EmployeeID, FirstName, Salary FROM Employees WHERE EmployeeID = 1;
ROLLBACK;
-- WITH CHECK OPTION rejects changes that would hide the row from the view:
-- UPDATE v_Baristas SET Role = 'Manager' WHERE EmployeeID = 1;

-- 19.9 Inspecting views
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SHOW CREATE VIEW v_OrderSummary;
SELECT TABLE_NAME, IS_UPDATABLE FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'CoffeeShop';

-- 19.10 DROP VIEW
DROP VIEW v_BestDays;
DROP VIEW IF EXISTS v_Baristas, v_BestDays;


-- ============================================================================
-- 20. INDEXES AND EXPLAIN
-- Make searches fast and understand how MySQL runs a query
-- ============================================================================

-- 20.1 Existing indexes
-- PRIMARY KEY, UNIQUE and FOREIGN KEY columns are indexed automatically
SHOW INDEX FROM Orders;
SHOW INDEXES FROM Employees;
SHOW KEYS FROM Products;

-- 20.2 CREATE INDEX
CREATE INDEX idx_orders_date ON Orders (OrderDate);
CREATE INDEX idx_employees_lastname ON Employees (LastName);

-- 20.3 UNIQUE INDEX
CREATE UNIQUE INDEX uq_products_name ON Products (ProductName);

-- 20.4 Composite index
-- Column order matters: the leftmost column must be used in the search
CREATE INDEX idx_orders_type_date ON Orders (OrderType, OrderDate);

-- 20.5 Prefix index
CREATE INDEX idx_suppliers_company ON Suppliers (CompanyName(10));

-- 20.6 Descending and functional indexes (MySQL 8.0)
CREATE INDEX idx_products_price_desc ON Products (Price DESC);
CREATE INDEX idx_orders_month ON Orders ((MONTH(OrderDate)));

-- 20.7 FULLTEXT index
CREATE FULLTEXT INDEX ft_products_name ON Products (ProductName);
SELECT ProductName FROM Products WHERE MATCH(ProductName) AGAINST('chocolate');
SELECT ProductName, MATCH(ProductName) AGAINST('chocolate cake' IN NATURAL LANGUAGE MODE) AS Score
FROM Products WHERE MATCH(ProductName) AGAINST('chocolate cake' IN NATURAL LANGUAGE MODE);
SELECT ProductName FROM Products WHERE MATCH(ProductName) AGAINST('+coffee -beans' IN BOOLEAN MODE);
SELECT ProductName FROM Products WHERE MATCH(ProductName) AGAINST('late*' IN BOOLEAN MODE);

-- 20.8 EXPLAIN
-- type = ALL means a full table scan, ref / range / const use an index
EXPLAIN SELECT * FROM Orders WHERE OrderDate = '2025-10-01 08:15:00';
EXPLAIN SELECT * FROM Orders WHERE OrderType = 'Takeaway' AND OrderDate >= '2025-10-02';
EXPLAIN SELECT * FROM Employees WHERE LastName = 'Alketbi';
EXPLAIN SELECT * FROM Employees WHERE FirstName = 'Sara';
EXPLAIN SELECT o.OrderID, e.FirstName FROM Orders o JOIN Employees e ON e.EmployeeID = o.EmployeeID;
EXPLAIN FORMAT = TREE SELECT * FROM Orders WHERE EmployeeID = 3;
EXPLAIN ANALYZE SELECT * FROM Orders WHERE EmployeeID = 3;

-- 20.9 Index hints
SELECT * FROM Orders USE INDEX (idx_orders_date) WHERE OrderDate >= '2025-10-05';
SELECT * FROM Orders FORCE INDEX (idx_orders_type_date) WHERE OrderType = 'Takeaway';
SELECT * FROM Orders IGNORE INDEX (idx_orders_date) WHERE OrderDate >= '2025-10-05';

-- 20.10 Invisible indexes
-- Test the effect of dropping an index without really dropping it
ALTER TABLE Orders ALTER INDEX idx_orders_date INVISIBLE;
ALTER TABLE Orders ALTER INDEX idx_orders_date VISIBLE;

-- 20.11 Index maintenance
ANALYZE TABLE Orders;
CHECK TABLE Orders;
OPTIMIZE TABLE Orders;
SHOW INDEX FROM Orders;

-- 20.12 ADD INDEX with ALTER TABLE
ALTER TABLE Attendance ADD INDEX idx_attendance_date (Date);

-- 20.13 DROP INDEX
DROP INDEX idx_orders_date ON Orders;
DROP INDEX idx_employees_lastname ON Employees;
DROP INDEX uq_products_name ON Products;
DROP INDEX idx_orders_type_date ON Orders;
DROP INDEX idx_suppliers_company ON Suppliers;
DROP INDEX idx_products_price_desc ON Products;
DROP INDEX idx_orders_month ON Orders;
DROP INDEX ft_products_name ON Products;
ALTER TABLE Attendance DROP INDEX idx_attendance_date;
SHOW INDEX FROM Orders;


-- ============================================================================
-- 21. VARIABLES AND PREPARED STATEMENTS
-- User variables, system variables, warnings, dynamic SQL
-- ============================================================================

-- 21.1 User-defined variables
SET @MinSalary = 3000;
SET @Role = 'Barista', @Bonus = 250;
SELECT @MinSalary, @Role, @Bonus;
SELECT FirstName, Salary FROM Employees WHERE Salary >= @MinSalary AND Role = @Role;

-- 21.2 Assigning values from queries
SELECT COUNT(*) INTO @EmployeeCount FROM Employees;
SELECT MAX(Price), MIN(Price) INTO @MaxPrice, @MinPrice FROM Products;
SET @AveragePrice = (SELECT AVG(Price) FROM Products);
SELECT @EmployeeCount, @MaxPrice, @MinPrice, @AveragePrice;
SELECT @Counter := 0;
SELECT @Counter := @Counter + 1;

-- 21.3 Using variables in calculations
SELECT ProductName, Price, ROUND(Price * (1 + @Bonus / 1000), 2) AS NewPrice FROM Products LIMIT 5;

-- 21.4 System variables
SHOW VARIABLES LIKE 'version%';
SHOW VARIABLES LIKE 'character_set%';
SHOW VARIABLES LIKE '%isolation%';
SELECT @@version, @@global.max_connections, @@session.autocommit, @@sql_mode;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';
SET SESSION sql_mode = DEFAULT;

-- 21.5 Status and process information
SHOW STATUS LIKE 'Threads_connected';
SHOW PROCESSLIST;

-- 21.6 Warnings and errors
SELECT CAST('12abc' AS UNSIGNED);
SHOW WARNINGS;
SELECT @@warning_count;
SHOW ERRORS;

-- 21.7 Prepared statements
-- The query is parsed once and executed many times with different values
PREPARE FindByRole FROM 'SELECT FirstName, Salary FROM Employees WHERE Role = ? AND Salary >= ?';
SET @r = 'Barista', @s = 3000;
EXECUTE FindByRole USING @r, @s;
SET @r = 'Cashier', @s = 2000;
EXECUTE FindByRole USING @r, @s;
DEALLOCATE PREPARE FindByRole;

-- 21.8 Prepared statements with LIMIT
PREPARE TopProducts FROM 'SELECT ProductName, Price FROM Products ORDER BY Price DESC LIMIT ?';
SET @n = 3;
EXECUTE TopProducts USING @n;
DEALLOCATE PREPARE TopProducts;

-- 21.9 Dynamic SQL
-- Table and column names cannot be parameters, so build the text with CONCAT
SET @TableName = 'Suppliers';
SET @Query = CONCAT('SELECT COUNT(*) AS RowsInTable FROM ', @TableName);
PREPARE DynamicCount FROM @Query;
EXECUTE DynamicCount;
DEALLOCATE PREPARE DynamicCount;

-- 21.10 Why prepared statements matter
-- Values passed with USING are never executed as SQL (protection from SQL injection)


-- ============================================================================
-- 22. STORED PROCEDURES, FUNCTIONS AND CURSORS
-- Programs saved inside the database
-- ============================================================================

-- 22.1 The DELIMITER command
-- The body of a procedure contains semicolons, so the client delimiter is changed temporarily

-- 22.2 Procedure without parameters
DROP PROCEDURE IF EXISTS sp_ShowEmployees;
DELIMITER //
CREATE PROCEDURE sp_ShowEmployees()
BEGIN
    SELECT EmployeeID, FirstName, LastName, Role, Salary FROM Employees ORDER BY EmployeeID;
END //
DELIMITER ;
CALL sp_ShowEmployees();

-- 22.3 IN parameter
DROP PROCEDURE IF EXISTS sp_EmployeesByRole;
DELIMITER //
CREATE PROCEDURE sp_EmployeesByRole(IN p_Role VARCHAR(20))
BEGIN
    SELECT EmployeeID, FirstName, LastName, Salary FROM Employees WHERE Role = p_Role ORDER BY Salary DESC;
END //
DELIMITER ;
CALL sp_EmployeesByRole('Barista');
CALL sp_EmployeesByRole('Cashier');

-- 22.4 OUT parameter
DROP PROCEDURE IF EXISTS sp_CountByRole;
DELIMITER //
CREATE PROCEDURE sp_CountByRole(IN p_Role VARCHAR(20), OUT p_Total INT)
BEGIN
    SELECT COUNT(*) INTO p_Total FROM Employees WHERE Role = p_Role;
END //
DELIMITER ;
CALL sp_CountByRole('Barista', @BaristaCount);
SELECT @BaristaCount;

-- 22.5 INOUT parameter
DROP PROCEDURE IF EXISTS sp_AddBonus;
DELIMITER //
CREATE PROCEDURE sp_AddBonus(INOUT p_Amount DECIMAL(10,2), IN p_Percent DECIMAL(5,2))
BEGIN
    SET p_Amount = p_Amount + p_Amount * p_Percent / 100;
END //
DELIMITER ;
SET @Salary = 3000;
CALL sp_AddBonus(@Salary, 10);
SELECT @Salary;

-- 22.6 Local variables: DECLARE, SET, SELECT INTO
DROP PROCEDURE IF EXISTS sp_EmployeeSummary;
DELIMITER //
CREATE PROCEDURE sp_EmployeeSummary(IN p_EmployeeID INT)
BEGIN
    DECLARE v_Name VARCHAR(101);
    DECLARE v_Orders INT DEFAULT 0;
    DECLARE v_Revenue DECIMAL(10,2) DEFAULT 0;

    SELECT CONCAT(FirstName, ' ', LastName) INTO v_Name FROM Employees WHERE EmployeeID = p_EmployeeID;
    SELECT COUNT(*), IFNULL(SUM(TotalAmount), 0) INTO v_Orders, v_Revenue FROM Orders WHERE EmployeeID = p_EmployeeID;

    SELECT v_Name AS Employee, v_Orders AS Orders, v_Revenue AS Revenue;
END //
DELIMITER ;
CALL sp_EmployeeSummary(3);

-- 22.7 IF / ELSEIF / ELSE
DROP PROCEDURE IF EXISTS sp_OrdersByStatus;
DELIMITER //
CREATE PROCEDURE sp_OrdersByStatus(IN p_Status VARCHAR(20))
BEGIN
    IF p_Status = 'Completed' THEN
        SELECT OrderID, OrderDate, OrderType, TotalAmount FROM Orders WHERE IsCompleted = TRUE;
    ELSEIF p_Status = 'Pending' THEN
        SELECT OrderID, OrderDate, OrderType, TotalAmount FROM Orders WHERE IsCompleted = FALSE;
    ELSE
        SELECT OrderID, OrderDate, OrderType, TotalAmount, IsCompleted FROM Orders;
    END IF;
END //
DELIMITER ;
CALL sp_OrdersByStatus('Completed');
CALL sp_OrdersByStatus('Pending');
CALL sp_OrdersByStatus('All');

-- 22.8 CASE statement
DROP PROCEDURE IF EXISTS sp_ShiftInfo;
DELIMITER //
CREATE PROCEDURE sp_ShiftInfo(IN p_Hour INT)
BEGIN
    CASE
        WHEN p_Hour < 12 THEN SELECT 'Morning shift' AS Shift;
        WHEN p_Hour < 17 THEN SELECT 'Afternoon shift' AS Shift;
        ELSE SELECT 'Evening shift' AS Shift;
    END CASE;
END //
DELIMITER ;
CALL sp_ShiftInfo(9);
CALL sp_ShiftInfo(19);

-- 22.9 WHILE loop
DROP PROCEDURE IF EXISTS sp_DailyReport;
DELIMITER //
CREATE PROCEDURE sp_DailyReport(IN p_Start DATE, IN p_Days INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_DailyReport (SaleDate DATE, Orders INT, Revenue DECIMAL(10,2));
    TRUNCATE TABLE tmp_DailyReport;

    WHILE i < p_Days DO
        INSERT INTO tmp_DailyReport
        SELECT p_Start + INTERVAL i DAY, COUNT(*), IFNULL(SUM(TotalAmount), 0)
        FROM Orders WHERE DATE(OrderDate) = p_Start + INTERVAL i DAY;
        SET i = i + 1;
    END WHILE;

    SELECT * FROM tmp_DailyReport;
    DROP TEMPORARY TABLE tmp_DailyReport;
END //
DELIMITER ;
CALL sp_DailyReport('2025-10-01', 7);

-- 22.10 REPEAT loop
DROP PROCEDURE IF EXISTS sp_CountDown;
DELIMITER //
CREATE PROCEDURE sp_CountDown(IN p_Start INT)
BEGIN
    DECLARE n INT DEFAULT p_Start;
    DECLARE result VARCHAR(200) DEFAULT '';
    REPEAT
        SET result = CONCAT(result, n, ' ');
        SET n = n - 1;
    UNTIL n = 0 END REPEAT;
    SELECT result AS CountDown;
END //
DELIMITER ;
CALL sp_CountDown(5);

-- 22.11 LOOP with LEAVE and ITERATE
DROP PROCEDURE IF EXISTS sp_OddNumbers;
DELIMITER //
CREATE PROCEDURE sp_OddNumbers(IN p_Max INT)
BEGIN
    DECLARE n INT DEFAULT 0;
    DECLARE result VARCHAR(200) DEFAULT '';
    numbers: LOOP
        SET n = n + 1;
        IF n > p_Max THEN LEAVE numbers; END IF;
        IF n MOD 2 = 0 THEN ITERATE numbers; END IF;
        SET result = CONCAT(result, n, ' ');
    END LOOP numbers;
    SELECT result AS OddNumbers;
END //
DELIMITER ;
CALL sp_OddNumbers(10);

-- 22.12 Error handling: SIGNAL and HANDLER
-- A realistic sale: everything succeeds together or nothing is saved
DROP PROCEDURE IF EXISTS sp_PlaceOrder;
DELIMITER //
CREATE PROCEDURE sp_PlaceOrder(IN p_EmployeeID INT, IN p_ProductID INT, IN p_Quantity INT,
                               IN p_CardID INT, IN p_PaymentType VARCHAR(20), OUT p_OrderID INT)
BEGIN
    DECLARE v_Price DECIMAL(10,2);
    DECLARE v_Stock INT;
    DECLARE v_Total DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT Price, StockQuantity INTO v_Price, v_Stock FROM Products WHERE ProductID = p_ProductID;

    IF v_Price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product does not exist';
    END IF;
    IF v_Stock < p_Quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough stock';
    END IF;

    SET v_Total = v_Price * p_Quantity;

    START TRANSACTION;
    INSERT INTO Orders (EmployeeID, IsCompleted, OrderType, LoyaltyCardID, TotalAmount)
    VALUES (p_EmployeeID, TRUE, 'Takeaway', p_CardID, v_Total);
    SET p_OrderID = LAST_INSERT_ID();
    INSERT INTO Order_Details (OrderID, ProductID, Quantity, UnitPrice) VALUES (p_OrderID, p_ProductID, p_Quantity, v_Price);
    INSERT INTO Payments (OrderID, PaymentType, Amount) VALUES (p_OrderID, p_PaymentType, v_Total);
    UPDATE Products SET StockQuantity = StockQuantity - p_Quantity WHERE ProductID = p_ProductID;
    COMMIT;
END //
DELIMITER ;
CALL sp_PlaceOrder(3, 3, 2, 1, 'Card', @NewOrderID);
SELECT @NewOrderID;
SELECT * FROM Orders WHERE OrderID = @NewOrderID;
SELECT ProductName, StockQuantity FROM Products WHERE ProductID = 3;
-- Reusable Cup has no stock, so the next call raises "Not enough stock":
-- CALL sp_PlaceOrder(3, 16, 1, NULL, 'Cash', @NewOrderID);

-- 22.13 HANDLER types and GET DIAGNOSTICS
DROP PROCEDURE IF EXISTS sp_TryInsertEmployee;
DELIMITER //
CREATE PROCEDURE sp_TryInsertEmployee(IN p_Email VARCHAR(100))
BEGIN
    DECLARE v_Code INT;
    DECLARE v_Message TEXT;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_Code = MYSQL_ERRNO, v_Message = MESSAGE_TEXT;
        SELECT v_Code AS ErrorCode, v_Message AS ErrorMessage;
    END;

    INSERT INTO Employees (FirstName, LastName, Role, Email, Phone, Salary)
    VALUES ('Test', 'User', 'Other', p_Email, '0500000000', 1500);
END //
DELIMITER ;
CALL sp_TryInsertEmployee('ali.m@coffeeshop.ae');

-- 22.14 Cursor
-- Reads a query result row by row
DROP PROCEDURE IF EXISTS sp_ReorderReport;
DELIMITER //
CREATE PROCEDURE sp_ReorderReport(IN p_Limit INT)
BEGIN
    DECLARE v_Done INT DEFAULT 0;
    DECLARE v_Name VARCHAR(100);
    DECLARE v_Stock INT;
    DECLARE v_Supplier VARCHAR(100);

    DECLARE cur CURSOR FOR
        SELECT p.ProductName, p.StockQuantity, IFNULL(s.CompanyName, 'No supplier')
        FROM Products p LEFT JOIN Suppliers s ON s.SupplierID = p.SupplierID
        WHERE p.StockQuantity < p_Limit
        ORDER BY p.StockQuantity;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_Done = 1;

    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Reorder (Message VARCHAR(255));
    TRUNCATE TABLE tmp_Reorder;

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_Name, v_Stock, v_Supplier;
        IF v_Done = 1 THEN LEAVE read_loop; END IF;
        INSERT INTO tmp_Reorder VALUES (CONCAT('Reorder ', v_Name, ' (', v_Stock, ' left) from ', v_Supplier));
    END LOOP;
    CLOSE cur;

    SELECT * FROM tmp_Reorder;
    DROP TEMPORARY TABLE tmp_Reorder;
END //
DELIMITER ;
CALL sp_ReorderReport(30);

-- 22.15 Dynamic SQL inside a procedure
DROP PROCEDURE IF EXISTS sp_CountRows;
DELIMITER //
CREATE PROCEDURE sp_CountRows(IN p_Table VARCHAR(64))
BEGIN
    SET @sql = CONCAT('SELECT ''', p_Table, ''' AS TableName, COUNT(*) AS TotalRows FROM `', p_Table, '`');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;
CALL sp_CountRows('Employees');
CALL sp_CountRows('Order_Details');

-- 22.16 Stored functions
-- A function returns one value and can be used inside any query
DROP FUNCTION IF EXISTS fn_FullName;
DROP FUNCTION IF EXISTS fn_ProfitMargin;
DROP FUNCTION IF EXISTS fn_LoyaltyTier;
DROP FUNCTION IF EXISTS fn_OrderItems;
DELIMITER //
CREATE FUNCTION fn_FullName(p_EmployeeID INT) RETURNS VARCHAR(101)
READS SQL DATA
BEGIN
    DECLARE v_Name VARCHAR(101);
    SELECT CONCAT(FirstName, ' ', LastName) INTO v_Name FROM Employees WHERE EmployeeID = p_EmployeeID;
    RETURN v_Name;
END //

CREATE FUNCTION fn_ProfitMargin(p_Price DECIMAL(10,2), p_Cost DECIMAL(10,2)) RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    RETURN ROUND((p_Price - p_Cost) / p_Price * 100, 2);
END //

CREATE FUNCTION fn_LoyaltyTier(p_Points INT) RETURNS VARCHAR(10)
DETERMINISTIC
BEGIN
    IF p_Points >= 250 THEN
        RETURN 'Gold';
    ELSEIF p_Points >= 100 THEN
        RETURN 'Silver';
    ELSE
        RETURN 'Bronze';
    END IF;
END //

CREATE FUNCTION fn_OrderItems(p_OrderID INT) RETURNS INT
READS SQL DATA
BEGIN
    RETURN (SELECT IFNULL(SUM(Quantity), 0) FROM Order_Details WHERE OrderID = p_OrderID);
END //
DELIMITER ;

SELECT fn_FullName(3);
SELECT EmployeeID, fn_FullName(EmployeeID) AS FullName, Role FROM Employees;
SELECT ProductName, Price, Cost, fn_ProfitMargin(Price, Cost) AS MarginPercent FROM Products ORDER BY MarginPercent DESC;
SELECT CardNumber, Points, fn_LoyaltyTier(Points) AS Tier FROM LoyaltyCards;
SELECT OrderID, fn_OrderItems(OrderID) AS Items, TotalAmount FROM Orders;
SELECT * FROM Products WHERE fn_ProfitMargin(Price, Cost) > 60;

-- 22.17 Inspecting stored programs
SHOW PROCEDURE STATUS WHERE Db = 'CoffeeShop';
SHOW FUNCTION STATUS WHERE Db = 'CoffeeShop';
SHOW CREATE PROCEDURE sp_PlaceOrder;
SELECT ROUTINE_NAME, ROUTINE_TYPE FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = 'CoffeeShop' ORDER BY ROUTINE_TYPE, ROUTINE_NAME;

-- 22.18 Cleanup of the practice procedures
-- sp_PlaceOrder and the fn_ functions are kept for the next sections
DROP PROCEDURE IF EXISTS sp_ShowEmployees;
DROP PROCEDURE IF EXISTS sp_EmployeesByRole;
DROP PROCEDURE IF EXISTS sp_CountByRole;
DROP PROCEDURE IF EXISTS sp_AddBonus;
DROP PROCEDURE IF EXISTS sp_EmployeeSummary;
DROP PROCEDURE IF EXISTS sp_OrdersByStatus;
DROP PROCEDURE IF EXISTS sp_ShiftInfo;
DROP PROCEDURE IF EXISTS sp_DailyReport;
DROP PROCEDURE IF EXISTS sp_CountDown;
DROP PROCEDURE IF EXISTS sp_OddNumbers;
DROP PROCEDURE IF EXISTS sp_TryInsertEmployee;
DROP PROCEDURE IF EXISTS sp_ReorderReport;
DROP PROCEDURE IF EXISTS sp_CountRows;


-- ============================================================================
-- 23. TRIGGERS AND EVENTS
-- Code that runs automatically: on data changes (triggers) or on a schedule (events)
-- ============================================================================

-- 23.1 Helper tables for logging
-- The eight original tables are not touched
CREATE TABLE IF NOT EXISTS Salary_History (
    HistoryID INT AUTO_INCREMENT PRIMARY KEY,
    EmployeeID INT NOT NULL,
    OldSalary DECIMAL(10,2),
    NewSalary DECIMAL(10,2),
    ChangedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS Audit_Log (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    TableName VARCHAR(50),
    Action VARCHAR(20),
    Details VARCHAR(255),
    LoggedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 23.2 AFTER UPDATE trigger
-- OLD = the row before the change, NEW = the row after the change
DROP TRIGGER IF EXISTS trg_salary_history;
DELIMITER //
CREATE TRIGGER trg_salary_history
AFTER UPDATE ON Employees
FOR EACH ROW
BEGIN
    IF OLD.Salary <> NEW.Salary THEN
        INSERT INTO Salary_History (EmployeeID, OldSalary, NewSalary) VALUES (OLD.EmployeeID, OLD.Salary, NEW.Salary);
    END IF;
END //
DELIMITER ;

START TRANSACTION;
UPDATE Employees SET Salary = Salary + 300 WHERE EmployeeID = 6;
SELECT * FROM Salary_History;
ROLLBACK;

-- 23.3 BEFORE UPDATE trigger
-- Validates or changes data before it is saved
DROP TRIGGER IF EXISTS trg_salary_no_decrease;
DELIMITER //
CREATE TRIGGER trg_salary_no_decrease
BEFORE UPDATE ON Employees
FOR EACH ROW
BEGIN
    IF NEW.Salary < OLD.Salary THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Salary cannot be decreased';
    END IF;
END //
DELIMITER ;
-- UPDATE Employees SET Salary = 1000 WHERE EmployeeID = 2;

-- 23.4 BEFORE INSERT trigger
-- Cleans data automatically
DROP TRIGGER IF EXISTS trg_employee_clean;
DELIMITER //
CREATE TRIGGER trg_employee_clean
BEFORE INSERT ON Employees
FOR EACH ROW
BEGIN
    SET NEW.FirstName = TRIM(NEW.FirstName);
    SET NEW.LastName = TRIM(NEW.LastName);
    SET NEW.Email = LOWER(NEW.Email);
END //
DELIMITER ;

DROP TRIGGER IF EXISTS trg_card_upper;
DELIMITER //
CREATE TRIGGER trg_card_upper
BEFORE INSERT ON LoyaltyCards
FOR EACH ROW
BEGIN
    SET NEW.CardNumber = UPPER(NEW.CardNumber);
END //
DELIMITER ;

START TRANSACTION;
INSERT INTO Employees (FirstName, LastName, Role, Email, Phone, Salary) VALUES ('  Hind ', ' Almazrouei ', 'Cashier', 'HIND.M@CoffeeShop.AE', '0501110013', 2600);
INSERT INTO LoyaltyCards (CardNumber, IssueDate) VALUES ('lc-1007', '2025-11-01');
SELECT FirstName, LastName, Email FROM Employees WHERE Phone = '0501110013';
SELECT CardNumber FROM LoyaltyCards WHERE CardNumber LIKE 'LC-1007';
ROLLBACK;

-- 23.5 AFTER INSERT trigger
-- Every payment adds loyalty points to the card used in the order (1 point per currency unit)
DROP TRIGGER IF EXISTS trg_payment_points;
DELIMITER //
CREATE TRIGGER trg_payment_points
AFTER INSERT ON Payments
FOR EACH ROW
BEGIN
    UPDATE LoyaltyCards
    SET Points = Points + FLOOR(NEW.Amount)
    WHERE CardID = (SELECT LoyaltyCardID FROM Orders WHERE OrderID = NEW.OrderID);
END //
DELIMITER ;
SELECT CardID, CardNumber, Points FROM LoyaltyCards WHERE CardID = 1;
CALL sp_PlaceOrder(3, 5, 2, 1, 'Card', @NewOrderID);
SELECT CardID, CardNumber, Points FROM LoyaltyCards WHERE CardID = 1;

-- 23.6 AFTER UPDATE trigger on stock
DROP TRIGGER IF EXISTS trg_low_stock;
DELIMITER //
CREATE TRIGGER trg_low_stock
AFTER UPDATE ON Products
FOR EACH ROW
BEGIN
    IF NEW.StockQuantity < 10 AND OLD.StockQuantity >= 10 THEN
        INSERT INTO Audit_Log (TableName, Action, Details)
        VALUES ('Products', 'LOW STOCK', CONCAT(NEW.ProductName, ' dropped to ', NEW.StockQuantity));
    END IF;
END //
DELIMITER ;
START TRANSACTION;
UPDATE Products SET StockQuantity = 5 WHERE ProductID = 13;
SELECT * FROM Audit_Log;
ROLLBACK;

-- 23.7 BEFORE DELETE trigger
-- Protects completed orders from being deleted
DROP TRIGGER IF EXISTS trg_protect_orders;
DELIMITER //
CREATE TRIGGER trg_protect_orders
BEFORE DELETE ON Orders
FOR EACH ROW
BEGIN
    IF OLD.IsCompleted = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed orders cannot be deleted';
    END IF;
END //
DELIMITER ;
-- DELETE FROM Orders WHERE OrderID = 1;
DELETE FROM Orders WHERE OrderID = 14;

-- 23.8 AFTER DELETE trigger
-- Keeps a record of removed employees
DROP TRIGGER IF EXISTS trg_employee_deleted;
DELIMITER //
CREATE TRIGGER trg_employee_deleted
AFTER DELETE ON Employees
FOR EACH ROW
BEGIN
    INSERT INTO Audit_Log (TableName, Action, Details)
    VALUES ('Employees', 'DELETE', CONCAT(OLD.FirstName, ' ', OLD.LastName, ' (', OLD.Role, ')'));
END //
DELIMITER ;
START TRANSACTION;
DELETE FROM Employees WHERE EmployeeID = 12;
SELECT * FROM Audit_Log;
ROLLBACK;

-- 23.9 Inspecting triggers
SHOW TRIGGERS;
SELECT TRIGGER_NAME, EVENT_MANIPULATION, EVENT_OBJECT_TABLE, ACTION_TIMING FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = 'CoffeeShop';
SHOW CREATE TRIGGER trg_payment_points;

-- 23.10 Trigger rules
-- 6 types: BEFORE / AFTER x INSERT / UPDATE / DELETE
-- Actions caused by foreign keys (CASCADE, SET NULL) do not fire triggers
-- A trigger cannot COMMIT or ROLLBACK and cannot change the table it is defined on

-- 23.11 DROP TRIGGER
DROP TRIGGER IF EXISTS trg_salary_no_decrease;
DROP TRIGGER IF EXISTS trg_protect_orders;
DROP TRIGGER IF EXISTS trg_low_stock;
SHOW TRIGGERS;

-- 23.12 Events
-- The event scheduler must be ON
SHOW VARIABLES LIKE 'event_scheduler';
SET GLOBAL event_scheduler = ON;

CREATE TABLE IF NOT EXISTS Daily_Sales_Summary (
    SummaryDate DATE PRIMARY KEY,
    OrdersCount INT,
    Revenue DECIMAL(10,2)
);

-- 23.13 One-time event
DROP EVENT IF EXISTS ev_run_once;
CREATE EVENT ev_run_once
ON SCHEDULE AT CURRENT_TIMESTAMP + INTERVAL 1 SECOND
ON COMPLETION PRESERVE
DO
    REPLACE INTO Daily_Sales_Summary
    SELECT DATE(OrderDate), COUNT(*), SUM(TotalAmount) FROM Orders WHERE IsCompleted = TRUE GROUP BY DATE(OrderDate);
SELECT SLEEP(3);
SELECT * FROM Daily_Sales_Summary ORDER BY SummaryDate;

-- 23.14 Recurring event
DROP EVENT IF EXISTS ev_daily_summary;
CREATE EVENT ev_daily_summary
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_DATE + INTERVAL 1 DAY - INTERVAL 1 MINUTE
COMMENT 'Saves the sales of the day just before midnight'
DO
    REPLACE INTO Daily_Sales_Summary
    SELECT CURRENT_DATE, COUNT(*), IFNULL(SUM(TotalAmount), 0) FROM Orders WHERE DATE(OrderDate) = CURRENT_DATE;

-- 23.15 Managing events
SHOW EVENTS;
ALTER EVENT ev_daily_summary DISABLE;
ALTER EVENT ev_daily_summary ENABLE;
SELECT EVENT_NAME, STATUS, EVENT_TYPE, INTERVAL_VALUE, INTERVAL_FIELD FROM information_schema.EVENTS WHERE EVENT_SCHEMA = 'CoffeeShop';
DROP EVENT IF EXISTS ev_run_once;
DROP EVENT IF EXISTS ev_daily_summary;


-- ============================================================================
-- 24. USERS, PRIVILEGES, BACKUP AND METADATA
-- Security, exporting data and reading the database dictionary
-- ============================================================================

-- 24.1 Users
DROP USER IF EXISTS 'barista_user'@'localhost';
DROP USER IF EXISTS 'manager_user'@'localhost';
CREATE USER 'barista_user'@'localhost' IDENTIFIED BY 'Barista#2025';
CREATE USER 'manager_user'@'localhost' IDENTIFIED BY 'Manager#2025';
SELECT User, Host FROM mysql.user WHERE User LIKE '%_user';

-- 24.2 GRANT
GRANT SELECT ON CoffeeShop.Products TO 'barista_user'@'localhost';
GRANT SELECT, INSERT ON CoffeeShop.Orders TO 'barista_user'@'localhost';
GRANT SELECT (FirstName, LastName, Role) ON CoffeeShop.Employees TO 'barista_user'@'localhost';
GRANT EXECUTE ON PROCEDURE CoffeeShop.sp_PlaceOrder TO 'barista_user'@'localhost';
GRANT ALL PRIVILEGES ON CoffeeShop.* TO 'manager_user'@'localhost' WITH GRANT OPTION;
SHOW GRANTS FOR 'barista_user'@'localhost';
SHOW GRANTS FOR 'manager_user'@'localhost';

-- 24.3 REVOKE
REVOKE INSERT ON CoffeeShop.Orders FROM 'barista_user'@'localhost';
SHOW GRANTS FOR 'barista_user'@'localhost';

-- 24.4 Roles
DROP ROLE IF EXISTS 'cashier_role';
CREATE ROLE 'cashier_role';
GRANT SELECT ON CoffeeShop.* TO 'cashier_role';
GRANT INSERT, UPDATE ON CoffeeShop.Orders TO 'cashier_role';
GRANT INSERT ON CoffeeShop.Order_Details TO 'cashier_role';
GRANT INSERT ON CoffeeShop.Payments TO 'cashier_role';
GRANT 'cashier_role' TO 'barista_user'@'localhost';
SET DEFAULT ROLE 'cashier_role' TO 'barista_user'@'localhost';
SHOW GRANTS FOR 'barista_user'@'localhost' USING 'cashier_role';

-- 24.5 Managing users
ALTER USER 'barista_user'@'localhost' IDENTIFIED BY 'NewBarista#2026';
ALTER USER 'barista_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'barista_user'@'localhost' WITH MAX_QUERIES_PER_HOUR 1000;
FLUSH PRIVILEGES;

-- 24.6 Removing users and roles
DROP USER 'barista_user'@'localhost';
DROP USER 'manager_user'@'localhost';
DROP ROLE 'cashier_role';

-- 24.7 Backup and restore (run from the operating system terminal, not inside MySQL)
-- Full database backup:      mysqldump -u root -p CoffeeShop > CoffeeShop_backup.sql
-- With routines and events:  mysqldump -u root -p --routines --events --triggers CoffeeShop > CoffeeShop_full.sql
-- One table only:            mysqldump -u root -p CoffeeShop Employees > Employees.sql
-- Structure only:            mysqldump -u root -p --no-data CoffeeShop > CoffeeShop_structure.sql
-- Restore:                   mysql -u root -p CoffeeShop < CoffeeShop_backup.sql
-- Run a script file from the mysql client:  SOURCE C:/scripts/CoffeeShop.sql;

-- 24.8 Exporting and importing files
-- Needs the FILE privilege and a folder allowed by secure_file_priv
SHOW VARIABLES LIKE 'secure_file_priv';
-- SELECT * FROM Products INTO OUTFILE '/var/lib/mysql-files/products.csv'
--     FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n';
-- LOAD DATA INFILE '/var/lib/mysql-files/products.csv' INTO TABLE Products_Copy
--     FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n';

-- 24.9 Generated columns
-- A column calculated automatically from other columns
CREATE TABLE Pricing_Demo (
    ProductName VARCHAR(50),
    Price DECIMAL(10,2),
    Cost DECIMAL(10,2),
    Profit DECIMAL(10,2) GENERATED ALWAYS AS (Price - Cost) VIRTUAL,
    ProfitPercent DECIMAL(5,2) GENERATED ALWAYS AS (ROUND((Price - Cost) / Price * 100, 2)) STORED
);
INSERT INTO Pricing_Demo (ProductName, Price, Cost) SELECT ProductName, Price, Cost FROM Products;
SELECT * FROM Pricing_Demo;
DROP TABLE Pricing_Demo;

-- 24.10 Partitioning
-- Splits a big table into parts (the partition column must be part of the primary key)
CREATE TABLE Orders_Partitioned (
    OrderID INT NOT NULL,
    OrderDate DATE NOT NULL,
    TotalAmount DECIMAL(10,2),
    PRIMARY KEY (OrderID, OrderDate)
)
PARTITION BY RANGE (YEAR(OrderDate)) (
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION pmax VALUES LESS THAN MAXVALUE
);
INSERT INTO Orders_Partitioned SELECT OrderID, DATE(OrderDate), TotalAmount FROM Orders;
SELECT PARTITION_NAME, TABLE_ROWS FROM information_schema.PARTITIONS WHERE TABLE_SCHEMA = 'CoffeeShop' AND TABLE_NAME = 'Orders_Partitioned';
SELECT * FROM Orders_Partitioned PARTITION (p2025) LIMIT 3;
DROP TABLE Orders_Partitioned;

-- 24.11 Information schema
-- The data dictionary: MySQL describes itself in tables
SELECT TABLE_NAME, TABLE_ROWS, ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'CoffeeShop' ORDER BY TABLE_NAME;
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_DEFAULT
FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'CoffeeShop' AND TABLE_NAME = 'Products';
SELECT TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = 'CoffeeShop' AND REFERENCED_TABLE_NAME IS NOT NULL;
SELECT CONSTRAINT_NAME, TABLE_NAME, DELETE_RULE, UPDATE_RULE FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = 'CoffeeShop';
SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = 'CoffeeShop' ORDER BY TABLE_NAME;
SELECT TABLE_NAME, ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024, 1) AS SizeKB FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'CoffeeShop' ORDER BY SizeKB DESC;
SELECT COUNT(*) AS TotalColumns FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'CoffeeShop';

-- 24.12 Server information
SHOW STATUS LIKE 'Uptime';
SHOW GLOBAL VARIABLES LIKE 'max_connections';
SHOW ENGINE INNODB STATUS;


-- ============================================================================
-- 25. FINAL PRACTICE: BUSINESS REPORTS
-- Real questions of the coffee shop owner answered with everything learned
-- ============================================================================

-- 25.1 Revenue per day with a running total
SELECT SaleDate, Orders, Revenue, SUM(Revenue) OVER (ORDER BY SaleDate) AS RunningRevenue FROM v_DailySales;

-- 25.2 Best selling products
SELECT p.ProductName, p.Category, SUM(d.Quantity) AS UnitsSold,
       ROUND(SUM(d.Quantity * d.UnitPrice * (1 - d.Discount / 100)), 2) AS Revenue
FROM Order_Details d JOIN Products p ON p.ProductID = d.ProductID
GROUP BY p.ProductID, p.ProductName, p.Category
ORDER BY UnitsSold DESC, Revenue DESC
LIMIT 5;

-- 25.3 Profit per product
SELECT p.ProductName,
       SUM(d.Quantity) AS UnitsSold,
       ROUND(SUM(d.Quantity * (d.UnitPrice * (1 - d.Discount / 100) - p.Cost)), 2) AS Profit
FROM Order_Details d JOIN Products p ON p.ProductID = d.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY Profit DESC;

-- 25.4 Employee performance ranking
SELECT RANK() OVER (ORDER BY SUM(o.TotalAmount) DESC) AS Position,
       fn_FullName(e.EmployeeID) AS Employee, e.Role, COUNT(o.OrderID) AS Orders, SUM(o.TotalAmount) AS Revenue
FROM Employees e JOIN Orders o ON o.EmployeeID = e.EmployeeID
WHERE o.IsCompleted = TRUE
GROUP BY e.EmployeeID, e.Role;

-- 25.5 Payment method share
SELECT PaymentType, COUNT(*) AS Payments, SUM(Amount) AS Total,
       ROUND(SUM(Amount) / SUM(SUM(Amount)) OVER () * 100, 1) AS SharePercent
FROM Payments GROUP BY PaymentType;

-- 25.6 Busiest hours
SELECT HOUR(OrderDate) AS HourOfDay, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue FROM Orders GROUP BY HOUR(OrderDate) ORDER BY Orders DESC, HourOfDay;

-- 25.7 Dine-in vs takeaway
SELECT OrderType, COUNT(*) AS Orders, ROUND(AVG(TotalAmount), 2) AS AverageOrder FROM Orders WHERE IsCompleted = TRUE GROUP BY OrderType;

-- 25.8 Products to reorder and products about to expire
SELECT ProductName, StockQuantity, 'Low stock' AS Alert FROM Products WHERE StockQuantity < 30
UNION ALL
SELECT ProductName, StockQuantity, CONCAT('Expires ', ExpirationDate) FROM Products WHERE ExpirationDate <= '2025-11-08'
ORDER BY Alert;

-- 25.9 Products that never sold
SELECT p.ProductName FROM Products p WHERE NOT EXISTS (SELECT 1 FROM Order_Details d WHERE d.ProductID = p.ProductID);

-- 25.10 Loyalty customers value
SELECT lc.CardNumber, lc.Points, fn_LoyaltyTier(lc.Points) AS Tier, COUNT(o.OrderID) AS Orders, IFNULL(SUM(o.TotalAmount), 0) AS Spent
FROM LoyaltyCards lc LEFT JOIN Orders o ON o.LoyaltyCardID = lc.CardID
GROUP BY lc.CardID, lc.CardNumber, lc.Points
ORDER BY Spent DESC;

-- 25.11 Loyalty vs non-loyalty orders
SELECT IF(LoyaltyCardID IS NULL, 'No card', 'With card') AS Customer, COUNT(*) AS Orders, ROUND(AVG(TotalAmount), 2) AS AverageOrder
FROM Orders GROUP BY Customer;

-- 25.12 Late arrivals (check-in after 08:15)
SELECT fn_FullName(a.EmployeeID) AS Employee, COUNT(*) AS LateDays, MAX(a.CheckInTime) AS Latest
FROM Attendance a WHERE a.CheckInTime > '08:15:00' GROUP BY a.EmployeeID ORDER BY LateDays DESC;

-- 25.13 Hours worked per employee
SELECT fn_FullName(e.EmployeeID) AS Employee, COUNT(a.AttendanceID) AS Days,
       ROUND(SUM(TIME_TO_SEC(TIMEDIFF(a.CheckOutTime, a.CheckInTime))) / 3600, 1) AS Hours
FROM Employees e JOIN Attendance a ON a.EmployeeID = e.EmployeeID
WHERE a.CheckOutTime IS NOT NULL GROUP BY e.EmployeeID;

-- 25.14 Payroll by role
SELECT Role, COUNT(*) AS Staff, SUM(Salary) AS Payroll, ROUND(SUM(Salary) / SUM(SUM(Salary)) OVER () * 100, 1) AS PercentOfPayroll
FROM Employees GROUP BY Role ORDER BY Payroll DESC;

-- 25.15 Supplier dependency
SELECT s.CompanyName, COUNT(p.ProductID) AS Products, IFNULL(SUM(p.StockQuantity * p.Cost), 0) AS StockValue
FROM Suppliers s LEFT JOIN Products p ON p.SupplierID = s.SupplierID GROUP BY s.SupplierID, s.CompanyName ORDER BY StockValue DESC;

-- 25.16 Employees with duplicated names
SELECT FirstName, LastName, COUNT(*) AS People, GROUP_CONCAT(EmployeeID) AS IDs, GROUP_CONCAT(Salary) AS Salaries
FROM Employees GROUP BY FirstName, LastName HAVING COUNT(*) > 1;

-- 25.17 Monthly summary
SELECT DATE_FORMAT(OrderDate, '%Y-%m') AS Month, COUNT(*) AS Orders, SUM(TotalAmount) AS Revenue, ROUND(AVG(TotalAmount), 2) AS AverageOrder
FROM Orders WHERE IsCompleted = TRUE GROUP BY Month WITH ROLLUP;

-- 25.18 Database health check
SELECT (SELECT COUNT(*) FROM Employees) AS Employees, (SELECT COUNT(*) FROM Products) AS Products,
       (SELECT COUNT(*) FROM Orders) AS Orders, (SELECT COUNT(*) FROM Order_Details) AS OrderLines,
       (SELECT COUNT(*) FROM Payments) AS Payments, (SELECT COUNT(*) FROM LoyaltyCards) AS Cards;
SELECT o.OrderID, o.TotalAmount, ROUND(SUM(d.Quantity * d.UnitPrice * (1 - d.Discount / 100)), 2) AS DetailsTotal
FROM Orders o JOIN Order_Details d ON d.OrderID = o.OrderID
GROUP BY o.OrderID, o.TotalAmount HAVING o.TotalAmount <> DetailsTotal;

-- ============================================================================
-- END OF COURSE
-- ============================================================================
SELECT 'CoffeeShop course script completed' AS Status;
