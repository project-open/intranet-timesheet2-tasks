# /packages/intranet-timesheet2-tasks/tcl/intranet-timesheet2-tasks.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    @author frank.bergmann@project-open.com
}


# ----------------------------------------------------------------------
# Category Constants
# ----------------------------------------------------------------------

ad_proc -public im_timesheet_task_status_active { } { return 10100 }
ad_proc -public im_timesheet_task_status_inactive { } { return 10102 }

ad_proc -public im_timesheet_task_type_a { } { return 10000 }
ad_proc -public im_timesheet_task_type_b { } { return 10002 }


ad_proc -public im_package_timesheet_task_id {} {
    Returns the package id of the intranet-timesheet2-tasks module
} {
    return [util_memoize "im_package_timesheet_task_id_helper"]
}

ad_proc -private im_package_timesheet_task_id_helper {} {
    return [db_string im_package_core_id {
        select package_id from apm_packages
        where package_key = 'intranet-timesheet2-tasks'
    } -default 0]
}



# ----------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------

ad_proc -private im_timesheet_task_type_options { {-include_empty 1} } {

    set options [db_list_of_lists task_type_options "
        select category, category_id
        from im_categories
        where category_type = 'Intranet Timesheet Task Type'
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}

ad_proc -private im_timesheet_task_status_options { {-include_empty 1} } {

    set options [db_list_of_lists task_status_options "
        select category, category_id
        from im_categories
        where category_type = 'Intranet Timesheet Task Status'
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}



# ----------------------------------------------------------------------
# Task List Page Component
# ---------------------------------------------------------------------

ad_proc -public im_timesheet_task_list_component {
    {-view_name "im_timesheet_task_list"} 
    {-order_by "priority"} 
    {-restrict_to_type_id 0} 
    {-restrict_to_status_id 0} 
    {-restrict_to_material_id 0} 
    {-restrict_to_project_id 0} 
    {-max_entries_per_page 50} 
    {-start_idx 0} 
    -current_page_url 
    -return_url 
    -export_var_list
} {
    Creates a HTML table showing a table of Tasks 
} {
    set user_id [ad_get_user_id]

    set bgcolor(0) " class=roweven"
    set bgcolor(1) " class=rowodd"
    set date_format "YYYY-MM-DD"

    set max_entries_per_page 50
    set end_idx [expr $start_idx + $max_entries_per_page - 1]

    im_project_permissions $user_id $restrict_to_project_id view read write admin
    if {!$read && ![im_permission $user_id view_timesheet_tasks_all]} { return ""}

    set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name" -default 0]
    if {0 == $view_id} {
	# We haven't found the specified view, so let's emit an error message
	# and proceed with a default view that should work everywhere.
	ns_log Error "im_timesheet_task_component: we didn't find view_name=$view_name"
	set view_name "im_timesheet_task_list"
	set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name"]
    }
    ns_log Notice "im_timesheet_task_component: view_id=$view_id"

    # ---------------------- Get Columns ----------------------------------
    # Define the column headers and column contents that
    # we want to show:
    #
    set column_headers [list]
    set column_vars [list]

    set column_sql "
	select
	        column_name,
	        column_render_tcl,
	        visible_for
	from
	        im_view_columns
	where
	        view_id=:view_id
	        and group_id is null
	order by
	        sort_order
    "

    db_foreach column_list_sql $column_sql {
	if {"" == $visible_for || [eval $visible_for]} {
        lappend column_headers "$column_name"
        lappend column_vars "$column_render_tcl"
	}
    }
    ns_log Notice "im_timesheet_task_component: column_headers=$column_headers"

    # -------- Compile the list of parameters to pass-through-------

    set form_vars [ns_conn form]
    if {"" == $form_vars} { set form_vars [ns_set create] }

    set bind_vars [ns_set create]
    foreach var $export_var_list {
        upvar 1 $var value
        if { [info exists value] } {
            ns_set put $bind_vars $var $value
            ns_log Notice "im_timesheet_task_component: $var <- $value"
        } else {
        
            set value [ns_set get $form_vars $var]
            if {![string equal "" $value]} {
 	        ns_set put $bind_vars $var $value
 	        ns_log Notice "im_timesheet_task_component: $var <- $value"
            }
            
        }
    }

    ns_set delkey $bind_vars "order_by"
    ns_set delkey $bind_vars "task_start_idx"
    set params [list]
    set len [ns_set size $bind_vars]
    for {set i 0} {$i < $len} {incr i} {
        set key [ns_set key $bind_vars $i]
        set value [ns_set value $bind_vars $i]
        if {![string equal $value ""]} {
            lappend params "$key=[ns_urlencode $value]"
        }
    }
    set pass_through_vars_html [join $params "&"]

    # ---------------------- Format Header ----------------------------------

    # Set up colspan to be the number of headers + 1 for the # column
    set colspan [expr [llength $column_headers] + 1]

    # Format the header names with links that modify the
    # sort order of the SQL query.
    #
    set table_header_html "<tr>\n"
    foreach col $column_headers {

        set cmd_eval ""
	ns_log Notice "im_timesheet_task_component: eval=$cmd_eval $col"
        set cmd "set cmd_eval $col"
        eval $cmd
	append table_header_html "  <td class=rowtitle>$cmd_eval</td>\n"

    }
    append table_header_html "</tr>\n"
    

    # ---------------------- Build the SQL query ---------------------------

    set order_by_clause "order by t.task_id"
    set order_by_clause_ext "order by task_id"
    switch $order_by {
	"Status" { 
	    set order_by_clause "order by t.task_status_id" 
	    set order_by_clause_ext "m.task_id"
	}
    }
	
	
    set restrictions [list]
    if {$restrict_to_status_id} {
	lappend criteria "t.task_status_id in (
        	select :task_status_id from dual
        	UNION
        	select child_id
        	from im_category_hierarchy
        	where parent_id = :task_status_id
        )"
    }
    if {$restrict_to_type_id} {
	lappend criteria "t.task_type_id in (
        	select :task_type_id from dual
        	UNION
        	select child_id
        	from im_category_hierarchy
        	where parent_id = :task_type_id
        )"
    }

    set restriction_clause [join $restrictions "\n\tand "]
    if {"" != $restriction_clause} { 
	set restriction_clause "and $restriction_clause" 
    }
		
    set task_statement [db_qd_get_fullname "task_query" 0]
    set task_sql_uneval [db_qd_replace_sql $task_statement {}]
    set task_sql [expr "\"$task_sql_uneval\""]
	
    # ---------------------- Limit query to MAX rows -------------------------
    
    # We can't get around counting in advance if we want to be able to
    # sort inside the table on the page for only those rows in the query 
    # results
    
    set limited_query [im_select_row_range $task_sql $start_idx [expr $start_idx + $max_entries_per_page]]
    set total_in_limited_sql "select count(*) from ($task_sql) f"
    set total_in_limited [db_string total_limited $total_in_limited_sql]
    set selection "select z.* from ($limited_query) z $order_by_clause_ext"
    
    # How many items remain unseen?
    set remaining_items [expr $total_in_limited - $start_idx - $max_entries_per_page]
    ns_log Notice "im_timesheet_task_component: total_in_limited=$total_in_limited, remaining_items=$remaining_items"
    
    # ---------------------- Format the body -------------------------------
    
    set table_body_html ""
    set ctr 0
    set idx $start_idx
    set old_task_type_id 0
	
    db_foreach task_query_limited $selection {
	
	# insert intermediate headers for every task type
	if {[string equal "Type" $order_by]} {
	    if {$old_task_type_id != $task_type_id} {
		append table_body_html "
    	            <tr><td colspan=$colspan>&nbsp;</td></tr>
    	            <tr><td class=rowtitle colspan=$colspan>
    	              <A href=/intranet/projects/view?project_id=$task_type_id>
    	                $task_type
    	              </A>
    	            </td></tr>\n"
		set old_task_type_id $task_type_id
	    }
	}
	
	append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n"
	foreach column_var $column_vars {
	    append table_body_html "\t<td valign=top>"
	    set cmd "append table_body_html $column_var"
	    eval $cmd
	    append table_body_html "</td>\n"
	}
	append table_body_html "</tr>\n"
	
	incr ctr
	if { $max_entries_per_page > 0 && $ctr >= $max_entries_per_page } {
	    break
	}
    }
    # Show a reasonable message when there are no result rows:
    if { [empty_string_p $table_body_html] } {
	set table_body_html "
		<tr><td colspan=$colspan align=center><b>
		[_ intranet-timesheet2-tasks.There_are_no_active_tasks]
		</b></td></tr>"
    }
    
    if { $ctr == $max_entries_per_page && $end_idx < [expr $total_in_limited - 1] } {
	# This means that there are rows that we decided not to return
	# Include a link to go to the next page
	set next_start_idx [expr $end_idx + 1]
	set task_max_entries_per_page $max_entries_per_page
	set next_page_url  "$current_page_url?[export_url_vars task_object_id task_max_entries_per_page order_by]&task_start_idx=$next_start_idx&$pass_through_vars_html"
	set next_page_html "($remaining_items more) <A href=\"$next_page_url\">&gt;&gt;</a>"
    } else {
	set next_page_html ""
    }
    
    if { $start_idx > 0 } {
	# This means we didn't start with the first row - there is
	# at least 1 previous row. add a previous page link
	set previous_start_idx [expr $start_idx - $max_entries_per_page]
	if { $previous_start_idx < 0 } { set previous_start_idx 0 }
	set previous_page_html "<A href=$current_page_url?$pass_through_vars_html&order_by=$order_by&task_start_idx=$previous_start_idx>&lt;&lt;</a>"
    } else {
	set previous_page_html ""
    }
    

    # ---------------------- Join all parts together ------------------------

    set component_html "
<table bgcolor=white border=0 cellpadding=1 cellspacing=1>
  $table_header_html
  $table_body_html
</table>
"

    return $component_html
}

