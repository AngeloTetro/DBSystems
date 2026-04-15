-- Performance Validation Script
-- Execute this script after script.sql
-- Objective: capture performance metrics for all 5 operations

SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET FEEDBACK ON;
SET LINESIZE 220;
SET PAGESIZE 2000;

BEGIN
  DELETE FROM PLAN_TABLE WHERE STATEMENT_ID LIKE 'STAGEUP_%';
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
/

-- ========================================
-- OPERATION 1 - REGISTER CUSTOMER
-- ========================================

BEGIN
   EXECUTE IMMEDIATE 'DELETE FROM CUSTOMER WHERE CustomerCode = ''CUST9001''';
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

-- Step 1: EXPLAIN PLAN
EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP1_INS' FOR INSERT INTO CUSTOMER (CustomerCode, Phone, Email, CustomerType, FirstName, LastName, CompanyName) VALUES ('CUST9001', '333777111', 'trace_op1@example.com', 'individual', 'Trace', 'One', NULL);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP1_INS', 'ALL'));

-- Step 2: RUN + OUTPUT
INSERT INTO CUSTOMER (
  CustomerCode, Phone, Email, CustomerType, FirstName, LastName, CompanyName
) VALUES (
  'CUST9001', '333777111', 'trace_op1@example.com', 'individual', 'Trace', 'One', NULL
);
COMMIT;

SELECT CustomerCode, CustomerType, Email
FROM CUSTOMER
WHERE CustomerCode = 'CUST9001';

-- ========================================
-- OPERATION 2 - ADD BOOKING
-- ========================================

BEGIN
   EXECUTE IMMEDIATE 'DELETE FROM BOOKING WHERE BookingCode = ''BOOK9001''';
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

-- Step 1: EXPLAIN PLAN
EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP2_INS' FOR INSERT INTO BOOKING (BookingCode, BookingType, BookingChannel, BookingDate, DurationDays, Cost, CustomerCode, LocationCode, TeamCode, OfficeCode) VALUES ('BOOK9001', 'one-time', 'website', TRUNC(SYSDATE) + 30, 2, 1000, 'CUST001', 'LOC001', 'TEAM001', 'HQ1');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP2_INS', 'ALL'));

-- Step 2: RUN + OUTPUT
INSERT INTO BOOKING (
  BookingCode, BookingType, BookingChannel, BookingDate, DurationDays, Cost,
  CustomerCode, LocationCode, TeamCode, OfficeCode
) VALUES (
  'BOOK9001', 'one-time', 'website', TRUNC(SYSDATE) + 30, 2, 1000,
  'CUST001', 'LOC001', 'TEAM001', 'HQ1'
);
COMMIT;

SELECT BookingCode, BookingType, TeamCode
FROM BOOKING
WHERE BookingCode = 'BOOK9001';

-- ========================================
-- OPERATION 3 - ADD EVENT LOCATION
-- ========================================

BEGIN
   EXECUTE IMMEDIATE 'DELETE FROM EVENTLOCATION WHERE LocationCode = ''LOC9001''';
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

-- Step 1: EXPLAIN PLAN
EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP3_INS' FOR INSERT INTO EVENTLOCATION (LocationCode, LocationAddress, SetupTimeEstimate, EquipmentCapacity, BookingCount, CustomerCode) VALUES ('LOC9001', AddressTY('Trace Street', '99', '20100', 'Milano', 'MI'), 60, 100, 0, 'CUST001');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP3_INS', 'ALL'));

-- Step 2: RUN + OUTPUT
INSERT INTO EVENTLOCATION (
  LocationCode, LocationAddress, SetupTimeEstimate, EquipmentCapacity, BookingCount, CustomerCode
) VALUES (
  'LOC9001', AddressTY('Trace Street', '99', '20100', 'Milano', 'MI'), 60, 100, 0, 'CUST001'
);
COMMIT;

SELECT LocationCode, CustomerCode, BookingCount
FROM EVENTLOCATION
WHERE LocationCode = 'LOC9001';

-- ========================================
-- OPERATION 4 - BEFORE OPTIMIZATION
-- ========================================

BEGIN
   EXECUTE IMMEDIATE 'DROP INDEX idx_booking_location_date';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

-- Step 1: EXPLAIN PLAN (before)
EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP4_BEFORE' FOR
SELECT TeamName
FROM (
  SELECT s.TeamName
  FROM BOOKING b
  JOIN SETUPTEAM s ON s.TeamCode = b.TeamCode
  WHERE b.CustomerCode = 'CUST001'
    AND b.LocationCode = 'LOC001'
  ORDER BY b.BookingDate DESC
)
WHERE ROWNUM = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP4_BEFORE', 'ALL'));

-- Step 2: QUERY OUTPUT (before)
SELECT TeamName
FROM (
  SELECT s.TeamName
  FROM BOOKING b
  JOIN SETUPTEAM s ON s.TeamCode = b.TeamCode
  WHERE b.CustomerCode = 'CUST001'
    AND b.LocationCode = 'LOC001'
  ORDER BY b.BookingDate DESC
)
WHERE ROWNUM = 1;

-- ========================================
-- OPERATION 4 - AFTER OPTIMIZATION
-- ========================================

CREATE INDEX idx_booking_location_date ON BOOKING (CustomerCode, LocationCode, BookingDate DESC);

-- Step 1: EXPLAIN PLAN (after)
EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP4_AFTER' FOR
SELECT TeamName
FROM (
  SELECT s.TeamName
  FROM BOOKING b
  JOIN SETUPTEAM s ON s.TeamCode = b.TeamCode
  WHERE b.CustomerCode = 'CUST001'
    AND b.LocationCode = 'LOC001'
  ORDER BY b.BookingDate DESC
)
WHERE ROWNUM = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP4_AFTER', 'ALL'));

-- ========================================
-- OPERATION 5 - BEFORE OPTIMIZATION
-- ========================================

-- Rimuovo l'indice per testare l'op 5 senza ottimizzazione
BEGIN
   EXECUTE IMMEDIATE 'DROP INDEX idx_booking_location_date';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

-- Step 1: EXPLAIN PLAN (before)
EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP5_BEFORE' FOR
SELECT el.LocationCode, COUNT(b.BookingCode) AS NumBookings
FROM EVENTLOCATION el
LEFT JOIN BOOKING b
  ON b.CustomerCode = el.CustomerCode
 AND b.LocationCode = el.LocationCode
GROUP BY el.LocationCode
ORDER BY NumBookings DESC, el.LocationCode;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP5_BEFORE', 'ALL'));

-- ========================================
-- OPERATION 5 - AFTER OPTIMIZATION
-- ========================================

CREATE INDEX idx_booking_location_date ON BOOKING (CustomerCode, LocationCode, BookingDate DESC);

-- Step 1: EXPLAIN PLAN (after)
EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP5_AFTER' FOR
SELECT el.LocationCode, COUNT(b.BookingCode) AS NumBookings
FROM EVENTLOCATION el
LEFT JOIN BOOKING b
  ON b.CustomerCode = el.CustomerCode
 AND b.LocationCode = el.LocationCode
GROUP BY el.LocationCode
ORDER BY NumBookings DESC, el.LocationCode;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP5_AFTER', 'ALL'));
