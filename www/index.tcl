# /packages/intranet-material/www/intranet/material/index.tcl
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
    { material_order_by "Type" }
    { material_view_name "material_list" }
    { material_topic_type_id:integer 0 }
    { material_status_id 0 }
    { material_type_id 0 }
    { material_group_id:integer 0 }
    { material_start_idx:integer 0 }
    { material_how_many 0 }
    { material_max_entries_per_page 0 }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
set current_user_id $user_id
set page_title "[_ intranet-material.Material]"
set context_bar [im_context_bar $page_title]
set page_focus "im_header_form.keywords"
set user_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]

set return_url [im_url_with_query]
set current_url [ns_conn url]

if { [empty_string_p $material_how_many] || $material_how_many < 1 } {
    set material_how_many [ad_parameter -package_id [im_package_core_id] NumberResultsPerPage "" 50]
} 

set end_idx [expr $material_start_idx + $material_how_many - 1]

if {[string equal $material_view_name "material_list_tasks"]} {
    set material_view_name "material_list_material"
    # Preselect "Tasks & Incidents"
    set material_topic_type_id 1
}

# ---------------------------------------------------------------
# Define Filter Categories
# ---------------------------------------------------------------

# Material Topic Types come from a category list, but we need
# some manual extensions...
#
set material_types [im_memoize_list select_material_types \
   "select * from im_material_types order by material_type_id"]
set material_types [linsert $material_types 0 1 "Tasks / Incidents]"]
set material_types [linsert $material_types 0 0 "All"]
ns_log Notice "/intranet-material/index: material_types=$material_types"

# ---------------------------------------------------------------
# Format the Filter
# ---------------------------------------------------------------

# Note that we use a nested table because im_slider might
# return a table with a form in it (if there are too many
# options
set filter_html "
<table border=0 cellpadding=0 cellspacing=0>
<tr>
  <td colspan='2' class=rowtitle align=center>[_ intranet-material.Filter_Materials]</td>
</tr>\n"

    append filter_html "
<tr>
  <td valign=top>[_ intranet-material.Status]:</td>
  <td valign=top>[im_select material_status_id $material_types $material_status_id]</td>
</tr>
<tr>
  <td valign=top>[_ intranet-material.Type]:</td>
  <td valign=top>[im_select material_type_id $material_types $material_type_id]
    <input type=submit value=Go name=submit>
  </td>
</tr>
</table>
"

# ---------------------------------------------------------------
# Admin Links
# ---------------------------------------------------------------

set admin_html "
<li><a href=\"new?[export_url_vars return_url]\">Add a new Material</a>
"


# ---------------------------------------------------------------
# Prepare parameters for the Material Component
# ---------------------------------------------------------------

# Variables of this page to pass through im_material_component to maintain the
# current selection and view of the current project

set export_var_list [list material_start_idx material_order_by material_how_many material_view_name]

set material_content [im_material_list_component \
	-user_id		$current_user_id \
	-current_page_url	$current_url \
	-return_url		$return_url \
	-start_idx		$material_start_idx \
	-export_var_list	$export_var_list \
	-view_name 		material_view_name \
	-order_by		material_order_by \
	-max_entries_per_page	$material_max_entries_per_page \
	-restrict_to_type_id	$material_type_id \
	-restrict_to_status_id	$material_status_id \
]

