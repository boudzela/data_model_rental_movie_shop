use video_rental;
-- QUERIES: 

-- for Employees to see the list of movies: 
select * from EMovie; 
-- for Employees to see movies availbale for rent at the moment: 
select * from EMovie where status = 'in stock';
-- to find a movie that starts with F: 
select * from Emovie where name like '%F%' or 'F%';

-- to insert a new customer 
INSERT INTO Customer (phone_number, name) VALUES
	('13456789004', 'Julia Wang');
INSERT INTO Email (customer_id, email) VALUES
	((select customer_id from Customer where name = 'Julia Wang'), 'julia.w@example.com'); 
    
-- insert a new Rental 
INSERT INTO Rental (rental_rate_id, customer_id, employee_id, date_issued) VALUES
		(1, 1, 2, '2023-10-01 10:00:00'),
        (7, 1, 2, '2023-10-01 10:05:00'),
        (19, 1, 2, '2023-10-01 10:10:00'), 
        (13, 2, 1, '2023-10-01 16:00:00'); 
-- check if the status changed to rented 
select * from movie;  

-- insert a new Payment 
INSERT INTO Payment (rental_id, coupon_id, employee_id, date_returned, status) VALUES
	(1, 1, 2, '2023-10-02 11:00:00', 'returned'), -- returned
	(2, null, 2, '2023-10-02 11:05:00', 'lost'), -- lost 
    (4, null, 2, '2023-10-02 12:00:00', 'returned'); 

-- check if triggers worked
select * from movie; 
select * from Payment;
select * from coupon; 

-- delete from Payment 
delete from Payment 
where rental_id = 1; 

-- check if the deleted info was added to Audit page 
select * from audit;

-- see the list of customers and who stil own the rental
select customer, count(rental_id), group_concat(movie)
from 
(
select c.name as customer , r.rental_id, m.name  as movie
from Rental r
join Rental_rate rr on rr.rental_rate_id = r.rental_rate_id 
join Movie m on rr.movie_id = m.movie_id and m.status = 'rented' 
join Customer c on r.customer_id = c.customer_id
) list 
group by customer; 

-- see the revenue per week
select sum(amount)
from Payment 
where date(date_returned) between '2023-10-01' and '2023-10-07'; 
 
 -- see top customers for all the period
 select c.name, sum(amount)
 from Payment p
 join Rental r on r.rental_id = p.rental_id
 right join Customer c on r.customer_id = c.customer_id 
 group by c.customer_id
 order by sum(amount) desc; 

