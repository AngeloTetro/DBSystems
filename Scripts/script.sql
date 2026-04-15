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
BEGIN EXECUTE IMMEDIATE 'DROP TABLE EMPLOYEE CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE SETUPTEAM CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE DEPOT CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE CENTRALOFFICE CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE CUSTOMER CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN EXECUTE IMMEDIATE 'DROP TYPE BookingTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE EventLocationTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE EmployeeTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE SetupTeamTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE DepotTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE CentralOfficeTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE CustomerTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE AddressTY FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ========================================
-- 1) SCHEMA CREATION
-- ========================================

CREATE OR REPLACE TYPE AddressTY AS OBJECT (
    Street       VARCHAR2(100),
    HouseNumber  VARCHAR2(10),
    PostalCode   VARCHAR2(10),
    City         VARCHAR2(50),
    Province     VARCHAR2(50)
);
/

CREATE OR REPLACE TYPE CustomerTY AS OBJECT (
    CustomerCode VARCHAR2(20),
    Phone        VARCHAR2(20),
    Email        VARCHAR2(100),
    CustomerType VARCHAR2(20),
    FirstName    VARCHAR2(50),
    LastName     VARCHAR2(50),
    CompanyName  VARCHAR2(100)
);
/

CREATE OR REPLACE TYPE DepotTY AS OBJECT (
    DepotCode      VARCHAR2(20),
    DepotName      VARCHAR2(100),
    DepotAddress   AddressTY,
    RegionName     VARCHAR2(50),
    EmployeeCount  NUMBER
);
/

CREATE OR REPLACE TYPE CentralOfficeTY AS OBJECT (
    OfficeCode       VARCHAR2(20),
    OfficeName       VARCHAR2(100),
    OfficeAddress    AddressTY,
    EmployeeCount    NUMBER
);
/

CREATE OR REPLACE TYPE SetupTeamTY AS OBJECT (
    TeamCode           VARCHAR2(20),
    TeamName           VARCHAR2(100),
    MaxMembers         NUMBER,
    InstallationCount  NUMBER,
    DepotCode          VARCHAR2(20)
);
/

CREATE OR REPLACE TYPE EmployeeTY AS OBJECT (
    FiscalCode   VARCHAR2(16),
    FirstName    VARCHAR2(50),
    LastName     VARCHAR2(50),
    DateOfBirth  DATE,
    HireDate     DATE,
    TeamCode     VARCHAR2(20)
);
/

CREATE OR REPLACE TYPE EventLocationTY AS OBJECT (
    LocationCode       VARCHAR2(20),
    LocationAddress    AddressTY,
    SetupTimeEstimate  NUMBER,
    EquipmentCapacity  NUMBER,
    BookingCount       NUMBER,
    CustomerCode       VARCHAR2(20)
);
/

CREATE OR REPLACE TYPE BookingTY AS OBJECT (
    BookingCode     VARCHAR2(20),
    BookingType     VARCHAR2(20),
    BookingChannel  VARCHAR2(20),
    BookingDate     DATE,
    DurationDays    NUMBER,
    Cost            NUMBER,
    CustomerCode    VARCHAR2(20),
    LocationCode    VARCHAR2(20),
    TeamCode        VARCHAR2(20),
    OfficeCode      VARCHAR2(20)
);
/

CREATE TABLE CUSTOMER OF CustomerTY (
    PRIMARY KEY (CustomerCode),
    UNIQUE (Email),
    CONSTRAINT chk_customer_type CHECK (CustomerType IN ('individual', 'company')),
    CONSTRAINT chk_customer_data CHECK (
        (CustomerType = 'individual' AND FirstName IS NOT NULL AND LastName IS NOT NULL)
        OR
        (CustomerType = 'company' AND CompanyName IS NOT NULL)
    )
);

CREATE TABLE DEPOT OF DepotTY (
    PRIMARY KEY (DepotCode),
    CONSTRAINT chk_depot_emp CHECK (EmployeeCount >= 0)
);

CREATE TABLE CENTRALOFFICE OF CentralOfficeTY (
    PRIMARY KEY (OfficeCode),
    CONSTRAINT chk_office_emp CHECK (EmployeeCount >= 0)
);

CREATE TABLE SETUPTEAM OF SetupTeamTY (
    PRIMARY KEY (TeamCode),
    CONSTRAINT chk_team_members CHECK (MaxMembers BETWEEN 1 AND 10),
    CONSTRAINT chk_team_install CHECK (InstallationCount >= 0),
    DepotCode NOT NULL,
    FOREIGN KEY (DepotCode) REFERENCES DEPOT (DepotCode)
);

CREATE TABLE EMPLOYEE OF EmployeeTY (
    PRIMARY KEY (FiscalCode),
    TeamCode NOT NULL,
    FOREIGN KEY (TeamCode) REFERENCES SETUPTEAM (TeamCode)
);

CREATE TABLE EVENTLOCATION OF EventLocationTY (
    PRIMARY KEY (CustomerCode, LocationCode),
    CONSTRAINT chk_location_setup CHECK (SetupTimeEstimate > 0),
    CONSTRAINT chk_location_equip CHECK (EquipmentCapacity > 0),
    CONSTRAINT chk_location_booking CHECK (BookingCount >= 0),
    CustomerCode NOT NULL,
    FOREIGN KEY (CustomerCode) REFERENCES CUSTOMER (CustomerCode)
);

CREATE TABLE BOOKING OF BookingTY (
    PRIMARY KEY (BookingCode),
    CONSTRAINT chk_booking_type CHECK (BookingType IN ('one-time', 'recurring', 'seasonal', 'promotional')),
    CONSTRAINT chk_booking_channel CHECK (BookingChannel IN ('phone', 'postal', 'email', 'website')),
    CONSTRAINT chk_booking_duration CHECK (DurationDays > 0),
    CONSTRAINT chk_booking_cost CHECK (Cost >= 0),
    CustomerCode NOT NULL,
    LocationCode NOT NULL,
    TeamCode NOT NULL,
    OfficeCode NOT NULL,
    FOREIGN KEY (CustomerCode) REFERENCES CUSTOMER (CustomerCode),
    FOREIGN KEY (CustomerCode, LocationCode) REFERENCES EVENTLOCATION (CustomerCode, LocationCode),
    FOREIGN KEY (TeamCode) REFERENCES SETUPTEAM (TeamCode),
    FOREIGN KEY (OfficeCode) REFERENCES CENTRALOFFICE (OfficeCode)
);

CREATE INDEX idx_booking_location_date ON BOOKING (CustomerCode, LocationCode, BookingDate DESC);
CREATE INDEX idx_eventlocation_bookingcount ON EVENTLOCATION (BookingCount DESC);

-- ========================================
-- 2) BUSINESS LOGIC OBJECTS
-- ========================================

CREATE OR REPLACE TRIGGER trg_inc_team_installations
AFTER INSERT ON BOOKING
FOR EACH ROW
BEGIN
    UPDATE SETUPTEAM
    SET InstallationCount = InstallationCount + 1
    WHERE TeamCode = :NEW.TeamCode;
END;
/

CREATE OR REPLACE TRIGGER trg_inc_location_bookings
AFTER INSERT ON BOOKING
FOR EACH ROW
BEGIN
    UPDATE EVENTLOCATION
    SET BookingCount = BookingCount + 1
    WHERE CustomerCode = :NEW.CustomerCode
      AND LocationCode = :NEW.LocationCode;
END;
/

CREATE OR REPLACE PROCEDURE proc_register_customer (
    p_customer_code IN VARCHAR2,
    p_phone         IN VARCHAR2,
    p_email         IN VARCHAR2,
    p_customer_type IN VARCHAR2,
    p_first_name    IN VARCHAR2,
    p_last_name     IN VARCHAR2,
    p_company_name  IN VARCHAR2
)
AS
BEGIN
    INSERT INTO CUSTOMER (
        CustomerCode, Phone, Email, CustomerType, FirstName, LastName, CompanyName
    ) VALUES (
        p_customer_code, p_phone, p_email, p_customer_type, p_first_name, p_last_name, p_company_name
    );
END;
/

CREATE OR REPLACE PROCEDURE proc_add_event_location (
    p_location_code      IN VARCHAR2,
    p_customer_code      IN VARCHAR2,
    p_street             IN VARCHAR2,
    p_house_number       IN VARCHAR2,
    p_postal_code        IN VARCHAR2,
    p_city               IN VARCHAR2,
    p_province           IN VARCHAR2,
    p_setup_time_est     IN NUMBER,
    p_equipment_capacity IN NUMBER
)
AS
BEGIN
    INSERT INTO EVENTLOCATION (
        LocationCode, LocationAddress, SetupTimeEstimate, EquipmentCapacity, BookingCount, CustomerCode
    ) VALUES (
        p_location_code,
        AddressTY(p_street, p_house_number, p_postal_code, p_city, p_province),
        p_setup_time_est,
        p_equipment_capacity,
        0,
        p_customer_code
    );
END;
/

CREATE OR REPLACE PROCEDURE proc_add_booking (
    p_booking_code    IN VARCHAR2,
    p_booking_type    IN VARCHAR2,
    p_booking_date    IN DATE,
    p_duration_days   IN NUMBER,
    p_cost            IN NUMBER,
    p_customer_code   IN VARCHAR2,
    p_location_code   IN VARCHAR2,
    p_team_code       IN VARCHAR2,
    p_booking_channel IN VARCHAR2 DEFAULT 'website',
    p_office_code     IN VARCHAR2 DEFAULT 'HQ1'
)
AS
BEGIN
    INSERT INTO BOOKING (
        BookingCode, BookingType, BookingChannel, BookingDate, DurationDays, Cost,
        CustomerCode, LocationCode, TeamCode, OfficeCode
    ) VALUES (
        p_booking_code,
        p_booking_type,
        p_booking_channel,
        p_booking_date,
        p_duration_days,
        p_cost,
        p_customer_code,
        p_location_code,
        p_team_code,
        p_office_code
    );
END;
/

CREATE OR REPLACE FUNCTION func_get_team_by_location (
    p_customer_code IN VARCHAR2,
    p_location_code IN VARCHAR2
) RETURN VARCHAR2
AS
    v_team_name VARCHAR2(100);
BEGIN
    SELECT s.TeamName
    INTO v_team_name
    FROM BOOKING b
    JOIN SETUPTEAM s ON s.TeamCode = b.TeamCode
    WHERE b.CustomerCode = p_customer_code
      AND b.LocationCode = p_location_code
    ORDER BY b.BookingDate DESC
    FETCH FIRST 1 ROW ONLY;

    RETURN v_team_name;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'No team found for this location';
END;
/

CREATE OR REPLACE VIEW vw_ranked_locations AS
SELECT LocationCode, BookingCount
FROM EVENTLOCATION
ORDER BY BookingCount DESC;
/

-- ========================================
-- 3) DATA POPULATION
-- ========================================

INSERT INTO CENTRALOFFICE VALUES (
    CentralOfficeTY('HQ1', 'StageUp Central Office', AddressTY('Corso Italia', '1', '00100', 'Roma', 'RM'), 25)
);

INSERT INTO DEPOT VALUES (
    DepotTY('DEP001', 'North Depot', AddressTY('Via Roma', '10', '20100', 'Milano', 'MI'), 'Lombardia', 40)
);

INSERT INTO DEPOT VALUES (
    DepotTY('DEP002', 'Central Depot', AddressTY('Via Firenze', '22', '00100', 'Roma', 'RM'), 'Lazio', 35)
);

INSERT INTO SETUPTEAM VALUES (SetupTeamTY('TEAM001', 'Audio Crew North', 10, 0, 'DEP001'));
INSERT INTO SETUPTEAM VALUES (SetupTeamTY('TEAM002', 'Video Crew Central', 10, 0, 'DEP002'));

INSERT INTO EMPLOYEE VALUES (EmployeeTY('RSSMRA90A01F205X', 'Mario', 'Rossi', DATE '1990-01-01', DATE '2020-03-10', 'TEAM001'));
INSERT INTO EMPLOYEE VALUES (EmployeeTY('VRDLGI92B14H501Y', 'Luigi', 'Verdi', DATE '1992-02-14', DATE '2021-06-01', 'TEAM002'));

BEGIN
    proc_register_customer('CUST001', '333111222', 'alice@example.com', 'individual', 'Alice', 'Brown', NULL);
    proc_register_customer('CUST002', '333999000', 'acme@example.com', 'company', NULL, NULL, 'ACME SRL');
END;
/

BEGIN
    proc_add_event_location('LOC001', 'CUST001', 'Main Street', '5', '20121', 'Milano', 'MI', 90, 200);
    proc_add_event_location('LOC002', 'CUST002', 'Business Ave', '12', '00144', 'Roma', 'RM', 120, 500);
END;
/

BEGIN
    proc_add_booking('BOOK001', 'one-time', TRUNC(SYSDATE) + 1, 2, 1500, 'CUST001', 'LOC001', 'TEAM001');
    proc_add_booking('BOOK002', 'promotional', TRUNC(SYSDATE) + 2, 1, 900, 'CUST002', 'LOC002', 'TEAM002', 'email');
END;
/

COMMIT;

-- ========================================
-- 4) OPERATION TESTS
-- ========================================

BEGIN
    proc_register_customer('CUST003', '320111000', 'newcustomer@example.com', 'individual', 'John', 'Doe', NULL);
END;
/
SELECT CustomerCode, CustomerType, Email FROM CUSTOMER WHERE CustomerCode = 'CUST003';

BEGIN
    proc_add_booking('BOOK003', 'seasonal', TRUNC(SYSDATE) + 3, 5, 3200, 'CUST001', 'LOC001', 'TEAM001', 'phone');
END;
/
SELECT BookingCode, BookingType, TeamCode FROM BOOKING WHERE BookingCode = 'BOOK003';

BEGIN
    proc_add_event_location('LOC003', 'CUST001', 'Lake Road', '44', '20122', 'Milano', 'MI', 80, 180);
END;
/
SELECT LocationCode, CustomerCode, BookingCount FROM EVENTLOCATION WHERE LocationCode = 'LOC003';

SELECT func_get_team_by_location('CUST001', 'LOC001') AS TEAM_NAME FROM DUAL;
SELECT * FROM vw_ranked_locations;
