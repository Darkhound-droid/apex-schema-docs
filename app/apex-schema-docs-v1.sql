prompt --application/set_environment
set define off verify off feedback off

begin
  wwv_flow_api.set_security_group_id(nvl(wwv_flow_application_install.get_workspace_id, 1000000000000000));
  wwv_flow_api.g_id_offset := nvl(wwv_flow_application_install.get_offset, 0);
  wwv_flow_api.g_flow_id := nvl(wwv_flow_application_install.get_application_id, 110);
  wwv_flow_api.g_flow_owner := nvl(wwv_flow_application_install.get_schema, user);
  wwv_flow_api.import_begin(
    p_version_yyyy_mm_dd => '2022.04.12',
    p_release            => '22.1.0',
    p_default_workspace_id => 1000000000000000,
    p_default_application_id => 110,
    p_default_id_offset  => 0,
    p_default_owner      => user);
end;
/

prompt APPLICATION 110 - APEX Schema Docs
-- Application Export

prompt --application/create_application
begin
    wwv_flow_api.create_flow(
        p_id                           => wwv_flow_api.id(110),
        p_name                         => 'APEX Schema Docs',
        p_page_view_logging            => 'YES',
        p_flow_language                => 'en',
        p_flow_language_derived_from   => 'FLOW_PRIMARY_LANGUAGE',
        p_flow_version                 => '1.0.0',
        p_flow_status                  => 'AVAILABLE_W_EDIT_LINK',
        p_exact_substitutions_only     => 'Y',
        p_owner                        => wwv_flow_api.g_flow_owner,
        p_authentication               => 'NATIVE_APEX_ACCOUNTS',
        p_build_status                 => 'RUN_AND_BUILD',
        p_theme_id                     => 42,
        p_home_link                    => 'f?p=&APP_ID.:1:&APP_SESSION.::&DEBUG.::::',
        p_logo_type                    => 'T',
        p_logo_text                    => 'APEX Schema Docs',
        p_flow_image_prefix            => nvl(wwv_flow_application_install.get_image_prefix,'/i/')
    );
end;
/

prompt --application/shared_components/navigation/lists/navigation_menu
begin
    wwv_flow_api.create_list(
        p_id   => wwv_flow_api.id(100001),
        p_name => 'Navigation Menu');

    wwv_flow_api.create_list_item(
        p_id=>wwv_flow_api.id(100002),
        p_list_id=>wwv_flow_api.id(100001),
        p_list_item_display_sequence=>10,
        p_list_item_link_target=>'f?p=&APP_ID.:1:&APP_SESSION.::&DEBUG.::::',
        p_list_item_text=>'Home',
        p_list_item_current_type=>'TARGET_PAGE');

    wwv_flow_api.create_list_item(
        p_id=>wwv_flow_api.id(100003),
        p_list_id=>wwv_flow_api.id(100001),
        p_list_item_display_sequence=>20,
        p_list_item_link_target=>'f?p=&APP_ID.:2:&APP_SESSION.::&DEBUG.::::',
        p_list_item_text=>'Select Tables',
        p_list_item_current_type=>'TARGET_PAGE');

    wwv_flow_api.create_list_item(
        p_id=>wwv_flow_api.id(100004),
        p_list_id=>wwv_flow_api.id(100001),
        p_list_item_display_sequence=>30,
        p_list_item_link_target=>'f?p=&APP_ID.:4:&APP_SESSION.::&DEBUG.::::',
        p_list_item_text=>'About',
        p_list_item_current_type=>'TARGET_PAGE');
end;
/

prompt --application/pages/page_00001
begin
    wwv_flow_api.create_page(
        p_id                 => 1,
        p_name               => 'APEX Schema Docs',
        p_alias              => 'HOME',
        p_step_title         => 'APEX Schema Docs',
        p_autocomplete_on_off=> 'OFF',
        p_protection_level   => 'C');

    wwv_flow_api.create_page_plug(
        p_id                    => wwv_flow_api.id(110001),
        p_plug_name             => 'Hero',
        p_plug_display_sequence => 10,
        p_plug_source_type      => 'NATIVE_STATIC_REGION',
        p_plug_source           => q'[<div style="text-align:center;padding:2rem;">
<h1>APEX Schema Docs</h1>
<h3>Generate LLM-ready documentation from your Oracle schema in seconds.</h3>
<p>Stop copying and pasting DDL into ChatGPT one table at a time. APEX Schema Docs reads your Oracle schema and generates clean, structured documentation in Markdown, JSON, and Plain Text — ready to drop directly into any AI model as context.</p>
<div style="display:flex;gap:1rem;justify-content:center;flex-wrap:wrap;">
  <div class="t-Card" style="padding:1rem;min-width:220px;"><h4>Markdown</h4><p>Perfect for Claude and ChatGPT</p></div>
  <div class="t-Card" style="padding:1rem;min-width:220px;"><h4>JSON</h4><p>Ready for API-based LLM calls</p></div>
  <div class="t-Card" style="padding:1rem;min-width:220px;"><h4>Plain Text</h4><p>Compact token-efficient summaries</p></div>
</div>
<p style="margin-top:1.5rem;"><a class="t-Button t-Button--hot" href="f?p=&APP_ID.:2:&APP_SESSION.::&DEBUG.::::">Generate Documentation</a></p>
<p style="margin-top:2rem;">Open source under MIT License. Built by Hassan Raza, Oracle ACE Apprentice.</p>
</div>]');
end;
/

prompt --application/pages/page_00002
begin
    wwv_flow_api.create_page(
        p_id                 => 2,
        p_name               => 'Select Tables',
        p_alias              => 'SELECT-TABLES',
        p_step_title         => 'Select Tables',
        p_autocomplete_on_off=> 'OFF',
        p_protection_level   => 'C');

    wwv_flow_api.create_page_plug(
        p_id=>wwv_flow_api.id(120001),
        p_plug_name=>'Filter Bar',
        p_plug_display_sequence=>10,
        p_plug_source_type=>'NATIVE_STATIC_REGION');

    wwv_flow_api.create_page_item(
        p_id=>wwv_flow_api.id(120002),
        p_name=>'P2_SCHEMA',
        p_item_sequence=>10,
        p_item_plug_id=>wwv_flow_api.id(120001),
        p_prompt=>'Schema',
        p_source=>'SYS_CONTEXT(''USERENV'',''CURRENT_SCHEMA'')',
        p_source_type=>'QUERY',
        p_display_as=>'NATIVE_DISPLAY_ONLY');

    wwv_flow_api.create_page_item(
        p_id=>wwv_flow_api.id(120003),
        p_name=>'P2_SEARCH_TABLES',
        p_item_sequence=>20,
        p_item_plug_id=>wwv_flow_api.id(120001),
        p_prompt=>'Search tables',
        p_display_as=>'NATIVE_TEXT_FIELD');

    wwv_flow_api.create_page_plug(
        p_id=>wwv_flow_api.id(120004),
        p_plug_name=>'Table Selection',
        p_plug_display_sequence=>20,
        p_query_type=>'SQL',
        p_plug_source=>q'[select apex_item.checkbox2(1, table_name, 'checked="checked" class="tblchk"') as select_table,
       table_name,
       num_rows as estimated_rows,
       last_analyzed,
       case when comments is not null then substr(comments,1,80) else '-' end as description
  from (
    select ut.table_name, ut.num_rows, ut.last_analyzed, utc.comments
      from user_tables ut
      left join user_tab_comments utc
        on utc.table_name = ut.table_name
  )
 order by table_name]',
        p_plug_source_type=>'NATIVE_IR');

    wwv_flow_api.create_page_plug(
        p_id=>wwv_flow_api.id(120005),
        p_plug_name=>'Output Format Selection',
        p_plug_display_sequence=>30,
        p_plug_source_type=>'NATIVE_STATIC_REGION');

    wwv_flow_api.create_page_item(
        p_id=>wwv_flow_api.id(120006),
        p_name=>'P2_OUTPUT_FORMAT',
        p_item_sequence=>10,
        p_item_plug_id=>wwv_flow_api.id(120005),
        p_prompt=>'Output Format',
        p_display_as=>'NATIVE_RADIOGROUP',
        p_lov=>'STATIC2:Markdown;MARKDOWN,JSON;JSON,Plain Text;PLAIN_TEXT',
        p_item_default=>'MARKDOWN');

    wwv_flow_api.create_page_item(
        p_id=>wwv_flow_api.id(120007),
        p_name=>'P2_SELECTED_TABLES',
        p_item_sequence=>20,
        p_item_plug_id=>wwv_flow_api.id(120005),
        p_display_as=>'NATIVE_HIDDEN');

    wwv_flow_api.create_page_item(
        p_id=>wwv_flow_api.id(120008),
        p_name=>'P2_TOKEN_ESTIMATE',
        p_item_sequence=>30,
        p_item_plug_id=>wwv_flow_api.id(120005),
        p_prompt=>'Estimated Token Count',
        p_display_as=>'NATIVE_DISPLAY_ONLY');

    wwv_flow_api.create_page_button(
        p_id=>wwv_flow_api.id(120009),
        p_button_sequence=>40,
        p_button_plug_id=>wwv_flow_api.id(120005),
        p_button_name=>'GENERATE_DOCUMENTATION',
        p_button_action=>'SUBMIT',
        p_button_image_alt=>'Generate Documentation');

    wwv_flow_api.create_page_button(
        p_id=>wwv_flow_api.id(120010),
        p_button_sequence=>50,
        p_button_plug_id=>wwv_flow_api.id(120005),
        p_button_name=>'BACK',
        p_button_action=>'REDIRECT_PAGE',
        p_button_redirect_url=>'f?p=&APP_ID.:1:&APP_SESSION.::&DEBUG.::::',
        p_button_image_alt=>'Back');

    wwv_flow_api.create_page_da_event(
        p_id=>wwv_flow_api.id(120011),
        p_name=>'Collect Selected Tables',
        p_event_sequence=>10,
        p_triggering_element_type=>'BUTTON',
        p_triggering_button_id=>wwv_flow_api.id(120009),
        p_bind_type=>'bind',
        p_bind_event_type=>'click');

    wwv_flow_api.create_page_da_action(
        p_id=>wwv_flow_api.id(120012),
        p_event_id=>wwv_flow_api.id(120011),
        p_action_sequence=>10,
        p_action=>'NATIVE_JAVASCRIPT_CODE',
        p_attribute_01=>q'[var vals=[];
document.querySelectorAll('.tblchk:checked').forEach(function(el){ vals.push(el.value); });
apex.item('P2_SELECTED_TABLES').setValue(vals.join(','));]');

    wwv_flow_api.create_page_da_event(
        p_id=>wwv_flow_api.id(120013),
        p_name=>'Search Filter',
        p_event_sequence=>20,
        p_triggering_element_type=>'ITEM',
        p_triggering_element=>'P2_SEARCH_TABLES',
        p_bind_type=>'bind',
        p_bind_event_type=>'keyup');

    wwv_flow_api.create_page_da_action(
        p_id=>wwv_flow_api.id(120014),
        p_event_id=>wwv_flow_api.id(120013),
        p_action_sequence=>10,
        p_action=>'NATIVE_JAVASCRIPT_CODE',
        p_attribute_01=>q'[var v=this.triggeringElement.value.toUpperCase();
document.querySelectorAll('tr').forEach(function(r){
  if (r.innerText && r.innerText.toUpperCase().indexOf(v) > -1) { r.style.display=''; }
  else if (r.querySelector('.tblchk')) { r.style.display='none'; }
});]');

    wwv_flow_api.create_page_branch(
        p_id=>wwv_flow_api.id(120016),
        p_branch_action=>'f?p=&APP_ID.:3:&APP_SESSION.::&DEBUG.::P2_SELECTED_TABLES,P2_OUTPUT_FORMAT:&P2_SELECTED_TABLES.,&P2_OUTPUT_FORMAT.',
        p_branch_point=>'AFTER_PROCESSING',
        p_branch_type=>'REDIRECT_URL',
        p_branch_when_button_id=>wwv_flow_api.id(120009));
end;
/

prompt --application/pages/page_00003
begin
    wwv_flow_api.create_page(
        p_id                 => 3,
        p_name               => 'Generated Documentation',
        p_alias              => 'OUTPUT',
        p_step_title         => 'Generated Documentation',
        p_autocomplete_on_off=> 'OFF',
        p_protection_level   => 'C');

    wwv_flow_api.create_page_plug(
        p_id=>wwv_flow_api.id(130001),
        p_plug_name=>'Output Controls',
        p_plug_display_sequence=>10,
        p_plug_source_type=>'NATIVE_STATIC_REGION');

    wwv_flow_api.create_page_item(
        p_id=>wwv_flow_api.id(130002),
        p_name=>'P3_FORMAT',
        p_item_sequence=>10,
        p_item_plug_id=>wwv_flow_api.id(130001),
        p_prompt=>'Format',
        p_display_as=>'NATIVE_DISPLAY_ONLY',
        p_source=>'P2_OUTPUT_FORMAT',
        p_source_type=>'ITEM');

    wwv_flow_api.create_page_item(
        p_id=>wwv_flow_api.id(130003),
        p_name=>'P3_TABLE_COUNT',
        p_item_sequence=>20,
        p_item_plug_id=>wwv_flow_api.id(130001),
        p_prompt=>'Tables',
        p_display_as=>'NATIVE_DISPLAY_ONLY');

    wwv_flow_api.create_page_item(
        p_id=>wwv_flow_api.id(130004),
        p_name=>'P3_TOKEN_ESTIMATE',
        p_item_sequence=>30,
        p_item_plug_id=>wwv_flow_api.id(130001),
        p_prompt=>'Estimated Tokens',
        p_display_as=>'NATIVE_DISPLAY_ONLY');

    wwv_flow_api.create_page_button(
        p_id=>wwv_flow_api.id(130005),
        p_button_sequence=>40,
        p_button_plug_id=>wwv_flow_api.id(130001),
        p_button_name=>'COPY_TO_CLIPBOARD',
        p_button_action=>'DEFINED_BY_DA',
        p_button_image_alt=>'Copy to Clipboard');

    wwv_flow_api.create_page_button(
        p_id=>wwv_flow_api.id(130006),
        p_button_sequence=>50,
        p_button_plug_id=>wwv_flow_api.id(130001),
        p_button_name=>'DOWNLOAD_FILE',
        p_button_action=>'SUBMIT',
        p_button_image_alt=>'Download File');

    wwv_flow_api.create_page_button(
        p_id=>wwv_flow_api.id(130007),
        p_button_sequence=>60,
        p_button_plug_id=>wwv_flow_api.id(130001),
        p_button_name=>'REGENERATE',
        p_button_action=>'REDIRECT_PAGE',
        p_button_redirect_url=>'f?p=&APP_ID.:2:&APP_SESSION.::&DEBUG.::::',
        p_button_image_alt=>'Regenerate');

    wwv_flow_api.create_page_button(
        p_id=>wwv_flow_api.id(130008),
        p_button_sequence=>70,
        p_button_plug_id=>wwv_flow_api.id(130001),
        p_button_name=>'HOME',
        p_button_action=>'REDIRECT_PAGE',
        p_button_redirect_url=>'f?p=&APP_ID.:1:&APP_SESSION.::&DEBUG.::::',
        p_button_image_alt=>'Home');

    wwv_flow_api.create_page_plug(
        p_id=>wwv_flow_api.id(130009),
        p_plug_name=>'Output Display',
        p_plug_display_sequence=>20,
        p_plug_source_type=>'NATIVE_STATIC_REGION');

    wwv_flow_api.create_page_item(
        p_id=>wwv_flow_api.id(130010),
        p_name=>'P3_OUTPUT',
        p_item_sequence=>10,
        p_item_plug_id=>wwv_flow_api.id(130009),
        p_prompt=>'Output',
        p_display_as=>'NATIVE_TEXTAREA',
        p_cHeight=>30,
        p_item_css_classes=>'u-code-font');

    wwv_flow_api.create_page_da_event(
        p_id=>wwv_flow_api.id(130011),
        p_name=>'Copy to Clipboard',
        p_event_sequence=>10,
        p_triggering_element_type=>'BUTTON',
        p_triggering_button_id=>wwv_flow_api.id(130005),
        p_bind_type=>'bind',
        p_bind_event_type=>'click');

    wwv_flow_api.create_page_da_action(
        p_id=>wwv_flow_api.id(130012),
        p_event_id=>wwv_flow_api.id(130011),
        p_action_sequence=>10,
        p_action=>'NATIVE_JAVASCRIPT_CODE',
        p_attribute_01=>q'[function copyToClipboard() {
  const output = document.getElementById('P3_OUTPUT').value;
  navigator.clipboard.writeText(output).then(function() {
    apex.message.showPageSuccess('Copied to clipboard!');
  });
}
copyToClipboard();]');

    wwv_flow_api.create_page_process(
        p_id=>wwv_flow_api.id(130013),
        p_process_sequence=>10,
        p_process_point=>'BEFORE_HEADER',
        p_process_type=>'NATIVE_PLSQL',
        p_process_name=>'Generate Output',
        p_process_sql_clob=>q'[
BEGIN
  IF :P2_OUTPUT_FORMAT = 'MARKDOWN' THEN
    :P3_OUTPUT := apex_schema_docs_pkg.generate_markdown(:P2_SELECTED_TABLES);
  ELSIF :P2_OUTPUT_FORMAT = 'JSON' THEN
    :P3_OUTPUT := apex_schema_docs_pkg.generate_json(:P2_SELECTED_TABLES);
  ELSE
    :P3_OUTPUT := apex_schema_docs_pkg.generate_plain_text(:P2_SELECTED_TABLES);
  END IF;

  :P3_TOKEN_ESTIMATE := apex_schema_docs_pkg.estimate_tokens(:P3_OUTPUT);

  SELECT CASE
           WHEN :P2_SELECTED_TABLES IS NULL THEN 0
           ELSE REGEXP_COUNT(:P2_SELECTED_TABLES, '[^,]+')
         END
    INTO :P3_TABLE_COUNT
    FROM dual;
END;
]');

    wwv_flow_api.create_page_process(
        p_id=>wwv_flow_api.id(130014),
        p_process_sequence=>20,
        p_process_point=>'AFTER_SUBMIT',
        p_process_type=>'NATIVE_PLSQL',
        p_process_name=>'Download Output',
        p_process_when_button_id=>wwv_flow_api.id(130006),
        p_process_sql_clob=>q'[
DECLARE
  l_filename VARCHAR2(200);
  l_mime     VARCHAR2(200);
BEGIN
  IF :P2_OUTPUT_FORMAT = 'MARKDOWN' THEN
    l_filename := 'schema-docs.md';
    l_mime := 'text/markdown';
  ELSIF :P2_OUTPUT_FORMAT = 'JSON' THEN
    l_filename := 'schema-docs.json';
    l_mime := 'application/json';
  ELSE
    l_filename := 'schema-docs.txt';
    l_mime := 'text/plain';
  END IF;

  owa_util.mime_header(l_mime, FALSE);
  htp.p('Content-Disposition: attachment; filename="' || l_filename || '"');
  owa_util.http_header_close;
  htp.prn(:P3_OUTPUT);
  apex_application.stop_apex_engine;
END;
]');
end;
/

prompt --application/pages/page_00004
begin
    wwv_flow_api.create_page(
        p_id                 => 4,
        p_name               => 'About APEX Schema Docs',
        p_alias              => 'ABOUT',
        p_step_title         => 'About APEX Schema Docs',
        p_autocomplete_on_off=> 'OFF',
        p_protection_level   => 'C');

    wwv_flow_api.create_page_plug(
        p_id=>wwv_flow_api.id(140001),
        p_plug_name=>'About this project',
        p_plug_display_sequence=>10,
        p_plug_source_type=>'NATIVE_STATIC_REGION',
        p_plug_source=>q'[<h2>About this project</h2>
<p>APEX Schema Docs is an open-source Oracle APEX application built to solve a real developer problem: giving AI tools the context they need to actually help with your Oracle codebase.</p>
<p><strong>Built by Hassan Raza</strong><br>
Oracle ACE Apprentice | Senior Oracle APEX Developer<br>
oraclewithhassan.com<br>
github.com/hassanraza</p>
<p>Version: 1.0.0<br>
License: MIT<br>
Oracle APEX compatibility: 22.1 and above<br>
Oracle Database compatibility: 19c and above</p>
<h3>Contributing</h3>
<p>This project is open source. Contributions, bug reports, and feature requests are welcome on GitHub.</p>
<h3>Planned V2 features</h3>
<ul>
<li>Views and Triggers</li>
<li>PL/SQL Packages and Procedures</li>
<li>DBMS_Scheduler Jobs</li>
<li>Object relationship diagrams</li>
<li>Direct LLM API integration</li>
</ul>]');
end;
/

begin
    wwv_flow_api.import_end;
    commit;
end;
/

set verify on feedback on define on
prompt ...done
