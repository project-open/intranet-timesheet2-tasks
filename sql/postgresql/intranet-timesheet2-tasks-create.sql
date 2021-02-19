-- /packages/intranet-timesheet2-tasks/sql/postgresql/intranet-timesheet2-tasks-create.sql
--
--
-- Copyright (c) 2003-2008 ]project-open[
--
-- All rights reserved. Please check
-- https://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


-- Specifies how many units of what material are planned for
-- each project / subproject / task (all the same...)
-- Gantt tasks are now a subtype of project.
-- That may give us some more trouble "nuking" projects, 
-- but apart from that it's going to simplify the 
-- GanttProject integration, the hierarchical display of
-- projects and tasks in the timesheet entry page etc.
-- The main distinction line between a Task and a Project
-- is that a Project is completely generic, while a Task
-- draws strongly on intranet-cost and the financial 
-- management infrastructure.
--

---------------------------------------------------------
-- Gantt Task Object Type

select acs_object_type__create_type (
	'im_timesheet_task',		-- object_type
	'Gantt Task',			-- pretty_name
	'Gantt Tasks',			-- pretty_plural
	'im_project',			-- supertype
	'im_timesheet_tasks',		-- table_name
	'task_id',			-- id_column
	'intranet-timesheet2-tasks',	-- package_name
	'f',				-- abstract_p
	null,				-- type_extension_table
	'im_timesheet_task.name'	-- name_method
);

insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_timesheet_task', 'im_timesheet_tasks', 'task_id');
insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_timesheet_task', 'im_projects', 'project_id');


update acs_object_types set
	status_type_table = 'im_projects',
	status_column = 'project_status_id',
	type_column = 'project_type_id'
where object_type = 'im_timesheet_task';

insert into im_biz_object_role_map values ('im_timesheet_task',85,1300);

insert into im_biz_object_urls (object_type, url_type, url) values (
'im_timesheet_task','view','/intranet-timesheet2-tasks/new?task_id=');
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_timesheet_task','edit','/intranet-timesheet2-tasks/new?form_mode=edit&task_id=');


create table im_timesheet_tasks (
				-- Primary object id, same as project_id
	task_id			integer
				constraint im_timesheet_tasks_pk 
				primary key
				constraint im_timesheet_task_fk 
				references im_projects,
				-- Service type (senior development hour, consulting day, ...)
	material_id		integer 
				constraint im_timesheet_material_nn
				not null
				constraint im_timesheet_tasks_material_fk
				references im_materials,
				-- Unit of measure (hour, day)
	uom_id			integer
				constraint im_timesheet_uom_nn
				not null
				constraint im_timesheet_tasks_uom_fk
				references im_categories,
				-- Work (in UoM) as planned
	planned_units		float,
				-- Work (in UoM) as billable to a customer
	billable_units		float,
				-- Tasks may be associated to departments
	cost_center_id		integer
				constraint im_timesheet_tasks_cost_center_fk
				references im_cost_centers,
				-- Has this task already been invoiced?
	invoice_id		integer
				constraint im_timesheet_tasks_invoice_fk
				references im_invoices,
				-- Priority for scheduling
	priority		integer,
				-- Ordering when imported from GanttProject or MS-Project
	sort_order		integer,
				-- As soon as possible, as late as possible, must start on, ...
	scheduling_constraint_id integer
				constraint im_timesheet_tasks_scheduling_type_fk
				references im_categories,
	scheduling_constraint_date timestamptz,
				-- Fixed units, fixed duration or fixed work
	effort_driven_type_id	integer
				constraint im_timesheet_tasks_effort_driven_type_fk
				references im_categories,
	deadline_date		timestamptz,
	effort_driven_p		char(1) default('t')
				constraint im_timesheet_tasks_effort_driven_ck
				check (effort_driven_p in ('t','f'))
);


SELECT im_dynfield_attribute_new (
                'im_timesheet_task',                    -- p_object_type
                'milestone_p',                          -- p_column_name
                'Milestone',                            -- p_pretty_name
                'checkbox',                             -- p_widget_name
                'boolean',                              -- p_datatype
                'f',                                    -- p_required_p
                 0,                                     -- p_pos_y
                'f',                                    -- p_also_hard_coded_p
                'im_projects'                           -- p_table_name
);


create or replace view im_timesheet_tasks_view as
select	t.*,
	p.parent_id as project_id,
	p.project_name as task_name,
	p.project_nr as task_nr,
	p.percent_completed,
	p.project_type_id as task_type_id,
	p.project_status_id as task_status_id,
	p.start_date,
	p.end_date,
	p.reported_hours_cache,
	p.reported_days_cache,
	p.reported_hours_cache as reported_units_cache
from
	im_projects p,
	im_timesheet_tasks t
where
	t.task_id = p.project_id
;


create or replace function inline_0 ()
returns integer as '
declare
	v_count		integer;
begin
	select count(*) into v_count from user_tab_columns
	where lower(table_name) = ''im_biz_object_members'' and lower(column_name) = ''percentage'';
	IF 0 != v_count THEN return 0; END IF;

	ALTER TABLE im_biz_object_members ADD column percentage numeric(8,2);
	ALTER TABLE im_biz_object_members ALTER column percentage set default 100;

	return 1;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




create or replace function im_timesheet_task__new (
	integer, varchar, timestamptz, integer, varchar, integer,
	varchar, varchar, integer, integer, integer, integer, integer, integer, varchar
) returns integer as '
declare
	p_task_id		alias for $1;		-- timesheet_task_id default null
	p_object_type		alias for $2;		-- object_type default ''im_timesheet_task''
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
	select	p.company_id into v_company_id from im_projects p
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
		uom_id,
		cost_center_id
	) values (
		v_task_id,
		p_material_id,
		p_uom_id,
		p_cost_center_id
	);

	return v_task_id;
end;' language 'plpgsql';



-- Delete a single timesheet_task (if we know its ID...)
create or replace function im_timesheet_task__delete (integer)
returns integer as '
declare
	p_task_id		alias for $1;	-- timesheet_task_id
	row			RECORD;
begin
	-- Start deleting with im_gantt_projects
	delete from	im_gantt_projects
	where		project_id = p_task_id;

	-- Delete dependencies between tasks
	delete from	im_timesheet_task_dependencies
	where		(task_id_one = p_task_id OR task_id_two = p_task_id);

	-- Delete object_context_index
	delete from	acs_object_context_index
	where		(object_id = p_task_id OR ancestor_id = p_task_id);

	-- Delete relatinships
	FOR row IN
		select	*
		from	acs_rels
		where	(object_id_one = p_task_id OR object_id_two = p_task_id)
	LOOP
		PERFORM acs_rel__delete(row.rel_id);
	END LOOP;

	-- Erase the timesheet_task
	delete from im_timesheet_tasks
	where task_id = p_task_id;

	-- Erase the object
	PERFORM im_project__delete(p_task_id);
	return 0;
end;' language 'plpgsql';


create or replace function im_timesheet_task__name (integer)
returns varchar as '
declare
	p_task_id	alias for $1;	-- timesheet_task_id
	v_name		varchar;
begin
	select	project_name into v_name from im_projects
	where	project_id = p_task_id;

	return v_name;
end;' language 'plpgsql';




---------------------------------------------------------
-- Inter-Task Dependencies
--

-- Create a fake object type, because im_timesheet_task_dependency does not reference acs_objects.
select acs_object_type__create_type (
	'im_timesheet_task_dependency',			-- object_type
	'Gantt Task Dependency',			-- pretty_name
	'Gantt Task Dependencies',			-- pretty_plural
	'acs_object',					-- supertype
	'im_timesheet_task_dependencies',		-- table_name
	'dependency_id',				-- id_column
	'intranet-timesheet2-task-dep',			-- package_name
	'f',						-- abstract_p
	null,						-- type_extension_table
	'im_timesheet_task_dependency__name'		-- name_method
);

update acs_object_types set
	status_type_table = 'im_timesheet_task_dependencies',
	status_column = 'dependency_status_id',
	type_column = 'dependency_type_id'
where object_type = 'im_timesheet_task_dependency';


-- Defines the relationship between two tasks, based on
-- the data model of GanttProject.
-- <depend id="5" type="2" difference="0" hardness="Strong"/>
create sequence im_timesheet_task_dependency_seq start 1;
create table im_timesheet_task_dependencies (
	dependency_id		integer
				default nextval('im_timesheet_task_dependency_seq')
				constraint im_timesheet_task_dependency_pk
				primary key,
	task_id_one		integer
				constraint im_timesheet_task_map_one_nn
				not null
				constraint im_timesheet_task_map_one_fk
				references im_projects,
	task_id_two		integer
				constraint im_timesheet_task_map_two_nn
				not null
				constraint im_timesheet_task_map_two_fk
				references im_projects,
				-- status currently not used
	dependency_status_id	integer default 9740
				constraint im_timesheet_task_map_dep_status_nn
				not null
				constraint im_timesheet_task_map_dep_status_fk
				references im_categories,
	dependency_type_id	integer
				constraint im_timesheet_task_map_dep_type_nn
				not null
				constraint im_timesheet_task_map_dep_type_fk
				references im_categories,
	difference		numeric(12,2) default 0.0,
        difference_format_id    integer
                                constraint im_timesheet_task_dep_diff_format_fk
                                references im_categories,
	hardness_type_id	integer
				constraint im_timesheet_task_map_hardness_fk
				references im_categories
);

create unique index im_timesheet_task_dependency_un
on im_timesheet_task_dependencies (task_id_one, task_id_two);

create index im_timesheet_tasks_dep_task_one_idx 
on im_timesheet_task_dependencies (task_id_one);

create index im_timesheet_tasks_dep_task_two_idx 
on im_timesheet_task_dependencies (task_id_two);




-- Allocate a user to a specific task 
-- with a certain percentage of his time
--
create table im_timesheet_task_allocations (
	task_id			integer
				constraint im_timesheet_task_alloc_task_nn
				not null
				constraint im_timesheet_task_alloc_task_fk
				references acs_objects,
        user_id			integer
				constraint im_timesheet_task_alloc_user_fk
				references users,
	role_id			integer
				constraint im_timesheet_task_alloc_role_fk
				references im_categories,
	percentage		numeric(6,2),
--				-- No check anymore - might want to alloc 120%...
--				constraint im_timesheet_task_alloc_perc_ck
--				check (percentage >= 0 and percentage <= 200),
	task_manager_p		char(1)
				constraint im_timesheet_task_resp_ck
				check (task_manager_p in (''t'',''f'')),
	note			varchar(1000),

	primary key (task_id, user_id)
);

create index im_timesheet_tasks_dep_alloc_task_idx 
on im_timesheet_task_allocations (task_id);

create index im_timesheet_tasks_dep_alloc_user_idx 
on im_timesheet_task_allocations (user_id);




---------------------------------------------------------
-- Setup the "Tasks" menu entry in "Projects"
--

create or replace function inline_0 ()
returns integer as '
declare
	-- Menu IDs
	v_menu		integer;
	v_parent_menu		integer;
	-- Groups
	v_employees		integer;
	v_accounting		integer;
	v_senman		integer;
	v_customers		integer;
	v_freelancers	integer;
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

	select menu_id into v_parent_menu from im_menus
	where label=''project'';

	v_menu := im_menu__new (
		null,				-- p_menu_id
		''im_menu'',			-- object_type
		now(),				-- creation_date
		null,				-- creation_user
		null,				-- creation_ip
		null,				-- context_id
		''intranet-timesheet2-tasks'',	-- package_name
		''project_timesheet_task'',	-- label
		''Tasks'',				-- name
		''/intranet-timesheet2-tasks/index?view_name=im_timesheet_task_list'', -- url
		50,				-- sort_order
		v_parent_menu,			-- parent_menu_id
		''[expr [im_permission $user_id view_timesheet_tasks] && [im_project_has_type [ns_set get $bind_vars project_id] "Gantt Project"]]'' -- p_visible_tcl
	);

	-- Set permissions of the "Tasks" tab 
	update im_menus
	set visible_tcl = ''[expr [im_permission $user_id view_timesheet_tasks] && [im_project_has_type [ns_set get $bind_vars project_id] "Gantt Project"]]''
	where menu_id = v_menu;

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
-- Gantt Task Cateogries
--
-- 9500-9999	Intranet Gantt Tasks
--
-- 9500-9549	Gantt Task Type
-- 9550-9599	Intranet Gantt Task Dependency Hardness Type
-- 9600-9649	Intranet Gantt Task Status
-- 9650-9699	Intranet Gantt Task Dependency Type
-- 9700-9719	Intranet Gantt Task Scheduling Type
-- 9720-9739	Intranet Gantt Task Fixed Task Type
-- 9740-9759	Intranet Gantt Task Dependency Status
-- 9760-9799	unassigned
-- 9800-9899	Intranet Gantt Task Dependency Lag Format
-- 9900-9999	unassigned


-------------------------------
-- Add a new project type for the Tasks
--

create or replace function inline_0 ()
returns integer as '
declare
	v_count		integer;
begin
	select count(*) into v_count from im_categories
	where category_id = 100;
	IF 0 != v_count THEN return 0; END IF;

	insert into im_categories (CATEGORY_ID, CATEGORY, CATEGORY_TYPE) 
	values (100, ''Task'', ''Intranet Project Type'');

	return 1;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




-------------------------------
-- Gantt Task Dependency Status and Type
--
SELECT im_category_new(9740,'Active', 'Intranet Gantt Task Dependency Status');
--
-- Values used for GanttProject(?)
SELECT im_category_new(9650,'Depends', 'Intranet Gantt Task Dependency Type');
SELECT im_category_new(9652,'Sub-Task', 'Intranet Gantt Task Dependency Type');
--
-- Values used for MS-project
SELECT im_category_new(9660,'FF (finish-to-finish)', 'Intranet Gantt Task Dependency Type');
update im_categories set aux_int1 = 0 where category_id = 9660;
SELECT im_category_new(9662,'FS (finish-to-start)', 'Intranet Gantt Task Dependency Type');
update im_categories set aux_int1 = 1 where category_id = 9662;
SELECT im_category_new(9664,'SF (start-to-finish)', 'Intranet Gantt Task Dependency Type');
update im_categories set aux_int1 = 2 where category_id = 9664;
SELECT im_category_new(9666,'SS (start-to-start)', 'Intranet Gantt Task Dependency Type');
update im_categories set aux_int1 = 3 where category_id = 9666;


-------------------------------
-- Gantt Task Dependency Hardness Type
SELECT im_category_new(9550,'Hard', 'Intranet Gantt Task Dependency Hardness Type');



-------------------------------
-- 9800-9899	Intranet Gantt Task Dependency Lag Format
--
-- LagFormat can be: 3=m, 4=em, 5=h, 6=eh, 7=d, 8=ed, 9=w, 10=ew, 
-- 11=mo, 12=emo, 19=%, 20=e%, 35=m?, 36=em?, 37=h?, 38=eh?, 39=d?, 
-- 40=ed?, 41=w?, 42=ew?, 43=mo?, 44=emo?, 51=%? and 52=e%?
--
SELECT im_category_new(9803,'Month', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9804,'e-Month', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9805,'Hour', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9806,'e-Hour', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9807,'Day', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9808,'e-Day', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9809,'Week', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9810,'e-Week', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9811,'mo', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9812,'emo', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9819,'Percent', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9820,'e-Percent', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9835,'m?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9836,'em?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9837,'h?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9838,'eh?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9839,'d?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9840,'ed?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9841,'w?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9842,'ew?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9843,'mo?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9844,'emo?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9851,'Percent?', 'Intranet Gantt Task Dependency Lag Format');
SELECT im_category_new(9852,'e-Percent?', 'Intranet Gantt Task Dependency Lag Format');




-------------------------------
-- Gantt Task Scheduling Type
SELECT im_category_new(9700,'As soon as possible', 'Intranet Gantt Task Scheduling Type');
SELECT im_category_new(9701,'As late as possible', 'Intranet Gantt Task Scheduling Type');
SELECT im_category_new(9702,'Must start on', 'Intranet Gantt Task Scheduling Type');
SELECT im_category_new(9703,'Must finish on', 'Intranet Gantt Task Scheduling Type');
SELECT im_category_new(9704,'Start no earlier than', 'Intranet Gantt Task Scheduling Type');
SELECT im_category_new(9705,'Start no later than', 'Intranet Gantt Task Scheduling Type');
SELECT im_category_new(9706,'Finish no earlier than', 'Intranet Gantt Task Scheduling Type');
SELECT im_category_new(9707,'Finish no later than', 'Intranet Gantt Task Scheduling Type');

update im_categories set aux_int1 = 0 where category_id = 9700;
update im_categories set aux_int1 = 1 where category_id = 9701;
update im_categories set aux_int1 = 2 where category_id = 9702;
update im_categories set aux_int1 = 3 where category_id = 9703;
update im_categories set aux_int1 = 4 where category_id = 9704;
update im_categories set aux_int1 = 5 where category_id = 9705;
update im_categories set aux_int1 = 6 where category_id = 9706;
update im_categories set aux_int1 = 7 where category_id = 9707;


-------------------------------
-- Gantt Task Fixed Task Type
-- 9720-9739    Intranet Gantt Task Fixed Task Type
SELECT im_category_new(9720,'Fixed Units', 'Intranet Gantt Task Fixed Task Type');
SELECT im_category_new(9721,'Fixed Duration', 'Intranet Gantt Task Fixed Task Type');
SELECT im_category_new(9722,'Fixed Work', 'Intranet Gantt Task Fixed Task Type');


-------------------------------
-- Gantt Task Types
SELECT im_category_new(9500,'Standard','Intranet Gantt Task Type');
-- reserved until 9599

create or replace view im_timesheet_task_types as 
select	category_id as task_type_id, 
	category as task_type
from im_categories 
where category_type = 'Intranet Gantt Task Type';



-------------------------------
-- Intranet Gantt Task Status
SELECT im_category_new(9600,'Active','Intranet Gantt Task Status');
SELECT im_category_new(9602,'Inactive','Intranet Gantt Task Status');
-- reserved until 9699


create or replace view im_timesheet_task_status as 
select 	category_id as task_type_id, 
	category as task_type
from im_categories 
where category_type = 'Intranet Gantt Task Status';


create or replace view im_timesheet_task_status_active as 
select 	category_id as task_type_id, 
	category as task_type
from im_categories 
where	category_type = 'Intranet Gantt Task Status'
	and category_id not in (9602);










-- -------------------------------------------------------------------
-- Gantt TaskList
-- -------------------------------------------------------------------


--
-- Wide View in "Tasks" page, including Description
--
delete from im_view_columns where view_id = 910;
delete from im_views where view_id = 910;
insert into im_views (view_id, view_name, visible_for) values (910, 'im_timesheet_task_list', 'view_projects');


insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91022,910,NULL, 
'"<input id=list_check_all type=checkbox name=_dummy>"',
'"<input type=checkbox name=task_id.$task_id id=tasks,$task_id>"', '', '', -1, '');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91000,910,NULL,
'"<a href=https://www.project-open.net/en/package-intranet-task-management#task_status target=_blank>[im_gif help "Progress Status"]</a>"',
'[im_task_management_color_code_gif $progress_status_color_code]','im_task_management_color_code(t.task_id) as progress_status_color_code',
'',0,'im_package_exists_p "intranet-task-management"');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91002,910,NULL,'"Task Name"',
'"<nobr>$indent_html$gif_html<a href=$object_url target=_blank>$task_name</a></nobr>"','','',20,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91004,910,NULL,'Material',
'"<a href=/intranet-material/new?[export_vars -url {material_id return_url}] target=_blank>$material_nr</a>"',
'','',40,'set a 0');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91006,910,NULL,'"CC"',
'"<a href=/intranet-cost/cost-centers/new?[export_vars -url {cost_center_id return_url}] target=_blank>$cost_center_code</a>"',
'','',60,'set a 0');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91007,910,NULL,'"Start"',
'"<nobr>[string range $start_date 0 9]</nobr>"','','',80,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91008,910,NULL,'"End"',
'"<nobr><font color=$end_date_color>[string range $end_date 0 9]</font></nobr>"',
'CASE WHEN child.end_date < now() and coalesce(child.percent_completed,0) < 100 THEN ''red'' ELSE ''black'' END as end_date_color','',100,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91018,910,NULL,'Status',
'$status_select','','',120,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91010,910,NULL,'Plan',
'$planned_hours_input','','',200,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91012,910,NULL,'Bill',
'"<input type=textbox size=3 name=billable_units.$task_id value=$billable_units>"','','',220,'set a 0');

delete from im_view_columns where column_id = 91014;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91014,910,NULL,'Log',
'"[if {$planned_units > 0.0} { set t "
<div align=right><a href=[export_vars -base $timesheet_report_url {project_id {level_of_detail 5}}] target=_blank>
<font color=$log_color>$reported_units_cache / [expr round(100.0 * $reported_units_cache / $planned_units)]%</font></a></div>
" } else { set t "
<div align=right><a href=[export_vars -base $timesheet_report_url {project_id {level_of_detail 5}}] target=_blank>
<font color=$log_color>$reported_units_cache / -</font></a></div>
" }]"',
'CASE WHEN child.reported_hours_cache > child.percent_completed * t.planned_units / 100.0 
THEN ''red'' ELSE ''#235c96'' END as log_color','',240,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91103,911,NULL,'"End"',
'"[if {[string equal t $red_p]} { set t "<nobr><font color=red>[string range $end_date 2 9]</font></nobr>" } else { set t "<nobr>[string range $end_date 2 9]</nobr>" }]"',
'(child.end_date < now() and coalesce(child.percent_completed,0) < 100) as red_p','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91016,910,NULL,'UoM',
'$uom','','',260,'set a 0');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91021,910,NULL, 'Done',
'$percent_done_input', '','',400,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91023,910,NULL,'"ETC<br>Plan"',
'"<div align=right>[expr round((100.0 - $percent_completed) * $planned_units * 0.1) / 10.0]</div>"','',
'',500,'im_table_exists im_estimate_to_completes');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91025,910,NULL,'"ETC<br>Earned V."',
'"<div align=right>$etc_eva</div>"','
CASE WHEN child.percent_completed > 0.0 
THEN round((child.reported_hours_cache * 100.0 / child.percent_completed)::numeric,1) 
ELSE 0 END as etc_eva',
'',510,'im_table_exists im_estimate_to_completes');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91027,910,NULL,'"ETC<br>Manual"',
'"<div align=right>$etc_manual</div>"','
round(im_estimate_to_complete__user_etc(child.project_id),1) as etc_manual',
'',520,'im_table_exists im_estimate_to_completes');



-- insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
-- extra_select, extra_where, sort_order, visible_for) values (91020,910,NULL, 'Description', 
-- '[string_truncate -len 80 " $description"]', '','',300,'');



-- -------------------------------------------------------------------
--
-- -------------------------------------------------------------------



--
-- short view in project homepage
--
delete from im_view_columns where view_id = 911;
delete from im_views where view_id = 911;
--
insert into im_views (view_id, view_name, visible_for) values (911, 
'im_timesheet_task_list_short', 'view_projects');

delete from im_view_columns where column_id = 91112;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91112,911,NULL, 
'"<input id=list_check_all type=checkbox name=_dummy"',
'"<input type=checkbox name=task_id.$task_id id=tasks,$task_id>"', '', '', -1, '');

-- '"[im_gif del "Delete"]"', 
-- '"<input type=checkbox name=task_id.$task_id>"', '', '', -1, '');

-- insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
-- extra_select, extra_where, sort_order, visible_for) values (91100,911,NULL,'"Project Nr"',
-- '"<a href=/intranet/projects/view?[export_vars -url {project_id}]>$project_nr</a>"',
-- '','',0,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91101, 911, NULL, '"Task Name"',
'"<nobr>$indent_short_html$gif_html<a href=$object_url>$task_name</a></nobr>"','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91102,911,NULL,'"Start"',
'"<nobr>[string range $start_date 2 9]</nobr>"','','',2,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91103,911,NULL,'"End"',
'"[if {[string equal t $red_p]} { set t "<nobr><font color=red>[string range $end_date 2 9]</font></nobr>" } else { set t "<nobr>[string range $end_date 2 9]</nobr>" }]"','(child.end_date < now() and coalesce(child.percent_completed,0) < 100) as red_p','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91104,911,NULL,'Pln',
'$planned_units','','',4,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91106,911,NULL,'Bll',
'$billable_units','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91108,911,NULL,'Lg',
'"<a href=[export_vars -base $timesheet_report_url { task_id { project_id $project_id } return_url}]>
$reported_units_cache</a>"','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91109,911,NULL,'"%"',
'$percent_completed_rounded','','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91110,911,NULL,'UoM',
'$uom','','',10,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91115,911,NULL,'Members',
'"[im_biz_object_member_list_format $project_member_list]"','','',15,'');




------------------------------------------------------
-- Permissions and Privileges
--

-- add_timesheet_tasks actually is more of an obligation then a privilege...
select acs_privilege__create_privilege('add_timesheet_tasks', 'Add Gantt Task', 'Add Gantt Task');
select acs_privilege__add_child('admin', 'add_timesheet_tasks');
select im_priv_create('add_timesheet_tasks', 'Employees');


-- Does the user have the right to edit task estimates?
select acs_privilege__create_privilege('edit_timesheet_task_estimates', 'Edit Gantt Task Estimates', 'Edit Gantt Task Estimates');
select acs_privilege__add_child('admin', 'edit_timesheet_task_estimates');
select im_priv_create('edit_timesheet_task_estimates', 'Employees');

select acs_privilege__create_privilege('view_timesheet_task_estimates', 'View Gantt Task Estimates', 'View Gantt Task Esto,ates');
select acs_privilege__add_child('admin', 'view_timesheet_task_estimates');
select im_priv_create('view_timesheet_task_estimates', 'Employees');

select acs_privilege__create_privilege('view_timesheet_task_billables', 'View Gantt Task Billables', 'View Gantt Task Billables');
select acs_privilege__add_child('admin', 'view_timesheet_task_billables');
select im_priv_create('view_timesheet_task_billables', 'Employees');

-- Does the user have the right to edit percent done?
select acs_privilege__create_privilege('edit_timesheet_task_completion', 'Edit Timesheet Completion', 'Edit Timesheet Completion');
select acs_privilege__add_child('admin', 'edit_timesheet_task_completion');
select im_priv_create('edit_timesheet_task_completion', 'Employees');




select acs_privilege__create_privilege('view_timesheet_tasks_all', 'View All Gantt Tasks', 'View All Gantt Tasks');
select acs_privilege__add_child('admin', 'view_timesheet_tasks_all');
select im_priv_create('view_timesheet_tasks_all', 'Accounting');
select im_priv_create('view_timesheet_tasks_all', 'Project Managers');
select im_priv_create('view_timesheet_tasks_all', 'Sales');
select im_priv_create('view_timesheet_tasks_all', 'Senior Managers');



-- The new version of the delete also cleans up relationships etc.

-- Delete a single timesheet_task (if we know its ID...)
create or replace function im_timesheet_task__delete (integer)
returns integer as '
declare
	p_task_id		alias for $1;	-- timesheet_task_id
	row			RECORD;
begin
	-- Start deleting with im_gantt_projects
	delete from	im_gantt_projects
	where		project_id = p_task_id;

	-- Delete dependencies between tasks
	delete from	im_timesheet_task_dependencies
	where		(task_id_one = p_task_id OR task_id_two = p_task_id);

	-- Delete object_context_index
	delete from	acs_object_context_index
	where		(object_id = p_task_id OR ancestor_id = p_task_id);

	-- Delete relatinships
	FOR row IN
		select	*
		from	acs_rels
		where	(object_id_one = p_task_id OR object_id_two = p_task_id)
	LOOP
		PERFORM acs_rel__delete(row.rel_id);
	END LOOP;

	-- Erase the timesheet_task
	delete from im_timesheet_tasks
	where task_id = p_task_id;

	-- Erase the object
	PERFORM im_project__delete(p_task_id);
	return 0;
end;' language 'plpgsql';












select im_component_plugin__del_module('intranet-timesheet2-tasks');
select im_component_plugin__del_module('intranet-timesheet2-tasks-info');
select im_component_plugin__del_module('intranet-timesheet2-tasks-resources');

select im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',				-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creattion_ip
	null,					-- context_id

	'Project Gantt Tasks',		-- plugin_name
	'intranet-timesheet2-tasks',		-- package_name
	'left',					-- location
	'/intranet/projects/view',		-- page_url
	null,					-- view_name
	50,					-- sort_order
	'im_timesheet_task_list_component -restrict_to_project_id $project_id -max_entries_per_page 10 -view_name im_timesheet_task_list_short'
);

select im_component_plugin__new (
	null,						-- plugin_id
	'im_component_plugin',				-- object_type
	now(),						-- creation_date
	null,						-- creation_user
	null,						-- creattion_ip
	null,						-- context_id

	'Home Gantt Tasks',				-- plugin_name
	'intranet-timesheet2-tasks',			-- package_name
	'right',					-- location
	'/intranet/index',				-- page_url
	null,						-- view_name
	0,						-- sort_order
	'im_timesheet_task_list_component -max_entries_per_page 20 -view_name im_timesheet_task_list_short -restrict_to_mine_p mine -restrict_to_status_id [im_project_status_open]'
);


select im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',			-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creattion_ip
	null,				-- context_id

	'Task Dependencies',		-- plugin_name
	'intranet-timesheet2-tasks',	-- package_name
	'right',			-- location
	'/intranet-timesheet2-tasks/new',	-- page_url
	null,				-- view_name
	50,					-- sort_order
	'im_timesheet_task_info_component $project_id $task_id $return_url'
);


-- select im_component_plugin__new (
-- 	null,				-- plugin_id
-- 	'im_component_plugin',			-- object_type
-- 	now(),				-- creation_date
-- 	null,				-- creation_user
-- 	null,				-- creattion_ip
-- 	null,				-- context_id
-- 
-- 	'Task Resources',			-- plugin_name
-- 	'intranet-timesheet2-tasks',		-- package_name
-- 	'right',				-- location
-- 	'/intranet-timesheet2-tasks/new',		-- page_url
-- 	null,				-- view_name
-- 	50,					-- sort_order
-- 	'im_timesheet_task_members_component $project_id $task_id $return_url'
-- );


select im_component_plugin__new (
	null,						-- plugin_id
	'im_component_plugin',				-- object_type
	now(),						-- creation_date
	null,						-- creation_user
	null,						-- creattion_ip
	null,						-- context_id

	'Task Hierarchy',				-- plugin_name
	'intranet-timesheet2-tasks',			-- package_name
	'right',					-- location
	'/intranet-timesheet2-tasks/new',		-- page_url
	null,						-- view_name
	0,						-- sort_order
	'im_project_hierarchy_component -project_id $task_id'
);



------------------------------------------------------
-- Permissions and Privileges
--

-- view_timesheet_tasks actually is more of an obligation then a privilege...
select acs_privilege__create_privilege(
	'view_timesheet_tasks',
	'View Gantt Task',
	'View Gantt Task'
);
select acs_privilege__add_child('admin', 'view_timesheet_tasks');

select im_priv_create('view_timesheet_tasks', 'Accounting');
select im_priv_create('view_timesheet_tasks', 'Employees');
select im_priv_create('view_timesheet_tasks', 'P/O Admins');
select im_priv_create('view_timesheet_tasks', 'Project Managers');
select im_priv_create('view_timesheet_tasks', 'Sales');
select im_priv_create('view_timesheet_tasks', 'Senior Managers');

select im_priv_create('view_timesheet_tasks', 'Customers');
