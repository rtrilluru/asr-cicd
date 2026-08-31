prompt --application/shared_components/navigation/lists/navigation_menu
begin
--   Manifest
--     LIST: Navigation Menu
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
 p_id=>wwv_flow_imp.id(5407838482134273)
,p_name=>'Navigation Menu'
,p_static_id=>'navigation-menu'
,p_version_scn=>'SH256:q4xM2XmFpHI92KRm3x5HpHsO8wqlyIfy91MEXjFGljE'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(5421411825134407)
,p_list_item_display_sequence=>20
,p_list_item_link_text=>'Customers'
,p_static_id=>'customers'
,p_list_item_link_target=>'f?p=&APP_ID.:2:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-table'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(5420037242134399)
,p_list_item_display_sequence=>10
,p_list_item_link_text=>'Home'
,p_static_id=>'home'
,p_list_item_link_target=>'f?p=&APP_ID.:1:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-home'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp.component_end;
end;
/
