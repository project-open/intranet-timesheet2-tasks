# /packages/intranet-timesheet2-tasks/www/index.tcl
#
# Copyright (C) 2003-2004 Project/Open
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
    { task_start_idx:integer 0 }
    { task_how_many 0 }
    { task_max_entries_per_page 0 }
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


set return_url [im_url_with_query]
set current_url [ns_conn url]

set company_view_page "/intranet/companies/view"

if { [empty_string_p $task_how_many] || $task_how_many < 1 } {
    set task_how_many [ad_parameter -package_id [im_package_core_id] NumberResultsPerPage "" 50]
} 

set end_idx [expr $task_start_idx + $task_how_many - 1]


# ---------------------------------------------------------------
# Admin Links
# ---------------------------------------------------------------

set admin_links "<li><a href=\"new?[export_url_vars project_id return_url]\">Add a new task</a>\n"


# ---------------------------------------------------------------
# Task Component
# ---------------------------------------------------------------

# Variables of this page to pass through im_task_component to maintain the
# current selection and view of the current project

set export_var_list [list task_start_idx task_order_by task_how_many view_name]

# ad_return_complaint 1 $task_order_by

set task_content [im_timesheet_task_list_component \
	-current_page_url	$current_url \
	-return_url		$return_url \
	-start_idx		$task_start_idx \
	-export_var_list	$export_var_list \
	-view_name 		$view_name \
	-order_by		$task_order_by \
	-max_entries_per_page	$task_max_entries_per_page \
	-restrict_to_type_id	$task_type_id \
	-restrict_to_status_id	$task_status_id \
	-restrict_to_material_id $material_id \
	-restrict_to_project_id	$project_id \
]


# ---------------------------------------------------------------
# Project Menu
# ---------------------------------------------------------------

# Setup the subnavbar
set bind_vars [ns_set create]
ns_set put $bind_vars project_id $project_id
set project_menu_id [db_string parent_menu "select menu_id from im_menus where label='project'" -default 0]
set project_menu [im_sub_navbar $project_menu_id $bind_vars "" "pagedesriptionbar" "project_timesheet_task"]

