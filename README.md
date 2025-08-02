 # data_model_rental_movie_shop

## Files:    

rental_conceptual.drawio - conceptual model, draw.io  
rental_logical.drawio -  logical model draw.io, db management system independent  
rental_physical.mbw - physical model, mysql workbench   
rental_schema+populate.sql - sql script of the database, including indexes, triggers and creating new users, and queries to populate it  
rental_doc - explanation of the database created  
rental_queries.sql - some queries that can be performed on the db  

## Objective:  
This project focuses on the creating of db from scratch

## Skills gained:  
Triggers (+ Audit table for changes in logs in table Rental and Payment)   
Indexes  
Users and privilegies   
GROUP_CONCAT()  


# 1. Description and requirements

This is a project about designing the conceptual model, the logical model, the physical model, and finally the database for a video rental store.

Requirements:
This database will be used at a video rental store. We need different levels of permissions for different users. The store manager should be able to add/update/delete the list of movies. They will be in charge of setting the daily rental rate. Cashiers should have a read-only view of the list of movies. They should be able to manage the list of customers and create invoices.

At check out, a customer brings one or more movies. The cashier looks up a customer by their phone number or id. If the customer is a first-time customer, the cashier asks their full name, email and phone number, and then registers them in the system. The cashier then scans the movies the customer has brought to check out and records them in the system. Each movie has a 10 digit barcode printed on the cover.

When the customer returns to the store, they’ll bring the movies they rented. If a movie is lost, the customer should be charged 4 times the daily rental rate of the movie. The cashier should mark the movie as lost and this will reduce the stock. For other movies, the customer should be charged based on the number of days and the daily rental rate.

We issue discount coupons from time to time. The customer can bring a coupon when returning the movies. Each coupon can be applied to only one movie, only one coupon can be applied to one movie. 

It is possible that a customer returns the movies they’ve rented in multiple visits.

# 2. Conceptual model

   Process:
   1. Collect requirements
   2. Create ER diagram:  
      2.1. identify entities and their attributes (weak entity, single / multu-valued / derived attributes), define PKs  
      2.2. Indentify relationship in general   
   3. Present to stakeholers for feedabck, refine if needs till approved  
      
![image](https://github.com/user-attachments/assets/eccc6347-8ea1-4de8-8857-ed226bf402c7)


# 3. Logical model

   Process:
   1. Review conceptual entities and their attributes, define implementation-independent types of atributes (integer, float, text)  
   2.  Add PKs and FKs, specify relationships  
   3.  Add some constraints ( unique, business rules by check)   

![image](https://github.com/user-attachments/assets/6f91d080-4c67-43f0-935f-bb24482a411b)


 # 4. Physical model

   Process:
   1. Map logical entities and attributes to physical tables and columns, define columns data types (varchar, int(4), enum) and their properties (PK, NN, UQ, AI, G, Default), comment to explain the meaning of columns
   2. Add relationships (mind identifying and non-identifying)  
   3. Look into referential integrity constraints (what should happen to the foreign key if the primary key is updated or deleted)
   4. Add business rules: columns constraints (CHECK), calculated values
   5. Revise indexes  
   7. Look into triggers
   8. Design views and stored procedures 
   9. Create users and privileges

  <img width="1205" height="807" alt="image" src="https://github.com/user-attachments/assets/3c81a0f2-5763-4845-aad5-3ff42fa3e3cf" />




   

