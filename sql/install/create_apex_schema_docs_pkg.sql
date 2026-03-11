SET DEFINE OFF;

/*
  File: create_apex_schema_docs_pkg.sql
  Purpose: Install APEX_SCHEMA_DOCS_PKG for generating schema documentation outputs.
  Author: Hassan Raza
  Version: 1.0.0
  License: MIT
  Oracle Compatibility: 19c and above
*/

CREATE OR REPLACE PACKAGE apex_schema_docs_pkg AS

  -- Returns a list of all user tables for the schema browser
  FUNCTION get_table_list
    RETURN SYS_REFCURSOR;

  -- Generates Markdown documentation for selected tables
  -- p_table_names: comma-separated list of table names, or NULL for all tables
  FUNCTION generate_markdown (
    p_table_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  -- Generates JSON documentation for selected tables
  FUNCTION generate_json (
    p_table_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  -- Generates Plain Text documentation for selected tables
  FUNCTION generate_plain_text (
    p_table_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  -- Returns token estimate for the generated output
  -- Approximation: 1 token per 4 characters
  FUNCTION estimate_tokens (
    p_content IN CLOB
  ) RETURN NUMBER;

END apex_schema_docs_pkg;
/

CREATE OR REPLACE PACKAGE BODY apex_schema_docs_pkg AS

  g_newline CONSTANT VARCHAR2(2) := CHR(10);

  TYPE t_varchar2_tab IS TABLE OF VARCHAR2(32767);

  PROCEDURE append_line(
    p_clob IN OUT NOCOPY CLOB,
    p_text IN VARCHAR2
  ) IS
  BEGIN
    DBMS_LOB.APPEND(p_clob, TO_CLOB(NVL(p_text, '')) || g_newline);
  END append_line;

  FUNCTION format_data_type(
    p_data_type      IN VARCHAR2,
    p_data_length    IN NUMBER,
    p_data_precision IN NUMBER,
    p_data_scale     IN NUMBER
  ) RETURN VARCHAR2 IS
  BEGIN
    IF p_data_type IN ('VARCHAR2', 'NVARCHAR2', 'CHAR', 'NCHAR') THEN
      RETURN p_data_type || '(' || p_data_length || ')';
    ELSIF p_data_type = 'NUMBER' THEN
      IF p_data_precision IS NOT NULL AND p_data_scale IS NOT NULL THEN
        RETURN 'NUMBER(' || p_data_precision || ',' || p_data_scale || ')';
      ELSIF p_data_precision IS NOT NULL THEN
        RETURN 'NUMBER(' || p_data_precision || ')';
      ELSE
        RETURN 'NUMBER';
      END IF;
    ELSE
      RETURN p_data_type;
    END IF;
  END format_data_type;

  FUNCTION escape_json(p_text IN VARCHAR2) RETURN VARCHAR2 IS
    l_text VARCHAR2(32767) := NVL(p_text, '');
  BEGIN
    l_text := REPLACE(l_text, '\\', '\\\\');
    l_text := REPLACE(l_text, '"', '\\"');
    l_text := REPLACE(l_text, CHR(10), '\\n');
    l_text := REPLACE(l_text, CHR(13), '\\r');
    l_text := REPLACE(l_text, CHR(9), '\\t');
    RETURN l_text;
  END escape_json;

  FUNCTION in_selected_tables(
    p_table_name IN VARCHAR2,
    p_tables     IN apex_t_varchar2
  ) RETURN BOOLEAN IS
    l_value VARCHAR2(32767);
  BEGIN
    IF p_tables IS NULL OR p_tables.COUNT = 0 THEN
      RETURN TRUE;
    END IF;

    FOR i IN 1 .. p_tables.COUNT LOOP
      l_value := TRIM(UPPER(p_tables(i)));
      IF l_value = UPPER(p_table_name) THEN
        RETURN TRUE;
      END IF;
    END LOOP;

    RETURN FALSE;
  END in_selected_tables;

  /*
    Purpose: Returns all tables in the current user schema with comments and stats.
    Parameters: None.
    Return Value: SYS_REFCURSOR with TABLE_NAME, NUM_ROWS, LAST_ANALYZED, COMMENTS.
    Example Usage: OPEN l_rc FOR SELECT * FROM TABLE(apex_schema_docs_pkg.get_table_list);
  */
  FUNCTION get_table_list
    RETURN SYS_REFCURSOR IS
    l_rc SYS_REFCURSOR;
  BEGIN
    OPEN l_rc FOR
      SELECT ut.table_name,
             ut.num_rows,
             ut.last_analyzed,
             utc.comments
        FROM user_tables ut
        LEFT JOIN user_tab_comments utc
          ON utc.table_name = ut.table_name
       ORDER BY ut.table_name;

    RETURN l_rc;
  END get_table_list;

  /*
    Purpose: Generates Markdown schema documentation for selected tables.
    Parameters: p_table_names - comma-separated list of table names, NULL means all.
    Return Value: CLOB containing formatted Markdown.
    Example Usage: SELECT apex_schema_docs_pkg.generate_markdown('EMP,DEPT') FROM dual;
  */
  FUNCTION generate_markdown (
    p_table_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_output       CLOB;
    l_tables       apex_t_varchar2;
    l_col_list     VARCHAR2(4000);
    l_has_any      BOOLEAN;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_output, TRUE);
    l_tables := CASE WHEN p_table_names IS NOT NULL THEN apex_string.split(p_table_names, ',') ELSE apex_t_varchar2() END;

    FOR t IN (
      SELECT ut.table_name,
             ut.num_rows,
             NVL(utc.comments, 'No description available') AS comments
        FROM user_tables ut
        LEFT JOIN user_tab_comments utc
          ON utc.table_name = ut.table_name
       ORDER BY ut.table_name
    ) LOOP
      BEGIN
        IF NOT in_selected_tables(t.table_name, l_tables) THEN
          CONTINUE;
        END IF;

        append_line(l_output, '## TABLE: ' || t.table_name);
        append_line(l_output, '**Description:** ' || t.comments);
        append_line(l_output, '**Estimated Rows:** ' || NVL(TO_CHAR(t.num_rows), 'Unknown'));
        append_line(l_output, '');
        append_line(l_output, '### Columns');
        append_line(l_output, '| Column | Data Type | Nullable | Default | Description |');
        append_line(l_output, '|---|---|---|---|---|');

        FOR c IN (
          SELECT utc.column_name,
                 utc.data_type,
                 utc.data_length,
                 utc.data_precision,
                 utc.data_scale,
                 utc.nullable,
                 utc.data_default,
                 ucc.comments
            FROM user_tab_columns utc
            LEFT JOIN user_col_comments ucc
              ON ucc.table_name = utc.table_name
             AND ucc.column_name = utc.column_name
           WHERE utc.table_name = t.table_name
           ORDER BY utc.column_id
        ) LOOP
          append_line(
            l_output,
            '| ' || c.column_name ||
            ' | ' || format_data_type(c.data_type, c.data_length, c.data_precision, c.data_scale) ||
            ' | ' || CASE WHEN c.nullable = 'Y' THEN 'YES' ELSE 'NO' END ||
            ' | ' || NVL(TRIM(REPLACE(REPLACE(c.data_default, CHR(10), ' '), CHR(13), ' ')), '-') ||
            ' | ' || NVL(c.comments, '-') || ' |'
          );
        END LOOP;

        append_line(l_output, '');
        append_line(l_output, '### Constraints');

        l_col_list := NULL;
        SELECT LISTAGG(ucc.column_name, ', ') WITHIN GROUP (ORDER BY ucc.position)
          INTO l_col_list
          FROM user_constraints uc
          JOIN user_cons_columns ucc
            ON ucc.constraint_name = uc.constraint_name
           AND ucc.table_name = uc.table_name
         WHERE uc.table_name = t.table_name
           AND uc.constraint_type = 'P';

        IF l_col_list IS NOT NULL THEN
          FOR pk IN (
            SELECT uc.constraint_name
              FROM user_constraints uc
             WHERE uc.table_name = t.table_name
               AND uc.constraint_type = 'P'
          ) LOOP
            append_line(l_output, '**Primary Key:** ' || pk.constraint_name || ' ON (' || l_col_list || ')');
          END LOOP;
        ELSE
          append_line(l_output, '**Primary Key:** -');
        END IF;

        l_has_any := FALSE;
        FOR uk IN (
          SELECT uc.constraint_name,
                 LISTAGG(ucc.column_name, ', ') WITHIN GROUP (ORDER BY ucc.position) AS col_list
            FROM user_constraints uc
            JOIN user_cons_columns ucc
              ON ucc.constraint_name = uc.constraint_name
             AND ucc.table_name = uc.table_name
           WHERE uc.table_name = t.table_name
             AND uc.constraint_type = 'U'
           GROUP BY uc.constraint_name
           ORDER BY uc.constraint_name
        ) LOOP
          append_line(l_output, '**Unique:** ' || uk.constraint_name || ' ON (' || uk.col_list || ')');
          l_has_any := TRUE;
        END LOOP;
        IF NOT l_has_any THEN
          append_line(l_output, '**Unique:** -');
        END IF;

        append_line(l_output, '**Foreign Keys:**');
        l_has_any := FALSE;
        FOR fk IN (
          SELECT uc1.constraint_name,
                 ucc1.column_name AS fk_column,
                 uc2.table_name   AS ref_table,
                 ucc2.column_name AS ref_column
            FROM user_constraints  uc1
            JOIN user_cons_columns ucc1 ON ucc1.constraint_name = uc1.constraint_name
                                      AND ucc1.table_name      = uc1.table_name
            JOIN user_constraints  uc2  ON uc2.constraint_name  = uc1.r_constraint_name
            JOIN user_cons_columns ucc2 ON ucc2.constraint_name = uc2.constraint_name
                                      AND ucc2.position        = ucc1.position
           WHERE uc1.constraint_type = 'R'
             AND uc1.table_name      = t.table_name
           ORDER BY uc1.constraint_name, ucc1.position
        ) LOOP
          append_line(l_output, '  - ' || fk.constraint_name || ': ' || fk.fk_column || ' REFERENCES ' || fk.ref_table || '(' || fk.ref_column || ')');
          l_has_any := TRUE;
        END LOOP;
        IF NOT l_has_any THEN
          append_line(l_output, '  - None');
        END IF;

        append_line(l_output, '**Check Constraints:**');
        l_has_any := FALSE;
        FOR ck IN (
          SELECT constraint_name,
                 search_condition
            FROM user_constraints
           WHERE constraint_type = 'C'
             AND table_name = t.table_name
             AND UPPER(search_condition) NOT LIKE '%IS NOT NULL%'
           ORDER BY constraint_name
        ) LOOP
          append_line(l_output, '  - ' || ck.constraint_name || ': ' || NVL(ck.search_condition, '-'));
          l_has_any := TRUE;
        END LOOP;
        IF NOT l_has_any THEN
          append_line(l_output, '  - None');
        END IF;

        append_line(l_output, '');
        append_line(l_output, '---');
        append_line(l_output, '');
      EXCEPTION
        WHEN OTHERS THEN
          append_line(l_output, '## TABLE: ' || t.table_name);
          append_line(l_output, '**Error:** Unable to document table due to: ' || SQLERRM);
          append_line(l_output, '---');
      END;
    END LOOP;

    RETURN l_output;
  END generate_markdown;

  /*
    Purpose: Generates JSON schema documentation for selected tables.
    Parameters: p_table_names - comma-separated list of table names, NULL means all.
    Return Value: CLOB containing valid JSON.
    Example Usage: SELECT apex_schema_docs_pkg.generate_json(NULL) FROM dual;
  */
  FUNCTION generate_json (
    p_table_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_output      CLOB;
    l_tables      apex_t_varchar2;
    l_first_table BOOLEAN := TRUE;
    l_first_col   BOOLEAN;
    l_first_uk    BOOLEAN;
    l_first_fk    BOOLEAN;
    l_first_ck    BOOLEAN;
    l_first_fk_col BOOLEAN;
    l_first_ref_col BOOLEAN;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_output, TRUE);
    l_tables := CASE WHEN p_table_names IS NOT NULL THEN apex_string.split(p_table_names, ',') ELSE apex_t_varchar2() END;

    append_line(l_output, '{');
    append_line(l_output, '  "schema_docs": {');
    append_line(l_output, '    "generated_at": "' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD"T"HH24:MI:SS') || '",');
    append_line(l_output, '    "generated_by": "APEX Schema Docs v1.0",');
    append_line(l_output, '    "tables": [');

    FOR t IN (
      SELECT ut.table_name,
             ut.num_rows,
             NVL(utc.comments, 'No description available') AS comments
        FROM user_tables ut
        LEFT JOIN user_tab_comments utc
          ON utc.table_name = ut.table_name
       ORDER BY ut.table_name
    ) LOOP
      BEGIN
        IF NOT in_selected_tables(t.table_name, l_tables) THEN
          CONTINUE;
        END IF;

        IF NOT l_first_table THEN
          DBMS_LOB.APPEND(l_output, TO_CLOB(',' || g_newline));
        END IF;
        l_first_table := FALSE;

        append_line(l_output, '      {');
        append_line(l_output, '        "name": "' || escape_json(t.table_name) || '",');
        append_line(l_output, '        "description": "' || escape_json(t.comments) || '",');
        append_line(l_output, '        "estimated_rows": ' || NVL(TO_CHAR(t.num_rows), 'null') || ',');
        append_line(l_output, '        "columns": [');

        l_first_col := TRUE;
        FOR c IN (
          SELECT utc.column_name,
                 utc.data_type,
                 utc.data_length,
                 utc.data_precision,
                 utc.data_scale,
                 utc.nullable,
                 utc.data_default,
                 ucc.comments
            FROM user_tab_columns utc
            LEFT JOIN user_col_comments ucc
              ON ucc.table_name = utc.table_name
             AND ucc.column_name = utc.column_name
           WHERE utc.table_name = t.table_name
           ORDER BY utc.column_id
        ) LOOP
          IF NOT l_first_col THEN
            DBMS_LOB.APPEND(l_output, TO_CLOB(',' || g_newline));
          END IF;
          l_first_col := FALSE;

          append_line(l_output, '          {');
          append_line(l_output, '            "name": "' || escape_json(c.column_name) || '",');
          append_line(l_output, '            "data_type": "' || escape_json(format_data_type(c.data_type, c.data_length, c.data_precision, c.data_scale)) || '",');
          append_line(l_output, '            "nullable": ' || CASE WHEN c.nullable = 'Y' THEN 'true' ELSE 'false' END || ',');
          IF c.data_default IS NULL THEN
            append_line(l_output, '            "default": null,');
          ELSE
            append_line(l_output, '            "default": "' || escape_json(TRIM(c.data_default)) || '",');
          END IF;
          append_line(l_output, '            "description": "' || escape_json(NVL(c.comments, '-')) || '"');
          append_line(l_output, '          }');
        END LOOP;

        append_line(l_output, '        ],');
        append_line(l_output, '        "constraints": {');

        FOR pk IN (
          SELECT uc.constraint_name,
                 LISTAGG(ucc.column_name, '","') WITHIN GROUP (ORDER BY ucc.position) AS cols
            FROM user_constraints uc
            JOIN user_cons_columns ucc
              ON ucc.constraint_name = uc.constraint_name
             AND ucc.table_name = uc.table_name
           WHERE uc.table_name = t.table_name
             AND uc.constraint_type = 'P'
           GROUP BY uc.constraint_name
        ) LOOP
          append_line(l_output, '          "primary_key": {');
          append_line(l_output, '            "name": "' || escape_json(pk.constraint_name) || '",');
          append_line(l_output, '            "columns": ["' || escape_json(pk.cols) || '"]');
          append_line(l_output, '          },');
        END LOOP;

        IF SQL%ROWCOUNT = 0 THEN
          append_line(l_output, '          "primary_key": null,');
        END IF;

        append_line(l_output, '          "unique_keys": [');
        l_first_uk := TRUE;
        FOR uk IN (
          SELECT uc.constraint_name,
                 LISTAGG(ucc.column_name, '","') WITHIN GROUP (ORDER BY ucc.position) AS cols
            FROM user_constraints uc
            JOIN user_cons_columns ucc
              ON ucc.constraint_name = uc.constraint_name
             AND ucc.table_name = uc.table_name
           WHERE uc.table_name = t.table_name
             AND uc.constraint_type = 'U'
           GROUP BY uc.constraint_name
           ORDER BY uc.constraint_name
        ) LOOP
          IF NOT l_first_uk THEN
            DBMS_LOB.APPEND(l_output, TO_CLOB(',' || g_newline));
          END IF;
          l_first_uk := FALSE;
          append_line(l_output, '            {"name":"' || escape_json(uk.constraint_name) || '","columns":["' || escape_json(uk.cols) || '"]}');
        END LOOP;
        append_line(l_output, '          ],');

        append_line(l_output, '          "foreign_keys": [');
        l_first_fk := TRUE;
        FOR fk_name IN (
          SELECT DISTINCT uc1.constraint_name,
                 uc2.table_name AS ref_table
            FROM user_constraints uc1
            JOIN user_constraints uc2
              ON uc2.constraint_name = uc1.r_constraint_name
           WHERE uc1.constraint_type = 'R'
             AND uc1.table_name = t.table_name
           ORDER BY uc1.constraint_name
        ) LOOP
          IF NOT l_first_fk THEN
            DBMS_LOB.APPEND(l_output, TO_CLOB(',' || g_newline));
          END IF;
          l_first_fk := FALSE;

          append_line(l_output, '            {');
          append_line(l_output, '              "name": "' || escape_json(fk_name.constraint_name) || '",');
          append_line(l_output, '              "columns": [');
          l_first_fk_col := TRUE;
          FOR fk_col IN (
            SELECT ucc1.column_name
              FROM user_constraints uc1
              JOIN user_cons_columns ucc1 ON ucc1.constraint_name = uc1.constraint_name
                                        AND ucc1.table_name      = uc1.table_name
             WHERE uc1.constraint_name = fk_name.constraint_name
             ORDER BY ucc1.position
          ) LOOP
            IF NOT l_first_fk_col THEN
              DBMS_LOB.APPEND(l_output, TO_CLOB(','));
            END IF;
            l_first_fk_col := FALSE;
            DBMS_LOB.APPEND(l_output, TO_CLOB('"' || escape_json(fk_col.column_name) || '"'));
          END LOOP;
          DBMS_LOB.APPEND(l_output, TO_CLOB(g_newline));
          append_line(l_output, '              ],');
          append_line(l_output, '              "references_table": "' || escape_json(fk_name.ref_table) || '",');
          append_line(l_output, '              "references_columns": [');
          l_first_ref_col := TRUE;
          FOR ref_col IN (
            SELECT ucc2.column_name
              FROM user_constraints uc1
              JOIN user_cons_columns ucc1 ON ucc1.constraint_name = uc1.constraint_name
                                        AND ucc1.table_name      = uc1.table_name
              JOIN user_constraints uc2   ON uc2.constraint_name  = uc1.r_constraint_name
              JOIN user_cons_columns ucc2 ON ucc2.constraint_name = uc2.constraint_name
                                        AND ucc2.position        = ucc1.position
             WHERE uc1.constraint_name = fk_name.constraint_name
             ORDER BY ucc1.position
          ) LOOP
            IF NOT l_first_ref_col THEN
              DBMS_LOB.APPEND(l_output, TO_CLOB(','));
            END IF;
            l_first_ref_col := FALSE;
            DBMS_LOB.APPEND(l_output, TO_CLOB('"' || escape_json(ref_col.column_name) || '"'));
          END LOOP;
          DBMS_LOB.APPEND(l_output, TO_CLOB(g_newline));
          append_line(l_output, '              ]');
          append_line(l_output, '            }');
        END LOOP;
        append_line(l_output, '          ],');

        append_line(l_output, '          "check_constraints": [');
        l_first_ck := TRUE;
        FOR ck IN (
          SELECT constraint_name,
                 search_condition
            FROM user_constraints
           WHERE constraint_type = 'C'
             AND table_name = t.table_name
             AND UPPER(search_condition) NOT LIKE '%IS NOT NULL%'
           ORDER BY constraint_name
        ) LOOP
          IF NOT l_first_ck THEN
            DBMS_LOB.APPEND(l_output, TO_CLOB(',' || g_newline));
          END IF;
          l_first_ck := FALSE;
          append_line(l_output, '            {"name":"' || escape_json(ck.constraint_name) || '","condition":"' || escape_json(ck.search_condition) || '"}');
        END LOOP;
        append_line(l_output, '          ]');

        append_line(l_output, '        }');
        append_line(l_output, '      }');
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END LOOP;

    append_line(l_output, '    ]');
    append_line(l_output, '  }');
    append_line(l_output, '}');

    RETURN l_output;
  END generate_json;

  /*
    Purpose: Generates plain text schema documentation for selected tables.
    Parameters: p_table_names - comma-separated list of table names, NULL means all.
    Return Value: CLOB containing plain text output.
    Example Usage: SELECT apex_schema_docs_pkg.generate_plain_text('EMPLOYEES') FROM dual;
  */
  FUNCTION generate_plain_text (
    p_table_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_output      CLOB;
    l_tables      apex_t_varchar2;
    l_schema      VARCHAR2(128);
    l_table_count NUMBER := 0;
    l_has_any     BOOLEAN;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_output, TRUE);
    l_tables := CASE WHEN p_table_names IS NOT NULL THEN apex_string.split(p_table_names, ',') ELSE apex_t_varchar2() END;
    l_schema := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');

    FOR t_count IN (
      SELECT COUNT(*) AS cnt
        FROM user_tables ut
       WHERE p_table_names IS NULL
          OR EXISTS (
               SELECT 1
                 FROM TABLE(apex_string.split(p_table_names, ',')) x
                WHERE UPPER(TRIM(x.column_value)) = UPPER(ut.table_name)
             )
    ) LOOP
      l_table_count := t_count.cnt;
    END LOOP;

    append_line(l_output, '=== APEX SCHEMA DOCS ===');
    append_line(l_output, 'Generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    append_line(l_output, 'Schema: ' || l_schema);
    append_line(l_output, 'Tables Documented: ' || l_table_count);
    append_line(l_output, '');

    FOR t IN (
      SELECT ut.table_name,
             ut.num_rows,
             NVL(utc.comments, 'No description available') AS comments
        FROM user_tables ut
        LEFT JOIN user_tab_comments utc
          ON utc.table_name = ut.table_name
       ORDER BY ut.table_name
    ) LOOP
      BEGIN
        IF NOT in_selected_tables(t.table_name, l_tables) THEN
          CONTINUE;
        END IF;

        append_line(l_output, 'TABLE: ' || t.table_name);
        append_line(l_output, 'Description: ' || t.comments);
        append_line(l_output, 'Rows: ' || CASE WHEN t.num_rows IS NOT NULL THEN '~' || t.num_rows ELSE 'Unknown' END);
        append_line(l_output, '');
        append_line(l_output, 'COLUMNS:');

        FOR c IN (
          SELECT utc.column_name,
                 utc.data_type,
                 utc.data_length,
                 utc.data_precision,
                 utc.data_scale,
                 utc.nullable,
                 ucc.comments
            FROM user_tab_columns utc
            LEFT JOIN user_col_comments ucc
              ON ucc.table_name = utc.table_name
             AND ucc.column_name = utc.column_name
           WHERE utc.table_name = t.table_name
           ORDER BY utc.column_id
        ) LOOP
          append_line(
            l_output,
            '  ' || RPAD(c.column_name, 15) || ' ' ||
            RPAD(format_data_type(c.data_type, c.data_length, c.data_precision, c.data_scale), 18) || ' ' ||
            RPAD(CASE WHEN c.nullable = 'N' THEN 'NOT NULL' ELSE 'NULL' END, 10) || ' ' ||
            NVL(c.comments, '-')
          );
        END LOOP;

        append_line(l_output, '');
        append_line(l_output, 'CONSTRAINTS:');

        FOR pk IN (
          SELECT uc.constraint_name,
                 LISTAGG(ucc.column_name, ', ') WITHIN GROUP (ORDER BY ucc.position) AS col_list
            FROM user_constraints uc
            JOIN user_cons_columns ucc
              ON ucc.constraint_name = uc.constraint_name
             AND ucc.table_name = uc.table_name
           WHERE uc.table_name = t.table_name
             AND uc.constraint_type = 'P'
           GROUP BY uc.constraint_name
        ) LOOP
          append_line(l_output, '  PK: ' || pk.constraint_name || ' (' || pk.col_list || ')');
        END LOOP;

        FOR fk IN (
          SELECT uc1.constraint_name,
                 LISTAGG(ucc1.column_name, ', ') WITHIN GROUP (ORDER BY ucc1.position) AS fk_cols,
                 uc2.table_name AS ref_table,
                 LISTAGG(ucc2.column_name, ', ') WITHIN GROUP (ORDER BY ucc2.position) AS ref_cols
            FROM user_constraints uc1
            JOIN user_cons_columns ucc1 ON ucc1.constraint_name = uc1.constraint_name
                                      AND ucc1.table_name      = uc1.table_name
            JOIN user_constraints uc2   ON uc2.constraint_name  = uc1.r_constraint_name
            JOIN user_cons_columns ucc2 ON ucc2.constraint_name = uc2.constraint_name
                                      AND ucc2.position        = ucc1.position
           WHERE uc1.constraint_type = 'R'
             AND uc1.table_name = t.table_name
           GROUP BY uc1.constraint_name, uc2.table_name
           ORDER BY uc1.constraint_name
        ) LOOP
          append_line(l_output, '  FK: ' || fk.constraint_name || ' -> ' || fk.fk_cols || ' references ' || fk.ref_table || '(' || fk.ref_cols || ')');
        END LOOP;

        l_has_any := FALSE;
        FOR ck IN (
          SELECT constraint_name,
                 search_condition
            FROM user_constraints
           WHERE constraint_type = 'C'
             AND table_name = t.table_name
             AND UPPER(search_condition) NOT LIKE '%IS NOT NULL%'
           ORDER BY constraint_name
        ) LOOP
          append_line(l_output, '  CHECK: ' || ck.constraint_name || ' -> ' || ck.search_condition);
          l_has_any := TRUE;
        END LOOP;

        IF NOT l_has_any THEN
          append_line(l_output, '  CHECK: -');
        END IF;

        append_line(l_output, '');
        append_line(l_output, '----------------------------------------');
      EXCEPTION
        WHEN OTHERS THEN
          append_line(l_output, 'TABLE: ' || t.table_name);
          append_line(l_output, 'Error: ' || SQLERRM);
          append_line(l_output, '----------------------------------------');
      END;
    END LOOP;

    RETURN l_output;
  END generate_plain_text;

  /*
    Purpose: Estimates token count from generated content.
    Parameters: p_content - the generated documentation CLOB.
    Return Value: Estimated token count using 1 token per 4 characters.
    Example Usage: SELECT apex_schema_docs_pkg.estimate_tokens(apex_schema_docs_pkg.generate_markdown(NULL)) FROM dual;
  */
  FUNCTION estimate_tokens (
    p_content IN CLOB
  ) RETURN NUMBER IS
  BEGIN
    IF p_content IS NULL THEN
      RETURN 0;
    END IF;

    RETURN CEIL(DBMS_LOB.GETLENGTH(p_content) / 4);
  END estimate_tokens;

END apex_schema_docs_pkg;
/
SHOW ERRORS;
