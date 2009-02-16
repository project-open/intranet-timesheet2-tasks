# /packages/intranet-timesheet2-tasks/www/report-timesheet.tcl
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
    { project_id 0 }
    { task_id 0 }
    { return_url "" }
}


# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set page_focus "im_header_form.keywords"

set package_name "intranet-reporting"
set page_title "'$package_name' [lang::message::lookup "" intranet-core.Package_Not_Available "Package Not Available"]"
set context_bar [im_context_bar $page_title]


if { "" == $return_url} {
    set return_url [im_url_with_query]
}
set current_url [ns_conn url]

# ---------------------------------------------------------------
# Check if reporting is available
# ---------------------------------------------------------------

set report_label "reporting-timesheet-customer-project"

if {[db_0or1row report_info "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read') as read_p,
		m.url
	from	im_menus m
	where	m.label = :report_label
"]} {

    # Found the report

    set start_date "2000-01-01"
    set end_date "2099-12-31"
    set lod 99
    ad_returnredirect [export_vars -base $url { start_date end_date { project_id $project_id } { task_id $task_id} { level_of_detail $lod } { return_url $return_url } }]
    return

}

# No report there - Show a suitable screen from the .adp file
