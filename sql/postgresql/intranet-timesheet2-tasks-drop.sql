-- /package/intranet-timesheet2-tasks/sql/intranet-timesheet2-tasks-drop.sql
--
-- Copyright (c) 2003 - 2009 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


-----------------------------------------------------
-- Drop menus and components defined by the module

select im_menu__del_module('intranet-timesheet2-tasks');
select im_component_plugin__del_module('intranet-timesheet2-tasks');
select im_component_plugin__del_module('intranet-timesheet2-tasks-info');
select im_component_plugin__del_module('intranet-timesheet2-tasks-members');
delete from im_view_columns where column_id >= 91000 and column_id < 91999;
delete from im_views where view_id >= 910 and view_id <= 919;


-- delete all objects
create or replace function inline_0 ()
returns integer as '
DECLARE
        row RECORD;
BEGIN
    for row in
        select task_id
        from im_timesheet_tasks_view
    loop
        im_timesheet_task__delete(row.task_id);
    end loop;
    return 0;
END;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();


-- before remove priviliges remove granted permissions
create or replace function inline_revoke_permission (varchar)
returns integer as '
DECLARE
        p_priv_name     alias for $1;
BEGIN
--     lock table acs_permissions_lock;

     delete from acs_privilege_hierarchy
     where child_privilege = p_priv_name;

     delete from acs_permissions
     where privilege = p_priv_name;

     delete from acs_privileges
     where privilege = p_priv_name;

     return 0;

end;' language 'plpgsql';

select inline_revoke_permission ('add_timesheet_tasks');
select inline_revoke_permission ('view_timesheet_tasks_all');

delete from acs_objects where object_type='im_timesheet_task';
select acs_object_type__drop_type ('im_timesheet_task', 'f');

-- drop the table entirely
drop table im_timesheet_tasks;

