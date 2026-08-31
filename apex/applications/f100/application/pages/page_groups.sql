prompt --application/pages/page_groups
begin
--   Manifest
--     PAGE GROUPS: 100
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.0'
,p_default_workspace_id=>5000402782755320
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'ASR_OWNER'
);
wwv_flow_imp_page.create_page_group(
 p_id=>wwv_flow_imp.id(5412504601134357)
,p_group_name=>'Administration'
,p_static_id=>'administration'
);
wwv_flow_imp.component_end;
end;
/
