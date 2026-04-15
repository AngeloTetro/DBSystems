SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET FEEDBACK ON;
SET LINESIZE 220;
SET PAGESIZE 2000;

PROMPT ========================================
PROMPT STAGEUP INDEX VALIDATION (OR MODEL)
PROMPT ========================================

BEGIN
  DELETE FROM PLAN_TABLE WHERE STATEMENT_ID LIKE 'STAGEUP_%';
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
/

PROMPT ========================================
PROMPT RELATION-CONSISTENT POPULATION
PROMPT ========================================
BEGIN
    EXECUTE IMMEDIATE q'[
        BEGIN
            PopulateDatabase(
                p_num_depots                 => 10,
                p_num_teams_per_depot        => 10,
                p_num_customers              => 500,
                p_num_locations_per_customer => 2,
                p_num_bookings               => 50000
            );
        END;
    ]';
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('PopulateDatabase executed successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('PopulateDatabase not available or failed: ' || SQLERRM);
END;
/

PROMPT ========================================
PROMPT OPERATION 1 - REGISTER CUSTOMER
PROMPT ========================================
BEGIN
   EXECUTE IMMEDIATE 'DELETE FROM CUSTOMER WHERE TaxCode = ''CUST9001''';
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP1_INS' FOR
INSERT INTO CUSTOMER VALUES (
    CustomerTY('CUST9001', 'individual', 'Trace', 'One', NULL, NULL)
);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP1_INS', 'ALL'));

BEGIN
    proc_register_customer('CUST9001', '333777111', 'trace_op1@example.com', 'individual', 'Trace', 'One', NULL, NULL);
END;
/
COMMIT;

SELECT TaxCode, CustomerType, NVL(VAT, '-') AS VAT_OR_EMAIL
FROM CUSTOMER
WHERE TaxCode = 'CUST9001';

PROMPT ========================================
PROMPT OPERATION 2 - ADD BOOKING
PROMPT ========================================
BEGIN
   EXECUTE IMMEDIATE 'DELETE FROM BOOKING WHERE Code = ''BOOK9001''';
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP2_INS' FOR
INSERT INTO BOOKING VALUES (
    BookingTY(
        'BOOK9001',
        'W',
        1000,
        TRUNC(SYSDATE) + 30,
        2,
        'N',
        (SELECT REF(st) FROM SETUPTEAM st WHERE st.Code = 'TEAM001'),
        (SELECT REF(el) FROM EVENTLOCATION el WHERE el.Code = 'LOC001')
    )
);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP2_INS', 'ALL'));

BEGIN
    proc_add_booking('BOOK9001', 'one-time', TRUNC(SYSDATE) + 30, 2, 1000, 'CUST001', 'LOC001', 'TEAM001', 'website');
END;
/
COMMIT;

SELECT Code, Type, Cost, BookDate
FROM BOOKING
WHERE Code = 'BOOK9001';

PROMPT ========================================
PROMPT OPERATION 3 - ADD EVENT LOCATION
PROMPT ========================================
BEGIN
   EXECUTE IMMEDIATE 'DELETE FROM EVENTLOCATION WHERE Code = ''LOC9001''';
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP3_INS' FOR
INSERT INTO EVENTLOCATION VALUES (
    EventLocationTY(
        'LOC9001',
        'Trace Street',
        99,
        'Milano',
        'MI',
        '20100',
        (SELECT REF(cu) FROM CUSTOMER cu WHERE cu.TaxCode = 'CUST001')
    )
);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP3_INS', 'ALL'));

BEGIN
    proc_add_event_location('LOC9001', 'CUST001', 'Trace Street', '99', '20100', 'Milano', 'MI', 60, 100);
END;
/
COMMIT;

SELECT Code, City, ZIP
FROM EVENTLOCATION
WHERE Code = 'LOC9001';

PROMPT ========================================
PROMPT OPERATION 4 - TEAM BY LOCATION
PROMPT ========================================
BEGIN
   EXECUTE IMMEDIATE 'DROP INDEX idx_booking_bookdate';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP4_BEFORE' FOR
SELECT st.Code || ' - ' || st.Name AS TeamInfo
FROM BOOKING b
JOIN SETUPTEAM st ON DEREF(b.Team).Code = st.Code
WHERE DEREF(b.EventLocation).Code = 'LOC001'
ORDER BY b.BookDate DESC
FETCH FIRST 1 ROW ONLY;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP4_BEFORE', 'ALL'));

SELECT func_get_team_by_location('CUST001', 'LOC001') AS TeamInfo
FROM DUAL;

CREATE INDEX idx_booking_bookdate ON BOOKING (BookDate DESC);

EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP4_AFTER' FOR
SELECT st.Code || ' - ' || st.Name AS TeamInfo
FROM BOOKING b
JOIN SETUPTEAM st ON DEREF(b.Team).Code = st.Code
WHERE DEREF(b.EventLocation).Code = 'LOC001'
ORDER BY b.BookDate DESC
FETCH FIRST 1 ROW ONLY;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP4_AFTER', 'ALL'));

PROMPT ========================================
PROMPT OPERATION 5 - RANKED LOCATIONS
PROMPT ========================================
BEGIN
   EXECUTE IMMEDIATE 'DROP INDEX idx_booking_bookdate';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP5_BEFORE' FOR
SELECT el.Code AS LocationCode, COUNT(b.Code) AS NumBookings
FROM EVENTLOCATION el
LEFT JOIN BOOKING b
    ON DEREF(b.EventLocation).Code = el.Code
GROUP BY el.Code
ORDER BY NumBookings DESC, el.Code;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP5_BEFORE', 'ALL'));

CREATE INDEX idx_booking_bookdate ON BOOKING (BookDate DESC);

EXPLAIN PLAN SET STATEMENT_ID = 'STAGEUP_OP5_AFTER' FOR
SELECT el.Code AS LocationCode, COUNT(b.Code) AS NumBookings
FROM EVENTLOCATION el
LEFT JOIN BOOKING b
    ON DEREF(b.EventLocation).Code = el.Code
GROUP BY el.Code
ORDER BY NumBookings DESC, el.Code;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'STAGEUP_OP5_AFTER', 'ALL'));

SELECT el.Code AS LocationCode, COUNT(b.Code) AS NumBookings
FROM EVENTLOCATION el
LEFT JOIN BOOKING b
    ON DEREF(b.EventLocation).Code = el.Code
GROUP BY el.Code
ORDER BY NumBookings DESC, el.Code;
