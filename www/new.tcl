# /packages/intranet-timesheet2-task/www/new.tcl
#
# Copyright (c) 2003-2006 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    @param form_mode edit or display
    @author frank.bergmann@project-open.com
} {
    task_id:integer,optional
    { project_id:integer 0 }
    { return_url "" }
    edit_p:optional
    message:optional
    { form_mode "display" }
    { task_status_id 76 }

}


# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set action_url "/intranet-timesheet2-tasks/new"
set focus "task.var_name"
set page_title [_ intranet-timesheet2-tasks.New_Timesheet_Task]
set context [list $page_title]

set normalize_project_nr_p [parameter::get_from_package_key -package_key "intranet-core" -parameter "NormalizeProjectNrP" -default 1]

set current_user_id $user_id
set user_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]

# Check the case if there is no project specified. 
# This is only OK if there is a task_id specified (new task for project).
if {0 == $project_id} {
    if {[info exists task_id]} {
	set project_id [db_string project_from_task "select project_id from im_timesheet_tasks_view where task_id = :task_id" -default 0]
	set return_url "/intranet/projects/view?project_id=$project_id"
    } else {
	ad_return_complaint 1 "You need to specify atleast a task or a project"
	return
    }
}

set project_name [db_string project_name "select project_name from im_projects where project_id=:project_id" -default "Unknown"]

append page_title " for '$project_name'"

if {![info exists task_id]} { set form_mode "edit" }

im_project_permissions $user_id $project_id project_view project_read project_write project_admin

if {"display" == $form_mode} {
    if {!$project_read && ![im_permission $user_id view_timesheet_tasks_all]} {
	ad_return_complaint 1 "You have insufficient privileges to see timesheet tasks for this project"
	return
    }
} else {
    if {!$project_write && ![im_permission $user_id add_timesheet_tasks]} {
	ad_return_complaint 1 "You have insufficient privileges to add/modify timesheet tasks for this project"
	return
    }
}


# most used material...
set default_material_id [db_string default_cost_center "
	select material_id
	from im_timesheet_tasks_view
	group by material_id
	order by count(*) DESC
	limit 1
" -default ""]


set button_pressed [template::form get_action task]
if {"delete" == $button_pressed} {

    db_exec_plsql task_delete {}
    ad_returnredirect $return_url

}


# ------------------------------------------------------------------
# Check if converted from a project
# ------------------------------------------------------------------

# ... then no entry in im_timesheet_tasks will be available and
# the select_query below will fail

if {[info exists task_id]} {

    set project_exists_p [db_string project_exists "
	select	count(*)
	from	im_projects
	where	project_id = :task_id
		and not exists (
			select	task_id
			from	im_timesheet_tasks
			where	task_id = :task_id
		)
    "]

    if {$project_exists_p} {


	# Create a new task entry
	db_dml insert_task "
		insert into im_timesheet_tasks (
			task_id, material_id, uom_id
		) values (
			:task_id, :default_material_id, [im_uom_hour]
		)
	"

    }

}

# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

set type_options [im_timesheet_task_type_options -include_empty 0]
set material_options [im_material_options -include_empty 0]

set include_empty 0
set department_only_p 0
set cost_center_options [im_cost_center_options -include_empty $include_empty -department_only_p $department_only_p -cost_type_id [im_cost_type_timesheet]]

set uom_options [im_cost_uom_options 0]

set actions [list {"Edit" edit} ]
if {[im_permission $user_id add_tasks]} {
    lappend actions {"Delete" delete}
}

ad_form \
    -name task \
    -cancel_url $return_url \
    -action $action_url \
    -actions $actions \
    -mode $form_mode \
    -export {next_url user_id return_url} \
    -form {
	task_id:key
	{project_id:text(hidden)}
	{task_nr:text(text) {label "[_ intranet-timesheet2-tasks.Short_Name]"} {html {size 30}}}
	{task_name:text(text) {label "[_ intranet-timesheet2-tasks.Name]"} {html {size 50}}}
	{material_id:text(select) {label "[_ intranet-timesheet2-tasks.Material]"} {options $material_options} }
	{cost_center_id:text(select) {label "[_ intranet-timesheet2-tasks.Cost_Center]"} {options $cost_center_options} }
	{task_type_id:text(select) {label "[_ intranet-timesheet2-tasks.Type]"} {options $type_options} }
	{task_status_id:text(im_category_tree) {label "[_ intranet-timesheet2-tasks.Status]"} {custom {category_type "Intranet Project Status"}}}
	{uom_id:text(select) {label "[_ intranet-timesheet2-tasks.UoM]<br>([_ intranet-timesheet2-tasks.Unit_of_Measure])"} {options $uom_options} }
	{planned_units:float(text),optional {label "[_ intranet-timesheet2-tasks.Planned_Units]"} {html {size 10}}}
	{billable_units:float(text),optional {label "[_ intranet-timesheet2-tasks.Billable_Units]"} {html {size 10}}}
	{percent_completed:float(text),optional {label "[_ intranet-timesheet2-tasks.Percentage_completed]"} {html {size 10}}}
	{note:text(textarea),optional {label "[_ intranet-timesheet2-tasks.Note]"} {html {cols 40}}}
	{start_date:date(date),optional {label "[_ intranet-timesheet2.Start_Date]"} {}}
	{end_date:date(date),optional {label "[_ intranet-timesheet2.End_Date]"} {}}
    }


# Fix for problem changing to "edit" form_mode
set form_action [template::form::get_action "task"]
if {"" != $form_action} { set form_mode "edit" }

ad_form -extend -name task -on_request {
    # Populate elements from local variables

    # ToDo: Check if these queries get too slow if the
    # system is in use during a lot of time...

    # Set default UoM to Hour
    set uom_id [im_uom_hour]

    # Set default CostCenter to most used CostCenter
    set cost_center_id [db_string default_cost_center "
	select cost_center_id 
	from im_timesheet_tasks_view 
	group by cost_center_id 
	order by count(*) DESC 
	limit 1
    " -default ""]

    # Set default Material to most used Material
    set material_id $default_material_id

} -select_query {

select t.*,
        p.parent_id as project_id,
        p.project_name as task_name,
        p.project_nr as task_nr,
        p.percent_completed,
        p.project_type_id as task_type_id,
        p.project_status_id as task_status_id,
        to_char(p.start_date,'YYYY-MM-DD') as start_date, 
        to_char(p.end_date,'YYYY-MM-DD') as end_date, 
	p.reported_hours_cache,
	p.reported_hours_cache as reported_units_cache,
        p.note
from
        im_projects p,
        im_timesheet_tasks t
where
        t.task_id = :task_id 
  and   p.project_id = :task_id

} -new_data {

    # Issue from Anke@opus5: project_path is unique
    # ToDo: Make path unique, or distinguish between
    # task_nr and project_path

    set task_nr [string tolower $task_nr]
    set start_date_sql [template::util::date get_property sql_date $start_date]
    set end_date_sql [template::util::date get_property sql_timestamp $end_date]

    db_exec_plsql task_insert {}
    db_dml task_update {}
    db_dml project_update {}

    # Write Audit Trail
    im_project_audit $task_id

} -edit_data {

    set task_nr [string tolower $task_nr]
    set start_date_sql [template::util::date get_property sql_date $start_date]
    set end_date_sql [template::util::date get_property sql_timestamp $end_date]

    db_dml task_update {}
    db_dml project_update {}

    # Write Audit Trail
    im_project_audit $task_id

} -on_submit {

	ns_log Notice "new: on_submit"

} -after_submit {

	ad_returnredirect $return_url
	ad_script_abort

} -validate {
    {task_nr
	{ [string length $task_nr] < 30 }
	"[lang::message::lookup {} intranet-timesheet2-tasks.Short_Name_too_long {Short Name too long (max 30 characters).}]" 
    }
    {task_nr
	{ [regexp {^[a-zA-Z0-9_]+$} $task_nr match] }
	"Short Name contains non-alphanum characters." 
    }
}

# ---------------------------------------------------------------
# Project Menu
# ---------------------------------------------------------------

# Setup the subnavbar
set bind_vars [ns_set create]
ns_set put $bind_vars project_id $project_id
set project_menu_id [db_string parent_menu "select menu_id from im_menus where label='project'" -default 0]
set sub_navbar [im_sub_navbar \
    -components \
    -base_url "/intranet/projects/view?project_id=$project_id" \
    $project_menu_id \
    $bind_vars "" "pagedesriptionbar" "project_timesheet_task"] 


