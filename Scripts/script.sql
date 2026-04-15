SET SERVEROUTPUT ON
SET LINESIZE 220
SET PAGESIZE 2000
SET DEFINE OFF

DECLARE
    v_quota_ok NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_quota_ok
    FROM USER_TS_QUOTAS
    WHERE TABLESPACE_NAME = 'USERS'
      AND (MAX_BYTES = -1 OR MAX_BYTES > 0);

    IF v_quota_ok = 0 THEN
        RAISE_APPLICATION_ERROR(-20050, 'Missing quota on USERS tablespace. Ask DBA to run StageUp/SQL/admin_fix_test_user.sql');
    END IF;
END;
/

-- ========================================
-- 0) CLEANUP
-- ========================================

BEGIN EXECUTE IMMEDIATE 'DROP TABLE BOOKING CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE EVENTLOCATION CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE CUSTOMER CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE SETUPTEAM CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE DEPOT CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN EXECUTE IMMEDIATE 'DROP TYPE BookingTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE EventLocationTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE CustomerTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE SetupTeamTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE MemberListTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE MemberTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE DepotTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE MunicipalityListTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ========================================
-- 1) TYPES
-- ========================================

CREATE OR REPLACE TYPE MunicipalityListTY AS TABLE OF VARCHAR2(80);
/

CREATE OR REPLACE TYPE DepotTY AS OBJECT (
    ID             VARCHAR2(20),
    Name           VARCHAR2(100),
    Address        VARCHAR2(100),
    City           VARCHAR2(50),
    Province       VARCHAR2(50),
    N_Emp          NUMBER,
    CoveredRegion  VARCHAR2(80),
    Municipalities MunicipalityListTY
);
/

CREATE OR REPLACE TYPE MemberTY AS OBJECT (
    SSN      VARCHAR2(16),
    Name     VARCHAR2(50),
    Surname  VARCHAR2(50)
);
/

CREATE OR REPLACE TYPE MemberListTY AS TABLE OF MemberTY;
/

CREATE OR REPLACE TYPE SetupTeamTY AS OBJECT (
    Code     VARCHAR2(20),
    Name     VARCHAR2(100),
    Depot    REF DepotTY,
    Members  MemberListTY
);
/

CREATE OR REPLACE TYPE CustomerTY AS OBJECT (
    TaxCode       VARCHAR2(20),
    CustomerType  VARCHAR2(20),
    FirstName     VARCHAR2(50),
    LastName      VARCHAR2(50),
    VAT           VARCHAR2(20),
    CompanyName   VARCHAR2(100)
);
/

CREATE OR REPLACE TYPE EventLocationTY AS OBJECT (
    Code      VARCHAR2(20),
    Address   VARCHAR2(100),
    NumberH   NUMBER,
    City      VARCHAR2(50),
    Prov      VARCHAR2(50),
    ZIP       VARCHAR2(10),
    Customer  REF CustomerTY
);
/

CREATE OR REPLACE TYPE BookingTY AS OBJECT (
    Code          VARCHAR2(20),
    Type          CHAR(1),
    Cost          NUMBER(10,2),
    BookDate      DATE,
    IntervalM     NUMBER,
    IsSpecial     CHAR(1),
    Team          REF SetupTeamTY,
    EventLocation REF EventLocationTY
);
/

-- ========================================
-- 2) TABLES
-- ========================================

CREATE TABLE DEPOT OF DepotTY (
    ID PRIMARY KEY,
    Name NOT NULL,
    Address NOT NULL,
    City NOT NULL,
    Province NOT NULL,
    N_Emp CHECK (N_Emp >= 0)
)
NESTED TABLE Municipalities STORE AS DepotMunicipalitiesNT;

CREATE TABLE SETUPTEAM OF SetupTeamTY (
    Code PRIMARY KEY,
    Name NOT NULL,
    Depot NOT NULL REFERENCES DEPOT
)
NESTED TABLE Members STORE AS SetupTeamMembersNT;

CREATE TABLE CUSTOMER OF CustomerTY (
    TaxCode PRIMARY KEY,
    CustomerType NOT NULL CHECK (CustomerType IN ('individual', 'company')),
    VAT UNIQUE,
    CHECK (
        (CustomerType = 'individual'
            AND FirstName IS NOT NULL
            AND LastName IS NOT NULL
            AND VAT IS NULL
            AND CompanyName IS NULL)
        OR
        (CustomerType = 'company'
            AND VAT IS NOT NULL
            AND CompanyName IS NOT NULL
            AND FirstName IS NULL
            AND LastName IS NULL)
    )
);

CREATE TABLE EVENTLOCATION OF EventLocationTY (
    Code PRIMARY KEY,
    Address NOT NULL,
    NumberH CHECK (NumberH > 0),
    City NOT NULL,
    Prov NOT NULL,
    ZIP NOT NULL,
    Customer NOT NULL REFERENCES CUSTOMER ON DELETE CASCADE
);

CREATE TABLE BOOKING OF BookingTY (
    Code PRIMARY KEY,
    Type NOT NULL CHECK (Type IN ('P', 'M', 'E', 'W')),
    Cost NOT NULL CHECK (Cost >= 0),
    BookDate NOT NULL,
    IntervalM NOT NULL CHECK (IntervalM >= 0),
    IsSpecial NOT NULL CHECK (IsSpecial IN ('Y', 'N')),
    Team NOT NULL REFERENCES SETUPTEAM,
    EventLocation NOT NULL REFERENCES EVENTLOCATION
);

CREATE INDEX idx_booking_bookdate ON BOOKING (BookDate DESC);

-- ========================================
-- 3) TRIGGERS
-- ========================================

CREATE OR REPLACE TRIGGER trg_check_customer_type
BEFORE INSERT OR UPDATE ON CUSTOMER
FOR EACH ROW
BEGIN
    IF :NEW.CustomerType = 'individual' THEN
        IF :NEW.FirstName IS NULL OR :NEW.LastName IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Individual customer requires first and last name');
        END IF;
        IF :NEW.VAT IS NOT NULL OR :NEW.CompanyName IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Individual customer cannot have company data');
        END IF;
    ELSIF :NEW.CustomerType = 'company' THEN
        IF :NEW.VAT IS NULL OR :NEW.CompanyName IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'Company customer requires VAT and company name');
        END IF;
        IF :NEW.FirstName IS NOT NULL OR :NEW.LastName IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20004, 'Company customer cannot have personal name data');
        END IF;
    ELSE
        RAISE_APPLICATION_ERROR(-20005, 'Invalid customer type');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_check_depot_municipalities
BEFORE INSERT OR UPDATE ON DEPOT
FOR EACH ROW
BEGIN
    IF :NEW.Municipalities IS NULL OR :NEW.Municipalities.COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'Depot must include at least one municipality');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_check_team_members
BEFORE INSERT OR UPDATE ON SETUPTEAM
FOR EACH ROW
DECLARE
    v_dup NUMBER;
BEGIN
    IF :NEW.Members IS NOT NULL AND :NEW.Members.COUNT > 10 THEN
        RAISE_APPLICATION_ERROR(-20007, 'A setup team cannot contain more than 10 members');
    END IF;

    IF :NEW.Members IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_dup
        FROM (
            SELECT m.SSN
            FROM TABLE(:NEW.Members) m
            GROUP BY m.SSN
            HAVING COUNT(*) > 1
        );

        IF v_dup > 0 THEN
            RAISE_APPLICATION_ERROR(-20008, 'Duplicate member SSN in the same setup team');
        END IF;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_check_booking_overlap
BEFORE INSERT OR UPDATE ON BOOKING
FOR EACH ROW
DECLARE
    v_overlap NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_overlap
    FROM BOOKING b
    WHERE b.Team = :NEW.Team
      AND b.Code <> NVL(:OLD.Code, '###')
      AND :NEW.BookDate <= b.BookDate + b.IntervalM
      AND b.BookDate <= :NEW.BookDate + :NEW.IntervalM;

    IF v_overlap > 0 THEN
        RAISE_APPLICATION_ERROR(-20009, 'Team already assigned in an overlapping time window');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_booking_eventlocation_customer_match
BEFORE INSERT OR UPDATE ON BOOKING
FOR EACH ROW
DECLARE
    v_location EventLocationTY;
    v_customer CustomerTY;
BEGIN
    IF :NEW.EventLocation IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010, 'Booking must reference an event location');
    END IF;

    SELECT DEREF(:NEW.EventLocation)
    INTO v_location
    FROM DUAL;

    IF v_location IS NULL OR v_location.Customer IS NULL THEN
        RAISE_APPLICATION_ERROR(-20011, 'Event location must be linked to a customer');
    END IF;

    SELECT DEREF(v_location.Customer)
    INTO v_customer
    FROM DUAL;

    IF v_customer IS NULL THEN
        RAISE_APPLICATION_ERROR(-20012, 'Referenced customer does not exist');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_booking_date_not_past
BEFORE INSERT OR UPDATE ON BOOKING
FOR EACH ROW
BEGIN
    IF :NEW.BookDate < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20013, 'Booking date cannot be in the past');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_lock_past_booking_reassignment
BEFORE UPDATE OF Team, EventLocation ON BOOKING
FOR EACH ROW
BEGIN
    IF :OLD.BookDate < TRUNC(SYSDATE)
       AND (:OLD.Team <> :NEW.Team OR :OLD.EventLocation <> :NEW.EventLocation) THEN
        RAISE_APPLICATION_ERROR(-20014, 'Team or location cannot be changed for past bookings');
    END IF;
END;
/

-- ========================================
-- 4) OPERATIONS
-- ========================================

CREATE OR REPLACE PROCEDURE proc_register_customer(
    p_customer_code IN VARCHAR2,
    p_phone         IN VARCHAR2,
    p_email         IN VARCHAR2,
    p_customer_type IN VARCHAR2,
    p_first_name    IN VARCHAR2,
    p_last_name     IN VARCHAR2,
    p_vat           IN VARCHAR2,
    p_company_name  IN VARCHAR2
) AS
BEGIN
    IF p_customer_type = 'company' THEN
        INSERT INTO CUSTOMER VALUES (
            CustomerTY(
                p_customer_code,
                p_customer_type,
                NULL,
                NULL,
                p_vat,
                p_company_name
            )
        );
    ELSE
        INSERT INTO CUSTOMER VALUES (
            CustomerTY(
                p_customer_code,
                p_customer_type,
                p_first_name,
                p_last_name,
                NULL,
                NULL
            )
        );
    END IF;
END;
/

CREATE OR REPLACE PROCEDURE proc_add_booking(
    p_booking_code    IN VARCHAR2,
    p_booking_type    IN VARCHAR2,
    p_booking_date    IN DATE,
    p_duration_days   IN NUMBER,
    p_cost            IN NUMBER,
    p_customer_code   IN VARCHAR2,
    p_location_code   IN VARCHAR2,
    p_team_code       IN VARCHAR2,
    p_booking_channel IN VARCHAR2 DEFAULT 'website'
) AS
    v_type CHAR(1);
BEGIN
    v_type := CASE LOWER(NVL(p_booking_type, 'one-time'))
                WHEN 'one-time' THEN 'W'
                WHEN 'recurring' THEN 'M'
                                WHEN 'promotional' THEN 'P'
                ELSE 'W'
              END;

    INSERT INTO BOOKING VALUES (
        BookingTY(
            p_booking_code,
            v_type,
            p_cost,
            p_booking_date,
            p_duration_days,
            'N',
            (SELECT REF(st) FROM SETUPTEAM st WHERE st.Code = p_team_code),
            (
                SELECT REF(el)
                FROM EVENTLOCATION el
                JOIN CUSTOMER c ON REF(c) = el.Customer
                WHERE el.Code = p_location_code
                  AND c.TaxCode = p_customer_code
            )
        )
    );
END;
/

CREATE OR REPLACE PROCEDURE proc_add_event_location(
    p_location_code      IN VARCHAR2,
    p_customer_code      IN VARCHAR2,
    p_street             IN VARCHAR2,
    p_house_number       IN VARCHAR2,
    p_postal_code        IN VARCHAR2,
    p_city               IN VARCHAR2,
    p_province           IN VARCHAR2,
    p_setup_time_est     IN NUMBER,
    p_equipment_capacity IN NUMBER
) AS
    v_number NUMBER;
BEGIN
    v_number := NVL(TO_NUMBER(REGEXP_SUBSTR(p_house_number, '[0-9]+')), 1);

    INSERT INTO EVENTLOCATION VALUES (
        EventLocationTY(
            p_location_code,
            p_street,
            v_number,
            p_city,
            p_province,
            p_postal_code,
            (SELECT REF(cu) FROM CUSTOMER cu WHERE cu.TaxCode = p_customer_code)
        )
    );
END;
/

CREATE OR REPLACE FUNCTION func_get_team_by_location(
    p_customer_code IN VARCHAR2,
    p_location_code IN VARCHAR2
) RETURN VARCHAR2 AS
    v_team VARCHAR2(200);
BEGIN
    SELECT st.Code || ' - ' || st.Name
    INTO v_team
    FROM BOOKING b
    JOIN SETUPTEAM st ON DEREF(b.Team).Code = st.Code
    WHERE DEREF(b.EventLocation).Code = p_location_code
    ORDER BY b.BookDate DESC
    FETCH FIRST 1 ROW ONLY;

    RETURN v_team;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'No team found for this event location';
END;
/

CREATE OR REPLACE VIEW vw_ranked_locations AS
SELECT
    el.Code AS LocationCode,
    COUNT(b.Code) AS BookingCount
FROM EVENTLOCATION el
LEFT JOIN BOOKING b
    ON DEREF(b.EventLocation).Code = el.Code
GROUP BY el.Code
ORDER BY BookingCount DESC, el.Code;
/

-- ========================================
-- 5) POPULATION PROCEDURES (RELATION MODEL)
-- ========================================

CREATE OR REPLACE PROCEDURE populateDepot(p_num_depots IN NUMBER) AS
    v_emp_count NUMBER;
BEGIN
    FOR d IN 1 .. p_num_depots LOOP
        v_emp_count := TRUNC(DBMS_RANDOM.VALUE(8, 60));

        INSERT INTO DEPOT VALUES (
            DepotTY(
                'D' || TO_CHAR(d, 'FM000'),
                'Depot ' || DBMS_RANDOM.STRING('U', 6),
                'Street ' || DBMS_RANDOM.STRING('U', 8),
                'City ' || DBMS_RANDOM.STRING('U', 6),
                'PR' || TO_CHAR(MOD(d, 20), 'FM00'),
                v_emp_count,
                'Region ' || DBMS_RANDOM.STRING('U', 5),
                MunicipalityListTY(
                    'Municipality ' || DBMS_RANDOM.STRING('U', 6),
                    'Municipality ' || DBMS_RANDOM.STRING('U', 6),
                    'Municipality ' || DBMS_RANDOM.STRING('U', 6)
                )
            )
        );
    END LOOP;
END;
/

CREATE OR REPLACE PROCEDURE populateSetupTeam(p_num_teams_per_depot IN NUMBER) AS
    v_team_code    VARCHAR2(20);
    v_members      MemberListTY;
    v_member_count NUMBER;
BEGIN
    FOR d IN (SELECT ID FROM DEPOT ORDER BY ID) LOOP
        FOR t IN 1 .. p_num_teams_per_depot LOOP
            v_team_code := 'T' || SUBSTR(d.ID, 2) || '_' || TO_CHAR(t, 'FM00');
            v_members := MemberListTY();
            v_member_count := TRUNC(DBMS_RANDOM.VALUE(0, 11));

            FOR m IN 1 .. v_member_count LOOP
                v_members.EXTEND;
                v_members(v_members.COUNT) := MemberTY(
                    'SSN' || TO_CHAR(TO_NUMBER(SUBSTR(d.ID, 2)) * 10000 + t * 100 + m, 'FM0000000'),
                    'Name' || DBMS_RANDOM.STRING('U', 7),
                    'Surname' || DBMS_RANDOM.STRING('U', 7)
                );
            END LOOP;

            INSERT INTO SETUPTEAM VALUES (
                SetupTeamTY(
                    v_team_code,
                    'Team ' || DBMS_RANDOM.STRING('U', 6),
                    (SELECT REF(dp) FROM DEPOT dp WHERE dp.ID = d.ID),
                    v_members
                )
            );
        END LOOP;
    END LOOP;
END;
/

CREATE OR REPLACE PROCEDURE populateCustomer(p_num_customers IN NUMBER) AS
BEGIN
    FOR c IN 1 .. p_num_customers LOOP
        IF DBMS_RANDOM.VALUE(0, 1) < 0.6 THEN
            INSERT INTO CUSTOMER VALUES (
                CustomerTY(
                    'C' || TO_CHAR(c, 'FM0000'),
                    'individual',
                    'Name' || DBMS_RANDOM.STRING('U', 8),
                    'Surname' || DBMS_RANDOM.STRING('U', 8),
                    NULL,
                    NULL
                )
            );
        ELSE
            INSERT INTO CUSTOMER VALUES (
                CustomerTY(
                    'C' || TO_CHAR(c, 'FM0000'),
                    'company',
                    NULL,
                    NULL,
                    'VAT' || TO_CHAR(c, 'FM000000000'),
                    'Company ' || DBMS_RANDOM.STRING('U', 8)
                )
            );
        END IF;
    END LOOP;
END;
/

CREATE OR REPLACE PROCEDURE populateEventLocation(p_num_locations_per_customer IN NUMBER) AS
    v_location_code VARCHAR2(20);
BEGIN
    FOR c IN (SELECT TaxCode FROM CUSTOMER ORDER BY TaxCode) LOOP
        FOR l IN 1 .. p_num_locations_per_customer LOOP
            v_location_code := 'L' || SUBSTR(c.TaxCode, 2) || '_' || TO_CHAR(l, 'FM00');

            INSERT INTO EVENTLOCATION VALUES (
                EventLocationTY(
                    v_location_code,
                    'Address ' || DBMS_RANDOM.STRING('U', 10),
                    TRUNC(DBMS_RANDOM.VALUE(1, 300)),
                    'City ' || DBMS_RANDOM.STRING('U', 6),
                    'PR' || TO_CHAR(MOD(TO_NUMBER(SUBSTR(c.TaxCode, 2)), 20), 'FM00'),
                    'ZIP' || TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(10000, 99999))),
                    (SELECT REF(cu) FROM CUSTOMER cu WHERE cu.TaxCode = c.TaxCode)
                )
            );
        END LOOP;
    END LOOP;
END;
/

CREATE OR REPLACE PROCEDURE populateBooking(p_num_bookings IN NUMBER) AS
    TYPE refTeamTab IS TABLE OF REF SetupTeamTY INDEX BY PLS_INTEGER;
    TYPE refLocTab  IS TABLE OF REF EventLocationTY INDEX BY PLS_INTEGER;
    TYPE numTab     IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    teams      refTeamTab;
    locations  refLocTab;
    v_last_end numTab;
    v_t_idx    PLS_INTEGER;
    v_l_idx    PLS_INTEGER;
    v_type     CHAR(1);
    v_interval NUMBER;
    v_start    NUMBER;
    v_rand     NUMBER;
BEGIN
    SELECT REF(t) BULK COLLECT INTO teams FROM SETUPTEAM t;
    SELECT REF(l) BULK COLLECT INTO locations FROM EVENTLOCATION l;

    FOR i IN 1 .. teams.COUNT LOOP
        v_last_end(i) := 0;
    END LOOP;

    FOR b IN 1 .. p_num_bookings LOOP
        v_t_idx := TRUNC(DBMS_RANDOM.VALUE(1, teams.COUNT + 1));
        v_l_idx := TRUNC(DBMS_RANDOM.VALUE(1, locations.COUNT + 1));

        v_rand := DBMS_RANDOM.VALUE(0, 1);
        IF v_rand < 0.25 THEN
            v_type := 'P';
        ELSIF v_rand < 0.50 THEN
            v_type := 'M';
        ELSIF v_rand < 0.75 THEN
            v_type := 'E';
        ELSE
            v_type := 'W';
        END IF;

        v_interval := TRUNC(DBMS_RANDOM.VALUE(0, 4));
        v_start := v_last_end(v_t_idx) + 1 + TRUNC(DBMS_RANDOM.VALUE(0, 3));
        v_last_end(v_t_idx) := v_start + v_interval;

        INSERT INTO BOOKING VALUES (
            BookingTY(
                'B' || TO_CHAR(b, 'FM000000'),
                v_type,
                ROUND(DBMS_RANDOM.VALUE(80, 1200), 2),
                TRUNC(SYSDATE) + v_start,
                v_interval,
                CASE WHEN DBMS_RANDOM.VALUE(0, 1) < 0.3 THEN 'Y' ELSE 'N' END,
                teams(v_t_idx),
                locations(v_l_idx)
            )
        );
    END LOOP;
END;
/

CREATE OR REPLACE PROCEDURE PopulateDatabase(
    p_num_depots                  IN NUMBER,
    p_num_teams_per_depot         IN NUMBER,
    p_num_customers               IN NUMBER,
    p_num_locations_per_customer  IN NUMBER,
    p_num_bookings                IN NUMBER
) AS
BEGIN
    populateDepot(p_num_depots);
    populateSetupTeam(p_num_teams_per_depot);
    populateCustomer(p_num_customers);
    populateEventLocation(p_num_locations_per_customer);
    populateBooking(p_num_bookings);
END;
/
-- ========================================
-- 6) MINIMAL SAMPLE DATA
-- ========================================

INSERT INTO DEPOT VALUES (
    DepotTY(
        'DEP001',
        'North Depot',
        'Via Roma 10',
        'Milano',
        'MI',
        40,
        'Lombardia',
        MunicipalityListTY('Milano', 'Monza', 'Bergamo')
    )
);

INSERT INTO DEPOT VALUES (
    DepotTY(
        'DEP002',
        'Central Depot',
        'Via Firenze 22',
        'Roma',
        'RM',
        35,
        'Lazio',
        MunicipalityListTY('Roma', 'Frosinone', 'Viterbo')
    )
);

INSERT INTO SETUPTEAM VALUES (
    SetupTeamTY(
        'TEAM001',
        'Audio Crew North',
        (SELECT REF(d) FROM DEPOT d WHERE d.ID = 'DEP001'),
        MemberListTY(MemberTY('RSSMRA90A01F205X', 'Mario', 'Rossi'))
    )
);

INSERT INTO SETUPTEAM VALUES (
    SetupTeamTY(
        'TEAM002',
        'Video Crew Central',
        (SELECT REF(d) FROM DEPOT d WHERE d.ID = 'DEP002'),
        MemberListTY(MemberTY('VRDLGI92B14H501Y', 'Luigi', 'Verdi'))
    )
);

BEGIN
    proc_register_customer('CUST001', '333111222', 'alice@example.com', 'individual', 'Alice', 'Brown', NULL, NULL);
    proc_register_customer('CUST002', '333999000', 'acme@example.com', 'company', NULL, NULL, 'IT12345678901', 'ACME SRL');
END;
/

BEGIN
    proc_add_event_location('LOC001', 'CUST001', 'Main Street', '5', '20121', 'Milano', 'MI', 90, 200);
    proc_add_event_location('LOC002', 'CUST002', 'Business Ave', '12', '00144', 'Roma', 'RM', 120, 500);
END;
/

BEGIN
    proc_add_booking('BOOK001', 'one-time', TRUNC(SYSDATE) + 1, 2, 1500, 'CUST001', 'LOC001', 'TEAM001', 'website');
    proc_add_booking('BOOK002', 'promotional', TRUNC(SYSDATE) + 2, 1, 900, 'CUST002', 'LOC002', 'TEAM002', 'email');
END;
/

COMMIT;
