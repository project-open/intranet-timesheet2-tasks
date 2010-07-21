# -------------------------------------------------------------
# /packages/intranet-timesheet2-tasks/www/filter-task-form.tcl
#
# Copyright (c) 2007 - 2009 ]project-open[
# All rights reserved.
#
# Author: frank.bergmann@project-open.com
#

# -------------------------------------------------------------
# Variables:
#	<none>

set ttt {
if {![info exists object_id]} {

    ad_page_contract {
	@author frank.bergmann@project-open.com
    } {
	object_id
    }
}
}

# ---------------------------------------------------------------
# Filter with Dynamic Fields
# ---------------------------------------------------------------

set dynamic_fields_p 1
set form_id "task_filter"
set object_type "im_timesheet_task"
set action_url "/intranet-timesheet2-tasks/index"
set form_mode "edit"
set mine_p_options [list \
	[list [lang::message::lookup "" intranet-helpdesk.All "All"] "all" ] \
	[list [lang::message::lookup "" intranet-helpdesk.Mine "Mine"] "mine"] \
]

set task_member_options [util_memoize "db_list_of_lists task_members {
        select  distinct
                im_name_from_user_id(object_id_two) as user_name,
                object_id_two as user_id
        from    acs_rels r,
                im_timesheet_tasks p
        where   r.object_id_one = p.task_id
        order by user_name
}" 300]
set task_member_options [linsert $task_member_options 0 [list "" ""]]

set cost_center_options [im_cost_center_options -include_empty 1]


ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export {project_id return_url } \
    -form {
    	{mine_p:text(select),optional {label "Mine/All"} {options $mine_p_options }}
	{task_status_id:text(im_category_tree),optional {label "[lang::message::lookup {} intranet-helpdesk.Status Status]"} {custom {category_type "Intranet Project Status" translate_p 1}} }
	{with_member_id:text(select),optional {label "[lang::message::lookup {} intranet-helpdesk.With_Member {With Member}]"} {options $task_member_options} }
	{cost_center_id:text(select),optional {label "[lang::message::lookup {} intranet-cost.Cost_Center {Cost Center}]"} {options $cost_center_options} }
    }
		
template::element::set_value $form_id task_status_id $task_status_id
template::element::set_value $form_id mine_p $mine_p

im_dynfield::append_attributes_to_form \
    -object_type $object_type \
    -form_id $form_id \
    -object_id 0 \
    -advanced_filter_p 1 \
    -search_p 1

# Set the form values from the HTTP form variable frame
im_dynfield::set_form_values_from_http -form_id $form_id
im_dynfield::set_local_form_vars_from_http -form_id $form_id
array set extra_sql_array [im_dynfield::search_sql_criteria_from_form \
			       -form_id $form_id \
			       -object_type $object_type
]

