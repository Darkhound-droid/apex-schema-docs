# APEX Schema Docs

> Generate LLM-ready documentation from your Oracle schema in one click.

APEX Schema Docs is a free, open-source Oracle APEX application that reads your database schema through Oracle's data dictionary and generates clean, structured documentation in Markdown, JSON, and Plain Text — formatted specifically for use with AI models like Claude, ChatGPT, and others.

---

## The Problem

Oracle developers waste time manually copying DDL into AI tools one table at a time. The LLM never has enough context to give great answers.

By the time you have pasted enough tables, views, and package specs for the AI to actually understand your codebase, you have spent more time on setup than on the problem itself.

## The Solution

APEX Schema Docs reads your entire schema through `USER_*` data dictionary views and generates structured documentation in one click. Select your objects, pick a format, and get a complete context document ready to paste into any LLM or save as a file.

No data leaves your database. Everything runs inside your own APEX environment.

---

## Screenshots

<img width="957" height="422" alt="APEX Schema Docs - Schema Browser" src="https://github.com/user-attachments/assets/7616868b-0624-48df-b6e4-3a763e7da114" />
<img width="959" height="404" alt="APEX Schema Docs - Generated Output" src="https://github.com/user-attachments/assets/12935237-772e-4a8b-b725-e213c2059f99" />

---

## Features

### V2 (Current)

- **Tables** with columns, data types, nullable status, defaults, comments, and all constraint types
- **Views** with full query text and column list
- **PL/SQL Package Specs** with procedures, functions, argument names, IN/OUT modes, data types, and return types
- **Master generator** combining Tables + Views + Packages into one single output
- Three output formats: **Markdown**, **JSON**, **Plain Text**
- Token count estimation so you know if your output fits your LLM context window
- One-click copy to clipboard and file download
- Schema browser with search and multi-select for Tables, Views, and Packages
- Compatible with Oracle APEX 22.1+ and Oracle Database 19c+

---

## Installation

### Prerequisites

- Oracle Database 19c or above
- Oracle APEX 22.1 or above
- `CREATE SESSION`, `CREATE TABLE`, `CREATE PROCEDURE` privileges on your schema

### Steps

1. Run the install script in your schema via SQL Workshop or SQL*Plus:
   ```sql
   @sql/install/create_apex_schema_docs_pkg.sql
   ```
2. Import the APEX app via **App Builder > Import**:
   ```
   app/apex-schema-docs-v2.sql
   ```
3. Run the application and open **Select Objects** to get started.

For detailed setup instructions see the [Installation Guide](docs/installation.md).

---

## Usage

1. Open the **Select Objects** page
2. Search and select the Tables, Views, and Packages you want to document
3. Choose your output format: **Markdown**, **JSON**, or **Plain Text**
4. Click **Generate Documentation**
5. Copy to clipboard or download the file

See the [Usage Guide](docs/usage.md) for full details and tips.

---

## Output Examples

### Markdown — Tables

```markdown
## TABLE: EMPLOYEES
**Description:** Stores all active and historical employee records
**Estimated Rows:** 5000

### Columns
| Column    | Data Type     | Nullable | Default | Description        |
|-----------|---------------|----------|---------|--------------------|
| EMP_ID    | NUMBER(10)    | NO       | -       | Primary key        |
| FULL_NAME | VARCHAR2(200) | NO       | -       | Employee full name |
| DEPT_ID   | NUMBER(10)    | YES      | -       | Department ref     |

### Constraints
**Primary Key:** EMP_PK ON (EMP_ID)
**Foreign Keys:**
  - EMP_DEPT_FK: DEPT_ID REFERENCES DEPARTMENTS(DEPT_ID)
```

### Markdown — Views

```markdown
## VIEW: EMP_DEPARTMENT_V
**Description:** Joins employees with their department details
**Columns:** EMP_ID, FULL_NAME, DEPT_NAME, LOCATION

**Query:**
SELECT e.emp_id, e.full_name, d.dept_name, d.location
FROM   employees   e
JOIN   departments d ON d.dept_id = e.dept_id
WHERE  e.status = 'ACTIVE'
```

### Markdown — Package Specs

```markdown
## PACKAGE: EMP_PKG

### Procedures
- **HIRE_EMPLOYEE**(p_name IN VARCHAR2, p_dept_id IN NUMBER, p_salary IN NUMBER)
- **TERMINATE_EMPLOYEE**(p_emp_id IN NUMBER, p_reason IN VARCHAR2)

### Functions
- **GET_EMPLOYEE**(p_emp_id IN NUMBER) RETURN NUMBER
- **CALCULATE_TENURE**(p_emp_id IN NUMBER) RETURN NUMBER
```

### JSON

```json
{
  "schema_docs": {
    "generated_at": "2026-03-19T10:00:00",
    "generated_by": "APEX Schema Docs v2.0.0",
    "tables": [...],
    "views": [...],
    "packages": [...]
  }
}
```

### Plain Text

```
=== APEX SCHEMA DOCS ===
Generated: 2026-03-19 10:00:00
Schema: HR

TABLE: EMPLOYEES
Columns: EMP_ID, FULL_NAME, DEPT_ID, HIRE_DATE
Constraints:
  PK: EMP_PK (EMP_ID)
  FK: EMP_DEPT_FK -> DEPT_ID references DEPARTMENTS(DEPT_ID)

VIEW: EMP_DEPARTMENT_V
Columns: EMP_ID, FULL_NAME, DEPT_NAME, LOCATION

PACKAGE: EMP_PKG
  PROCEDURE HIRE_EMPLOYEE(p_name IN VARCHAR2, p_dept_id IN NUMBER)
  FUNCTION  GET_EMPLOYEE(p_emp_id IN NUMBER) RETURN NUMBER
```

---

## Roadmap

- **V1** — Tables, Columns, Constraints ✅
- **V2** — Views, PL/SQL Package Specs ✅ *(current)*
- **V3** — Triggers, Standalone Procedures and Functions, DBMS_Scheduler Jobs
- **V4** — Object relationship diagram, Direct API integration with Claude and OpenAI

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

If you find a bug or have a feature request, open an issue on GitHub.

---

## License

MIT License. See the [LICENSE](LICENSE) file for details.

---

## Author

**Hassan Raza**
Oracle ACE Associate | Senior Oracle APEX Developer
[oraclewithhassan.com](https://oraclewithhassan.com) · [GitHub](https://github.com/Darkhound-droid)
