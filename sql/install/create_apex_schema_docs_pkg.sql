SET DEFINE OFF;

/*
  File    : create_apex_schema_docs_pkg.sql
  Purpose : APEX Schema Docs - Generate LLM-ready Oracle schema documentation
  Author  : Hassan Raza
  Version : 2.0.0
  License : MIT
  Compat  : Oracle Database 19c+, Oracle APEX 22.1+
*/

-- ============================================================
-- PACKAGE SPEC
-- ============================================================
CREATE OR REPLACE PACKAGE apex_schema_docs_pkg AS

  FUNCTION get_table_list   RETURN SYS_REFCURSOR;
  FUNCTION get_view_list    RETURN SYS_REFCURSOR;
  FUNCTION get_package_list RETURN SYS_REFCURSOR;

  FUNCTION generate_markdown   (p_table_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB;
  FUNCTION generate_json       (p_table_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB;
  FUNCTION generate_plain_text (p_table_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB;

  FUNCTION generate_views_markdown   (p_view_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB;
  FUNCTION generate_views_json       (p_view_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB;
  FUNCTION generate_views_plain_text (p_view_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB;

  FUNCTION generate_packages_markdown   (p_package_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB;
  FUNCTION generate_packages_json       (p_package_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB;
  FUNCTION generate_packages_plain_text (p_package_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB;

  FUNCTION generate_full_markdown (
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  FUNCTION generate_full_json (
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  FUNCTION generate_full_plain_text (
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB;

  FUNCTION estimate_tokens (p_content IN CLOB) RETURN NUMBER;

END apex_schema_docs_pkg;
/


-- ============================================================
-- PACKAGE BODY
-- ============================================================
CREATE OR REPLACE PACKAGE BODY apex_schema_docs_pkg AS

  -- ============================================================
  -- CONSTANTS
  -- ============================================================
  nl  CONSTANT VARCHAR2(1)  := CHR(10);
  sep CONSTANT VARCHAR2(42) := '----------------------------------------';


  -- ============================================================
  -- PRIVATE: LOB HELPERS
  -- RULE: All CLOBs declared as NULL, initialized in BEGIN via
  -- new_clob(). Never initialized in DECLARE. Prevents ORA-22275.
  -- ============================================================

  FUNCTION new_clob RETURN CLOB IS
    lc CLOB;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(lc, TRUE, DBMS_LOB.CALL);
    RETURN lc;
  END new_clob;

  -- Append VARCHAR2 to CLOB
  PROCEDURE w(pc IN OUT NOCOPY CLOB, pt IN VARCHAR2) IS
  BEGIN
    IF pt IS NOT NULL AND LENGTH(pt) > 0 THEN
      DBMS_LOB.WRITEAPPEND(pc, LENGTH(pt), pt);
    END IF;
  END w;

  -- Append VARCHAR2 + newline
  PROCEDURE wl(pc IN OUT NOCOPY CLOB, pt IN VARCHAR2) IS
  BEGIN
    w(pc, pt);
    DBMS_LOB.WRITEAPPEND(pc, 1, nl);
  END wl;

  -- Append CLOB to CLOB
  PROCEDURE wc(p_target IN OUT NOCOPY CLOB, p_source IN CLOB) IS
  BEGIN
    IF p_source IS NOT NULL AND DBMS_LOB.GETLENGTH(p_source) > 0 THEN
      DBMS_LOB.APPEND(p_target, p_source);
    END IF;
  END wc;


  -- ============================================================
  -- PRIVATE: FORMATTING
  -- ============================================================

  FUNCTION fmt_type(
    p_type  IN VARCHAR2,
    p_len   IN NUMBER,
    p_prec  IN NUMBER,
    p_scale IN NUMBER
  ) RETURN VARCHAR2 IS
  BEGIN
    IF p_type IN ('VARCHAR2','NVARCHAR2','CHAR','NCHAR') THEN
      RETURN p_type || '(' || p_len || ')';
    ELSIF p_type = 'NUMBER' THEN
      IF    p_prec IS NOT NULL AND p_scale IS NOT NULL THEN RETURN 'NUMBER(' || p_prec || ',' || p_scale || ')';
      ELSIF p_prec IS NOT NULL                         THEN RETURN 'NUMBER(' || p_prec || ')';
      ELSE                                                  RETURN 'NUMBER';
      END IF;
    ELSE
      RETURN NVL(p_type, 'UNKNOWN');
    END IF;
  END fmt_type;

  FUNCTION esc(pv IN VARCHAR2) RETURN VARCHAR2 IS
    lv VARCHAR2(32767) := NVL(pv, '');
  BEGIN
    lv := REPLACE(lv, '\',   '\\');
    lv := REPLACE(lv, '"',   '\"');
    lv := REPLACE(lv, CHR(10), '\n');
    lv := REPLACE(lv, CHR(13), '\r');
    lv := REPLACE(lv, CHR(9),  '\t');
    RETURN lv;
  END esc;

  -- JSON-escape a CLOB chunk by chunk
  PROCEDURE wc_esc(p_target IN OUT NOCOPY CLOB, p_source IN CLOB) IS
    l_off PLS_INTEGER := 1;
    l_len PLS_INTEGER;
    l_chunk VARCHAR2(4000);
  BEGIN
    IF p_source IS NULL THEN RETURN; END IF;
    l_len := DBMS_LOB.GETLENGTH(p_source);
    WHILE l_off <= l_len LOOP
      l_chunk := DBMS_LOB.SUBSTR(p_source, 4000, l_off);
      w(p_target, esc(l_chunk));
      l_off := l_off + 4000;
    END LOOP;
  END wc_esc;

  -- Append CLOB indented line by line
  PROCEDURE wc_indent(p_target IN OUT NOCOPY CLOB, p_source IN CLOB, p_pfx IN VARCHAR2) IS
    l_len   PLS_INTEGER;
    l_start PLS_INTEGER := 1;
    l_next  PLS_INTEGER;
    l_line  VARCHAR2(32767);
  BEGIN
    IF p_source IS NULL THEN RETURN; END IF;
    l_len := DBMS_LOB.GETLENGTH(p_source);
    IF l_len = 0 THEN RETURN; END IF;
    LOOP
      l_next := DBMS_LOB.INSTR(p_source, nl, l_start, 1);
      IF l_next = 0 THEN
        l_line := DBMS_LOB.SUBSTR(p_source, l_len - l_start + 1, l_start);
        wl(p_target, p_pfx || l_line);
        EXIT;
      ELSE
        l_line := DBMS_LOB.SUBSTR(p_source, l_next - l_start, l_start);
        wl(p_target, p_pfx || l_line);
        l_start := l_next + 1;
        EXIT WHEN l_start > l_len;
      END IF;
    END LOOP;
  END wc_indent;


  -- ============================================================
  -- PRIVATE: NAME FILTER
  -- ============================================================

  FUNCTION is_included(p_names IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    RETURN p_names IS NULL OR LENGTH(TRIM(p_names)) > 0;
  END is_included;

  FUNCTION to_list(p_names IN VARCHAR2) RETURN apex_t_varchar2 IS
  BEGIN
    IF p_names IS NULL OR LENGTH(TRIM(p_names)) = 0 THEN
      RETURN apex_t_varchar2();
    END IF;
    RETURN apex_string.split(UPPER(TRIM(p_names)), ',');
  END to_list;

  FUNCTION in_list(p_name IN VARCHAR2, p_list IN apex_t_varchar2) RETURN BOOLEAN IS
  BEGIN
    IF p_list IS NULL OR p_list.COUNT = 0 THEN RETURN TRUE; END IF;
    FOR i IN 1 .. p_list.COUNT LOOP
      IF TRIM(UPPER(p_list(i))) = UPPER(p_name) THEN RETURN TRUE; END IF;
    END LOOP;
    RETURN FALSE;
  END in_list;


  -- ============================================================
  -- PRIVATE: VIEW TEXT
  -- USER_VIEWS.TEXT is LONG — MUST use EXECUTE IMMEDIATE + TO_LOB
  -- Never reference user_views.text directly in PL/SQL
  -- ============================================================

  FUNCTION view_text(p_view IN VARCHAR2) RETURN CLOB IS
    lc CLOB;
  BEGIN
    EXECUTE IMMEDIATE
      'SELECT TO_LOB(text) FROM user_views WHERE view_name = :1'
    INTO lc USING UPPER(p_view);
    RETURN lc;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN TO_CLOB('-- View text unavailable: ' || SQLERRM);
  END view_text;

  -- View columns via user_tab_columns (universal — works on all Oracle versions)
  FUNCTION view_cols_csv(p_view IN VARCHAR2) RETURN VARCHAR2 IS
    l_cols VARCHAR2(32767);
  BEGIN
    SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_id)
      INTO l_cols
      FROM user_tab_columns
     WHERE table_name = UPPER(p_view);
    RETURN l_cols;
  EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
  END view_cols_csv;


  -- ============================================================
  -- PRIVATE: PACKAGE SUBPROGRAM HELPERS
  -- IMPORTANT: These functions query user_arguments but are only
  -- called from PL/SQL context, never from SQL WHERE clauses.
  -- ============================================================

  FUNCTION subprog_is_func(p_pkg IN VARCHAR2, p_sub IN VARCHAR2, p_id IN NUMBER) RETURN BOOLEAN IS
    l_cnt PLS_INTEGER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt
      FROM user_arguments
     WHERE package_name  = UPPER(p_pkg)
       AND object_name   = p_sub
       AND subprogram_id = p_id
       AND argument_name IS NULL
       AND position      = 0
       AND data_level    = 0;
    RETURN l_cnt > 0;
  END subprog_is_func;

  FUNCTION subprog_return_type(p_pkg IN VARCHAR2, p_sub IN VARCHAR2, p_id IN NUMBER) RETURN VARCHAR2 IS
    l_type VARCHAR2(128);
  BEGIN
    SELECT data_type INTO l_type
      FROM user_arguments
     WHERE package_name  = UPPER(p_pkg)
       AND object_name   = p_sub
       AND subprogram_id = p_id
       AND argument_name IS NULL
       AND position      = 0
       AND data_level    = 0;
    RETURN NVL(l_type, 'UNKNOWN');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
  END subprog_return_type;

  FUNCTION subprog_args(p_pkg IN VARCHAR2, p_sub IN VARCHAR2, p_id IN NUMBER) RETURN VARCHAR2 IS
    l_args VARCHAR2(32767);
  BEGIN
    FOR r IN (
      SELECT LOWER(argument_name) AS arg_name,
             in_out,
             NVL(data_type,'UNKNOWN') AS dtype
        FROM user_arguments
       WHERE package_name  = UPPER(p_pkg)
         AND object_name   = p_sub
         AND subprogram_id = p_id
         AND argument_name IS NOT NULL
         AND data_level    = 0
       ORDER BY sequence
    ) LOOP
      l_args := l_args
             || CASE WHEN l_args IS NOT NULL THEN ', ' END
             || r.arg_name || ' ' || r.in_out || ' ' || r.dtype;
    END LOOP;
    RETURN NVL(l_args, '');
  END subprog_args;


  -- ============================================================
  -- PRIVATE: EXTRACT ARRAY FROM JSON WRAPPER
  -- Walks bracket depth correctly
  -- ============================================================

  FUNCTION extract_array(p_src IN CLOB, p_key IN VARCHAR2) RETURN CLOB IS
    l_result CLOB;
    l_kpos   PLS_INTEGER;
    l_spos   PLS_INTEGER;
    l_scan   PLS_INTEGER;
    l_epos   PLS_INTEGER;
    l_depth  PLS_INTEGER := 0;
    l_len    PLS_INTEGER;
    l_ch     VARCHAR2(1);
    l_csz    PLS_INTEGER;
  BEGIN
    l_result := new_clob;
    IF p_src IS NULL OR DBMS_LOB.GETLENGTH(p_src) = 0 THEN
      w(l_result, '[]'); RETURN l_result;
    END IF;
    l_kpos := DBMS_LOB.INSTR(p_src, '"' || p_key || '"', 1, 1);
    IF l_kpos = 0 THEN w(l_result, '[]'); RETURN l_result; END IF;
    l_spos := DBMS_LOB.INSTR(p_src, '[', l_kpos, 1);
    IF l_spos = 0 THEN w(l_result, '[]'); RETURN l_result; END IF;

    l_scan := l_spos;
    l_len  := DBMS_LOB.GETLENGTH(p_src);
    LOOP
      EXIT WHEN l_scan > l_len;
      l_ch := DBMS_LOB.SUBSTR(p_src, 1, l_scan);
      IF    l_ch = '[' THEN l_depth := l_depth + 1;
      ELSIF l_ch = ']' THEN
        l_depth := l_depth - 1;
        IF l_depth = 0 THEN l_epos := l_scan; EXIT; END IF;
      END IF;
      l_scan := l_scan + 1;
    END LOOP;

    IF l_epos = 0 THEN w(l_result, '[]'); RETURN l_result; END IF;

    l_scan := l_spos;
    l_len  := l_epos - l_spos + 1;
    WHILE l_len > 0 LOOP
      l_csz  := LEAST(32767, l_len);
      w(l_result, DBMS_LOB.SUBSTR(p_src, l_csz, l_scan));
      l_scan := l_scan + l_csz;
      l_len  := l_len  - l_csz;
    END LOOP;
    RETURN l_result;
  END extract_array;


  -- ============================================================
  -- PUBLIC: SCHEMA BROWSER CURSORS
  -- ============================================================

  FUNCTION get_table_list RETURN SYS_REFCURSOR IS
    l_rc SYS_REFCURSOR;
  BEGIN
    OPEN l_rc FOR
      SELECT t.table_name,
             t.num_rows,
             t.last_analyzed,
             c.comments
        FROM user_tables t
        LEFT JOIN user_tab_comments c ON c.table_name = t.table_name
       ORDER BY t.table_name;
    RETURN l_rc;
  END get_table_list;

  FUNCTION get_view_list RETURN SYS_REFCURSOR IS
    l_rc SYS_REFCURSOR;
  BEGIN
    -- Use user_tab_columns for column count (universal, no version dependency)
    OPEN l_rc FOR
      SELECT v.view_name,
             (SELECT COUNT(*) FROM user_tab_columns tc
               WHERE tc.table_name = v.view_name) AS column_count,
             c.comments
        FROM user_views v
        LEFT JOIN user_tab_comments c ON c.table_name = v.view_name
                                     AND c.table_type = 'VIEW'
       ORDER BY v.view_name;
    RETURN l_rc;
  END get_view_list;

  FUNCTION get_package_list RETURN SYS_REFCURSOR IS
    l_rc SYS_REFCURSOR;
  BEGIN
    OPEN l_rc FOR
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
    RETURN l_rc;
  END get_package_list;


  -- ============================================================
  -- PUBLIC: TABLE DOCUMENTATION
  -- ============================================================

  FUNCTION generate_markdown(p_table_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out   CLOB;
    l_list  apex_t_varchar2;
    l_cols  VARCHAR2(4000);
    l_any   BOOLEAN;
  BEGIN
    l_out  := new_clob;
    l_list := to_list(p_table_names);

    FOR t_rec IN (
      SELECT t.table_name,
             t.num_rows,
             NVL(tc.comments, 'No description available') AS t_comments
        FROM user_tables t
        LEFT JOIN user_tab_comments tc ON tc.table_name = t.table_name
       ORDER BY t.table_name
    ) LOOP
      BEGIN
        CONTINUE WHEN NOT in_list(t_rec.table_name, l_list);

        wl(l_out, '## TABLE: ' || t_rec.table_name);
        wl(l_out, '**Description:** ' || t_rec.t_comments);
        wl(l_out, '**Estimated Rows:** ' || NVL(TO_CHAR(t_rec.num_rows), 'Unknown'));
        wl(l_out, '');
        wl(l_out, '### Columns');
        wl(l_out, '| Column | Data Type | Nullable | Default | Description |');
        wl(l_out, '|---|---|---|---|---|');

        FOR col_rec IN (
          SELECT col.column_name,
                 col.data_type,
                 col.data_length,
                 col.data_precision,
                 col.data_scale,
                 col.nullable,
                 col.data_default, -- Selected purely, no SQL functions
                 cmt.comments AS col_comments
            FROM user_tab_columns col
            LEFT JOIN user_col_comments cmt
              ON cmt.table_name  = col.table_name
             AND cmt.column_name = col.column_name
           WHERE col.table_name = t_rec.table_name
           ORDER BY col.column_id
        ) LOOP
          DECLARE
            l_clean_default VARCHAR2(32767);
          BEGIN
            -- PL/SQL safely converts LONG to VARCHAR2 automatically here
            l_clean_default := TRIM(REPLACE(REPLACE(col_rec.data_default, CHR(10),' '), CHR(13),' '));

            wl(l_out, '| ' || col_rec.column_name
                   || ' | ' || fmt_type(col_rec.data_type, col_rec.data_length, col_rec.data_precision, col_rec.data_scale)
                   || ' | ' || CASE WHEN col_rec.nullable = 'Y' THEN 'YES' ELSE 'NO' END
                   || ' | ' || NVL(l_clean_default, '-')
                   || ' | ' || NVL(col_rec.col_comments, '-') || ' |');
          END;
        END LOOP;

        wl(l_out, '');
        wl(l_out, '### Constraints');

        -- Primary Key
        BEGIN
          SELECT LISTAGG(ucc.column_name, ', ') WITHIN GROUP (ORDER BY ucc.position)
            INTO l_cols
            FROM user_constraints uc
            JOIN user_cons_columns ucc ON ucc.constraint_name = uc.constraint_name
           WHERE uc.table_name = t_rec.table_name AND uc.constraint_type = 'P';
        EXCEPTION WHEN OTHERS THEN l_cols := NULL;
        END;

        IF l_cols IS NOT NULL THEN
          FOR pk_rec IN (SELECT constraint_name FROM user_constraints
                          WHERE table_name = t_rec.table_name AND constraint_type = 'P') LOOP
            wl(l_out, '**Primary Key:** ' || pk_rec.constraint_name || ' ON (' || l_cols || ')');
          END LOOP;
        ELSE
          wl(l_out, '**Primary Key:** -');
        END IF;

        -- Unique Keys
        l_any := FALSE;
        FOR uk_rec IN (
          SELECT uc.constraint_name,
                 LISTAGG(ucc.column_name, ', ') WITHIN GROUP (ORDER BY ucc.position) AS uk_cols
            FROM user_constraints uc
            JOIN user_cons_columns ucc ON ucc.constraint_name = uc.constraint_name
           WHERE uc.table_name = t_rec.table_name AND uc.constraint_type = 'U'
           GROUP BY uc.constraint_name ORDER BY uc.constraint_name
        ) LOOP
          wl(l_out, '**Unique:** ' || uk_rec.constraint_name || ' ON (' || uk_rec.uk_cols || ')');
          l_any := TRUE;
        END LOOP;
        IF NOT l_any THEN wl(l_out, '**Unique:** -'); END IF;

        -- Foreign Keys
        wl(l_out, '**Foreign Keys:**');
        l_any := FALSE;
        FOR fk_rec IN (
          SELECT uc1.constraint_name,
                 ucc1.column_name  AS fk_col,
                 uc2.table_name    AS ref_tbl,
                 ucc2.column_name  AS ref_col
            FROM user_constraints  uc1
            JOIN user_cons_columns ucc1 ON ucc1.constraint_name = uc1.constraint_name
                                       AND ucc1.table_name      = uc1.table_name
            JOIN user_constraints  uc2  ON uc2.constraint_name  = uc1.r_constraint_name
            JOIN user_cons_columns ucc2 ON ucc2.constraint_name = uc2.constraint_name
                                       AND ucc2.position        = ucc1.position
           WHERE uc1.constraint_type = 'R' AND uc1.table_name = t_rec.table_name
           ORDER BY uc1.constraint_name, ucc1.position
        ) LOOP
          wl(l_out, '  - ' || fk_rec.constraint_name || ': '
                 || fk_rec.fk_col || ' REFERENCES ' || fk_rec.ref_tbl || '(' || fk_rec.ref_col || ')');
          l_any := TRUE;
        END LOOP;
        IF NOT l_any THEN wl(l_out, '  - None'); END IF;

        -- Check Constraints
        wl(l_out, '**Check Constraints:**');
        l_any := FALSE;
        FOR ck_rec IN (
          SELECT constraint_name, search_condition_vc AS ck_cond
            FROM user_constraints
           WHERE table_name      = t_rec.table_name
             AND constraint_type = 'C'
             AND UPPER(search_condition_vc) NOT LIKE '%IS NOT NULL%'
           ORDER BY constraint_name
        ) LOOP
          wl(l_out, '  - ' || ck_rec.constraint_name || ': ' || NVL(ck_rec.ck_cond, '-'));
          l_any := TRUE;
        END LOOP;
        IF NOT l_any THEN wl(l_out, '  - None'); END IF;

        wl(l_out, '');
        wl(l_out, '---');
        wl(l_out, '');
      EXCEPTION
        WHEN OTHERS THEN
          wl(l_out, '## TABLE: ' || t_rec.table_name);
          wl(l_out, '**Error:** ' || SQLERRM);
          wl(l_out, '---');
          wl(l_out, '');
      END;
    END LOOP;
    RETURN l_out;
  END generate_markdown;


  FUNCTION generate_json(p_table_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out      CLOB;
    l_list     apex_t_varchar2;
    l_first_t  BOOLEAN;
    l_first_c  BOOLEAN;
    l_first_uk BOOLEAN;
    l_first_fk BOOLEAN;
    l_first_ck BOOLEAN;
    l_pk_name  VARCHAR2(128);
    l_pk_cols  VARCHAR2(4000);
  BEGIN
    l_out     := new_clob;
    l_list    := to_list(p_table_names);
    l_first_t := TRUE;

    wl(l_out, '{');
    wl(l_out, '  "schema_docs": {');
    wl(l_out, '    "generated_at": "' || TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS') || '",');
    wl(l_out, '    "generated_by": "APEX Schema Docs v2.0.0",');
    wl(l_out, '    "tables": [');

    FOR t_rec IN (
      SELECT t.table_name, t.num_rows,
             NVL(tc.comments,'No description available') AS t_comments
        FROM user_tables t
        LEFT JOIN user_tab_comments tc ON tc.table_name = t.table_name
       ORDER BY t.table_name
    ) LOOP
      BEGIN
        CONTINUE WHEN NOT in_list(t_rec.table_name, l_list);
        IF NOT l_first_t THEN w(l_out, ',' || nl); END IF;
        l_first_t := FALSE;

        wl(l_out, '      {');
        wl(l_out, '        "name": "'         || esc(t_rec.table_name)   || '",');
        wl(l_out, '        "description": "'  || esc(t_rec.t_comments)   || '",');
        wl(l_out, '        "estimated_rows": '|| NVL(TO_CHAR(t_rec.num_rows),'null') || ',');
        wl(l_out, '        "columns": [');
        l_first_c := TRUE;

        FOR col_rec IN (
          SELECT col.column_name,
                 col.data_type, col.data_length, col.data_precision, col.data_scale,
                 col.nullable,
                 col.data_default, -- Selected purely, no SQL functions
                 cmt.comments AS col_comments
            FROM user_tab_columns col
            LEFT JOIN user_col_comments cmt
              ON cmt.table_name  = col.table_name
             AND cmt.column_name = col.column_name
           WHERE col.table_name = t_rec.table_name ORDER BY col.column_id
        ) LOOP
          DECLARE
            l_clean_default VARCHAR2(32767);
          BEGIN
            -- Clean the LONG data inside the PL/SQL block
            l_clean_default := TRIM(col_rec.data_default);

            IF NOT l_first_c THEN w(l_out, ',' || nl); END IF;
            l_first_c := FALSE;
            wl(l_out, '          {');
            wl(l_out, '            "name": "'      || esc(col_rec.column_name) || '",');
            wl(l_out, '            "data_type": "' || esc(fmt_type(col_rec.data_type,col_rec.data_length,col_rec.data_precision,col_rec.data_scale)) || '",');
            wl(l_out, '            "nullable": '   || CASE WHEN col_rec.nullable='Y' THEN 'true' ELSE 'false' END || ',');
            
            IF l_clean_default IS NULL THEN
              wl(l_out, '            "default": null,');
            ELSE
              wl(l_out, '            "default": "' || esc(l_clean_default) || '",');
            END IF;
            
            wl(l_out, '            "description": "' || esc(NVL(col_rec.col_comments,'-')) || '"');
            wl(l_out, '          }');
          END;
        END LOOP;

        wl(l_out, '        ],');
        wl(l_out, '        "constraints": {');

        -- Primary Key
        BEGIN
          SELECT uc.constraint_name,
                 LISTAGG(ucc.column_name,'","') WITHIN GROUP (ORDER BY ucc.position)
            INTO l_pk_name, l_pk_cols
            FROM user_constraints uc
            JOIN user_cons_columns ucc ON ucc.constraint_name = uc.constraint_name
           WHERE uc.table_name = t_rec.table_name AND uc.constraint_type = 'P'
           GROUP BY uc.constraint_name;
          wl(l_out, '          "primary_key": {"name":"' || esc(l_pk_name) || '","columns":["' || esc(l_pk_cols) || '"]},');
        EXCEPTION
          WHEN NO_DATA_FOUND THEN wl(l_out, '          "primary_key": null,');
          WHEN OTHERS        THEN wl(l_out, '          "primary_key": null,');
        END;

        -- Unique Keys
        wl(l_out, '          "unique_keys": [');
        l_first_uk := TRUE;
        FOR uk_rec IN (
          SELECT uc.constraint_name,
                 LISTAGG(ucc.column_name,'","') WITHIN GROUP (ORDER BY ucc.position) AS uk_cols
            FROM user_constraints uc
            JOIN user_cons_columns ucc ON ucc.constraint_name = uc.constraint_name
           WHERE uc.table_name = t_rec.table_name AND uc.constraint_type = 'U'
           GROUP BY uc.constraint_name ORDER BY uc.constraint_name
        ) LOOP
          IF NOT l_first_uk THEN w(l_out, ',' || nl); END IF;
          l_first_uk := FALSE;
          wl(l_out, '            {"name":"' || esc(uk_rec.constraint_name) || '","columns":["' || esc(uk_rec.uk_cols) || '"]}');
        END LOOP;
        wl(l_out, '          ],');

        -- Foreign Keys
        wl(l_out, '          "foreign_keys": [');
        l_first_fk := TRUE;
        FOR fk_rec IN (
          SELECT uc1.constraint_name AS fk_name,
                 uc2.table_name      AS ref_tbl,
                 LISTAGG(ucc1.column_name,'","') WITHIN GROUP (ORDER BY ucc1.position) AS fk_cols,
                 LISTAGG(ucc2.column_name,'","') WITHIN GROUP (ORDER BY ucc1.position) AS ref_cols
            FROM user_constraints  uc1
            JOIN user_cons_columns ucc1 ON ucc1.constraint_name = uc1.constraint_name
                                       AND ucc1.table_name      = uc1.table_name
            JOIN user_constraints  uc2  ON uc2.constraint_name  = uc1.r_constraint_name
            JOIN user_cons_columns ucc2 ON ucc2.constraint_name = uc2.constraint_name
                                       AND ucc2.position        = ucc1.position
           WHERE uc1.constraint_type = 'R' AND uc1.table_name = t_rec.table_name
           GROUP BY uc1.constraint_name, uc2.table_name
           ORDER BY uc1.constraint_name
        ) LOOP
          IF NOT l_first_fk THEN w(l_out, ',' || nl); END IF;
          l_first_fk := FALSE;
          wl(l_out, '            {"name":"'              || esc(fk_rec.fk_name)  || '",'
                 || '"references_table":"'               || esc(fk_rec.ref_tbl)  || '",'
                 || '"columns":["'                       || esc(fk_rec.fk_cols)  || '"],'
                 || '"references_columns":["'            || esc(fk_rec.ref_cols) || '"]}');
        END LOOP;
        wl(l_out, '          ],');

        -- Check Constraints
        wl(l_out, '          "check_constraints": [');
        l_first_ck := TRUE;
        FOR ck_rec IN (
          SELECT constraint_name, search_condition_vc AS ck_cond
            FROM user_constraints
           WHERE table_name = t_rec.table_name AND constraint_type = 'C'
             AND UPPER(search_condition_vc) NOT LIKE '%IS NOT NULL%'
           ORDER BY constraint_name
        ) LOOP
          IF NOT l_first_ck THEN w(l_out, ',' || nl); END IF;
          l_first_ck := FALSE;
          wl(l_out, '            {"name":"' || esc(ck_rec.constraint_name) || '","condition":"' || esc(ck_rec.ck_cond) || '"}');
        END LOOP;
        wl(l_out, '          ]');
        wl(l_out, '        }');
        wl(l_out, '      }');
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
    END LOOP;

    wl(l_out, '    ]');
    wl(l_out, '  }');
    wl(l_out, '}');
    RETURN l_out;
  END generate_json;


  FUNCTION generate_plain_text(p_table_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out  CLOB;
    l_list apex_t_varchar2;
    l_any  BOOLEAN;
  BEGIN
    l_out  := new_clob;
    l_list := to_list(p_table_names);

    wl(l_out, '=== APEX SCHEMA DOCS ===');
    wl(l_out, 'Generated : ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS'));
    wl(l_out, 'Schema    : ' || SYS_CONTEXT('USERENV','CURRENT_SCHEMA'));
    wl(l_out, '');

    FOR t_rec IN (
      SELECT t.table_name, t.num_rows,
             NVL(tc.comments,'No description available') AS t_comments
        FROM user_tables t
        LEFT JOIN user_tab_comments tc ON tc.table_name = t.table_name
       ORDER BY t.table_name
    ) LOOP
      BEGIN
        CONTINUE WHEN NOT in_list(t_rec.table_name, l_list);

        wl(l_out, 'TABLE: '      || t_rec.table_name);
        wl(l_out, 'Description: '|| t_rec.t_comments);
        wl(l_out, 'Rows: '       || CASE WHEN t_rec.num_rows IS NOT NULL THEN '~'||t_rec.num_rows ELSE 'Unknown' END);
        wl(l_out, '');
        wl(l_out, 'COLUMNS:');

        FOR col_rec IN (
          SELECT col.column_name,
                 col.data_type, col.data_length, col.data_precision, col.data_scale,
                 col.nullable,
                 cmt.comments AS col_comments
            FROM user_tab_columns col
            LEFT JOIN user_col_comments cmt
              ON cmt.table_name  = col.table_name
             AND cmt.column_name = col.column_name
           WHERE col.table_name = t_rec.table_name ORDER BY col.column_id
        ) LOOP
          wl(l_out, '  ' || RPAD(col_rec.column_name, 25)
                 || ' ' || RPAD(fmt_type(col_rec.data_type,col_rec.data_length,col_rec.data_precision,col_rec.data_scale), 20)
                 || ' ' || RPAD(CASE WHEN col_rec.nullable='N' THEN 'NOT NULL' ELSE 'NULL' END, 10)
                 || ' ' || NVL(col_rec.col_comments,'-'));
        END LOOP;

        wl(l_out, '');
        wl(l_out, 'CONSTRAINTS:');

        FOR pk_rec IN (
          SELECT uc.constraint_name,
                 LISTAGG(ucc.column_name,', ') WITHIN GROUP (ORDER BY ucc.position) AS pk_cols
            FROM user_constraints uc
            JOIN user_cons_columns ucc ON ucc.constraint_name = uc.constraint_name
           WHERE uc.table_name = t_rec.table_name AND uc.constraint_type = 'P'
           GROUP BY uc.constraint_name
        ) LOOP
          wl(l_out, '  PK: ' || pk_rec.constraint_name || ' (' || pk_rec.pk_cols || ')');
        END LOOP;

        FOR fk_rec IN (
          SELECT uc1.constraint_name AS fk_name,
                 LISTAGG(ucc1.column_name,', ') WITHIN GROUP (ORDER BY ucc1.position) AS fk_cols,
                 uc2.table_name      AS ref_tbl,
                 LISTAGG(ucc2.column_name,', ') WITHIN GROUP (ORDER BY ucc1.position) AS ref_cols
            FROM user_constraints  uc1
            JOIN user_cons_columns ucc1 ON ucc1.constraint_name = uc1.constraint_name
                                       AND ucc1.table_name      = uc1.table_name
            JOIN user_constraints  uc2  ON uc2.constraint_name  = uc1.r_constraint_name
            JOIN user_cons_columns ucc2 ON ucc2.constraint_name = uc2.constraint_name
                                       AND ucc2.position        = ucc1.position
           WHERE uc1.constraint_type = 'R' AND uc1.table_name = t_rec.table_name
           GROUP BY uc1.constraint_name, uc2.table_name ORDER BY uc1.constraint_name
        ) LOOP
          wl(l_out,'  FK: '||fk_rec.fk_name||' -> '||fk_rec.fk_cols||' references '||fk_rec.ref_tbl||'('||fk_rec.ref_cols||')');
        END LOOP;

        l_any := FALSE;
        FOR ck_rec IN (
          SELECT constraint_name, search_condition_vc AS ck_cond
            FROM user_constraints
           WHERE table_name = t_rec.table_name AND constraint_type = 'C'
             AND UPPER(search_condition_vc) NOT LIKE '%IS NOT NULL%'
           ORDER BY constraint_name
        ) LOOP
          wl(l_out,'  CHECK: '||ck_rec.constraint_name||' -> '||ck_rec.ck_cond);
          l_any := TRUE;
        END LOOP;
        IF NOT l_any THEN wl(l_out,'  CHECK: -'); END IF;

        wl(l_out, '');
        wl(l_out, sep);
      EXCEPTION
        WHEN OTHERS THEN
          wl(l_out, 'TABLE: '||t_rec.table_name);
          wl(l_out, 'Error: '||SQLERRM);
          wl(l_out, sep);
      END;
    END LOOP;
    RETURN l_out;
  END generate_plain_text;


  -- ============================================================
  -- PUBLIC: VIEW DOCUMENTATION
  -- ============================================================

  FUNCTION generate_views_markdown(p_view_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out  CLOB;
    l_list apex_t_varchar2;
    l_qt   CLOB;
    l_cols VARCHAR2(32767);
  BEGIN
    l_out  := new_clob;
    IF NOT is_included(p_view_names) THEN RETURN l_out; END IF;
    l_list := to_list(p_view_names);

    FOR v_rec IN (
      SELECT v.view_name,
             NVL(tc.comments,'No description available') AS v_comments
        FROM user_views v
        LEFT JOIN user_tab_comments tc ON tc.table_name = v.view_name
                                      AND tc.table_type = 'VIEW'
       ORDER BY v.view_name
    ) LOOP
      BEGIN
        CONTINUE WHEN NOT in_list(v_rec.view_name, l_list);
        l_qt   := view_text(v_rec.view_name);
        l_cols := view_cols_csv(v_rec.view_name);

        wl(l_out, '## VIEW: '        || v_rec.view_name);
        wl(l_out, '**Description:** '|| v_rec.v_comments);
        wl(l_out, '**Columns:** '    || NVL(l_cols, '-'));
        wl(l_out, '');
        wl(l_out, '**Query:**');
        wc(l_out, l_qt);
        w(l_out, nl);
        wl(l_out, '');
        wl(l_out, '---');
        wl(l_out, '');
      EXCEPTION
        WHEN OTHERS THEN
          wl(l_out, '## VIEW: '||v_rec.view_name);
          wl(l_out, '**Error:** '||SQLERRM);
          wl(l_out, '---');
          wl(l_out, '');
      END;
    END LOOP;
    RETURN l_out;
  END generate_views_markdown;


  FUNCTION generate_views_json(p_view_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out   CLOB;
    l_list  apex_t_varchar2;
    l_first BOOLEAN;
    l_qt    CLOB;
    l_col   VARCHAR2(128);
    l_fc    BOOLEAN;
  BEGIN
    l_out   := new_clob;
    l_list  := to_list(p_view_names);
    l_first := TRUE;

    wl(l_out, '{');
    wl(l_out, '  "views": [');

    IF is_included(p_view_names) THEN
      FOR v_rec IN (
        SELECT v.view_name,
               NVL(tc.comments,'No description available') AS v_comments
          FROM user_views v
          LEFT JOIN user_tab_comments tc ON tc.table_name = v.view_name
                                        AND tc.table_type = 'VIEW'
         ORDER BY v.view_name
      ) LOOP
        BEGIN
          CONTINUE WHEN NOT in_list(v_rec.view_name, l_list);
          IF NOT l_first THEN w(l_out, ',' || nl); END IF;
          l_first := FALSE;

          l_qt := view_text(v_rec.view_name);

          wl(l_out, '    {');
          wl(l_out, '      "name": "'        || esc(v_rec.view_name)   || '",');
          wl(l_out, '      "description": "' || esc(v_rec.v_comments)  || '",');
          wl(l_out, '      "columns": [');

          l_fc := TRUE;
          FOR col_rec IN (
            SELECT column_name FROM user_tab_columns
             WHERE table_name = v_rec.view_name ORDER BY column_id
          ) LOOP
            IF NOT l_fc THEN w(l_out, ',' || nl); END IF;
            l_fc := FALSE;
            wl(l_out, '        "' || esc(col_rec.column_name) || '"');
          END LOOP;

          wl(l_out, '      ],');
          w(l_out,  '      "query": "');
          wc_esc(l_out, l_qt);
          wl(l_out, '"');
          wl(l_out, '    }');
        EXCEPTION
          WHEN OTHERS THEN
            IF NOT l_first THEN w(l_out, ',' || nl); END IF;
            l_first := FALSE;
            wl(l_out, '    {"name":"'||esc(v_rec.view_name)||'","error":"'||esc(SQLERRM)||'","columns":[],"query":""}');
        END;
      END LOOP;
    END IF;

    wl(l_out, '  ]');
    wl(l_out, '}');
    RETURN l_out;
  END generate_views_json;


  FUNCTION generate_views_plain_text(p_view_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out  CLOB;
    l_list apex_t_varchar2;
    l_qt   CLOB;
    l_cols VARCHAR2(32767);
  BEGIN
    l_out  := new_clob;
    IF NOT is_included(p_view_names) THEN RETURN l_out; END IF;
    l_list := to_list(p_view_names);

    FOR v_rec IN (
      SELECT v.view_name,
             NVL(tc.comments,'No description available') AS v_comments
        FROM user_views v
        LEFT JOIN user_tab_comments tc ON tc.table_name = v.view_name
                                      AND tc.table_type = 'VIEW'
       ORDER BY v.view_name
    ) LOOP
      BEGIN
        CONTINUE WHEN NOT in_list(v_rec.view_name, l_list);
        l_cols := view_cols_csv(v_rec.view_name);
        l_qt   := view_text(v_rec.view_name);

        wl(l_out, 'VIEW: '    || v_rec.view_name);
        wl(l_out, 'Columns: ' || NVL(l_cols,'-'));
        wl(l_out, 'Query:');
        wc_indent(l_out, l_qt, '  ');
        wl(l_out, '');
        wl(l_out, sep);
      EXCEPTION
        WHEN OTHERS THEN
          wl(l_out, 'VIEW: '||v_rec.view_name);
          wl(l_out, 'Error: '||SQLERRM);
          wl(l_out, sep);
      END;
    END LOOP;
    RETURN l_out;
  END generate_views_plain_text;


  -- ============================================================
  -- PUBLIC: PACKAGE SPEC DOCUMENTATION
  -- NOTE: subprog_is_func() is called in PL/SQL context only.
  -- It is NOT placed in SQL WHERE clauses anywhere in this file.
  -- ============================================================

  FUNCTION generate_packages_markdown(p_package_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out      CLOB;
    l_list     apex_t_varchar2;
    l_has_proc BOOLEAN;
    l_has_func BOOLEAN;
    l_is_func  BOOLEAN;
  BEGIN
    l_out  := new_clob;
    IF NOT is_included(p_package_names) THEN RETURN l_out; END IF;
    l_list := to_list(p_package_names);

    FOR pkg_rec IN (
      SELECT object_name AS pkg_name
        FROM user_objects
       WHERE object_type = 'PACKAGE'
       ORDER BY object_name
    ) LOOP
      BEGIN
        CONTINUE WHEN NOT in_list(pkg_rec.pkg_name, l_list);

        wl(l_out, '## PACKAGE: ' || pkg_rec.pkg_name);
        wl(l_out, '');
        l_has_proc := FALSE;
        l_has_func := FALSE;

        FOR sub_rec IN (
          SELECT DISTINCT procedure_name, subprogram_id
            FROM user_procedures
           WHERE object_name    = pkg_rec.pkg_name
             AND procedure_name IS NOT NULL
           ORDER BY procedure_name, subprogram_id
        ) LOOP
          -- Call is_func in PL/SQL context, never in SQL
          l_is_func := subprog_is_func(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id);

          IF l_is_func THEN
            IF NOT l_has_func THEN wl(l_out,'### Functions'); l_has_func := TRUE; END IF;
            wl(l_out, '- **' || sub_rec.procedure_name || '**('
                    || subprog_args(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id)
                    || ') RETURN '
                    || NVL(subprog_return_type(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id),'UNKNOWN'));
          ELSE
            IF NOT l_has_proc THEN wl(l_out,'### Procedures'); l_has_proc := TRUE; END IF;
            wl(l_out, '- **' || sub_rec.procedure_name || '**('
                    || subprog_args(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id) || ')');
          END IF;
        END LOOP;

        wl(l_out, '');
        wl(l_out, '---');
        wl(l_out, '');
      EXCEPTION
        WHEN OTHERS THEN
          wl(l_out, '## PACKAGE: '||pkg_rec.pkg_name);
          wl(l_out, '**Error:** '||SQLERRM);
          wl(l_out, '---');
          wl(l_out, '');
      END;
    END LOOP;
    RETURN l_out;
  END generate_packages_markdown;


  FUNCTION generate_packages_json(p_package_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out       CLOB;
    l_list      apex_t_varchar2;
    l_first_pkg BOOLEAN;
    l_first_p   BOOLEAN;
    l_first_f   BOOLEAN;
    l_first_a   BOOLEAN;
    l_is_func   BOOLEAN;
    l_rtype     VARCHAR2(128);
  BEGIN
    l_out       := new_clob;
    l_list      := to_list(p_package_names);
    l_first_pkg := TRUE;

    wl(l_out, '{');
    wl(l_out, '  "packages": [');

    IF is_included(p_package_names) THEN
      FOR pkg_rec IN (
        SELECT object_name AS pkg_name
          FROM user_objects
         WHERE object_type = 'PACKAGE'
         ORDER BY object_name
      ) LOOP
        BEGIN
          CONTINUE WHEN NOT in_list(pkg_rec.pkg_name, l_list);
          IF NOT l_first_pkg THEN w(l_out, ',' || nl); END IF;
          l_first_pkg := FALSE;

          wl(l_out, '    {');
          wl(l_out, '      "name": "' || esc(pkg_rec.pkg_name) || '",');
          wl(l_out, '      "procedures": [');
          l_first_p := TRUE;

          FOR sub_rec IN (
            SELECT DISTINCT procedure_name, subprogram_id
              FROM user_procedures
             WHERE object_name    = pkg_rec.pkg_name
               AND procedure_name IS NOT NULL
             ORDER BY procedure_name, subprogram_id
          ) LOOP
            l_is_func := subprog_is_func(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id);
            CONTINUE WHEN l_is_func;

            IF NOT l_first_p THEN w(l_out, ',' || nl); END IF;
            l_first_p := FALSE;
            w(l_out, '        {"name":"' || esc(sub_rec.procedure_name) || '","arguments":[');
            l_first_a := TRUE;
            FOR arg_rec IN (
              SELECT LOWER(argument_name) AS aname, in_out, NVL(data_type,'UNKNOWN') AS dtype
                FROM user_arguments
               WHERE package_name  = pkg_rec.pkg_name
                 AND object_name   = sub_rec.procedure_name
                 AND subprogram_id = sub_rec.subprogram_id
                 AND argument_name IS NOT NULL
                 AND data_level    = 0
               ORDER BY sequence
            ) LOOP
              IF NOT l_first_a THEN w(l_out, ','); END IF;
              l_first_a := FALSE;
              w(l_out, '{"name":"'||esc(arg_rec.aname)||'","in_out":"'||esc(arg_rec.in_out)||'","data_type":"'||esc(arg_rec.dtype)||'"}');
            END LOOP;
            wl(l_out, ']}');
          END LOOP;
          wl(l_out, '      ],');

          wl(l_out, '      "functions": [');
          l_first_f := TRUE;
          FOR sub_rec IN (
            SELECT DISTINCT procedure_name, subprogram_id
              FROM user_procedures
             WHERE object_name    = pkg_rec.pkg_name
               AND procedure_name IS NOT NULL
             ORDER BY procedure_name, subprogram_id
          ) LOOP
            l_is_func := subprog_is_func(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id);
            CONTINUE WHEN NOT l_is_func;

            IF NOT l_first_f THEN w(l_out, ',' || nl); END IF;
            l_first_f := FALSE;
            l_rtype := NVL(subprog_return_type(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id),'UNKNOWN');
            w(l_out, '        {"name":"' || esc(sub_rec.procedure_name) || '",'
                   || '"return_type":"' || esc(l_rtype) || '","arguments":[');
            l_first_a := TRUE;
            FOR arg_rec IN (
              SELECT LOWER(argument_name) AS aname, in_out, NVL(data_type,'UNKNOWN') AS dtype
                FROM user_arguments
               WHERE package_name  = pkg_rec.pkg_name
                 AND object_name   = sub_rec.procedure_name
                 AND subprogram_id = sub_rec.subprogram_id
                 AND argument_name IS NOT NULL
                 AND data_level    = 0
               ORDER BY sequence
            ) LOOP
              IF NOT l_first_a THEN w(l_out, ','); END IF;
              l_first_a := FALSE;
              w(l_out, '{"name":"'||esc(arg_rec.aname)||'","in_out":"'||esc(arg_rec.in_out)||'","data_type":"'||esc(arg_rec.dtype)||'"}');
            END LOOP;
            wl(l_out, ']}');
          END LOOP;
          wl(l_out, '      ]');
          wl(l_out, '    }');
        EXCEPTION
          WHEN OTHERS THEN
            IF NOT l_first_pkg THEN w(l_out, ',' || nl); END IF;
            l_first_pkg := FALSE;
            wl(l_out, '    {"name":"'||esc(pkg_rec.pkg_name)||'","error":"'||esc(SQLERRM)||'","procedures":[],"functions":[]}');
        END;
      END LOOP;
    END IF;

    wl(l_out, '  ]');
    wl(l_out, '}');
    RETURN l_out;
  END generate_packages_json;


  FUNCTION generate_packages_plain_text(p_package_names IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out     CLOB;
    l_list    apex_t_varchar2;
    l_is_func BOOLEAN;
  BEGIN
    l_out  := new_clob;
    IF NOT is_included(p_package_names) THEN RETURN l_out; END IF;
    l_list := to_list(p_package_names);

    FOR pkg_rec IN (
      SELECT object_name AS pkg_name
        FROM user_objects
       WHERE object_type = 'PACKAGE'
       ORDER BY object_name
    ) LOOP
      BEGIN
        CONTINUE WHEN NOT in_list(pkg_rec.pkg_name, l_list);

        wl(l_out, 'PACKAGE: ' || pkg_rec.pkg_name);
        wl(l_out, '');

        FOR sub_rec IN (
          SELECT DISTINCT procedure_name, subprogram_id
            FROM user_procedures
           WHERE object_name    = pkg_rec.pkg_name
             AND procedure_name IS NOT NULL
           ORDER BY procedure_name, subprogram_id
        ) LOOP
          l_is_func := subprog_is_func(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id);
          IF l_is_func THEN
            wl(l_out, '  FUNCTION  ' || sub_rec.procedure_name
                    || '(' || subprog_args(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id) || ')'
                    || ' RETURN ' || NVL(subprog_return_type(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id),'UNKNOWN'));
          ELSE
            wl(l_out, '  PROCEDURE ' || sub_rec.procedure_name
                    || '(' || subprog_args(pkg_rec.pkg_name, sub_rec.procedure_name, sub_rec.subprogram_id) || ')');
          END IF;
        END LOOP;

        wl(l_out, '');
        wl(l_out, sep);
      EXCEPTION
        WHEN OTHERS THEN
          wl(l_out, 'PACKAGE: '||pkg_rec.pkg_name);
          wl(l_out, 'Error: '||SQLERRM);
          wl(l_out, sep);
      END;
    END LOOP;
    RETURN l_out;
  END generate_packages_plain_text;


  -- ============================================================
  -- PUBLIC: MASTER GENERATORS
  -- ============================================================

  FUNCTION generate_full_markdown(
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_out CLOB;
  BEGIN
    l_out := new_clob;
    IF is_included(p_table_names)   THEN wc(l_out, generate_markdown(p_table_names));             w(l_out, nl); END IF;
    IF is_included(p_view_names)    THEN wc(l_out, generate_views_markdown(p_view_names));         w(l_out, nl); END IF;
    IF is_included(p_package_names) THEN wc(l_out, generate_packages_markdown(p_package_names));               END IF;
    RETURN l_out;
  END generate_full_markdown;


  FUNCTION generate_full_json(
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_out  CLOB;
    l_t    CLOB;
    l_v    CLOB;
    l_p    CLOB;
  BEGIN
    l_out := new_clob;

    -- All sub-document CLOBs assigned in BEGIN, never in DECLARE
    IF is_included(p_table_names) THEN
      l_t := extract_array(generate_json(p_table_names), 'tables');
    ELSE
      l_t := new_clob; w(l_t, '[]');
    END IF;

    IF is_included(p_view_names) THEN
      l_v := extract_array(generate_views_json(p_view_names), 'views');
    ELSE
      l_v := new_clob; w(l_v, '[]');
    END IF;

    IF is_included(p_package_names) THEN
      l_p := extract_array(generate_packages_json(p_package_names), 'packages');
    ELSE
      l_p := new_clob; w(l_p, '[]');
    END IF;

    wl(l_out, '{');
    wl(l_out, '  "schema_docs": {');
    wl(l_out, '    "generated_at": "' || TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS') || '",');
    wl(l_out, '    "generated_by": "APEX Schema Docs v2.0.0",');
    w(l_out,  '    "tables": ');   wc(l_out, l_t); wl(l_out, ',');
    w(l_out,  '    "views": ');    wc(l_out, l_v); wl(l_out, ',');
    w(l_out,  '    "packages": '); wc(l_out, l_p); w(l_out, nl);
    wl(l_out, '  }');
    wl(l_out, '}');
    RETURN l_out;
  END generate_full_json;


  FUNCTION generate_full_plain_text(
    p_table_names   IN VARCHAR2 DEFAULT NULL,
    p_view_names    IN VARCHAR2 DEFAULT NULL,
    p_package_names IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_out CLOB;
  BEGIN
    l_out := new_clob;
    IF is_included(p_table_names)   THEN wc(l_out, generate_plain_text(p_table_names));             w(l_out, nl); END IF;
    IF is_included(p_view_names)    THEN wc(l_out, generate_views_plain_text(p_view_names));         w(l_out, nl); END IF;
    IF is_included(p_package_names) THEN wc(l_out, generate_packages_plain_text(p_package_names));               END IF;
    RETURN l_out;
  END generate_full_plain_text;


  -- ============================================================
  -- PUBLIC: UTILITY
  -- ============================================================

  FUNCTION estimate_tokens(p_content IN CLOB) RETURN NUMBER IS
  BEGIN
    IF p_content IS NULL THEN RETURN 0; END IF;
    RETURN CEIL(DBMS_LOB.GETLENGTH(p_content) / 4);
  END estimate_tokens;

END apex_schema_docs_pkg;
/

SHOW ERRORS;
