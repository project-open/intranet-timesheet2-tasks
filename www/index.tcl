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
    { task_view_name "im_timesheet_task_list" }
    { material_id:integer 0 }
    { project_id:integer 0 }
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
set page_title "[_ intranet-timesheet2-tasks.Timesheet_Task]"
set context_bar [im_context_bar $page_title]
set page_focus "im_header_form.keywords"
set user_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]

set return_url [im_url_with_query]
set current_url [ns_conn url]

if { [empty_string_p $task_how_many] || $task_how_many < 1 } {
    set task_how_many [ad_parameter -package_id [im_package_core_id] NumberResultsPerPage "" 50]
} 

set end_idx [expr $task_start_idx + $task_how_many - 1]

# ---------------------------------------------------------------
# Task Component
# ---------------------------------------------------------------

# Variables of this page to pass through im_task_component to maintain the
# current selection and view of the current project

set export_var_list [list task_start_idx task_order_by task_how_many task_view_name]

set task_content [im_timesheet_task_list_component \
	-current_page_url	$current_url \
	-return_url		$return_url \
	-start_idx		$task_start_idx \
	-export_var_list	$export_var_list \
	-view_name 		task_view_name \
	-order_by		task_order_by \
	-max_entries_per_page	$task_max_entries_per_page \
	-restrict_to_type_id	$task_type_id \
	-restrict_to_status_id	$task_status_id \
	-restrict_to_material_id $material_id \
	-restrict_to_project_id	$project_id \
]

