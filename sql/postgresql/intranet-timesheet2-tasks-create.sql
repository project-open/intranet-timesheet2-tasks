-- /packages/intranet-timesheet2-tasks/sql/postgresql/intranet-timesheet2-tasks-create.sql
--
--
-- Copyright (c) 2003-2004 Project/Open
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


-- specified how many units of what material are planned for
-- each project / subproject / task (all the same...)
--
create table im_timesheet_tasks (
	task_id			integer
				constraint im_timesheet_tasks_pk 
				primary key
				constraint im_timesheet_task_fk 
				references acs_objects,
	task_name		varchar(400),
	project_id		integer 
				constraint im_timesheet_project_nn
				not null 
				constraint im_timesheet_tasks_project_fk
				references im_projects,
	material_id		integer 
				constraint im_timesheet_material_nn
				not null
				constraint im_timesheet_tasks_material_fk
				references im_materials,
	uom_id			integer
				constraint im_timesheet_uom_nn
				not null
				constraint im_timesheet_tasks_uom_fk
				references im_categories,
	planned_units		float,
	billable_units		float,
				-- sum of timesheet hours cached here for reporting
	reported_units_cache	float,
	description		varchar(4000)
);


---------------------------------------------------------
-- Timesheet Task Object Type

select acs_object_type__create_type (
	'im_timesheet_task',		-- object_type
	'Timesheet Task',		-- pretty_name
	'Timesheet Tasks',		-- pretty_plural
	'acs_object',			-- supertype
	'im_timesheet_tasks',		-- table_name
	'task_id',			-- id_column
	'intranet-timesheet2-tasks',	-- package_name
	'f',				-- abstract_p
	null,				-- type_extension_table
	'im_timesheet_task.name'	-- name_method
);


create or replace function im_timesheet_task__new (
	integer,
	varchar,
	timestamptz,
	integer,
	varchar,
	integer,
	
	varchar,
	integer,
	integer,
	integer,
	varchar
    ) 
returns integer as '
declare
	p_task_id		alias for $1;		-- timesheet task_id default null
	p_object_type		alias for $2;		-- object_type default ''im_timesheet task''
	p_creation_date		alias for $3;		-- creation_date default now()
	p_creation_user		alias for $4;		-- creation_user
	p_creation_ip		alias for $5;		-- creation_ip default null
	p_context_id		alias for $6;		-- context_id default null

	p_task_name		alias for $7;
	p_project_id		alias for $8;
	p_material_id		alias for $9;	
	p_uom_id		alias for $10;
	p_description		alias for $11;

	v_timesheet task_id		integer;
    begin
 	v_task_id := acs_object__new (
                p_task_id,		  -- object_id
                p_object_type,            -- object_type
                p_creation_date,          -- creation_date
                p_creation_user,          -- creation_user
                p_creation_ip,            -- creation_ip
                p_context_id,             -- context_id
                ''t''                     -- security_inherit_p
        );

	insert into im_timesheet_tasks (
		task_id,
		task_name,
		project_id,
		material_id,
		uom_id
	) values (
		v_task_id,
		p_task_name,
		p_project_id,
		p_material_id,
		p_uom_id
	);

	return v_task_id;
end;' language 'plpgsql';



-- Delete a single timesheet_task (if we know its ID...)
create or replace function im_timesheet_task__delete (integer)
returns integer as '
declare
	p_task_id alias for $1;	-- timesheet_task_id
begin
	-- Erase the timesheet_task
	delete from 	im_timesheet_tasks
	where		task_id = p_task_id;

        -- Erase the object
        PERFORM acs_object__delete(p_task_id);
        return 0;
end;' language 'plpgsql';


create or replace function im_timesheet_task__name (integer)
returns varchar as '
declare
	p_task_id alias for $1;	-- timesheet_task_id
	v_name	varchar(40);
begin
	select	task_name
	into	v_name
	from	im_timesheet_tasks
	where	task_id = p_task_id;
	return v_name;
end;' language 'plpgsql';



---------------------------------------------------------
-- Setup the "Materials" menu entry in "Projects"
--

create or replace function inline_0 ()
returns integer as '
declare
        -- Menu IDs
        v_menu                  integer;
	v_parent_menu		integer;

        -- Groups
        v_employees             integer;
        v_accounting            integer;
        v_senman                integer;
        v_companies             integer;
        v_freelancers           integer;
        v_proman                integer;
        v_admins                integer;
BEGIN

    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_senman from groups where group_name = ''Senior Managers'';
    select group_id into v_proman from groups where group_name = ''Project Managers'';
    select group_id into v_accounting from groups where group_name = ''Accounting'';
    select group_id into v_employees from groups where group_name = ''Employees'';
    select group_id into v_companies from groups where group_name = ''Customers'';
    select group_id into v_freelancers from groups where group_name = ''Freelancers'';

    select menu_id
    into v_parent_menu
    from im_menus
    where label=''project'';

    v_menu := im_menu__new (
        null,                   -- p_menu_id
        ''acs_object'',         -- object_type
        now(),                  -- creation_date
        null,                   -- creation_user
        null,                   -- creation_ip
        null,                   -- context_id
        ''intranet-timesheet2-tasks'',	-- package_name
        ''timesheet_task'',   		-- label
        ''Tasks'',  		-- name
        ''/intranet-timesheet2-tasks/'', -- url
        85,                     -- sort_order
        v_parent_menu,           -- parent_menu_id
        null                    -- p_visible_tcl
    );

    PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_proman, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_employees, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_customers, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_freelancers, ''read'');

    return 0;
end;' language 'plpgsql';

select inline_0 ();
drop function inline_0 ();




-- Timesheet TaskList
--

-- insert the view
insert into im_views (view_id, view_name, visible_for) values (910, 'im_timesheet_task_list', 'view_projects');

delete from im_view_columns where column_id >= 91000 and column_id < 91099;

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91000,910,NULL,'Nr',
'"<a href=/intranet-timesheet_task/new?[export_url_vars timesheet_task_id return_url]>$timesheet_task_nr</a>"',
'','',0,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91002,910,NULL,'Name',
'"<a href=/intranet-timesheet_task/new?[export_url_vars timesheet_task_id return_url]>$timesheet_task_name</a>"',
'','',2,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91004,910,NULL,'Type',
'$timesheet_task_type','','',4,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91006,910,NULL,'Status',
'$timesheet_task_status','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91008,910,NULL,'UoM',
'$uom','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91010,910,NULL,
'Description', '$description', '','',10,'');




------------------------------------------------------
-- Permissions and Privileges
--

-- add_timesheet_tasks actually is more of an obligation then a privilege...
select acs_privilege__create_privilege('add_timesheet_tasks','Add Timesheet Task','Add Timesheet Task');
select acs_privilege__add_child('admin', 'add_timesheet_tasks');


-- Everybody is able to see his own hours, so view_hours doesn't
-- make much sense...
select acs_privilege__create_privilege('view_timesheet_tasks_all','View All Timesheet Tasks','View All Timesheet Tasks');
select acs_privilege__add_child('admin', 'view_timesheet_tasks_all');


select im_priv_create('add_timesheet_tasks', 'Accounting');
select im_priv_create('add_timesheet_tasks', 'Employees');
select im_priv_create('add_timesheet_tasks', 'P/O Admins');
select im_priv_create('add_timesheet_tasks', 'Project Managers');
select im_priv_create('add_timesheet_tasks', 'Sales');
select im_priv_create('add_timesheet_tasks', 'Senior Managers');

select im_priv_create('view_timesheet_tasks_all', 'Accounting');
select im_priv_create('view_timesheet_tasks_all', 'P/O Admins');
select im_priv_create('view_timesheet_tasks_all', 'Project Managers');
select im_priv_create('view_timesheet_tasks_all', 'Sales');
select im_priv_create('view_timesheet_tasks_all', 'Senior Managers');


select im_component_plugin__new (
	null,					-- plugin_id
	'acs_object',				-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creattion_ip
	null,					-- context_id

        'Project Timesheet Tasks',		-- plugin_name
        'intranet-timesheet2-tasks',		-- package_name
        'right',				-- location
	'/intranet/projects/view',		-- page_url
        null,					-- view_name
        50,					-- sort_order
        'im_table_with_title "[_ intranet-timesheet2.Timesheet_Tasks]" [im_timesheet_tasks_component $project_id ]'
    );
