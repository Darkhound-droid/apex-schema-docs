SET DEFINE OFF;

/*
  File: create_apex_schema_docs_pkg.sql
  Purpose: Install APEX_SCHEMA_DOCS_PKG for generating schema documentation outputs.
  Author: Hassan Raza
  Version: 2.0.0
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

  /*
    Purpose: Returns all views in the current user schema for the schema browser.
    Parameters: None.
    Return Value: SYS_REFCURSOR with VIEW_NAME, COLUMN_COUNT, COMMENTS.
    Example Usage: OPEN l_rc FOR SELECT * FROM TABLE(apex_schema_docs_pkg.get_view_list);
  */
  FUNCTION get_view_list
    RETURN SYS_REFCURSOR;

  /*
    Purpose: Returns all package specs in the current user schema for the schema browser.
    Parameters: None.
    Return Value: SYS_REFCURSOR with PACKAGE_NAME, SUBPROGRAM_COUNT, STATUS, LAST_DDL_TIME.
    Example Usage: OPEN l_rc FOR SELECT * FROM TABLE(apex_schema_docs_pkg.get_package_list);
  */
  FUNCTION get_package_list
    RETURN SYS_REFCURSOR;

  /*
    Purpose: Generates Markdown documentation for selected views.
    Parameters: p_view_names - comma-separated list of view names, NULL means all, empty string excludes all.
    Return Value: CLOB containing formatted Markdown for views.
    Example Usage: SELECT apex_schema_docs_pkg.generate_views_markdown('EMP_DEPARTMENT_V') FROM dual;
  */
  FUNCTION generate_views_markdown (
    p_view_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  /*
    Purpose: Generates JSON documentation for selected views.
    Parameters: p_view_names - comma-separated list of view names, NULL means all, empty string excludes all.
    Return Value: CLOB containing valid JSON for views.
    Example Usage: SELECT apex_schema_docs_pkg.generate_views_json(NULL) FROM dual;
  */
  FUNCTION generate_views_json (
    p_view_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  /*
    Purpose: Generates plain text documentation for selected views.
    Parameters: p_view_names - comma-separated list of view names, NULL means all, empty string excludes all.
    Return Value: CLOB containing plain text for views.
    Example Usage: SELECT apex_schema_docs_pkg.generate_views_plain_text('EMP_DEPARTMENT_V') FROM dual;
  */
  FUNCTION generate_views_plain_text (
    p_view_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  /*
    Purpose: Generates Markdown documentation for selected package specs.
    Parameters: p_package_names - comma-separated list of package names, NULL means all, empty string excludes all.
    Return Value: CLOB containing formatted Markdown for package specs.
    Example Usage: SELECT apex_schema_docs_pkg.generate_packages_markdown('EMP_PKG') FROM dual;
  */
  FUNCTION generate_packages_markdown (
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  /*
    Purpose: Generates JSON documentation for selected package specs.
    Parameters: p_package_names - comma-separated list of package names, NULL means all, empty string excludes all.
    Return Value: CLOB containing valid JSON for package specs.
    Example Usage: SELECT apex_schema_docs_pkg.generate_packages_json(NULL) FROM dual;
  */
  FUNCTION generate_packages_json (
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  /*
    Purpose: Generates plain text documentation for selected package specs.
    Parameters: p_package_names - comma-separated list of package names, NULL means all, empty string excludes all.
    Return Value: CLOB containing plain text for package specs.
    Example Usage: SELECT apex_schema_docs_pkg.generate_packages_plain_text('EMP_PKG') FROM dual;
  */
  FUNCTION generate_packages_plain_text (
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  /*
    Purpose: Generates combined Markdown documentation for tables, views, and package specs.
    Parameters: p_table_names, p_view_names, p_package_names - NULL includes all, empty string excludes that object type.
    Return Value: CLOB containing combined Markdown output.
    Example Usage: SELECT apex_schema_docs_pkg.generate_full_markdown(NULL, NULL, NULL) FROM dual;
  */
  FUNCTION generate_full_markdown (
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  /*
    Purpose: Generates combined JSON documentation for tables, views, and package specs.
    Parameters: p_table_names, p_view_names, p_package_names - NULL includes all, empty string excludes that object type.
    Return Value: CLOB containing combined JSON output.
    Example Usage: SELECT apex_schema_docs_pkg.generate_full_json(NULL, 'EMP_DEPARTMENT_V', 'EMP_PKG') FROM dual;
  */
  FUNCTION generate_full_json (
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  /*
    Purpose: Generates combined plain text documentation for tables, views, and package specs.
    Parameters: p_table_names, p_view_names, p_package_names - NULL includes all, empty string excludes that object type.
    Return Value: CLOB containing combined plain text output.
    Example Usage: SELECT apex_schema_docs_pkg.generate_full_plain_text(NULL, NULL, '') FROM dual;
  */
  FUNCTION generate_full_plain_text (
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

END apex_schema_docs_pkg;
/

CREATE OR REPLACE PACKAGE BODY apex_schema_docs_pkg AS

  g_newline CONSTANT VARCHAR2(2) := CHR(10);

  TYPE t_varchar2_tab IS TABLE OF VARCHAR2(32767);

  PROCEDURE append_text(
    p_clob IN OUT NOCOPY CLOB,
    p_text IN VARCHAR2
  ) IS
  BEGIN
    DBMS_LOB.APPEND(p_clob, TO_CLOB(NVL(p_text, '')));
  END append_text;

  PROCEDURE append_line(
    p_clob IN OUT NOCOPY CLOB,
    p_text IN VARCHAR2
  ) IS
  BEGIN
    append_text(p_clob, p_text);
    append_text(p_clob, g_newline);
  END append_line;

  PROCEDURE append_clob(
    p_target IN OUT NOCOPY CLOB,
    p_source IN CLOB
  ) IS
  BEGIN
    IF p_source IS NOT NULL THEN
      DBMS_LOB.APPEND(p_target, p_source);
    END IF;
  END append_clob;

  FUNCTION create_temp_clob RETURN CLOB IS
    l_output CLOB;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_output, TRUE);
    RETURN l_output;
  END create_temp_clob;

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
    l_text := REPLACE(l_text, '\', '\\');
    l_text := REPLACE(l_text, '"', '\"');
    l_text := REPLACE(l_text, CHR(10), '\n');
    l_text := REPLACE(l_text, CHR(13), '\r');
    l_text := REPLACE(l_text, CHR(9), '\t');
    RETURN l_text;
  END escape_json;

  PROCEDURE append_escaped_json_clob(
    p_target IN OUT NOCOPY CLOB,
    p_source IN CLOB
  ) IS
    l_offset NUMBER := 1;
    l_chunk  VARCHAR2(32767);
  BEGIN
    IF p_source IS NULL THEN
      RETURN;
    END IF;

    WHILE l_offset <= DBMS_LOB.GETLENGTH(p_source) LOOP
      l_chunk := DBMS_LOB.SUBSTR(p_source, 32767, l_offset);
      append_text(p_target, escape_json(l_chunk));
      l_offset := l_offset + 32767;
    END LOOP;
  END append_escaped_json_clob;

  FUNCTION has_selected_names(
    p_names IN VARCHAR2
  ) RETURN BOOLEAN IS
  BEGIN
    RETURN p_names IS NULL OR LENGTH(TRIM(p_names)) > 0;
  END has_selected_names;

  FUNCTION split_names(
    p_names IN VARCHAR2
  ) RETURN apex_t_varchar2 IS
  BEGIN
    IF p_names IS NULL THEN
      RETURN apex_t_varchar2();
    ELSIF LENGTH(TRIM(p_names)) = 0 THEN
      RETURN apex_t_varchar2();
    ELSE
      RETURN apex_string.split(p_names, ',');
    END IF;
  END split_names;

  FUNCTION in_selected_list(
    p_object_name IN VARCHAR2,
    p_objects     IN apex_t_varchar2
  ) RETURN BOOLEAN IS
    l_value VARCHAR2(32767);
  BEGIN
    IF p_objects IS NULL OR p_objects.COUNT = 0 THEN
      RETURN TRUE;
    END IF;

    FOR i IN 1 .. p_objects.COUNT LOOP
      l_value := TRIM(UPPER(p_objects(i)));
      IF l_value = UPPER(p_object_name) THEN
        RETURN TRUE;
      END IF;
    END LOOP;

    RETURN FALSE;
  END in_selected_list;

  FUNCTION in_selected_tables(
    p_table_name IN VARCHAR2,
    p_tables     IN apex_t_varchar2
  ) RETURN BOOLEAN IS
  BEGIN
    RETURN in_selected_list(p_table_name, p_tables);
  END in_selected_tables;

  FUNCTION view_text_to_clob (p_view_name IN VARCHAR2) RETURN CLOB IS
    l_clob CLOB;
  BEGIN
    EXECUTE IMMEDIATE
      'SELECT TO_LOB(text) FROM user_views WHERE view_name = :1'
    INTO l_clob
    USING UPPER(p_view_name);
    RETURN l_clob;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN TO_CLOB('-- View text unavailable: ' || SQLERRM);
  END view_text_to_clob;

  FUNCTION package_subprogram_return_type(
    p_package_name  IN VARCHAR2,
    p_subprog_name  IN VARCHAR2,
    p_subprogram_id IN NUMBER
  ) RETURN VARCHAR2 IS
    l_return_type USER_ARGUMENTS.DATA_TYPE%TYPE;
  BEGIN
    SELECT data_type
      INTO l_return_type
      FROM user_arguments
     WHERE package_name  = UPPER(p_package_name)
       AND object_name   = p_subprog_name
       AND subprogram_id = p_subprogram_id
       AND argument_name IS NULL
       AND position      = 0
       AND data_level    = 0;

    RETURN NVL(l_return_type, 'UNKNOWN');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END package_subprogram_return_type;

  FUNCTION package_subprogram_arguments(
    p_package_name  IN VARCHAR2,
    p_subprog_name  IN VARCHAR2,
    p_subprogram_id IN NUMBER
  ) RETURN VARCHAR2 IS
    l_args VARCHAR2(32767);
  BEGIN
    FOR arg_rec IN (
      SELECT argument_name,
             in_out,
             data_type
        FROM user_arguments
       WHERE package_name  = UPPER(p_package_name)
         AND object_name   = p_subprog_name
         AND subprogram_id = p_subprogram_id
         AND argument_name IS NOT NULL
         AND data_level    = 0
       ORDER BY sequence
    ) LOOP
      IF l_args IS NOT NULL THEN
        l_args := l_args || ', ';
      END IF;

      l_args := l_args || LOWER(arg_rec.argument_name) || ' ' || arg_rec.in_out || ' ' || NVL(arg_rec.data_type, 'UNKNOWN');
    END LOOP;

    RETURN NVL(l_args, '');
  END package_subprogram_arguments;

  PROCEDURE append_indented_clob(
    p_target IN OUT NOCOPY CLOB,
    p_source IN CLOB,
    p_prefix IN VARCHAR2
  ) IS
    l_length    NUMBER;
    l_start     NUMBER := 1;
    l_next      NUMBER;
    l_line      VARCHAR2(32767);
  BEGIN
    IF p_source IS NULL THEN
      RETURN;
    END IF;

    l_length := DBMS_LOB.GETLENGTH(p_source);
    IF l_length = 0 THEN
      RETURN;
    END IF;

    WHILE l_start <= l_length LOOP
      l_next := DBMS_LOB.INSTR(p_source, g_newline, l_start, 1);
      IF l_next = 0 THEN
        l_line := DBMS_LOB.SUBSTR(p_source, l_length - l_start + 1, l_start);
        append_line(p_target, p_prefix || l_line);
        EXIT;
      ELSE
        l_line := DBMS_LOB.SUBSTR(p_source, l_next - l_start, l_start);
        append_line(p_target, p_prefix || l_line);
        l_start := l_next + 1;
      END IF;
    END LOOP;
  END append_indented_clob;

  FUNCTION extract_top_level_array(
    p_json IN CLOB,
    p_key  IN VARCHAR2
  ) RETURN CLOB IS
    l_result    CLOB := create_temp_clob;
    l_key_pos   NUMBER;
    l_start_pos NUMBER;
    l_end_pos   NUMBER := 0;
    l_scan_pos  NUMBER := 1;
    l_len       NUMBER;
    l_chunk     VARCHAR2(32767);
    l_copy_len  NUMBER;
  BEGIN
    l_key_pos := DBMS_LOB.INSTR(p_json, '"' || p_key || '"', 1, 1);
    IF l_key_pos = 0 THEN
      append_text(l_result, '[]');
      RETURN l_result;
    END IF;

    l_start_pos := DBMS_LOB.INSTR(p_json, '[', l_key_pos, 1);
    IF l_start_pos = 0 THEN
      append_text(l_result, '[]');
      RETURN l_result;
    END IF;

    LOOP
      l_end_pos := DBMS_LOB.INSTR(p_json, ']', l_scan_pos, 1);
      EXIT WHEN l_end_pos = 0;
      l_scan_pos := l_end_pos + 1;
    END LOOP;

    IF l_end_pos = 0 OR l_end_pos < l_start_pos THEN
      append_text(l_result, '[]');
      RETURN l_result;
    END IF;

    l_len := l_end_pos - l_start_pos + 1;
    l_scan_pos := l_start_pos;

    WHILE l_len > 0 LOOP
      l_copy_len := LEAST(32767, l_len);
      l_chunk := DBMS_LOB.SUBSTR(p_json, l_copy_len, l_scan_pos);
      append_text(l_result, l_chunk);
      l_scan_pos := l_scan_pos + l_copy_len;
      l_len := l_len - l_copy_len;
    END LOOP;

    RETURN l_result;
  END extract_top_level_array;

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
                 search_condition_vc AS search_condition_text
            FROM user_constraints
           WHERE constraint_type = 'C'
             AND table_name = t.table_name
             AND UPPER(search_condition_vc) NOT LIKE '%IS NOT NULL%'
           ORDER BY constraint_name
        ) LOOP
          append_line(l_output, '  - ' || ck.constraint_name || ': ' || NVL(ck.search_condition_text, '-'));
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
    l_output       CLOB;
    l_tables       apex_t_varchar2;
    l_first_table  BOOLEAN := TRUE;
    l_first_col    BOOLEAN;
    l_first_uk     BOOLEAN;
    l_first_fk     BOOLEAN;
    l_first_ck     BOOLEAN;
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
          append_text(l_output, ',' || g_newline);
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
            append_text(l_output, ',' || g_newline);
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
            append_text(l_output, ',' || g_newline);
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
            append_text(l_output, ',' || g_newline);
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
              append_text(l_output, ',');
            END IF;
            l_first_fk_col := FALSE;
            append_text(l_output, '"' || escape_json(fk_col.column_name) || '"');
          END LOOP;
          append_text(l_output, g_newline);
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
              append_text(l_output, ',');
            END IF;
            l_first_ref_col := FALSE;
            append_text(l_output, '"' || escape_json(ref_col.column_name) || '"');
          END LOOP;
          append_text(l_output, g_newline);
          append_line(l_output, '              ]');
          append_line(l_output, '            }');
        END LOOP;
        append_line(l_output, '          ],');

        append_line(l_output, '          "check_constraints": [');
        l_first_ck := TRUE;
        FOR ck IN (
          SELECT constraint_name,
                 search_condition_vc AS search_condition_text
            FROM user_constraints
           WHERE constraint_type = 'C'
             AND table_name = t.table_name
             AND UPPER(search_condition_vc) NOT LIKE '%IS NOT NULL%'
           ORDER BY constraint_name
        ) LOOP
          IF NOT l_first_ck THEN
            append_text(l_output, ',' || g_newline);
          END IF;
          l_first_ck := FALSE;
          append_line(l_output, '            {"name":"' || escape_json(ck.constraint_name) || '","condition":"' || escape_json(ck.search_condition_text) || '"}');
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
                 search_condition_vc AS search_condition_text
            FROM user_constraints
           WHERE constraint_type = 'C'
             AND table_name = t.table_name
             AND UPPER(search_condition_vc) NOT LIKE '%IS NOT NULL%'
           ORDER BY constraint_name
        ) LOOP
          append_line(l_output, '  CHECK: ' || ck.constraint_name || ' -> ' || ck.search_condition_text);
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

  /*
    Purpose: Returns all views in the current user schema for the schema browser.
    Parameters: None.
    Return Value: SYS_REFCURSOR with VIEW_NAME, COLUMN_COUNT, COMMENTS.
    Example Usage: OPEN l_rc FOR SELECT * FROM TABLE(apex_schema_docs_pkg.get_view_list);
  */
  FUNCTION get_view_list
    RETURN SYS_REFCURSOR IS
    l_cursor SYS_REFCURSOR;
  BEGIN
    OPEN l_cursor FOR
      SELECT v.view_name,
             (SELECT COUNT(*)
                FROM user_view_columns c
               WHERE c.view_name = v.view_name) AS column_count,
             tc.comments
        FROM user_views v
        LEFT JOIN user_tab_comments tc
          ON tc.table_name = v.view_name
         AND tc.table_type = 'VIEW'
       ORDER BY v.view_name;

    RETURN l_cursor;
  END get_view_list;

  /*
    Purpose: Returns all package specs in the current user schema for the schema browser.
    Parameters: None.
    Return Value: SYS_REFCURSOR with PACKAGE_NAME, SUBPROGRAM_COUNT, STATUS, LAST_DDL_TIME.
    Example Usage: OPEN l_rc FOR SELECT * FROM TABLE(apex_schema_docs_pkg.get_package_list);
  */
  FUNCTION get_package_list
    RETURN SYS_REFCURSOR IS
    l_cursor SYS_REFCURSOR;
  BEGIN
    OPEN l_cursor FOR
      SELECT o.object_name AS package_name,
             (SELECT COUNT(DISTINCT procedure_name)
                FROM user_procedures p
               WHERE p.object_name    = o.object_name
                 AND p.procedure_name IS NOT NULL) AS subprogram_count,
             o.status,
             o.last_ddl_time
        FROM user_objects o
       WHERE o.object_type = 'PACKAGE'
       ORDER BY o.object_name;

    RETURN l_cursor;
  END get_package_list;

  /*
    Purpose: Generates Markdown documentation for selected views.
    Parameters: p_view_names - comma-separated list of view names, NULL means all, empty string excludes all.
    Return Value: CLOB containing formatted Markdown for views.
    Example Usage: SELECT apex_schema_docs_pkg.generate_views_markdown('EMP_DEPARTMENT_V') FROM dual;
  */
  FUNCTION generate_views_markdown (
    p_view_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_output       CLOB := create_temp_clob;
    l_views        apex_t_varchar2 := split_names(p_view_names);
    l_columns      VARCHAR2(32767);
    l_query_text   CLOB;
    l_description  VARCHAR2(4000);
  BEGIN
    IF NOT has_selected_names(p_view_names) THEN
      RETURN l_output;
    END IF;

    FOR view_rec IN (
      SELECT v.view_name,
             NVL(tc.comments, 'No description available') AS comments
        FROM user_views v
        LEFT JOIN user_tab_comments tc
          ON tc.table_name = v.view_name
         AND tc.table_type = 'VIEW'
       ORDER BY v.view_name
    ) LOOP
      BEGIN
        IF NOT in_selected_list(view_rec.view_name, l_views) THEN
          CONTINUE;
        END IF;

        l_columns := NULL;
        l_query_text := view_text_to_clob(view_rec.view_name);
        l_description := view_rec.comments;

        SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_id)
          INTO l_columns
          FROM user_view_columns
         WHERE view_name = view_rec.view_name;

        append_line(l_output, '## VIEW: ' || view_rec.view_name);
        append_line(l_output, '**Description:** ' || l_description);
        append_line(l_output, '**Columns:** ' || NVL(l_columns, '-'));
        append_line(l_output, '');
        append_line(l_output, '**Query:**');
        append_clob(l_output, l_query_text);
        append_text(l_output, g_newline);
        append_line(l_output, '');
        append_line(l_output, '---');
        append_line(l_output, '');
      EXCEPTION
        WHEN OTHERS THEN
          append_line(l_output, '## VIEW: ' || view_rec.view_name);
          append_line(l_output, '**Error:** Unable to document view due to: ' || SQLERRM);
          append_line(l_output, '---');
          append_line(l_output, '');
      END;
    END LOOP;

    RETURN l_output;
  END generate_views_markdown;

  /*
    Purpose: Generates JSON documentation for selected views.
    Parameters: p_view_names - comma-separated list of view names, NULL means all, empty string excludes all.
    Return Value: CLOB containing valid JSON for views.
    Example Usage: SELECT apex_schema_docs_pkg.generate_views_json(NULL) FROM dual;
  */
  FUNCTION generate_views_json (
    p_view_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_output        CLOB := create_temp_clob;
    l_views         apex_t_varchar2 := split_names(p_view_names);
    l_first_view    BOOLEAN := TRUE;
    l_query_text    CLOB;
    l_had_previous  BOOLEAN;
  BEGIN
    append_line(l_output, '{');
    append_line(l_output, '  "views": [');

    IF has_selected_names(p_view_names) THEN
      FOR view_rec IN (
        SELECT v.view_name,
               NVL(tc.comments, 'No description available') AS comments
          FROM user_views v
          LEFT JOIN user_tab_comments tc
            ON tc.table_name = v.view_name
           AND tc.table_type = 'VIEW'
         ORDER BY v.view_name
      ) LOOP
        BEGIN
          IF NOT in_selected_list(view_rec.view_name, l_views) THEN
            CONTINUE;
          END IF;

          l_had_previous := NOT l_first_view;
          IF l_had_previous THEN
            append_text(l_output, ',' || g_newline);
          END IF;

          l_query_text := view_text_to_clob(view_rec.view_name);

          append_line(l_output, '    {');
          append_line(l_output, '      "name": "' || escape_json(view_rec.view_name) || '",');
          append_line(l_output, '      "description": "' || escape_json(view_rec.comments) || '",');
          append_line(l_output, '      "columns": [');

          DECLARE
            l_first_column BOOLEAN := TRUE;
          BEGIN
            FOR col_rec IN (
              SELECT column_name
                FROM user_view_columns
               WHERE view_name = view_rec.view_name
               ORDER BY column_id
            ) LOOP
              IF NOT l_first_column THEN
                append_text(l_output, ',' || g_newline);
              END IF;
              l_first_column := FALSE;
              append_line(l_output, '        "' || escape_json(col_rec.column_name) || '"');
            END LOOP;
          END;

          append_line(l_output, '      ],');
          append_text(l_output, '      "query": "');
          append_escaped_json_clob(l_output, l_query_text);
          append_line(l_output, '"');
          append_line(l_output, '    }');
          l_first_view := FALSE;
        EXCEPTION
          WHEN OTHERS THEN
            IF l_had_previous THEN
              append_text(l_output, ',' || g_newline);
            END IF;
            append_line(l_output, '    {');
            append_line(l_output, '      "name": "' || escape_json(view_rec.view_name) || '",');
            append_line(l_output, '      "description": "Error: ' || escape_json(SQLERRM) || '",');
            append_line(l_output, '      "columns": [],');
            append_line(l_output, '      "query": ""');
            append_line(l_output, '    }');
            l_first_view := FALSE;
        END;
      END LOOP;
    END IF;

    append_line(l_output, '  ]');
    append_line(l_output, '}');

    RETURN l_output;
  END generate_views_json;

  /*
    Purpose: Generates plain text documentation for selected views.
    Parameters: p_view_names - comma-separated list of view names, NULL means all, empty string excludes all.
    Return Value: CLOB containing plain text for views.
    Example Usage: SELECT apex_schema_docs_pkg.generate_views_plain_text('EMP_DEPARTMENT_V') FROM dual;
  */
  FUNCTION generate_views_plain_text (
    p_view_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_output     CLOB := create_temp_clob;
    l_views      apex_t_varchar2 := split_names(p_view_names);
    l_columns    VARCHAR2(32767);
    l_query_text CLOB;
  BEGIN
    IF NOT has_selected_names(p_view_names) THEN
      RETURN l_output;
    END IF;

    FOR view_rec IN (
      SELECT v.view_name,
             NVL(tc.comments, 'No description available') AS comments
        FROM user_views v
        LEFT JOIN user_tab_comments tc
          ON tc.table_name = v.view_name
         AND tc.table_type = 'VIEW'
       ORDER BY v.view_name
    ) LOOP
      BEGIN
        IF NOT in_selected_list(view_rec.view_name, l_views) THEN
          CONTINUE;
        END IF;

        SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_id)
          INTO l_columns
          FROM user_view_columns
         WHERE view_name = view_rec.view_name;

        l_query_text := view_text_to_clob(view_rec.view_name);

        append_line(l_output, 'VIEW: ' || view_rec.view_name);
        append_line(l_output, 'Columns: ' || NVL(l_columns, '-'));
        append_line(l_output, 'Query:');
        append_indented_clob(l_output, l_query_text, '  ');
        append_line(l_output, '');
        append_line(l_output, '----------------------------------------');
      EXCEPTION
        WHEN OTHERS THEN
          append_line(l_output, 'VIEW: ' || view_rec.view_name);
          append_line(l_output, 'Error: ' || SQLERRM);
          append_line(l_output, '----------------------------------------');
      END;
    END LOOP;

    RETURN l_output;
  END generate_views_plain_text;

  /*
    Purpose: Generates Markdown documentation for selected package specs.
    Parameters: p_package_names - comma-separated list of package names, NULL means all, empty string excludes all.
    Return Value: CLOB containing formatted Markdown for package specs.
    Example Usage: SELECT apex_schema_docs_pkg.generate_packages_markdown('EMP_PKG') FROM dual;
  */
  FUNCTION generate_packages_markdown (
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_output         CLOB := create_temp_clob;
    l_packages       apex_t_varchar2 := split_names(p_package_names);
    l_has_procedures BOOLEAN;
    l_has_functions  BOOLEAN;
    l_arguments      VARCHAR2(32767);
    l_return_type    VARCHAR2(32767);
  BEGIN
    IF NOT has_selected_names(p_package_names) THEN
      RETURN l_output;
    END IF;

    FOR pkg_rec IN (
      SELECT o.object_name AS package_name
        FROM user_objects o
       WHERE o.object_type = 'PACKAGE'
       ORDER BY o.object_name
    ) LOOP
      BEGIN
        IF NOT in_selected_list(pkg_rec.package_name, l_packages) THEN
          CONTINUE;
        END IF;

        append_line(l_output, '## PACKAGE: ' || pkg_rec.package_name);
        append_line(l_output, '');

        l_has_procedures := FALSE;
        FOR proc_rec IN (
          SELECT DISTINCT p.procedure_name,
                 p.subprogram_id
            FROM user_procedures p
           WHERE p.object_name = pkg_rec.package_name
             AND p.procedure_name IS NOT NULL
             AND NOT EXISTS (
                   SELECT 1
                     FROM user_arguments a
                    WHERE a.package_name  = pkg_rec.package_name
                      AND a.object_name   = p.procedure_name
                      AND a.subprogram_id = p.subprogram_id
                      AND a.argument_name IS NULL
                      AND a.position      = 0
                      AND a.data_level    = 0
                 )
           ORDER BY p.procedure_name, p.subprogram_id
        ) LOOP
          IF NOT l_has_procedures THEN
            append_line(l_output, '### Procedures');
            l_has_procedures := TRUE;
          END IF;

          l_arguments := package_subprogram_arguments(pkg_rec.package_name, proc_rec.procedure_name, proc_rec.subprogram_id);
          append_line(l_output, '- **' || proc_rec.procedure_name || '**(' || l_arguments || ')');
        END LOOP;

        IF l_has_procedures THEN
          append_line(l_output, '');
        END IF;

        l_has_functions := FALSE;
        FOR func_rec IN (
          SELECT DISTINCT p.procedure_name,
                 p.subprogram_id
            FROM user_procedures p
           WHERE p.object_name = pkg_rec.package_name
             AND p.procedure_name IS NOT NULL
             AND EXISTS (
                   SELECT 1
                     FROM user_arguments a
                    WHERE a.package_name  = pkg_rec.package_name
                      AND a.object_name   = p.procedure_name
                      AND a.subprogram_id = p.subprogram_id
                      AND a.argument_name IS NULL
                      AND a.position      = 0
                      AND a.data_level    = 0
                 )
           ORDER BY p.procedure_name, p.subprogram_id
        ) LOOP
          IF NOT l_has_functions THEN
            append_line(l_output, '### Functions');
            l_has_functions := TRUE;
          END IF;

          l_arguments := package_subprogram_arguments(pkg_rec.package_name, func_rec.procedure_name, func_rec.subprogram_id);
          l_return_type := package_subprogram_return_type(pkg_rec.package_name, func_rec.procedure_name, func_rec.subprogram_id);
          append_line(l_output, '- **' || func_rec.procedure_name || '**(' || l_arguments || ') RETURN ' || NVL(l_return_type, 'UNKNOWN'));
        END LOOP;

        append_line(l_output, '');
        append_line(l_output, '---');
        append_line(l_output, '');
      EXCEPTION
        WHEN OTHERS THEN
          append_line(l_output, '## PACKAGE: ' || pkg_rec.package_name);
          append_line(l_output, '**Error:** Unable to document package due to: ' || SQLERRM);
          append_line(l_output, '---');
          append_line(l_output, '');
      END;
    END LOOP;

    RETURN l_output;
  END generate_packages_markdown;

  /*
    Purpose: Generates JSON documentation for selected package specs.
    Parameters: p_package_names - comma-separated list of package names, NULL means all, empty string excludes all.
    Return Value: CLOB containing valid JSON for package specs.
    Example Usage: SELECT apex_schema_docs_pkg.generate_packages_json(NULL) FROM dual;
  */
  FUNCTION generate_packages_json (
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_output          CLOB := create_temp_clob;
    l_packages        apex_t_varchar2 := split_names(p_package_names);
    l_first_package   BOOLEAN := TRUE;
    l_had_previous    BOOLEAN;
  BEGIN
    append_line(l_output, '{');
    append_line(l_output, '  "packages": [');

    IF has_selected_names(p_package_names) THEN
      FOR pkg_rec IN (
        SELECT o.object_name AS package_name
          FROM user_objects o
         WHERE o.object_type = 'PACKAGE'
         ORDER BY o.object_name
      ) LOOP
        BEGIN
          IF NOT in_selected_list(pkg_rec.package_name, l_packages) THEN
            CONTINUE;
          END IF;

          l_had_previous := NOT l_first_package;
          IF l_had_previous THEN
            append_text(l_output, ',' || g_newline);
          END IF;

          append_line(l_output, '    {');
          append_line(l_output, '      "name": "' || escape_json(pkg_rec.package_name) || '",');
          append_line(l_output, '      "procedures": [');

          DECLARE
            l_first_proc BOOLEAN := TRUE;
          BEGIN
            FOR proc_rec IN (
              SELECT DISTINCT p.procedure_name,
                     p.subprogram_id
                FROM user_procedures p
               WHERE p.object_name = pkg_rec.package_name
                 AND p.procedure_name IS NOT NULL
                 AND NOT EXISTS (
                       SELECT 1
                         FROM user_arguments a
                        WHERE a.package_name  = pkg_rec.package_name
                          AND a.object_name   = p.procedure_name
                          AND a.subprogram_id = p.subprogram_id
                          AND a.argument_name IS NULL
                          AND a.position      = 0
                          AND a.data_level    = 0
                     )
               ORDER BY p.procedure_name, p.subprogram_id
            ) LOOP
              IF NOT l_first_proc THEN
                append_text(l_output, ',' || g_newline);
              END IF;
              l_first_proc := FALSE;

              append_line(l_output, '        {');
              append_line(l_output, '          "name": "' || escape_json(proc_rec.procedure_name) || '",');
              append_line(l_output, '          "arguments": [');

              DECLARE
                l_first_arg BOOLEAN := TRUE;
              BEGIN
                FOR arg_rec IN (
                  SELECT argument_name,
                         in_out,
                         data_type
                    FROM user_arguments
                   WHERE package_name  = pkg_rec.package_name
                     AND object_name   = proc_rec.procedure_name
                     AND subprogram_id = proc_rec.subprogram_id
                     AND argument_name IS NOT NULL
                     AND data_level    = 0
                   ORDER BY sequence
                ) LOOP
                  IF NOT l_first_arg THEN
                    append_text(l_output, ',' || g_newline);
                  END IF;
                  l_first_arg := FALSE;
                  append_line(l_output, '            {"name": "' || escape_json(arg_rec.argument_name) || '", "in_out": "' || escape_json(arg_rec.in_out) || '", "data_type": "' || escape_json(NVL(arg_rec.data_type, 'UNKNOWN')) || '"}');
                END LOOP;
              END;

              append_line(l_output, '          ]');
              append_line(l_output, '        }');
            END LOOP;
          END;

          append_line(l_output, '      ],');
          append_line(l_output, '      "functions": [');

          DECLARE
            l_first_func  BOOLEAN := TRUE;
            l_return_type VARCHAR2(32767);
          BEGIN
            FOR func_rec IN (
              SELECT DISTINCT p.procedure_name,
                     p.subprogram_id
                FROM user_procedures p
               WHERE p.object_name = pkg_rec.package_name
                 AND p.procedure_name IS NOT NULL
                 AND EXISTS (
                       SELECT 1
                         FROM user_arguments a
                        WHERE a.package_name  = pkg_rec.package_name
                          AND a.object_name   = p.procedure_name
                          AND a.subprogram_id = p.subprogram_id
                          AND a.argument_name IS NULL
                          AND a.position      = 0
                          AND a.data_level    = 0
                     )
               ORDER BY p.procedure_name, p.subprogram_id
            ) LOOP
              IF NOT l_first_func THEN
                append_text(l_output, ',' || g_newline);
              END IF;
              l_first_func := FALSE;
              l_return_type := package_subprogram_return_type(pkg_rec.package_name, func_rec.procedure_name, func_rec.subprogram_id);

              append_line(l_output, '        {');
              append_line(l_output, '          "name": "' || escape_json(func_rec.procedure_name) || '",');
              append_line(l_output, '          "return_type": "' || escape_json(NVL(l_return_type, 'UNKNOWN')) || '",');
              append_line(l_output, '          "arguments": [');

              DECLARE
                l_first_arg BOOLEAN := TRUE;
              BEGIN
                FOR arg_rec IN (
                  SELECT argument_name,
                         in_out,
                         data_type
                    FROM user_arguments
                   WHERE package_name  = pkg_rec.package_name
                     AND object_name   = func_rec.procedure_name
                     AND subprogram_id = func_rec.subprogram_id
                     AND argument_name IS NOT NULL
                     AND data_level    = 0
                   ORDER BY sequence
                ) LOOP
                  IF NOT l_first_arg THEN
                    append_text(l_output, ',' || g_newline);
                  END IF;
                  l_first_arg := FALSE;
                  append_line(l_output, '            {"name": "' || escape_json(arg_rec.argument_name) || '", "in_out": "' || escape_json(arg_rec.in_out) || '", "data_type": "' || escape_json(NVL(arg_rec.data_type, 'UNKNOWN')) || '"}');
                END LOOP;
              END;

              append_line(l_output, '          ]');
              append_line(l_output, '        }');
            END LOOP;
          END;

          append_line(l_output, '      ]');
          append_line(l_output, '    }');
          l_first_package := FALSE;
        EXCEPTION
          WHEN OTHERS THEN
            IF l_had_previous THEN
              append_text(l_output, ',' || g_newline);
            END IF;
            append_line(l_output, '    {');
            append_line(l_output, '      "name": "' || escape_json(pkg_rec.package_name) || '",');
            append_line(l_output, '      "procedures": [],');
            append_line(l_output, '      "functions": [],');
            append_line(l_output, '      "error": "' || escape_json(SQLERRM) || '"');
            append_line(l_output, '    }');
            l_first_package := FALSE;
        END;
      END LOOP;
    END IF;

    append_line(l_output, '  ]');
    append_line(l_output, '}');

    RETURN l_output;
  END generate_packages_json;

  /*
    Purpose: Generates plain text documentation for selected package specs.
    Parameters: p_package_names - comma-separated list of package names, NULL means all, empty string excludes all.
    Return Value: CLOB containing plain text for package specs.
    Example Usage: SELECT apex_schema_docs_pkg.generate_packages_plain_text('EMP_PKG') FROM dual;
  */
  FUNCTION generate_packages_plain_text (
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_output      CLOB := create_temp_clob;
    l_packages    apex_t_varchar2 := split_names(p_package_names);
    l_arguments   VARCHAR2(32767);
    l_return_type VARCHAR2(32767);
  BEGIN
    IF NOT has_selected_names(p_package_names) THEN
      RETURN l_output;
    END IF;

    FOR pkg_rec IN (
      SELECT o.object_name AS package_name
        FROM user_objects o
       WHERE o.object_type = 'PACKAGE'
       ORDER BY o.object_name
    ) LOOP
      BEGIN
        IF NOT in_selected_list(pkg_rec.package_name, l_packages) THEN
          CONTINUE;
        END IF;

        append_line(l_output, 'PACKAGE: ' || pkg_rec.package_name);
        append_line(l_output, '');

        FOR proc_rec IN (
          SELECT DISTINCT p.procedure_name,
                 p.subprogram_id
            FROM user_procedures p
           WHERE p.object_name = pkg_rec.package_name
             AND p.procedure_name IS NOT NULL
             AND NOT EXISTS (
                   SELECT 1
                     FROM user_arguments a
                    WHERE a.package_name  = pkg_rec.package_name
                      AND a.object_name   = p.procedure_name
                      AND a.subprogram_id = p.subprogram_id
                      AND a.argument_name IS NULL
                      AND a.position      = 0
                      AND a.data_level    = 0
                 )
           ORDER BY p.procedure_name, p.subprogram_id
        ) LOOP
          l_arguments := package_subprogram_arguments(pkg_rec.package_name, proc_rec.procedure_name, proc_rec.subprogram_id);
          append_line(l_output, '  PROCEDURE ' || proc_rec.procedure_name || '(' || l_arguments || ')');
        END LOOP;

        FOR func_rec IN (
          SELECT DISTINCT p.procedure_name,
                 p.subprogram_id
            FROM user_procedures p
           WHERE p.object_name = pkg_rec.package_name
             AND p.procedure_name IS NOT NULL
             AND EXISTS (
                   SELECT 1
                     FROM user_arguments a
                    WHERE a.package_name  = pkg_rec.package_name
                      AND a.object_name   = p.procedure_name
                      AND a.subprogram_id = p.subprogram_id
                      AND a.argument_name IS NULL
                      AND a.position      = 0
                      AND a.data_level    = 0
                 )
           ORDER BY p.procedure_name, p.subprogram_id
        ) LOOP
          l_arguments := package_subprogram_arguments(pkg_rec.package_name, func_rec.procedure_name, func_rec.subprogram_id);
          l_return_type := package_subprogram_return_type(pkg_rec.package_name, func_rec.procedure_name, func_rec.subprogram_id);
          append_line(l_output, '  FUNCTION  ' || func_rec.procedure_name || '(' || l_arguments || ') RETURN ' || NVL(l_return_type, 'UNKNOWN'));
        END LOOP;

        append_line(l_output, '');
        append_line(l_output, '----------------------------------------');
      EXCEPTION
        WHEN OTHERS THEN
          append_line(l_output, 'PACKAGE: ' || pkg_rec.package_name);
          append_line(l_output, 'Error: ' || SQLERRM);
          append_line(l_output, '----------------------------------------');
      END;
    END LOOP;

    RETURN l_output;
  END generate_packages_plain_text;

  /*
    Purpose: Generates combined Markdown documentation for tables, views, and package specs.
    Parameters: p_table_names, p_view_names, p_package_names - NULL includes all, empty string excludes that object type.
    Return Value: CLOB containing combined Markdown output.
    Example Usage: SELECT apex_schema_docs_pkg.generate_full_markdown(NULL, NULL, NULL) FROM dual;
  */
  FUNCTION generate_full_markdown (
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_result CLOB := create_temp_clob;
  BEGIN
    IF p_table_names IS NULL OR LENGTH(TRIM(p_table_names)) > 0 THEN
      append_clob(l_result, generate_markdown(p_table_names));
      append_text(l_result, g_newline);
    END IF;

    IF p_view_names IS NULL OR LENGTH(TRIM(p_view_names)) > 0 THEN
      append_clob(l_result, generate_views_markdown(p_view_names));
      append_text(l_result, g_newline);
    END IF;

    IF p_package_names IS NULL OR LENGTH(TRIM(p_package_names)) > 0 THEN
      append_clob(l_result, generate_packages_markdown(p_package_names));
    END IF;

    RETURN l_result;
  END generate_full_markdown;

  /*
    Purpose: Generates combined JSON documentation for tables, views, and package specs.
    Parameters: p_table_names, p_view_names, p_package_names - NULL includes all, empty string excludes that object type.
    Return Value: CLOB containing combined JSON output.
    Example Usage: SELECT apex_schema_docs_pkg.generate_full_json(NULL, 'EMP_DEPARTMENT_V', 'EMP_PKG') FROM dual;
  */
  FUNCTION generate_full_json (
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_result        CLOB := create_temp_clob;
    l_tables_json   CLOB := extract_top_level_array(generate_json(p_table_names), 'tables');
    l_views_json    CLOB := extract_top_level_array(generate_views_json(p_view_names), 'views');
    l_packages_json CLOB := extract_top_level_array(generate_packages_json(p_package_names), 'packages');
  BEGIN
    IF p_table_names IS NOT NULL AND LENGTH(TRIM(p_table_names)) = 0 THEN
      l_tables_json := TO_CLOB('[]');
    END IF;

    IF p_view_names IS NOT NULL AND LENGTH(TRIM(p_view_names)) = 0 THEN
      l_views_json := TO_CLOB('[]');
    END IF;

    IF p_package_names IS NOT NULL AND LENGTH(TRIM(p_package_names)) = 0 THEN
      l_packages_json := TO_CLOB('[]');
    END IF;

    append_line(l_result, '{');
    append_line(l_result, '  "schema_docs": {');
    append_line(l_result, '    "generated_at": "' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD"T"HH24:MI:SS') || '",');
    append_line(l_result, '    "generated_by": "APEX Schema Docs v2.0.0",');
    append_text(l_result, '    "tables": ');
    append_clob(l_result, l_tables_json);
    append_text(l_result, ',' || g_newline);
    append_text(l_result, '    "views": ');
    append_clob(l_result, l_views_json);
    append_text(l_result, ',' || g_newline);
    append_text(l_result, '    "packages": ');
    append_clob(l_result, l_packages_json);
    append_text(l_result, g_newline);
    append_line(l_result, '  }');
    append_line(l_result, '}');

    RETURN l_result;
  END generate_full_json;

  /*
    Purpose: Generates combined plain text documentation for tables, views, and package specs.
    Parameters: p_table_names, p_view_names, p_package_names - NULL includes all, empty string excludes that object type.
    Return Value: CLOB containing combined plain text output.
    Example Usage: SELECT apex_schema_docs_pkg.generate_full_plain_text(NULL, NULL, '') FROM dual;
  */
  FUNCTION generate_full_plain_text (
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_result CLOB := create_temp_clob;
  BEGIN
    IF p_table_names IS NULL OR LENGTH(TRIM(p_table_names)) > 0 THEN
      append_clob(l_result, generate_plain_text(p_table_names));
      append_text(l_result, g_newline);
    END IF;

    IF p_view_names IS NULL OR LENGTH(TRIM(p_view_names)) > 0 THEN
      append_clob(l_result, generate_views_plain_text(p_view_names));
      append_text(l_result, g_newline);
    END IF;

    IF p_package_names IS NULL OR LENGTH(TRIM(p_package_names)) > 0 THEN
      append_clob(l_result, generate_packages_plain_text(p_package_names));
    END IF;

    RETURN l_result;
  END generate_full_plain_text;

END apex_schema_docs_pkg;
/
SHOW ERRORS;
