prompt --application/shared_components/navigation/lists/page_navigation
begin
--   Manifest
--     LIST: Page Navigation
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.0'
,p_default_workspace_id=>5000402782755320
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'ASR_OWNER'
);
wwv_flow_imp_shared.create_list(
 p_id=>wwv_flow_imp.id(5433651056134619)
,p_name=>'Page Navigation'
,p_static_id=>'page-navigation'
,p_version_scn=>'SH256:PQ34PoRq3RzpCxWd28V04XXxss0nMqnvGsK7UEmfjzc'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(5434117294134620)
,p_list_item_display_sequence=>20
,p_list_item_link_text=>'Customers'
,p_static_id=>'customers'
,p_list_item_link_target=>'f?p=&APP_ID.:2:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-table'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp.component_end;
end;
/
