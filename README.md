# DBProject - StageUp Inc. Database System

## Overview

DBProject contains the complete design and implementation of an Oracle database system for StageUp Inc., including:
- an object-relational data model
- PL/SQL business logic (triggers, procedures, functions)
- physical design and performance analysis
- a Flask web application to execute the required operations

## Project Structure

```text
DBProject/
|-- Paper/
|   |-- main.tex
|   |-- front.tex
|   |-- pages/
|   |   |-- 1_conceptual_design.tex
|   |   |-- 2_logical_design.tex
|   |   |-- 3_implementation.tex
|   |   |-- 5_physical_design.tex
|   |   `-- 6_web_app.tex
|   |-- Draw/
|   `-- images/
|-- Scripts/
|   |-- script.sql
|   `-- index.sql
`-- App/
    |-- app.py
    |-- database.py
    |-- templates/
    `-- static/
```

## Documentation Chapters

1. Conceptual Design
2. Logical Design
3. Implementation
4. Physical Design
5. Web Application

## SQL Scripts

- Scripts/script.sql  
  Creates schema objects, types, tables, constraints, triggers, procedures/functions, and test data.

- Scripts/index.sql  
  Runs performance validation for the 5 operations (EXPLAIN PLAN + query output).

## Implemented Operations

1. Register a new customer
2. Insert a new booking
3. Insert a new event location
4. View the team associated with a location
5. Rank locations by number of bookings

## Prerequisites

- Oracle Database XE 21c (or compatible)
- Python 3.9+
- Python packages: flask, oracledb
- LaTeX distribution (MiKTeX/TeX Live) for documentation build

## Quick Start

### 1) Database setup

Run from SQL*Plus/SQLcl with the application user (e.g., TEST):

```sql
@Scripts/script.sql
```

### 2) Operations and plan validation

```sql
@Scripts/index.sql
```

### 3) Run the web application

**Option 1: Using open.bat (Windows)**

From the project root, double-click `App/open.bat` to launch the web application directly.

**Option 2: Manual start from PowerShell**

```powershell
Set-Location App
$env:DB_USER="TEST"
$env:DB_PASSWORD="test123"
$env:DB_DSN="localhost:1521/XE"
python app.py
```

## Build Documentation

From Paper/:

```powershell
latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex
```

## Author

- Angelantonio Fedele Murolo (ID: 840167)
- Course: Database Systems
- University: University of Bari "Aldo Moro"
- Academic Year: 2025/2026
