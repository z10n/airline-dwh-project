# ✈️ Airline Data Warehouse with Row-Level Security (RLS)

This project demonstrates the implementation of a secure Data Warehouse on **Snowflake**, featuring dynamic **Row-Level Security (RLS)**. It simulates a real-world scenario where different regional teams (e.g., Japan, USA) can only access data relevant to their specific continent, while administrators retain full visibility.

##  Key Features

-   **Multi-Layer Architecture:** Raw, Staging, and Marts layers for clean data organization.
-   **Dynamic Row-Level Security:** Uses Snowflake's `ROW ACCESS POLICY` to filter data at query time based on the user's role.
-   **Role-Based Access Control (RBAC):** Custom roles (`ROLE_JAPAN`, `ROLE_USA`) with least-privilege permissions.
-   **Secure Views:** Implementation of secure views to protect sensitive underlying logic.
-   **Automated Testing:** SQL scripts to verify that security policies are working correctly for each role.

## ️ Architecture & Security Logic

The security model relies on a simple but effective mapping between **Roles** and **Continents**:

| Role | Allowed Continent | Expected Result |
| :--- | :--- | :--- |
| `ROLE_JAPAN` | Asia (`ASIA`) | Sees only Asian airports/flights |
| `ROLE_USA` | North America (`NAM`) | Sees only North American airports/flights |
| `ACCOUNTADMIN` | All | Full access to all data |

### How RLS Works Here
1.  A **Row Access Policy** (`rap_continent_filter`) is attached to the `DIM_AIRPORTS` table.
2.  The policy evaluates `CURRENT_ROLE()` at runtime.
3.  If the role matches the allowed continent code, the row is returned; otherwise, it is hidden.

```sql
-- Simplified Logic of the Policy
CASE 
    WHEN CURRENT_ROLE() = 'ROLE_JAPAN' AND continent_code = 'ASIA' THEN TRUE
    WHEN CURRENT_ROLE() = 'ROLE_USA' AND continent_code = 'NAM' THEN TRUE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN') THEN TRUE
    ELSE FALSE
END
```

## 🛠️ Setup & Installation

### Prerequisites
-   A Snowflake account with `ACCOUNTADMIN` privileges.
-   SnowSQL or Snowsight interface.

### Step-by-Step Guide

1.  **Clone the Repository**
    ```bash
    git clone <your-repo-url>
    cd airline-dwh-security
    ```

2.  **Run Infrastructure Scripts**
    Execute the SQL files in numerical order to build the database, schemas, and tables:
    -   `01_infrastructure.sql`: Creates DB, Schemas, and Roles.
    -   `02_raw_layer.sql` to `04_marts_tables.sql`: Builds the data model.
    -   `06_load_data.sql`: Populates tables with sample data.

3.  **Apply Security Policies**
    Run `11_security.sql`. This script:
    -   Creates the `rap_continent_filter` policy.
    -   Attaches it to `DIM_AIRPORTS`.
    -   Grants necessary `USAGE` and `SELECT` privileges to regional roles.

## 🧪 Verification & Testing

To verify that RLS is working, run the test queries included in `11_security.sql` or use the snippets below:

**Test as Japan Team:**
```sql
USE ROLE role_japan;
SELECT DISTINCT continent_name, COUNT(*) 
FROM airline_dwh.marts.dim_airports 
GROUP BY continent_name;
-- Expected Output: Only 'Asia'
```

**Test as USA Team:**
```sql
USE ROLE role_usa;
SELECT DISTINCT continent_name, COUNT(*) 
FROM airline_dwh.marts.dim_airports 
GROUP BY continent_name;
-- Expected Output: Only 'North America'
```

## 📂 Project Structure

```text
├── 01_infrastructure.sql      # DB, Schema, Role creation
├── 02_raw_layer.sql           # Raw data tables
├── 03_staging_views.sql       # Cleaning & staging logic
├── 04_marts_tables.sql        # Final dimensional & fact tables
├── 06_load_data.sql           # Data ingestion
├── 11_security.sql            # RLS Policies & Access Control
└── README.md
```

## 💡 Lessons Learned
-   **Policy Management:** Always detach a policy (`ALTER TABLE ... DROP ROW ACCESS POLICY`) before dropping or replacing it if it's currently bound to a table.
-   **Case Sensitivity:** `CURRENT_ROLE()` returns uppercase identifiers by default. Ensure your policy comparisons match this format (e.g., `'ROLE_JAPAN'` not `'role_japan'`).
-   **Permissions:** RLS filters *rows*, but standard GRANTS still control *access*. Users need `USAGE` on the schema and `SELECT` on the table to see even the filtered results.

---
*Built with Snowflake | Data Engineering & Security Demo*