-- Kyle Calabro
-- Dr. Dutta
-- CMPS 664 - Project One
-- 28 April 2021

DROP SCHEMA IF EXISTS project_one;
CREATE DATABASE project_one;
USE project_one;

-- ************************************************************************************************************************
-- Tables
-- ************************************************************************************************************************

-- ************************************************************************************************************************
-- Table: Seat_Classes

-- Attributes:
	-- class: The different seat classes available for all flights.
-- ************************************************************************************************************************
CREATE TABLE Seat_classes(
	class VARCHAR(30) NOT NULL,
    PRIMARY KEY(class)
);

-- ************************************************************************************************************************
-- Table: Seats

-- Attributes:
	-- class: The class of seat (first, business, economy)
    -- num_seats: The base number of seats for each class for all flights.
-- ************************************************************************************************************************
CREATE TABLE Seats(
	num_seats INT NOT NULL,
    class VARCHAR(30) NOT NULL,
    FOREIGN KEY(class) REFERENCES Seat_classes(class)
);

-- ************************************************************************************************************************
-- Table: Pnr
-- Original data provided via the given PNR file.

-- Attributes:
	-- first_name
    -- last_name
    -- address
    -- age
    -- origin: The airport from which the patron is departing from.
    -- destination: The airport which the patron is flying to.
    -- travel_date: Date of travel.
    -- class: The patron's requested class of seat(s).
    -- booking_time: The time the booking request was issued by the patron.
    -- num_passengers: Number of seats to make the reservation for.
-- ************************************************************************************************************************
CREATE TABLE Pnr(
	first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NULL,
    address VARCHAR(255) NOT NULL,
    age INT NOT NULL,
    origin VARCHAR(4) NOT NULL,
    destination VARCHAR(4) NOT NULL,
    travel_date DATE NOT NULL,
    class VARCHAR(30) NOT NULL,
    booking_time TIME NOT NULL,
    num_passengers INT NOT NULL
);

-- ************************************************************************************************************************
-- Table: Airports
-- Original data provided via the given IATA file.

-- Attributes:
	-- iata_code: The IATA code for an airport.
-- ************************************************************************************************************************
CREATE TABLE Airports(
		iata_code VARCHAR(4) NOT NULL,
        PRIMARY KEY(iata_code)
);

-- ************************************************************************************************************************
-- Table: Passengers
-- Contains all pertinent information for a given passenger.

-- Attributes:
	-- passenger_id: Unique identifier for a given passenger.
    -- first_name
    -- last_name
    -- address
    -- age
-- ************************************************************************************************************************
CREATE TABLE Passengers(
	passenger_id INT NOT NULL AUTO_INCREMENT, 
	first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NULL,
    address VARCHAR(255) NOT NULL,
    age INT NOT NULL,
    PRIMARY KEY(passenger_id)
);

-- ************************************************************************************************************************
-- Table: Flights

-- Attributes:
	-- flight_id: Unique identifier for a given flight.alter
    -- departure_date: Date the flight departs origin airport.
    -- origin: The source airport (departing from).
    -- destination: The destination airport (traveling to).
    -- first_remaining: The number of seats remaining in first class.
    -- business_remaining: The number of seats remaining in business class.
	-- economy_remaining: The number of seats remaining in economy class.
	-- total_remaining: The total number of seats remaining on the flight (all classes).
-- ************************************************************************************************************************
CREATE TABLE Flights(
	flight_id INT NOT NULL AUTO_INCREMENT,
	departure_date DATETIME NOT NULL,
    origin VARCHAR(4) NOT NULL,
    destination VARCHAR(4) NOT NULL,
    first_remaining INT NOT NULL DEFAULT 50,
    business_remaining INT NOT NULL DEFAULT 100,
    economy_remaining INT NOT NULL DEFAULT 150,
    total_remaining INT NOT NULL DEFAULT 300,
    PRIMARY KEY(flight_id),
    FOREIGN KEY(origin) REFERENCES Airports(iata_code),
    FOREIGN KEY(destination) REFERENCES Airports(iata_code)
);

-- ************************************************************************************************************************
-- Table: Master_reservations

-- Attributes:
	-- reservation_id: Unique identifier for each reservation.
    -- passenger_id: Unique identifier for each passenger.
    -- booking_time: Time the reservation request was submitted by the patron.
    -- travel_date: The date when which the patron will be traveling.
    -- num_passengers: The number of seats to reserve on a flight for a given reservation.
    -- assigned_flight_id: The id of the flight that was assigned to the given passenger's reservation request.
    -- requested_class: The class which the patron requested for on a given reservation.
    -- first_assigned: The number of first class seats assigned to a given reservation.
    -- business_assigned: The number of business class seats assigned to a given reservation.
    -- economy_assigned: The number of economy class seats assigned to a given reservation.
    -- checked_in: Boolean value indicating if the patron checked in (must be within 24 hours of flight but not after).
-- ************************************************************************************************************************
CREATE TABLE Master_reservations(
	reservation_id INT NOT NULL AUTO_INCREMENT,
    passenger_id INT NOT NULL,
    booking_time TIME NOT NULL,
    travel_date DATETIME NOT NULL,
    num_passengers INT NOT NULL,
    assigned_flight_id INT NULL,
    requested_class VARCHAR(30) NOT NULL,
    first_assigned INT NOT NULL DEFAULT 0,
    business_assigned INT NOT NULL DEFAULT 0,
    economy_assigned INT NOT NULL DEFAULT 0,
    checked_in BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY(reservation_id),
    FOREIGN KEY(passenger_id) REFERENCES Passengers(passenger_id),
    FOREIGN KEY(assigned_flight_id) REFERENCES Flights(flight_id),
    FOREIGN KEY(requested_class) REFERENCES Seat_classes(class)
);

-- ************************************************************************************************************************
-- Utility Procedures and Trigger(s)
-- ************************************************************************************************************************

-- ************************************************************************************************************************
-- Trigger: insert_reservation

-- Prior to insertion into the Master_reservations table, first checks that the requested flight has enough seats
-- to accomodate the reservation. If the number of seats requested exceeds the remaining capacity of the assigned flight,
-- the reservation request is cancelled. Otherwise, checks to see if the requested class can accomodate all passengers in 
-- the party. If so, the reservation is made and the Flights table is updated to reflect the new number of seats. Otherwise,
-- the party is upgraded or downgraded into different, potentially distant, classes appropriately. The reservation is made
-- and the Flights table is also updated in this case.
-- ************************************************************************************************************************
DROP TRIGGER IF EXISTS insert_reservation

DELIMITER //

USE project_one//

CREATE TRIGGER insert_reservation
BEFORE INSERT
ON Master_reservations 
FOR EACH ROW
BEGIN
	-- Number of seats in each class available
	DECLARE total_available INT;
    DECLARE first_available INT;
    DECLARE business_available INT;
    DECLARE economy_available INT;
    
    -- Number of seats reserved in each class by the passenger
    DECLARE first_reserved INT DEFAULT 0;
    DECLARE business_reserved INT DEFAULT 0;
    DECLARE economy_reserved INT DEFAULT 0;
    
    -- Number of people to make a reservation for
    DECLARE n_pass INT;
    SET n_pass = NEW.num_passengers;
    
    SELECT total_remaining, first_remaining, business_remaining, economy_remaining
    INTO total_available, first_available, business_available, economy_available
    FROM Flights
    WHERE Flights.flight_id = NEW.assigned_flight_id;
    
    -- Ensure the entire party can fit onto the flight
    IF total_available >= NEW.num_passengers THEN
    
		IF NEW.requested_class = "first" THEN
			-- Check if all passengers can fit into first class...
			IF first_available >= n_pass THEN
                SET first_reserved = n_pass;
                -- Make reservation, update flights table with all passengers in first
                
			-- If you cannot fit all passengers into first, see how many can fit into first
            -- Then, attempt to downgrade the remainder.
            ELSE
				SET first_reserved = first_available;
                SET n_pass = n_pass - first_reserved;
                
                IF business_available >= n_pass THEN
					SET business_reserved = n_pass;
					-- Make reservation, update flights table with first_reserved in first and n_pass in business
                    
				-- If you cannot fit all passengers into first and business, the remainder
                -- must go into economy.
				ELSE
					SET business_reserved = business_available;
                    SET n_pass = n_pass - business_reserved;
                    SET economy_reserved = n_pass;
                    -- Make reservation with all seat classe being updated.
                    
				END IF;
                
            END IF;
		
        ELSEIF NEW.requested_class = "business" THEN 
			-- Check if all passengers can fit into requested business class
			IF business_available >= n_pass THEN
				SET business_reserved = n_pass;
                -- Make reservation
                
			-- Check if remainder of passengers can fit into first class
			ELSE
				SET business_reserved = business_available;
                SET n_pass = n_pass - business_reserved;
                
                IF first_available >= n_pass THEN
					SET first_reserved = n_pass;
                    -- Make reservation
				
                -- If all remaining passengers cannot fit into first
                -- They must all fit into economy
				ELSE
					SET first_reserved = first_available;
                    SET n_pass = n_pass - first_reserved;
                    SET economy_reserved = n_pass;
                    -- Make reservation
				END IF;
			END IF;
		
        -- Class must be economy
		ELSE
        
			-- Check if all passengers can fit into economy class
			IF economy_available >= n_pass THEN
				SET economy_reserved = n_pass;
                -- Make reservation
                
			ELSE
				SET economy_reserved = economy_available;
                SET n_pass = n_pass - economy_reserved;
                
                -- See if all remaining passengers can fit into business class
                IF business_available >= n_pass THEN
					SET business_reserved = n_pass;
                    -- Make reservation
				
                -- If all remaining passengers cannot fit into business, they must all
                -- fly first class
                ELSE
					SET business_reserved = business_available;
                    SET n_pass = n_pass - business_reserved;
                    SET first_reserved = n_pass;
                    -- Make reservation
				END IF;
			END IF;
		END IF;
        
        CALL update_flights(first_reserved, business_reserved, economy_reserved, NEW.assigned_flight_id, NEW.num_passengers);
        SET NEW.first_assigned = first_reserved;
        SET NEW.business_assigned = business_reserved;
        SET NEW.economy_assigned = economy_reserved;
        
	-- Flight cannot accomodate the party, delete the reservation
	ELSE
        SIGNAL SQLSTATE "02000" 
        SET MESSAGE_TEXT = "Reservation cannot be accomodated! Reservation canceled!";
	END IF;
			
END//
DELIMITER ;

-- ************************************************************************************************************************
-- Procedure: run_setup_inserts()
-- Inserts pertinent information into the Passengers, Seats, Seat_classes and Flights tables from the original files.
-- ************************************************************************************************************************
DROP PROCEDURE IF EXISTS run_setup_inserts;

DELIMITER //
CREATE PROCEDURE run_setup_inserts()
BEGIN
	INSERT INTO Passengers(first_name, last_name, address, age)
	SELECT DISTINCT first_name, last_name, address, age 
	FROM Pnr;

	INSERT INTO Seat_classes(class)
	SELECT DISTINCT class FROM Pnr;

	INSERT INTO Seats(num_seats, class)
	VALUES(50, "first");

	INSERT INTO Seats(num_seats, class)
	VALUES(100, "business");

	INSERT INTO Seats(num_seats, class)
	VALUES(150, "economy");

	INSERT INTO Flights(departure_date, origin, destination)
		SELECT DISTINCT travel_date, origin, destination 
		FROM Pnr 
		ORDER BY origin, destination;
END //

DELIMITER ;

-- ************************************************************************************************************************
-- Procedure: update_flights()
-- To update the seat availability for a given flight.

-- Inputs:
	-- first_reserved: The number of seats to reserve in first class.
    -- business_reserved: The number of seats to reserve in business class.
    -- economy_reserved: The number of seats to reserve in economy class.
    -- flight_id: The id number of the flight to update.
    -- n_pass: The total number of passengers to reserve seats for.
-- ************************************************************************************************************************
DROP PROCEDURE IF EXISTS update_flights;

DELIMITER //
CREATE PROCEDURE update_flights(IN first_reserved INT, IN business_reserved INT, IN economy_reserved INT, IN flight_id INT, IN n_pass INT)
BEGIN
	UPDATE Flights
    SET 
		first_remaining = first_remaining - first_reserved,
        business_remaining = business_remaining - business_reserved,
        economy_remaining = economy_remaining - economy_reserved,
        total_remaining = total_remaining - n_pass
	WHERE
		Flights.flight_id = flight_id;
END //

DELIMITER ; 

-- ************************************************************************************************************************
-- Procedure: update_checkin()
-- Implements check-in feature for reservations. Check-in must be within 24 hours prior to flight departure.

-- Inputs:
	-- i_curr_time: The current time a patron is attempting to check-in at.
    -- i_res_id: The reservation id to attempt check-in for.
-- ************************************************************************************************************************
DROP PROCEDURE IF EXISTS update_checkin;

DELIMITER //
CREATE PROCEDURE update_checkin(IN i_curr_time DATETIME, IN i_res_id INT)
BEGIN
	
	DECLARE travel_dtime DATETIME;
    
    SELECT travel_date
    INTO travel_dtime
    FROM Master_reservations
    WHERE i_res_id = Master_reservations.reservation_id;
    
    IF (i_curr_time BETWEEN DATE_SUB(travel_dtime, INTERVAL 1 DAY) AND travel_dtime) THEN
		UPDATE Master_reservations
		SET 
			checked_in = TRUE
		WHERE
			Master_reservations.reservation_id = i_res_id;
	ELSE
		SIGNAL SQLSTATE "03000" 
        SET MESSAGE_TEXT = "Check-In must be performed within 24 hours prior to flight departure!";
	END IF;
END //

DELIMITER ; 

-- Demonstration:
-- Run once Master_reservations table is populated

-- Success
CALL update_checkin("2100-01-06 00:00:01", 1);

-- Fail, > 24 hours prior to departure
CALL update_checkin("2100-01-05 00:00:01", 1);

-- Fail, after departure
CALL update_checkin("2100-01-07 00:00:01", 1);

SELECT * FROM Master_reservations WHERE reservation_id = 1;

UPDATE Master_reservations SET checked_in = FALSE WHERE reservation_id = 1;

-- ************************************************************************************************************************
-- Procedure: reserve_seats()
-- To implement an actual reservation:

-- Assigns n_pass seats to each passenger, on a first come, first serve basis, based on booking time.

-- Allow automatic upgrade to the next available upper level class, or downgrade to the next available lower class 
-- if requested class is full to accomodate all passengers in the party.

-- Allow for distant seats with co-passengers, i.e. party can be split amongst all seat classes.
-- ************************************************************************************************************************
DROP PROCEDURE IF EXISTS reserve_seats;

DELIMITER //

CREATE PROCEDURE reserve_seats()
BEGIN
	CREATE TEMPORARY TABLE IF NOT EXISTS to_insert
	AS
		SELECT Passengers.passenger_id, Pnr.booking_time, f.departure_date, Pnr.num_passengers, f.flight_id, Pnr.class
		FROM Pnr 
		INNER JOIN Flights f
		ON Pnr.travel_date = DATE(f.departure_date)
		AND Pnr.origin = f.origin
		AND Pnr.destination = f.destination
		INNER JOIN Passengers 
		ON Pnr.first_name = Passengers.first_name 
		AND Pnr.last_name = Passengers.last_name
		AND Pnr.age = Passengers.age
		AND Pnr.address = Passengers.address
		ORDER BY Pnr.booking_time;
        
	INSERT INTO Master_reservations(passenger_id, booking_time, travel_date, num_passengers, assigned_flight_id, requested_class)
    SELECT * FROM to_insert;
    
    DROP TABLE to_insert;

END //

DELIMITER ;

-- ************************************************************************************************************************
-- Example Queries and Corresponding Procedures
-- ************************************************************************************************************************

-- ************************************************************************************************************************
-- Procedure: flight_schedule()
-- 1). Show the flight schedule between two airports between two dates

-- Inputs:
	-- i_source: The source airport.
    -- i_dest: The destination airport.
    -- i_start_date: The start date of the time period to search.
    -- i_end_date: The end date of the time period to search.
-- ************************************************************************************************************************
DROP PROCEDURE IF EXISTS flight_schedule;

DELIMITER //

CREATE PROCEDURE flight_schedule(IN i_source VARCHAR(4), IN i_dest VARCHAR(4), IN i_start_date DATE, IN i_end_date DATE) 
BEGIN
	SELECT *
    FROM Flights
	WHERE origin = i_source AND destination = i_dest
    OR destination = i_source AND origin = i_dest
    AND departure_date BETWEEN i_start_date AND i_end_date
	ORDER BY departure_date;
END //

DELIMITER ;

-- Demonstration
CALL flight_schedule("ATL", "BOS", "2100-01-01", "2100-01-07");

-- ************************************************************************************************************************
-- Procedure: top_airports()
-- 2). Rank the top three (source, destination) airports based on the booking requests for a week.

-- Inputs:
	-- week_start: The start date from which to search for the duration of a week from.
-- ************************************************************************************************************************
DROP PROCEDURE IF EXISTS top_airports;

DELIMITER //

CREATE PROCEDURE top_airports(IN week_start DATE)
BEGIN
	SELECT COUNT(origin) AS count_flights, origin
	FROM 
		(SELECT * FROM Pnr 
        WHERE travel_date BETWEEN week_start AND DATE_ADD(week_start, INTERVAL 7 DAY)) AS t
	 GROUP BY origin, destination
	 ORDER BY count_flights DESC LIMIT 3;
END //

DELIMITER ;

-- Demonstration
CALL top_airports("2100-01-01");

-- ************************************************************************************************************************
-- Procedure: next_available_flight()
-- 3). Next available flight with available seats between given airports

-- Inputs:
	-- i_source: Source airport to search with.
    -- i_dest: Destinatio airport to search with.
-- ************************************************************************************************************************
DROP PROCEDURE IF EXISTS next_available_flight

DELIMITER //

CREATE PROCEDURE next_available_flight(IN i_source VARCHAR(4), IN i_dest VARCHAR(4))
BEGIN
	SELECT * 
    FROM Flights
    WHERE total_remaining > 0
    AND origin = i_source
    AND destination = i_dest
    ORDER BY departure_date LIMIT 1;
END //

DELIMITER ;

-- Demonstration
CALL next_available_flight("ATL", "BOS");

-- ************************************************************************************************************************
-- Procedure: avg_occupancy()
-- 4). Average occupancy rate (% full) for all flights between two cities.

-- Inputs:
	-- i_source: The source airport to search with.
    -- i_dest: The destination airport to search with.
-- ************************************************************************************************************************
DROP PROCEDURE IF EXISTS avg_occupancy;

DELIMITER //

CREATE PROCEDURE avg_occupancy(IN i_source VARCHAR(4), IN i_dest VARCHAR(4))
BEGIN 
	SELECT (total_seats_occupied / total_seats) * 100 AS average_occupancy, num_flights
    FROM
		(SELECT COUNT(flight_id) * 300 AS total_seats, SUM(300 - total_remaining) AS total_seats_occupied, COUNT(flight_id) AS num_flights
		FROM Flights
        WHERE origin = i_source 
		AND destination = i_dest) AS t;
END //

DELIMITER ;

-- Demonstration
CALL avg_occupancy("ATL", "BOS");

-- ************************************************************************************************************************
-- Demonstration purposes only:

-- CALL run_setup_inserts();
-- CALL reserve_seats();

SELECT * FROM Passengers;

SELECT * FROM Seat_classes;

SELECT * FROM Seats;

SELECT * FROM Airports;

SELECT * FROM Flights;

SELECT * FROM Pnr;

SELECT * FROM Master_reservations;

-- DROP TABLE Flights;
-- DROP TABLE Master_reservations;

-- DROP TABLE Pnr;
-- DROP TABLE Airports;
-- ************************************************************************************************************************

-- ************************************************************************************************************************
-- Demonstration purposes only:
-- Use when Master_reservations table has not been populated.

DROP TABLE Master_reservations;
DROP TABLE Flights;

-- Split between first and business
INSERT INTO Master_reservations(passenger_id, booking_time, travel_date, num_passengers, assigned_flight_id, requested_class)
VALUES(1, "08:08:38", "2100-01-01", 79, 1, "first");

-- Split between all classes occupying the whole flight
INSERT INTO Master_reservations(passenger_id, booking_time, travel_date, num_passengers, assigned_flight_id, requested_class)
VALUES(1, "08:08:39", "2100-01-01", 300, 1, "business");

-- Split between economy and business
INSERT INTO Master_reservations(passenger_id, booking_time, travel_date, num_passengers, assigned_flight_id, requested_class)
VALUES(1, "08:08:39", "2100-01-01", 170, 1, "economy");

-- Reservation cannot be accomodated
INSERT INTO Master_reservations(passenger_id, booking_time, travel_date, num_passengers, assigned_flight_id, requested_class)
VALUES(1, "08:08:39", "2100-01-01", 400, 1, "economy");

SELECT * FROM Master_reservations;

SELECT * FROM Flights WHERE flight_id = 1;

DELETE FROM Master_reservations WHERE passenger_id = 1;

UPDATE Flights
    SET 
		first_remaining = 50,
        business_remaining = 100,
        economy_remaining = 150,
        total_remaining = 300
	WHERE
		Flights.flight_id = 1;

-- ************************************************************************************************************************