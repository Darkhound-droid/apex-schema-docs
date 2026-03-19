# APEX Schema Docs

> Generate LLM-ready documentation from your Oracle schema in one click.

APEX Schema Docs is an open-source Oracle APEX application that reads your database schema and produces clean, structured documentation in Markdown, JSON, and Plain Text — formatted specifically for use with AI models like Claude, ChatGPT, and others.

## The Problem

Oracle developers often need to provide rich schema context to LLMs before asking for SQL or PL/SQL assistance. Manually copying DDL and object definitions table-by-table is slow, error-prone, and difficult to keep consistent. The result is wasted time and lower-quality AI responses due to incomplete context.

## The Solution

APEX Schema Docs automates schema context generation using `USER_*` data dictionary views. In one flow, you select tables, choose an output format, and generate structured documentation ready to paste into an LLM prompt or save as a file.

## Screenshots

<img width="957" height="422" alt="image" src="https://github.com/user-attachments/assets/7616868b-0624-48df-b6e4-3a763e7da114" />
<img width="959" height="404" alt="image" src="https://github.com/user-attachments/assets/12935237-772e-4a8b-b725-e213c2059f99" />



## Features

### V2 (Current)
- Tables, Columns, and Constraints documentation
- Views documentation including full query text and column list
- PL/SQL Package Spec documentation with procedures, functions, arguments, and return types
- Master generator combining Tables + Views + Packages into one single output
- Three output formats: Markdown, JSON, Plain Text
- Token count estimation
- One-click copy and file download
- Schema browser with search and multi-select for Tables, Views, and Packages
- Works on Oracle APEX 22.1+ and Oracle Database 19c+

## Installation

### Prerequisites

- Oracle Database 19c or above
- Oracle APEX 22.1 or above
- `CREATE SESSION`, `CREATE TABLE`, `CREATE PROCEDURE` privileges

### Steps

1. Run `sql/install/create_apex_schema_docs_pkg.sql` in your schema.
2. Import `app/apex-schema-docs-v1.sql` via APEX App Builder > Import.
3. Run the application.

## Usage

1. Open page **Select Tables**.
2. Optionally search/filter table names.
3. Select or deselect tables.
4. Choose **Markdown**, **JSON**, or **Plain Text** output.
5. Click **Generate Documentation**.
6. On the output page, copy the generated content or download it as a file.

See also:
- [Installation Guide](docs/installation.md)
- [Usage Guide](docs/usage.md)

## Output Examples

### Markdown Example

```markdown
## TABLE: EMPLOYEES
**Description:** Stores all employee records
**Estimated Rows:** 5000

### Columns
| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| EMP_ID | NUMBER(10) | NO | - | Primary key |
```

### JSON Example

```json
{
  "schema_docs": {
    "generated_at": "2026-03-11T10:00:00",
    "generated_by": "APEX Schema Docs v1.0",
    "tables": []
  }
}
```

### Plain Text Example

```text
=== APEX SCHEMA DOCS ===
Generated: 2026-03-11 10:00:00
Schema: HR
Tables Documented: 1
```

## Roadmap
- V1: Tables, Columns, Constraints (done)
- V2: Views, Package Specs (current)
- V3: Triggers, Standalone Procedures and Functions, DBMS_Scheduler Jobs
- V4: Object relationship diagram, Direct API integration with Claude and OpenAI

## Contributing

Pull requests are welcome. For major changes, open an issue first.

## License

MIT License. See LICENSE file.

## Author

**Hassan Raza**
Oracle ACE Apprentice | Senior Oracle APEX Developer
[oraclewithhassan.com](https://oraclewithhassan.com)
