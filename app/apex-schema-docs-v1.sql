prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback

begin
  apex_application_install.set_application_id(110);
  apex_application_install.set_application_alias('APEX-SCHEMA-DOCS');
  apex_application_install.set_application_name('APEX Schema Docs');
  apex_application_install.set_schema(sys_context('USERENV','CURRENT_SCHEMA'));
end;
/

prompt --application/create_application
begin
wwv_flow_api.create_flow(
 p_id=>apex_application_install.get_application_id,
 p_display_id=>apex_application_install.get_application_id,
 p_owner=>sys_context('USERENV','CURRENT_SCHEMA'),
 p_name=>'APEX Schema Docs',
 p_alias=>'APEX-SCHEMA-DOCS',
 p_page_view_logging=>'YES',
 p_page_protection_enabled_y_n=>'Y',
 p_checksum_salt=>'APEX_SCHEMA_DOCS_V1',
 p_bookmark_checksum_function=>'SH512',
 p_compatibility_mode=>'22.1',
 p_flow_language=>'en',
 p_flow_language_derived_from=>'FLOW_PRIMARY_LANGUAGE',
 p_authentication=>'PLUGIN',
 p_authentication_id=>wwv_flow_api.id(41595446503615914),
 p_application_tab_set=>0,
 p_logo_type=>'T',
 p_logo_text=>'APEX Schema Docs',
 p_theme_id=>42,
 p_theme_style_by_user_pref=>'N',
 p_theme_style=>'Vita',
 p_navigation_list_position=>'SIDE',
 p_navigation_list_template_id=>wwv_flow_api.id(41574771489615862),
 p_nav_bar_type=>'LIST',
 p_nav_bar_list_id=>wwv_flow_api.id(41594324111615911),
 p_nav_bar_list_template_id=>wwv_flow_api.id(41574585846615862),
 p_nav_bar_template_options=>'#DEFAULT#',
 p_nav_list_position=>'SIDE',
 p_app_version=>'1.0.0');
end;
/

prompt --application/shared_components/navigation/lists/navigation_menu
begin
wwv_flow_api.create_list(
 p_id=>wwv_flow_api.id(50100000000000001),
 p_name=>'Navigation Menu');

wwv_flow_api.create_list_item(
 p_id=>wwv_flow_api.id(50100000000000002),
 p_list_id=>wwv_flow_api.id(50100000000000001),
 p_list_item_display_sequence=>10,
 p_list_item_link_target=>'f?p=&APP_ID.:1:&SESSION.::&DEBUG.::::',
 p_list_item_text=>'Home',
 p_list_item_current_type=>'TARGET_PAGE');
wwv_flow_api.create_list_item(
 p_id=>wwv_flow_api.id(50100000000000003),
 p_list_id=>wwv_flow_api.id(50100000000000001),
 p_list_item_display_sequence=>20,
 p_list_item_link_target=>'f?p=&APP_ID.:2:&SESSION.::&DEBUG.::::',
 p_list_item_text=>'Select Tables',
 p_list_item_current_type=>'TARGET_PAGE');
wwv_flow_api.create_list_item(
 p_id=>wwv_flow_api.id(50100000000000004),
 p_list_id=>wwv_flow_api.id(50100000000000001),
 p_list_item_display_sequence=>30,
 p_list_item_link_target=>'f?p=&APP_ID.:4:&SESSION.::&DEBUG.::::',
 p_list_item_text=>'About',
 p_list_item_current_type=>'TARGET_PAGE');
end;
/

prompt --application/pages/page_00001
begin
wwv_flow_api.create_page(
 p_id=>1,
 p_name=>'APEX Schema Docs',
 p_alias=>'HOME',
 p_step_title=>'APEX Schema Docs',
 p_autocomplete_on_off=>'OFF',
 p_page_template_options=>'#DEFAULT#',
 p_required_patch=>null,
 p_protection_level=>'C');

wwv_flow_api.create_page_plug(
 p_id=>wwv_flow_api.id(50110000000000001),
 p_plug_name=>'Hero',
 p_region_template_options=>'#DEFAULT#',
 p_component_template_options=>'#DEFAULT#',
 p_plug_template=>wwv_flow_api.id(41539810751615818),
 p_plug_display_sequence=>10,
 p_plug_source=>q'[<div style="text-align:center;padding:2rem;">
<h1>APEX Schema Docs</h1>
<h3>Generate LLM-ready documentation from your Oracle schema in seconds.</h3>
<p>Stop copying and pasting DDL into ChatGPT one table at a time. APEX Schema Docs reads your Oracle schema and generates clean, structured documentation in Markdown, JSON, and Plain Text — ready to drop directly into any AI model as context.</p>
<div style="display:flex;gap:1rem;justify-content:center;">
<div class="t-Card"><h4>Markdown</h4><p>Perfect for Claude and ChatGPT</p></div>
<div class="t-Card"><h4>JSON</h4><p>Ready for API-based LLM calls</p></div>
<div class="t-Card"><h4>Plain Text</h4><p>Compact token-efficient summaries</p></div>
</div>
<a class="t-Button t-Button--hot" href="f?p=&APP_ID.:2:&SESSION.::&DEBUG.::::">Generate Documentation</a>
<p style="margin-top:2rem;">Open source under MIT License. Built by Hassan Raza, Oracle ACE Apprentice.</p>
</div>]',
 p_plug_source_type=>'NATIVE_STATIC_REGION');
end;
/

prompt --application/pages/page_00002
begin
wwv_flow_api.create_page(
 p_id=>2,
 p_name=>'Select Tables',
 p_alias=>'SELECT-TABLES',
 p_step_title=>'Select Tables',
 p_autocomplete_on_off=>'OFF',
 p_page_template_options=>'#DEFAULT#',
 p_protection_level=>'C');

wwv_flow_api.create_page_plug(
 p_id=>wwv_flow_api.id(50210000000000001),
 p_plug_name=>'Filter Bar',
 p_plug_template=>wwv_flow_api.id(41539810751615818),
 p_plug_display_sequence=>10,
 p_plug_source_type=>'NATIVE_STATIC_REGION');

wwv_flow_api.create_page_item(
 p_id=>wwv_flow_api.id(50210000000000002),
 p_name=>'P2_SCHEMA',
 p_item_sequence=>10,
 p_item_plug_id=>wwv_flow_api.id(50210000000000001),
 p_prompt=>'Schema',
 p_source=>'SYS_CONTEXT(''USERENV'',''CURRENT_SCHEMA'')',
 p_source_type=>'QUERY',
 p_display_as=>'NATIVE_DISPLAY_ONLY');

wwv_flow_api.create_page_item(
 p_id=>wwv_flow_api.id(50210000000000003),
 p_name=>'P2_SEARCH_TABLES',
 p_item_sequence=>20,
 p_item_plug_id=>wwv_flow_api.id(50210000000000001),
 p_prompt=>'Search tables',
 p_display_as=>'NATIVE_TEXT_FIELD');

wwv_flow_api.create_page_plug(
 p_id=>wwv_flow_api.id(50210000000000004),
 p_plug_name=>'Table Selection',
 p_plug_template=>wwv_flow_api.id(41539810751615818),
 p_plug_display_sequence=>20,
 p_query_type=>'SQL',
 p_plug_source=>q'[select apex_item.checkbox2(1,table_name,'checked="checked" class="tblchk"') as select_table,
       table_name,
       num_rows as estimated_rows,
       last_analyzed,
       case when comments is not null then substr(comments,1,80) else '-' end as description
  from (
    select ut.table_name, ut.num_rows, ut.last_analyzed, utc.comments
      from user_tables ut
      left join user_tab_comments utc on utc.table_name = ut.table_name
  )
 order by table_name]',
 p_plug_source_type=>'NATIVE_IR');

wwv_flow_api.create_page_plug(
 p_id=>wwv_flow_api.id(50210000000000005),
 p_plug_name=>'Output Format Selection',
 p_plug_template=>wwv_flow_api.id(41539810751615818),
 p_plug_display_sequence=>30,
 p_plug_source_type=>'NATIVE_STATIC_REGION');

wwv_flow_api.create_page_item(
 p_id=>wwv_flow_api.id(50210000000000006),
 p_name=>'P2_OUTPUT_FORMAT',
 p_item_sequence=>10,
 p_item_plug_id=>wwv_flow_api.id(50210000000000005),
 p_prompt=>'Output Format',
 p_display_as=>'NATIVE_RADIOGROUP',
 p_lov=>'STATIC2:Markdown;MARKDOWN,JSON;JSON,Plain Text;PLAIN_TEXT',
 p_begin_on_new_line=>'Y',
 p_item_default=>'MARKDOWN');

wwv_flow_api.create_page_item(
 p_id=>wwv_flow_api.id(50210000000000007),
 p_name=>'P2_SELECTED_TABLES',
 p_item_sequence=>20,
 p_item_plug_id=>wwv_flow_api.id(50210000000000005),
 p_display_as=>'NATIVE_HIDDEN');

wwv_flow_api.create_page_item(
 p_id=>wwv_flow_api.id(50210000000000008),
 p_name=>'P2_TOKEN_ESTIMATE',
 p_item_sequence=>30,
 p_item_plug_id=>wwv_flow_api.id(50210000000000005),
 p_prompt=>'Estimated Token Count',
 p_display_as=>'NATIVE_DISPLAY_ONLY');

wwv_flow_api.create_page_button(
 p_id=>wwv_flow_api.id(50210000000000009),
 p_button_sequence=>40,
 p_button_plug_id=>wwv_flow_api.id(50210000000000005),
 p_button_name=>'GENERATE_DOCUMENTATION',
 p_button_action=>'SUBMIT',
 p_button_template_id=>wwv_flow_api.id(41574002116615862),
 p_button_image_alt=>'Generate Documentation');

wwv_flow_api.create_page_button(
 p_id=>wwv_flow_api.id(50210000000000010),
 p_button_sequence=>50,
 p_button_plug_id=>wwv_flow_api.id(50210000000000005),
 p_button_name=>'BACK',
 p_button_action=>'REDIRECT_PAGE',
 p_button_redirect_url=>'f?p=&APP_ID.:1:&SESSION.::&DEBUG.::::',
 p_button_template_id=>wwv_flow_api.id(41574002116615862),
 p_button_image_alt=>'Back');

wwv_flow_api.create_page_da_event(
 p_id=>wwv_flow_api.id(50210000000000011),
 p_name=>'Collect Selected Tables',
 p_event_sequence=>10,
 p_triggering_element_type=>'BUTTON',
 p_triggering_button_id=>wwv_flow_api.id(50210000000000009),
 p_bind_type=>'bind',
 p_bind_event_type=>'click');

wwv_flow_api.create_page_da_action(
 p_id=>wwv_flow_api.id(50210000000000012),
 p_event_id=>wwv_flow_api.id(50210000000000011),
 p_action_sequence=>10,
 p_action=>'NATIVE_JAVASCRIPT_CODE',
 p_attribute_01=>q'[var vals=[];
document.querySelectorAll('.tblchk:checked').forEach(function(el){vals.push(el.value);});
apex.item('P2_SELECTED_TABLES').setValue(vals.join(','));]');

wwv_flow_api.create_page_da_event(
 p_id=>wwv_flow_api.id(50210000000000013),
 p_name=>'Search Filter',
 p_event_sequence=>20,
 p_triggering_element_type=>'ITEM',
 p_triggering_element=>'P2_SEARCH_TABLES',
 p_bind_type=>'bind',
 p_bind_event_type=>'keyup');

wwv_flow_api.create_page_da_action(
 p_id=>wwv_flow_api.id(50210000000000014),
 p_event_id=>wwv_flow_api.id(50210000000000013),
 p_action_sequence=>10,
 p_action=>'NATIVE_JAVASCRIPT_CODE',
 p_attribute_01=>q'[var v=this.triggeringElement.value.toUpperCase();
document.querySelectorAll('tr').forEach(function(r){
  if (r.innerText && r.innerText.toUpperCase().indexOf(v) > -1) { r.style.display=''; }
  else if(r.querySelector('.tblchk')) { r.style.display='none'; }
});]');

wwv_flow_api.create_page_process(
 p_id=>wwv_flow_api.id(50210000000000015),
 p_process_sequence=>10,
 p_process_point=>'AFTER_SUBMIT',
 p_process_type=>'NATIVE_SESSION_STATE',
 p_process_name=>'Branch to Output',
 p_process_sql_clob=>'NULL;');

wwv_flow_api.create_page_branch(
 p_id=>wwv_flow_api.id(50210000000000016),
 p_branch_action=>'f?p=&APP_ID.:3:&SESSION.::&DEBUG.::P2_SELECTED_TABLES,P2_OUTPUT_FORMAT:&P2_SELECTED_TABLES.,&P2_OUTPUT_FORMAT.',
 p_branch_point=>'AFTER_PROCESSING',
 p_branch_type=>'REDIRECT_URL',
 p_branch_when_button_id=>wwv_flow_api.id(50210000000000009));
end;
/

prompt --application/pages/page_00003
begin
wwv_flow_api.create_page(
 p_id=>3,
 p_name=>'Generated Documentation',
 p_alias=>'OUTPUT',
 p_step_title=>'Generated Documentation',
 p_autocomplete_on_off=>'OFF',
 p_page_template_options=>'#DEFAULT#',
 p_protection_level=>'C');

wwv_flow_api.create_page_plug(
 p_id=>wwv_flow_api.id(50310000000000001),
 p_plug_name=>'Output Controls',
 p_plug_template=>wwv_flow_api.id(41539810751615818),
 p_plug_display_sequence=>10,
 p_plug_source_type=>'NATIVE_STATIC_REGION');

wwv_flow_api.create_page_item(p_id=>wwv_flow_api.id(50310000000000002),p_name=>'P3_FORMAT',p_item_sequence=>10,p_item_plug_id=>wwv_flow_api.id(50310000000000001),p_prompt=>'Format',p_display_as=>'NATIVE_DISPLAY_ONLY',p_source=>'P2_OUTPUT_FORMAT',p_source_type=>'ITEM');
wwv_flow_api.create_page_item(p_id=>wwv_flow_api.id(50310000000000003),p_name=>'P3_TABLE_COUNT',p_item_sequence=>20,p_item_plug_id=>wwv_flow_api.id(50310000000000001),p_prompt=>'Tables',p_display_as=>'NATIVE_DISPLAY_ONLY');
wwv_flow_api.create_page_item(p_id=>wwv_flow_api.id(50310000000000004),p_name=>'P3_TOKEN_ESTIMATE',p_item_sequence=>30,p_item_plug_id=>wwv_flow_api.id(50310000000000001),p_prompt=>'Estimated Tokens',p_display_as=>'NATIVE_DISPLAY_ONLY');

wwv_flow_api.create_page_button(p_id=>wwv_flow_api.id(50310000000000005),p_button_sequence=>40,p_button_plug_id=>wwv_flow_api.id(50310000000000001),p_button_name=>'COPY_TO_CLIPBOARD',p_button_action=>'DEFINED_BY_DA',p_button_image_alt=>'Copy to Clipboard');
wwv_flow_api.create_page_button(p_id=>wwv_flow_api.id(50310000000000006),p_button_sequence=>50,p_button_plug_id=>wwv_flow_api.id(50310000000000001),p_button_name=>'DOWNLOAD_FILE',p_button_action=>'SUBMIT',p_button_image_alt=>'Download File');
wwv_flow_api.create_page_button(p_id=>wwv_flow_api.id(50310000000000007),p_button_sequence=>60,p_button_plug_id=>wwv_flow_api.id(50310000000000001),p_button_name=>'REGENERATE',p_button_action=>'REDIRECT_PAGE',p_button_redirect_url=>'f?p=&APP_ID.:2:&SESSION.::&DEBUG.::::',p_button_image_alt=>'Regenerate');
wwv_flow_api.create_page_button(p_id=>wwv_flow_api.id(50310000000000008),p_button_sequence=>70,p_button_plug_id=>wwv_flow_api.id(50310000000000001),p_button_name=>'HOME',p_button_action=>'REDIRECT_PAGE',p_button_redirect_url=>'f?p=&APP_ID.:1:&SESSION.::&DEBUG.::::',p_button_image_alt=>'Home');

wwv_flow_api.create_page_plug(
 p_id=>wwv_flow_api.id(50310000000000009),
 p_plug_name=>'Output Display',
 p_plug_template=>wwv_flow_api.id(41539810751615818),
 p_plug_display_sequence=>20,
 p_plug_source_type=>'NATIVE_STATIC_REGION');

wwv_flow_api.create_page_item(
 p_id=>wwv_flow_api.id(50310000000000010),
 p_name=>'P3_OUTPUT',
 p_item_sequence=>10,
 p_item_plug_id=>wwv_flow_api.id(50310000000000009),
 p_prompt=>'Output',
 p_display_as=>'NATIVE_TEXTAREA',
 p_cHeight=>30,
 p_field_template=>wwv_flow_api.id(41572700523615858),
 p_item_css_classes=>'u-code-font');

wwv_flow_api.create_page_da_event(
 p_id=>wwv_flow_api.id(50310000000000011),
 p_name=>'Copy to Clipboard',
 p_event_sequence=>10,
 p_triggering_element_type=>'BUTTON',
 p_triggering_button_id=>wwv_flow_api.id(50310000000000005),
 p_bind_type=>'bind',
 p_bind_event_type=>'click');

wwv_flow_api.create_page_da_action(
 p_id=>wwv_flow_api.id(50310000000000012),
 p_event_id=>wwv_flow_api.id(50310000000000011),
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
 p_id=>wwv_flow_api.id(50310000000000013),
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

  SELECT COUNT(*)
    INTO :P3_TABLE_COUNT
    FROM TABLE(apex_string.split(:P2_SELECTED_TABLES, ','));
EXCEPTION
  WHEN OTHERS THEN
    :P3_OUTPUT := 'Error generating documentation: ' || SQLERRM;
END;
]');

wwv_flow_api.create_page_process(
 p_id=>wwv_flow_api.id(50310000000000014),
 p_process_sequence=>20,
 p_process_point=>'AFTER_SUBMIT',
 p_process_type=>'NATIVE_PLSQL',
 p_process_name=>'Download Output',
 p_process_when_button_id=>wwv_flow_api.id(50310000000000006),
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
  wpg_docload.download_file(:P3_OUTPUT);
  apex_application.stop_apex_engine;
END;
]');
end;
/

prompt --application/pages/page_00004
begin
wwv_flow_api.create_page(
 p_id=>4,
 p_name=>'About APEX Schema Docs',
 p_alias=>'ABOUT',
 p_step_title=>'About APEX Schema Docs',
 p_autocomplete_on_off=>'OFF',
 p_page_template_options=>'#DEFAULT#',
 p_protection_level=>'C');

wwv_flow_api.create_page_plug(
 p_id=>wwv_flow_api.id(50410000000000001),
 p_plug_name=>'About this project',
 p_plug_template=>wwv_flow_api.id(41539810751615818),
 p_plug_display_sequence=>10,
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
</ul>]',
 p_plug_source_type=>'NATIVE_STATIC_REGION');
end;
/

begin
  commit;
end;
/
