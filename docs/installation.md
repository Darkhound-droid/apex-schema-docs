# Installation Guide

## Prerequisites

- Oracle Database 19c+
- Oracle APEX 22.1+
- Access to a target schema
- Privileges to create PL/SQL objects and import APEX applications

## Install Steps

1. Connect to your schema in SQL Workshop or SQL*Plus.
2. Run:
   - `sql/install/create_apex_schema_docs_pkg.sql`
3. In APEX App Builder, import:
   - `app/apex-schema-docs-v1.sql`
4. Run the application.

## Uninstall

Run:

- `sql/uninstall/drop_apex_schema_docs_pkg.sql`

Then delete the imported APEX app from App Builder.
