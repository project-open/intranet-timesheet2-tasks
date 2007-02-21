-- /packages/intranet-timesheet2-tasks/sql/postgresql/intranet-timesheet2-tasks-create.sql
--
--
-- Copyright (c) 2003-2004 Project/Open
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


-- Specifies how many units of what material are planned for
-- each project / subproject / task (all the same...)
-- Timesheet Tasks are now a subtype of project.
-- That may give us some more trouble "nuking" projects, 
-- but apart from that it's going to simplify the 
-- GanttProject integration, the hierarchical display of
-- projects and tasks in the timesheet entry page etc.
-- The main distinction line between a Task and a Project
-- is that a Project is completely generic, while a Task
-- draws strongly on intranet-cost and the financial 
-- management infrastructure.
--
create table im_timesheet_tasks (
	task_id			integer
				constraint im_timesheet_tasks_pk 
				primary key
				constraint im_timesheet_task_fk 
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
				-- link this task to an invoice in order to
				-- make sure it is invoiced.
	cost_center_id		integer
				constraint im_timesheet_tasks_cost_center_fk
				references im_cost_centers,
	invoice_id		integer
				constraint im_timesheet_tasks_invoice_fk
				references im_invoices,
	priority		integer,
	sort_order		integer
);



-- sum of timesheet hours cached here for reporting
alter table im_projects add reported_hours_cache float;


create or replace view im_timesheet_tasks_view as
select  t.*,
        p.parent_id as project_id,
        p.project_name as task_name,
        p.project_nr as task_nr,
        p.percent_completed,
        p.project_type_id as task_type_id,
        p.project_status_id as task_status_id,
        p.start_date,
        p.end_date,
	p.reported_hours_cache,
	p.reported_hours_cache as reported_units_cache
from
        im_projects p,
        im_timesheet_tasks t
where
        t.task_id = p.project_id
;


-- Defines the relationship between two tasks, based on
-- the data model of GanttProject.
-- <depend id="5" type="2" difference="0" hardness="Strong"/>
create table im_timesheet_task_dependencies (
	task_id_one		integer
				constraint im_timesheet_task_map_one_nn
				not null
				constraint im_timesheet_task_map_one_fk
				references acs_objects,
	task_id_two		integer
				constraint im_timesheet_task_map_two_nn
				not null
				constraint im_timesheet_task_map_two_fk
				references acs_objects,
	dependency_type_id	integer
				constraint im_timesheet_task_map_dep_type_fk
				references im_categories,
	difference		numeric(12,2),
	hardness_type_id	integer
				constraint im_timesheet_task_map_hardness_fk
				references im_categories,

	primary key (task_id_one, task_id_two)
);

create index im_timesheet_tasks_dep_task_one_idx 
on im_timesheet_task_dependencies (task_id_one);

create index im_timesheet_tasks_dep_task_two_idx 
on im_timesheet_task_dependencies (task_id_two);







---------------------------------------------------------
-- Assignment information is stored in im_biz_object_members


alter table im_biz_object_members
add percentage numeric(8,2);



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
	integer, varchar, timestamptz, integer, varchar, integer,
	varchar, varchar, integer, integer, integer, integer, integer, integer, varchar
) returns integer as '
declare
	p_task_id		alias for $1;		-- timesheet task_id default null
	p_object_type		alias for $2;		-- object_type default ''im_timesheet task''
	p_creation_date		alias for $3;		-- creation_date default now()
	p_creation_user		alias for $4;		-- creation_user
	p_creation_ip		alias for $5;		-- creation_ip default null
	p_context_id		alias for $6;		-- context_id default null

	p_task_nr		alias for $7;
	p_task_name		alias for $8;
	p_project_id		alias for $9;
	p_material_id		alias for $10;
	p_cost_center_id	alias for $11;
	p_uom_id		alias for $12;
	p_task_type_id		alias for $13;
	p_task_status_id	alias for $14;
	p_description		alias for $15;

	v_task_id		integer;
	v_company_id		integer;
    begin
	select	p.company_id
	into	v_company_id
	from	im_projects p
	where	p.project_id = p_project_id;

	v_task_id := im_project__new (
		p_task_id,		-- object_id
		p_object_type,		-- object_type
		p_creation_date,	-- creation_date
		p_creation_user,	-- creation_user
		p_creation_ip,		-- creation_ip
		p_context_id,		-- context_id

		p_task_name,		-- project_name
		p_task_nr,		-- project_nr
		p_task_nr,		-- project_path
		p_project_id,		-- parent_id
		v_company_id,		-- company_id
		p_task_type_id,		-- project_type
		p_task_status_id	-- project_status
	);

	update	im_projects
	set	description = p_description
	where	project_id = v_task_id;

	insert into im_timesheet_tasks (
		task_id,
		material_id,
		uom_id
	) values (
		v_task_id,
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
	PERFORM im_project__delete(p_task_id);
	return 0;
end;' language 'plpgsql';


create or replace function im_timesheet_task__name (integer)
returns varchar as '
declare
	p_task_id alias for $1;	-- timesheet_task_id
	v_name	varchar(1000);
begin
	select	project_name
	into	v_name
	from	im_projects
	where	project_id = p_task_id;
	return v_name;
end;' language 'plpgsql';



---------------------------------------------------------
-- Setup the "Tasks" menu entry in "Projects"
--

create or replace function inline_0 ()
returns integer as '
declare
	-- Menu IDs
	v_menu		  integer;
	v_parent_menu		integer;
	-- Groups
	v_employees	     integer;
	v_accounting	    integer;
	v_senman		integer;
	v_customers	     integer;
	v_freelancers	   integer;
	v_proman		integer;
	v_admins		integer;
BEGIN
    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_senman from groups where group_name = ''Senior Managers'';
    select group_id into v_proman from groups where group_name = ''Project Managers'';
    select group_id into v_accounting from groups where group_name = ''Accounting'';
    select group_id into v_employees from groups where group_name = ''Employees'';
    select group_id into v_customers from groups where group_name = ''Customers'';
    select group_id into v_freelancers from groups where group_name = ''Freelancers'';

    select menu_id
    into v_parent_menu
    from im_menus
    where label=''project'';

    v_menu := im_menu__new (
	null,				-- p_menu_id
	''acs_object'',			-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	''intranet-timesheet2-tasks'',	-- package_name
	''project_timesheet_task'',	-- label
	''Tasks'',  			-- name
        ''/intranet-timesheet2-tasks/index?view_name=im_timesheeet_task_list'', -- url
	50,				-- sort_order
	v_parent_menu,			-- parent_menu_id
	''[expr [im_permission $user_id view_timesheet_tasks] && [im_project_has_type [ns_set get $bind_vars project_id] "Consulting Project"]]'' -- p_visible_tcl
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


----------------------------------------------------------
-- Timesheet Task Cateogries
--
-- 9500-9999    Intranet Timesheet Tasks
--
-- 9500-9549	Timesheet Task Type
-- 9550-9599	Intranet Timesheet Task Dependency Hardness Type
-- 9600-9649	Intranet Timesheet Task Status
-- 9650-9699	Intranet Timesheet Task Dependency Type
-- 9700-9999	unassigned


-------------------------------
-- Add a new project type for the Tasks
--
insert into im_categories (CATEGORY_ID, CATEGORY, CATEGORY_TYPE) 
values ('100', 'Task', 'Intranet Project Type');



-------------------------------
-- Timesheet Task Dependency Type
delete from im_categories where category_type = 'Intranet Timesheet Task Dependency Type';

INSERT INTO im_categories (category_id, category, category_type) 
VALUES (9650,'2', 'Intranet Timesheet Task Dependency Type');

INSERT INTO im_categories (category_id, category, category_type) 
VALUES (9652,'Sub-Task', 'Intranet Timesheet Task Dependency Type');



-------------------------------
-- Timesheet Task Dependency Hardness Type
delete from im_categories where category_type = 'Intranet Timesheet Task Dependency Hardness Type';

INSERT INTO im_categories (category_id, category, category_type) 
VALUES (9550,'Hard', 'Intranet Timesheet Task Dependency Hardness Type');






-------------------------------
-- Timesheet Task Types
delete from im_categories where category_type = 'Intranet Timesheet Task Type';

INSERT INTO im_categories VALUES (9500,'Standard',
'','Intranet Timesheet Task Type','category','t','f');

-- reserved until 9599

create or replace view im_timesheet_task_types as 
select 
	category_id as task_type_id, 
	category as task_type
from im_categories 
where category_type = 'Intranet Timesheet Task Type';



-------------------------------
-- Intranet Timesheet Task Status
delete from im_categories where category_type = 'Intranet Timesheet Task Status';

INSERT INTO im_categories VALUES (9600,'Active',
'','Intranet Timesheet Task Status','category','t','f');

INSERT INTO im_categories VALUES (9602,'Inactive',
'','Intranet Timesheet Task Status','category','t','f');

-- reserved until 9699


create or replace view im_timesheet_task_status as 
select 	category_id as task_type_id, 
	category as task_type
from im_categories 
where category_type = 'Intranet Timesheet Task Status';


create or replace view im_timesheet_task_status_active as 
select 	category_id as task_type_id, 
	category as task_type
from im_categories 
where	category_type = 'Intranet Timesheet Task Status'
	and category_id not in (9602);



-- -------------------------------------------------------------------
-- Timesheet TaskList
-- -------------------------------------------------------------------

--
-- Wide View in "Tasks" page, including Description
--
delete from im_view_columns where view_id = 910;
delete from im_views where view_id = 910;
--
insert into im_views (view_id, view_name, visible_for) values (910, 'im_timesheet_task_list', 'view_projects');
--
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91000,910,NULL,'"Task Code"',
'"<a href=/intranet-timesheet2-tasks/new?[export_url_vars project_id task_id return_url]>
$task_nr</a>"','','',0,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91002,910,NULL,'"Task Name"',
'"<a href=/intranet-timesheet2-tasks/new?[export_url_vars project_id task_id return_url]>
$task_name</a>"','','',2,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91004,910,NULL,'Material',
'"<a href=/intranet-material/new?[export_url_vars material_id return_url]>$material_nr</a>"',
'','',4,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91006,910,NULL,'"Cost Center"',
'"<a href=/intranet-cost/cost_centers/new?[export_url_vars cost_center_id return_url]>$cost_center_name</a>"',
'','',6,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91010,910,NULL,'Plan',
'$planned_units','','',10,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91012,910,NULL,'Bill',
'$billable_units','','',12,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91014,910,NULL,'Log',
'"<a href=[export_vars -base $timesheet_report_url { task_id { project_id $project_id } return_url}]>
$reported_hours_cache</a>"','','',14,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91016,910,NULL,'UoM',
'$uom','','',16,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91018,910,NULL,'Status',
'$task_status','','',18,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91020,910,NULL, 'Description', 
'[string_truncate -len 80 " $description"]', '','',20,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91021,910,NULL, 'Done',
'"<input type=textbox size=6 name=percent_completed.$task_id value=$percent_completed>"', 
'','',21,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91022,910,NULL, 
'"[im_gif del "Delete"]"', 
'"<input type=checkbox name=task_id.$task_id>"', '', '', 22, '');





--
-- short view in project homepage
--
delete from im_view_columns where view_id = 911;
delete from im_views where view_id = 911;
--
insert into im_views (view_id, view_name, visible_for) values (911, 
'im_timesheet_task_list_short', 'view_projects');
--
-- insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
-- extra_select, extra_where, sort_order, visible_for) values (91100,911,NULL,'"Project Nr"',
-- '"<a href=/intranet/projects/view?[export_url_vars project_id]>$project_nr</a>"',
-- '','',0,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91101,911,NULL,'"Task Name"',
'"<a href=/intranet-timesheet2-tasks/new?[export_url_vars project_id task_id return_url]>
$task_name</a>"','','',1,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91103,911,NULL,'Material',
'"<a href=/intranet-material/new?[export_url_vars material_id return_url]>$material_nr</a>"',
'','',3,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91104,911,NULL,'Plan',
'$planned_units','','',4,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91106,911,NULL,'Bill',
'$billable_units','','',6,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91108,911,NULL,'Log',
'"<a href=[export_vars -base $timesheet_report_url { task_id { project_id $project_id } return_url}]>
$reported_hours_cache</a>"','','',8,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91109,911,NULL,'"%"',
'$percent_completed_rounded','','',9,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91110,911,NULL,'UoM',
'$uom','','',10,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91112,911,NULL, 
'"[im_gif del "Delete"]"', 
'"<input type=checkbox name=task_id.$task_id>"', '', '', 12, '');




------------------------------------------------------
-- Permissions and Privileges
--

-- add_timesheet_tasks actually is more of an obligation then a privilege...
select acs_privilege__create_privilege(
	'add_timesheet_tasks',
	'Add Timesheet Task',
	'Add Timesheet Task'
);
select acs_privilege__add_child('admin', 'add_timesheet_tasks');

select acs_privilege__create_privilege(
	'view_timesheet_tasks_all',
	'View All Timesheet Tasks',
	'View All Timesheet Tasks'
);
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


select im_component_plugin__del_module('intranet-timesheet2-tasks');
select im_component_plugin__new (
	null,					-- plugin_id
	'acs_object',				-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creattion_ip
	null,					-- context_id

	'Project Timesheet Tasks',		-- plugin_name
	'intranet-timesheet2-tasks',		-- package_name
	'left',					-- location
	'/intranet/projects/view',		-- page_url
	null,					-- view_name
	50,					-- sort_order
	'im_timesheet_task_list_component -restrict_to_project_id $project_id -max_entries_per_page 10 -view_name im_timesheet_task_list_short'
);



insert into im_biz_object_urls (object_type, url_type, url) values (
'im_timesheet_task','view','/intranet-timesheet2-tasks/new?task_id=');
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_timesheet_task','edit','/intranet-timesheet2-tasks/new?form_mode=edit&task_id=');



------------------------------------------------------
-- Permissions and Privileges
--

-- view_timesheet_tasks actually is more of an obligation then a privilege...
select acs_privilege__create_privilege(
	'view_timesheet_tasks',
	'View Timesheet Task',
	'View Timesheet Task'
);
select acs_privilege__add_child('admin', 'view_timesheet_tasks');


select im_priv_create('view_timesheet_tasks', 'Accounting');
select im_priv_create('view_timesheet_tasks', 'Employees');
select im_priv_create('view_timesheet_tasks', 'P/O Admins');
select im_priv_create('view_timesheet_tasks', 'Project Managers');
select im_priv_create('view_timesheet_tasks', 'Sales');
select im_priv_create('view_timesheet_tasks', 'Senior Managers');




