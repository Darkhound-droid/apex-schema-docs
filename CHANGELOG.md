# Changelog

## [2.0.0] - 2026-03-19
### Added
- Views documentation (USER_VIEWS, USER_VIEW_COLUMNS, USER_TAB_COMMENTS)
- Package Spec documentation (USER_OBJECTS, USER_PROCEDURES, USER_ARGUMENTS)
- get_view_list: returns all user views for schema browser
- get_package_list: returns all user package specs for schema browser
- generate_views_markdown, generate_views_json, generate_views_plain_text
- generate_packages_markdown, generate_packages_json, generate_packages_plain_text
- generate_full_markdown, generate_full_json, generate_full_plain_text
  (master generators combining Tables + Views + Packages in one output)
- Private view_text_to_clob helper for safe LONG-to-CLOB conversion

### Changed
- Package version bumped to 2.0.0 in header comments
- README updated: Features and Roadmap sections only
- View column lookups now fall back to USER_TAB_COLUMNS when USER_VIEW_COLUMNS is unavailable

## [1.0.0] - 2026-03-11
### Added
- Initial release
- Table, Column, and Constraint documentation
- Markdown output format
- JSON output format
- Plain Text output format
- Token count estimation
- Schema browser with search and multi-select
- Copy to clipboard functionality
- File download for all three formats
- APEX Schema Docs PL/SQL package (apex_schema_docs_pkg)
