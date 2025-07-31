drop database video_rental;
create database video_rental; 
use video_rental; 

-- create customer's part -- 
CREATE TABLE IF NOT EXISTS Customer (
    customer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(55),
    phone_number VARCHAR(12) NOT NULL UNIQUE COMMENT '12 digits, do not include +'
);

CREATE TABLE IF NOT EXISTS Email (
    customer_id INT UNSIGNED NOT NULL, 
    email VARCHAR(255),
    PRIMARY KEY (customer_id, email),
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id)
    ON DELETE NO ACTION
    ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS Coupon (
    coupon_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id INT UNSIGNED NOT NULL,
    percent TINYINT NOT NULL,
    CHECK (percent > 0 AND percent < 100),
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- create movies' part --

CREATE TABLE IF NOT EXISTS Movie (
    movie_id INT(10) PRIMARY KEY COMMENT '10 digit barcode',
    name VARCHAR(45) NOT NULL,
    year YEAR NOT NULL,
    status ENUM('in stock', 'rented', 'lost') NOT NULL DEFAULT 'in stock'
);

CREATE TABLE IF NOT EXISTS rental_rate (
    rental_rate_id INT AUTO_INCREMENT PRIMARY KEY,
    movie_id INT(10) NOT NULL,
    date DATETIME DEFAULT NOW(),
    daily_charge DECIMAL(8,2) NOT NULL COMMENT 'added by the manager every morning',
    CHECK (daily_charge > 0),
    FOREIGN KEY (movie_id) REFERENCES Movie(movie_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
);

-- create employee's part --

CREATE TABLE IF NOT EXISTS Employee (
    employee_id TINYINT(3) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    role ENUM('manager', 'employee') NOT NULL,
    password VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS Timesheet (
    timesheet_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id TINYINT(3) UNSIGNED NOT NULL,
    date DATE NOT NULL,
    shift ENUM('1', '2') NOT NULL,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- create fact tables -

CREATE TABLE IF NOT EXISTS Rental (
    rental_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    rental_rate_id INT UNSIGNED NOT NULL,
    customer_id INT UNSIGNED NOT NULL,
    employee_id TINYINT UNSIGNED NOT NULL,
    date_issued DATETIME NOT NULL DEFAULT NOW() COMMENT 'the date when the movie borrowed',
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id)
    ON DELETE NO ACTION
    ON UPDATE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
    ON DELETE NO ACTION
    ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS Payment (
    rental_id INT UNSIGNED PRIMARY KEY,
    coupon_id INT UNSIGNED,
    employee_id TINYINT UNSIGNED NOT NULL,
    date_returned DATETIME NOT NULL DEFAULT NOW() COMMENT 'the date the movies has been returned to the rental shop',
    status ENUM('returned', 'lost') NOT NULL,
    amount DECIMAL(10, 2),
    FOREIGN KEY (rental_id) REFERENCES Rental(rental_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
    FOREIGN KEY (coupon_id) REFERENCES Coupon(coupon_id)
    ON DELETE NO ACTION
    ON UPDATE CASCADE
);

-- create indexes 
create index idx_customer ON Customer (phone_number); 
create index idx_movie_name ON Movie (name); 
create index idx_rental_date_issued ON Rental (date_issued);
create index idx_payment ON Payment (date_returned);







-- create triggers --
-- 1. before inserting a new rental, the system check if the movie status is 'in stock' 

DELIMITER //
CREATE TRIGGER  tr_rental_before_insert
BEFORE INSERT ON Rental
FOR EACH ROW
BEGIN
    -- Declare local variables
    DECLARE movie_id_current INT;
    DECLARE movie_status VARCHAR(255);

    -- Get the movie_id from the Rental_rate table
    SELECT movie_id INTO movie_id_current
    FROM Rental_rate
    WHERE rental_rate_id = NEW.rental_rate_id;
    
    -- Get the status of the movie
    SELECT status INTO movie_status
    FROM Movie
    WHERE movie_id = movie_id_current;

    -- Check if the movie status is not available
    IF movie_status = 'rented' OR movie_status = 'lost' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'The movie is not available';
    END IF;
END//

DELIMITER ;

-- 2. when a movie is rented, the status in table Movies is changed to 'rented' 

DELIMITER //

CREATE TRIGGER tr_rental_after_insert
AFTER INSERT ON Rental
FOR EACH ROW
BEGIN
    -- Update the status of the movie to 'rented'
    UPDATE Movie
    SET status = 'rented'
    WHERE movie_id = (SELECT movie_id
                      FROM Rental_rate
                      WHERE rental_rate_id = NEW.rental_rate_id);
END //

DELIMITER ;

-- 3. a) change the status of the movie upon returning  
DELIMITER //

CREATE TRIGGER tr_payment_after_insert
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN


    DECLARE movie_id_current INT;

    SELECT movie_id INTO movie_id_current
    FROM Rental_rate
    WHERE rental_rate_id = (
        SELECT rental_rate_id
        FROM Rental
        WHERE rental_id = NEW.rental_id
    );
	-- change the stutus of the movie when returned 
    IF NEW.status = 'returned' THEN
        UPDATE Movie
        SET status = 'in stock'
        WHERE movie_id = movie_id_current;
    ELSEIF NEW.status = 'lost' THEN
        UPDATE Movie
        SET status = 'lost'
        WHERE movie_id = movie_id_current;
    END IF;
END//
DELIMITER ;

-- 4. calculate amount before inserting or updating Payment

DELIMITER //
CREATE TRIGGER tr_payment_calculate_amount_before_insert
BEFORE INSERT ON Payment
FOR EACH ROW
BEGIN
    DECLARE date_issued_current DATETIME;
    DECLARE daily_charge_current DECIMAL(10,2);
    DECLARE percent_current INT DEFAULT 0; 

    -- Get the date_issued from Rental
    SELECT date_issued INTO date_issued_current
    FROM Rental
    WHERE rental_id = NEW.rental_id;

    -- Get the daily_charge from Rental_rate
    SELECT daily_charge INTO daily_charge_current
    FROM Rental_rate
    WHERE rental_rate_id = (SELECT rental_rate_id FROM Rental WHERE rental_id = NEW.rental_id);

    -- Get the percent from Coupon, handle NULL coupon_id
    IF NEW.coupon_id IS NOT NULL THEN
        SELECT percent INTO percent_current
        FROM Coupon
        WHERE coupon_id = NEW.coupon_id;
    END IF;

    -- Calculate and set the amount
    SET NEW.amount = 
		CASE 
            WHEN NEW.status = 'lost' THEN
				daily_charge_current * 4  
            ELSE  
                DATEDIFF(NEW.date_returned, date_issued_current) * 
                daily_charge_current * 
                (1 - percent_current / 100) 
        END;
END; //
DELIMITER ;


-- Audit Rental and Payment
 
-- 1. Create table Audit
CREATE TABLE IF NOT EXISTS Audit (
    table_name VARCHAR(25) NOT NULL COMMENT 'Rental or Payment',
    action_type VARCHAR(25) NOT NULL COMMENT 'delete or update',
    action_date DATETIME DEFAULT NOW(),
    date_of_operation DATETIME,
    employee_id INT UNSIGNED NOT NULL,
    customer_id INT UNSIGNED NOT NULL,
    movie_id INT(10)
);

-- 2. Trigger after Rental has been updated
DELIMITER //

CREATE TRIGGER tr_rental_after_update
AFTER UPDATE ON Rental
FOR EACH ROW
BEGIN
    INSERT INTO Audit VALUES
    ('Rental', 'update', NOW(), NEW.date_issued, NEW.employee_id, NEW.customer_id,
     (SELECT movie_id FROM Rental_rate WHERE rental_rate_id = NEW.rental_rate_id));
END //
DELIMITER ;

-- 3. Trigger after Rental has been deleted
DELIMITER //

CREATE TRIGGER  tr_rental_after_delete
AFTER DELETE ON Rental
FOR EACH ROW
BEGIN
    INSERT INTO Audit VALUES
    ('Rental', 'delete', NOW(), OLD.date_issued, OLD.employee_id, OLD.customer_id,
     (SELECT movie_id FROM Rental_rate WHERE rental_rate_id = OLD.rental_rate_id));
END //
DELIMITER ;

-- 4. Trigger after Payment has been updated
DELIMITER //
CREATE TRIGGER tr_payment_after_update
AFTER UPDATE ON Payment
FOR EACH ROW
BEGIN
    DECLARE movie_id_current INT;
    SELECT rr.movie_id INTO movie_id_current
    FROM Rental_rate rr
    JOIN Rental r ON r.rental_rate_id = rr.rental_rate_id
    WHERE r.rental_id = NEW.rental_id;
    INSERT INTO Audit VALUES
    ('Payment', 'update', NOW(), NEW.date_returned, NEW.employee_id,
     (SELECT customer_id FROM Rental WHERE rental_id = NEW.rental_id), movie_id_current);
END //
DELIMITER ;

-- 5. Trigger after Payment was deleted
DELIMITER //
CREATE TRIGGER tr_payment_after_delete
AFTER DELETE ON Payment
FOR EACH ROW
BEGIN
    DECLARE movie_id_current INT;
    SELECT rr.movie_id INTO movie_id_current
    FROM Rental_rate rr
    JOIN Rental r ON r.rental_rate_id = rr.rental_rate_id
    WHERE r.rental_id = OLD.rental_id;
    INSERT INTO Audit VALUES
    ('Payment', 'delete', NOW(), OLD.date_returned, OLD.employee_id,
     (SELECT customer_id FROM Rental WHERE rental_id = OLD.rental_id), movie_id_current);
END //
DELIMITER ;


-- create views -- 
-- 1. View Movies for employee 
CREATE VIEW EMovie AS
SELECT
    m.movie_id,
    m.name,
    m.year,
    m.status,
    rr.daily_charge,
    rr.rental_rate_id
FROM
    Movie m
JOIN
    Rental_rate rr ON m.movie_id = rr.movie_id 
WHERE
    (m.status = 'in stock' OR m.status = 'rented') AND DATE(rr.date) = CURRENT_DATE();


-- create users and grant privilegies -- 

-- create user 'manager',  grant all privileges on all the database
CREATE USER IF NOT EXISTS manager IDENTIFIED BY '007Bond';
GRANT ALL ON video_rental.* TO manager;

-- create user 'Sara',  grant specific privileges
CREATE USER IF NOT EXISTS Sara IDENTIFIED BY '002Sara';

GRANT SELECT, INSERT, UPDATE, DELETE ON video_rental.Customer TO Sara;
GRANT SELECT, INSERT, UPDATE, DELETE ON video_rental.Email TO Sara;
GRANT SELECT, INSERT, UPDATE, DELETE ON video_rental.Rental TO Sara;
GRANT SELECT, INSERT, UPDATE, DELETE ON video_rental.Payment TO Sara;
GRANT SELECT ON video_rental.Coupon TO Sara;
GRANT SELECT ON video_rental.Movie TO Sara;
GRANT SELECT ON video_rental.Rental_rate TO Sara;

-- create user Tom identical to Sara
CREATE USER IF NOT EXISTS Tom IDENTIFIED BY '003Tom';

GRANT SELECT, INSERT, UPDATE, DELETE ON video_rental.Customer TO Tom; 
GRANT SELECT, INSERT, UPDATE, DELETE ON video_rental.Email TO Tom; 
GRANT SELECT, INSERT, UPDATE, DELETE ON video_rental.Rental TO Tom; 
GRANT SELECT, INSERT, UPDATE, DELETE ON video_rental.Payment TO Tom; 
GRANT SELECT ON video_rental.Coupon TO Tom;
GRANT SELECT ON video_rental.Movie TO Tom;
GRANT SELECT ON video_rental.Rental_rate TO Tom;

-- populate the database 
-- populate Customers' part  
INSERT INTO Customer (phone_number, name) VALUES
	(123456789001, 'John Doe'),
	(123456789002, 'Jane Smith'),
	(123456789003, 'Alice Johnson');

INSERT INTO Email (customer_id, email) VALUES
	(1, 'john.doe@example.com'),
	(2, 'jane.smith@example.com'),
	(3, 'alice.johnson@example.com'),
	(1, 'king@example.com'),
	(1, 'kind.kitty@example.com');

INSERT INTO Coupon (customer_id, percent) VALUES
	(1, 10),
	(2, 5);

-- populate Movie's part
INSERT INTO Movie (movie_id, name, year) VALUES 
	(1, 'The Shawshank Redemption', 1994),
	(2, 'The Godfather', 1972),
	(3, 'The Dark Knight', 2008),
	(4, 'Pulp Fiction', 1994),
	(5, 'The Lord of the Rings: The Return of the King', 2003),
	(6, 'Forrest Gump', 1994),
	(7, 'Inception', 2010),
	(8, 'Fight Club', 1999),
	(9, 'The Matrix', 1999),
	(10, 'Goodfellas', 1990),
	(11, 'The Empire Strikes Back', 1980),
	(12, 'Interstellar', 2014),
	(13, 'The Silence of the Lambs', 1991),
	(14, 'Saving Private Ryan', 1998),
	(15, 'The Usual Suspects', 1995),
	(16, 'Se7en', 1995),
	(17, 'The Green Mile', 1999),
	(18, 'Gladiator', 2000),
	(19, 'The Departed', 2006),
	(20, 'The Lion King', 1994),
	(21, 'Titanic', 1997),
	(22, 'Jurassic Park', 1993),
	(23, 'The Prestige', 2006),
	(24, 'The Intouchables', 2011),
	(25, 'The Social Network', 2010);

INSERT INTO Rental_rate (movie_id, date, daily_charge) VALUES
	(1, '2023-10-01 00:00:00', 2.99),
	(1, '2023-10-02 00:00:00', 2.99),
	(1, '2023-10-03 00:00:00', 2.99),
	(1, '2023-10-04 00:00:00', 2.99),
	(1, '2023-10-05 00:00:00', 2.99),
	(1, '2023-10-06 00:00:00', 2.99),
	(2, '2023-10-01 00:00:00', 3.49),
	(2, '2023-10-02 00:00:00', 3.49),
	(2, '2023-10-03 00:00:00', 3.49),
	(2, '2023-10-04 00:00:00', 3.49),
	(2, '2023-10-05 00:00:00', 3.49),
	(2, '2023-10-06 00:00:00', 3.49),
	(3, '2023-10-01 00:00:00', 4.99),
	(3, '2023-10-02 00:00:00', 4.99),
	(3, '2023-10-03 00:00:00', 4.99),
	(3, '2023-10-04 00:00:00', 4.99),
	(3, '2023-10-05 00:00:00', 4.99),
	(3, '2023-10-06 00:00:00', 4.99),
	(4, '2023-10-01 00:00:00', 2.99),
	(4, '2023-10-02 00:00:00', 2.99),
	(4, '2023-10-03 00:00:00', 2.99),
	(4, '2023-10-04 00:00:00', 2.99),
	(4, '2023-10-05 00:00:00', 2.99),
	(4, '2023-10-06 00:00:00', 2.99),
	(5, '2023-10-01 00:00:00', 3.99),
	(5, '2023-10-02 00:00:00', 3.99),
	(5, '2023-10-03 00:00:00', 3.99),
	(5, '2023-10-04 00:00:00', 3.99),
	(5, '2023-10-05 00:00:00', 3.99),
	(5, '2023-10-06 00:00:00', 3.99),
	(6, '2023-10-01 00:00:00', 2.49),
	(6, '2023-10-02 00:00:00', 2.49),
	(6, '2023-10-03 00:00:00', 2.49),
	(6, '2023-10-04 00:00:00', 2.49),
	(6, '2023-10-05 00:00:00', 2.49),
	(6, '2023-10-06 00:00:00', 2.49),
	(7, '2023-10-01 00:00:00', 3.99),
	(7, '2023-10-02 00:00:00', 3.99),
	(7, '2023-10-03 00:00:00', 3.99),
	(7, '2023-10-04 00:00:00', 3.99),
	(7, '2023-10-05 00:00:00', 3.99),
	(7, '2023-10-06 00:00:00', 3.99),
	(8, '2023-10-01 00:00:00', 2.99),
	(8, '2023-10-02 00:00:00', 2.99),
	(8, '2023-10-03 00:00:00', 2.99),
	(8, '2023-10-04 00:00:00', 2.99),
	(8, '2023-10-05 00:00:00', 2.99),
	(8, '2023-10-06 00:00:00', 2.99),
	(9, '2023-10-01 00:00:00', 3.49),
	(9, '2023-10-02 00:00:00', 3.49),
	(9, '2023-10-03 00:00:00', 3.49),
	(9, '2023-10-04 00:00:00', 3.49),
	(9, '2023-10-05 00:00:00', 3.49),
	(9, '2023-10-06 00:00:00', 3.49),
	(10, '2023-10-01 00:00:00', 4.99),
	(10, '2023-10-02 00:00:00', 4.99),
	(10, '2023-10-03 00:00:00', 4.99),
	(10, '2023-10-04 00:00:00', 4.99),
	(10, '2023-10-05 00:00:00', 4.99),
	(10, '2023-10-06 00:00:00', 4.99),
	(11, '2023-10-01 00:00:00', 2.99),
	(11, '2023-10-02 00:00:00', 2.99),
	(11, '2023-10-03 00:00:00', 2.99),
	(11, '2023-10-04 00:00:00', 2.99),
	(11, '2023-10-05 00:00:00', 2.99),
	(11, '2023-10-06 00:00:00', 2.99),
	(12, '2023-10-01 00:00:00', 3.49),
	(12, '2023-10-02 00:00:00', 3.49),
	(12, '2023-10-03 00:00:00', 3.49),
	(12, '2023-10-04 00:00:00', 3.49),
	(12, '2023-10-05 00:00:00', 3.49),
	(12, '2023-10-06 00:00:00', 3.49),
	(13, '2023-10-01 00:00:00', 4.99),
	(13, '2023-10-02 00:00:00', 4.99),
	(13, '2023-10-03 00:00:00', 4.99),
	(13, '2023-10-04 00:00:00', 4.99),
	(13, '2023-10-05 00:00:00', 4.99),
	(13, '2023-10-06 00:00:00', 4.99),
	(14, '2023-10-01 00:00:00', 2.49),
	(14, '2023-10-02 00:00:00', 2.49),
	(14, '2023-10-03 00:00:00', 2.49),
	(14, '2023-10-04 00:00:00', 2.49),
	(14, '2023-10-05 00:00:00', 2.49),
	(14, '2023-10-06 00:00:00', 2.49),
	(15, '2023-10-01 00:00:00', 3.99),
	(15, '2023-10-02 00:00:00', 3.99),
	(15, '2023-10-03 00:00:00', 3.99),
	(15, '2023-10-04 00:00:00', 3.99),
	(15, '2023-10-05 00:00:00', 3.99),
	(15, '2023-10-06 00:00:00', 3.99),
	(16, '2023-10-01 00:00:00', 2.99),
	(16, '2023-10-02 00:00:00', 2.99),
	(16, '2023-10-03 00:00:00', 2.99),
	(16, '2023-10-04 00:00:00', 2.99),
	(16, '2023-10-05 00:00:00', 2.99),
	(16, '2023-10-06 00:00:00', 2.99),
	(17, '2023-10-01 00:00:00', 3.49),
	(17, '2023-10-02 00:00:00', 3.49),
	(17, '2023-10-03 00:00:00', 3.49),
	(17, '2023-10-04 00:00:00', 3.49),
	(17, '2023-10-05 00:00:00', 3.49),
	(17, '2023-10-06 00:00:00', 3.49),
	(18, '2023-10-01 00:00:00', 4.99),
	(18, '2023-10-02 00:00:00', 4.99),
	(18, '2023-10-03 00:00:00', 4.99),
	(18, '2023-10-04 00:00:00', 4.99),
	(18, '2023-10-05 00:00:00', 4.99),
	(18, '2023-10-06 00:00:00', 4.99),
	(19, '2023-10-01 00:00:00', 2.49),
	(19, '2023-10-02 00:00:00', 2.49),
	(19, '2023-10-03 00:00:00', 2.49),
	(19, '2023-10-04 00:00:00', 2.49),
	(19, '2023-10-05 00:00:00', 2.49),
	(19, '2023-10-06 00:00:00', 2.49),
	(20, '2023-10-01 00:00:00', 3.99),
	(20, '2023-10-02 00:00:00', 3.99),
	(20, '2023-10-03 00:00:00', 3.99),
	(20, '2023-10-04 00:00:00', 3.99),
	(20, '2023-10-05 00:00:00', 3.99),
	(20, '2023-10-06 00:00:00', 3.99),
	(21, '2023-10-01 00:00:00', 2.99),
	(21, '2023-10-02 00:00:00', 2.99),
	(21, '2023-10-03 00:00:00', 2.99),
	(21, '2023-10-04 00:00:00', 2.99),
	(21, '2023-10-05 00:00:00', 2.99),
	(21, '2023-10-06 00:00:00', 2.99),
	(22, '2023-10-01 00:00:00', 3.49),
	(22, '2023-10-02 00:00:00', 3.49),
	(22, '2023-10-03 00:00:00', 3.49),
	(22, '2023-10-04 00:00:00', 3.49),
	(22, '2023-10-05 00:00:00', 3.49),
	(22, '2023-10-06 00:00:00', 3.49),
	(23, '2023-10-01 00:00:00', 4.99),
	(23, '2023-10-02 00:00:00', 4.99),
	(23, '2023-10-03 00:00:00', 4.99),
	(23, '2023-10-04 00:00:00', 4.99),
	(23, '2023-10-05 00:00:00', 4.99),
	(23, '2023-10-06 00:00:00', 4.99),
	(24, '2023-10-01 00:00:00', 2.49),
	(24, '2023-10-02 00:00:00', 2.49),
	(24, '2023-10-03 00:00:00', 2.49),
	(24, '2023-10-04 00:00:00', 2.49),
	(24, '2023-10-05 00:00:00', 2.49),
	(24, '2023-10-06 00:00:00', 2.49),
	(25, '2023-10-01 00:00:00', 3.99),
	(25, '2023-10-02 00:00:00', 3.99),
	(25, '2023-10-03 00:00:00', 3.99),
	(25, '2023-10-04 00:00:00', 3.99),
	(25, '2023-10-05 00:00:00', 3.99),
	(25, '2023-10-06 00:00:00', 3.99);


-- populate Employee's part 

INSERT INTO Employee (employee_id, name, role, password ) VALUES
	(1, 'Mike Brown', 'manager', '007Bond'),
	(2, 'Sara White', 'employee', '002Sara'),
	(3, 'Tom Black', 'employee', '003Tom');

INSERT INTO Timesheet (employee_id, date, shift) VALUES 
   	(1, '2023-10-01', 1), 
   	(2, '2023-10-01', 1), 
   	(3, '2023-10-01', 2), 
   	(1, '2023-10-02', 2), 
   	(2, '2023-10-02', 1), 
   	(3, '2023-10-02', 2), 
   	(1, '2023-10-03', 1), 
   	(2, '2023-10-03', 2), 
   	(3, '2023-10-03', 1), 
   	(1, '2023-10-04', 1), 
   	(2, '2023-10-04', 2), 
   	(3, '2023-10-04', 1), 
   	(1, '2023-10-05', 2), 
   	(2, '2023-10-05', 2), 
   	(3, '2023-10-05', 1), 
   	(1, '2023-10-06', 1), 
   	(2, '2023-10-06', 1), 
   	(3, '2023-10-06', 2);