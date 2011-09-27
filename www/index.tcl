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
    { task_order_by "" }
    { view_name "im_timesheet_task_list" }
    { material_id:integer 0 }
    { project_id }
    { task_status_id 0 }
    { task_type_id 0 }
    { task_start_idx:integer ""}
    { task_how_many "" }
    { with_member_id "" }
    { cost_center_id "" }
    { mine_p "" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set show_context_help_p 1

# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
set current_user_id $user_id
set page_focus "im_header_form.keywords"
set user_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]

set project_nr ""
set project_name ""
db_0or1row project_info "
	select	project_nr,
		project_name
	from	im_projects
	where	project_id = :project_id
"

set page_title "$project_nr - $project_name - [lang::message::lookup "" intranet-timesheet2-tasks.Timesheet_Tasks "Timesheet Tasks"]"
if {[im_permission $user_id view_projects_all]} {
    set context_bar [im_context_bar [list /intranet/projects/ "[_ intranet-core.Projects]"] $page_title]
} else {
    set context_bar [im_context_bar $page_title]
}

if {"" == $mine_p} { set mine_p [parameter::get_from_package_key -package_key intranet-timesheet2-tasks -parameter DefaultFilterMineP -default "all"] }

if {"" == $task_order_by} { set task_order_by [parameter::get_from_package_key -package_key intranet-timesheet2-tasks -parameter TaskListDetailsDefaultSortOrder -default "sort_order"] }

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

append admin_links [im_menu_ul_list -no_uls 1 "timesheet_tasks" {}]

if {"" != $admin_links} {
    set admin_links "<ul>\n$admin_links\n</ul>\n"
}


# ---------------------------------------------------------------
# Task Component
# ---------------------------------------------------------------

# Variables of this page to pass through im_task_component to maintain the
# current selection and view of the current project

set export_var_list [list task_order_by task_how_many view_name]

set task_content [im_timesheet_task_list_component \
	-current_page_url		$current_url \
	-return_url			$return_url \
	-export_var_list		$export_var_list \
	-view_name 			$view_name \
	-order_by			$task_order_by \
	-restrict_to_type_id		$task_type_id \
	-restrict_to_status_id		$task_status_id \
	-restrict_to_material_id	$material_id \
	-restrict_to_project_id		$project_id \
	-restrict_to_mine_p		$mine_p \
	-restrict_to_with_member_id	$with_member_id \
	-restrict_to_cost_center_id	$cost_center_id \
	-task_how_many			$task_how_many \
	-task_start_idx			$task_start_idx \
]


# ---------------------------------------------------------------
# Project Menu Navbar
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



# ---------------------------------------------------------------
# Left Navbar
# ---------------------------------------------------------------


set params [list \
		[list project_id $project_id] \
		[list return_url [im_url_with_query]] \
		[list task_status_id $task_status_id] \
		[list mine_p $mine_p] \
]

set filter_form_html [ad_parse_template -params $params "/packages/intranet-timesheet2-tasks/www/filter-task-form"]


set left_navbar "
            <div class=\"filter-block\">
                <div class=\"filter-title\">
		[lang::message::lookup "" intranet-timesheet2-tasks.Filter_Tasks "Filter Tasks"]
                </div>
		$filter_form_html
            </div>
            <hr/>

            <div class=\"filter-block\">
                <div class=\"filter-title\">
		[lang::message::lookup "" intranet-timesheet2-tasks.Admin_Tasks "Admin Tasks"]
                </div>
		$admin_links
            </div>
            <hr/>
"
