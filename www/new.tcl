# /packages/intranet-timesheet2-task/www/new.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    @param form_mode edit or display
    @author frank.bergmann@project-open.com
} {
    task_id:integer,optional
    project_id:integer
    return_url
    edit_p:optional
    message:optional
    { form_mode "display" }
}


# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set action_url "/intranet-timesheet2-tasks/new"
set focus "task.var_name"
set page_title [_ intranet-timesheet2-tasks.New_Timesheet_Task]
set context [list $page_title]

set project_name [db_string project_name "select project_name from im_projects where project_id=:project_id" -default "Unknown"]

append page_title "for '$project_name'"

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


set button_pressed [template::form get_action task]
if {"delete" == $button_pressed} {

    db_exec_plsql task_delete {}
    ad_returnredirect $return_url

}


# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

set type_options [im_timesheet_task_type_options -include_empty 0]
set status_options [im_timesheet_task_status_options -include_empty 0]
set material_options [im_material_options -include_empty 0]
set cost_center_options [im_cost_center_options -include_empty 0]
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
	{task_nr:text(text) {label "Short Name"} {html {size 30}}}
	{task_name:text(text) {label Name} {html {size 50}}}
	{material_id:text(select) {label "Material"} {options $material_options} }
	{cost_center_id:text(select) {label "Cost Center"} {options $cost_center_options} }
	{task_type_id:text(select) {label "Type"} {options $type_options} }
	{task_status_id:text(select) {label "Status"} {options $status_options} }
	{uom_id:text(select) {label "UoM<br>(Unit of Measure)"} {options $uom_options} }
	{planned_units:float(text),optional {label "Planned Units"} {html {size 10}}}
	{billable_units:float(text),optional {label "Billable Units"} {html {size 10}}}
	{description:text(textarea),optional {label Description} {html {cols 40}}}
    }


ad_form -extend -name task -on_request {
    # Populate elements from local variables

} -select_query {

	select	m.*
	from	im_timesheet_tasks m
	where	m.task_id = :task_id

} -new_data {

    db_exec_plsql task_insert {}
    db_dml task_update {}

} -edit_data {

    db_dml task_update {}

} -on_submit {

	ns_log Notice "new: on_submit"

} -after_submit {

	ad_returnredirect $return_url
	ad_script_abort
}

