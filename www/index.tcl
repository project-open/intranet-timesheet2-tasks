# /packages/intranet-timesheet2-tasks/www/index.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    @author frank.bergmann@project-open.com
} {
    { task_order_by "Type" }
    { view_name "im_timesheet_task_list" }
    { material_id:integer 0 }
    { project_id }
    { task_status_id 0 }
    { task_type_id 0 }
    { task_how_many 0 }
    { task_max_entries_per_page 50 }
    { with_member_id "" }
    { mine_p "" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
set current_user_id $user_id
set page_focus "im_header_form.keywords"
set user_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]

set project_nr [db_string project_nr "select project_nr from im_projects where project_id=:project_id" -default [_ intranet-core.One_project]]

set page_title "$project_nr - [lang::message::lookup "" intranet-timesheet2-tasks.Timesheet_Tasks "Timesheet Tasks"]"
if {[im_permission $user_id view_projects_all]} {
    set context_bar [im_context_bar [list /intranet/projects/ "[_ intranet-core.Projects]"] $page_title]
} else {
    set context_bar [im_context_bar $page_title]
}

if {"" == $mine_p} { 
    set mine_p [parameter::get_from_package_key -package_key intranet-timesheet2-tasks -parameter DefaultFilterMineP -default "all"]
}

set return_url [im_url_with_query]
set current_url [ns_conn url]

set company_view_page "/intranet/companies/view"

if { [empty_string_p $task_how_many] || $task_how_many < 1 } {
    set task_how_many [ad_parameter -package_id [im_package_core_id] NumberResultsPerPage "" 50]
} 


# ---------------------------------------------------------------
# Admin Links
# ---------------------------------------------------------------

set admin_links "<li><a href=\"new?[export_url_vars project_id return_url]\">[_ intranet-timesheet2-tasks.New_Timesheet_Task]</a>\n"

set bind_vars [ad_tcl_vars_to_ns_set]
append admin_links [im_menu_ul_list -no_uls 1 "timesheet_tasks" $bind_vars]

if {"" != $admin_links} {
    set admin_links "<ul>\n$admin_links\n</ul>\n"
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




# ---------------------------------------------------------------
# Task Component
# ---------------------------------------------------------------

# Variables of this page to pass through im_task_component to maintain the
# current selection and view of the current project

set export_var_list [list task_order_by task_how_many view_name]

# ad_return_complaint 1 $task_order_by

set task_content [im_timesheet_task_list_component \
	-current_page_url	$current_url \
	-return_url		$return_url \
	-export_var_list	$export_var_list \
	-view_name 		$view_name \
	-order_by		$task_order_by \
	-max_entries_per_page	$task_max_entries_per_page \
	-restrict_to_type_id	$task_type_id \
	-restrict_to_status_id	$task_status_id \
	-restrict_to_material_id $material_id \
	-restrict_to_project_id	$project_id \
	-restrict_to_mine_p	$mine_p \
	-restrict_to_with_member_id	$with_member_id \
]


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

