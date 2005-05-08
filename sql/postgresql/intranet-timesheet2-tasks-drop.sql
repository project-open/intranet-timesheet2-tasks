-- /package/intranet-material/sql/intranet-material-drop.sql
--
-- Copyright (c) 2003-2004 Project/Open
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


-----------------------------------------------------
-- Drop menus and components defined by the module

select im_menu__del_module('intranet-material');
select im_component_plugin__del_module('intranet-material');


delete from im_view_columns where column_id >= 90000 and column_id < 99999;
delete from im_views where view_id >= 900 and view_id <= 999;


-- before remove priviliges remove granted permissions
create or replace function inline_revoke_permission (varchar)
returns integer as '
DECLARE
        p_priv_name     alias for $1;
BEGIN
     lock table acs_permissions_lock;

     delete from acs_permissions
     where privilege = p_priv_name;

     return 0;

end;' language 'plpgsql';

select inline_revoke_permission ('add_material');
select inline_revoke_permission ('view_material');


-- no objects yet...
-- delete from acs_objects where object_type='im_menu';

delete from im_component_plugins where package_name = 'intranet-material';

drop table im_materials;
