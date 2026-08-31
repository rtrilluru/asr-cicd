prompt --application/shared_components/logic/build_options
begin
--   Manifest
--     BUILD OPTIONS: 100
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.0'
,p_default_workspace_id=>5000402782755320
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'ASR_OWNER'
);
wwv_flow_imp_shared.create_build_option(
 p_id=>wwv_flow_imp.id(5406633393134252)
,p_build_option_name=>'Commented Out'
,p_static_id=>'commented-out'
,p_build_option_status=>'EXCLUDE'
,p_version_scn=>'SH256:1lQI3DW9n-0ZEGoDXUirkaB0JWCIATVWpJZCTCkODmI'
);
wwv_flow_imp.component_end;
end;
/
