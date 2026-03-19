# Changelog

## [2.0.0] - 2026-03-19
### Added
- Views documentation including full query text and column list (USER_VIEWS, USER_VIEW_COLUMNS)
- PL/SQL Package Spec documentation with procedures, functions, argument names, IN/OUT modes, data types, and return types (USER_OBJECTS, USER_PROCEDURES, USER_ARGUMENTS)
- get_view_list function for Views schema browser
- get_package_list function for Packages schema browser
- generate_views_markdown, generate_views_json, generate_views_plain_text
- generate_packages_markdown, generate_packages_json, generate_packages_plain_text
- generate_full_markdown, generate_full_json, generate_full_plain_text (master generators combining Tables + Views + Packages in one output)
- Private view_text_to_clob helper for safe LONG-to-CLOB conversion from USER_VIEWS

### Changed
- Package version bumped to 2.0.0
- README updated to reflect V2 features and output examples
- Usage Guide updated to cover Views and Packages selection flow

---

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
