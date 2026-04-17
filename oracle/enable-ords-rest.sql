WHENEVER SQLERROR EXIT SQL.SQLCODE

ALTER SESSION SET CONTAINER=FREEPDB1;

CONNECT legacy_app/legacy_app_password@//localhost/FREEPDB1

BEGIN
  ORDS.ENABLE_SCHEMA(
    p_enabled => TRUE,
    p_schema => 'LEGACY_APP',
    p_url_mapping_type => 'BASE_PATH',
    p_url_mapping_pattern => 'legacy-app',
    p_auto_rest_auth => FALSE
  );
  COMMIT;
END;
/

BEGIN
  ORDS.ENABLE_OBJECT(
    p_enabled => TRUE,
    p_schema => 'LEGACY_APP',
    p_object => 'CUSTOMERS',
    p_object_type => 'TABLE',
    p_object_alias => 'customers',
    p_auto_rest_auth => FALSE
  );

  ORDS.ENABLE_OBJECT(
    p_enabled => TRUE,
    p_schema => 'LEGACY_APP',
    p_object => 'FIELD_SITES',
    p_object_type => 'TABLE',
    p_object_alias => 'field_sites',
    p_auto_rest_auth => FALSE
  );

  ORDS.ENABLE_OBJECT(
    p_enabled => TRUE,
    p_schema => 'LEGACY_APP',
    p_object => 'WORK_ORDERS',
    p_object_type => 'TABLE',
    p_object_alias => 'work_orders',
    p_auto_rest_auth => FALSE
  );

  COMMIT;
END;
/

EXIT;