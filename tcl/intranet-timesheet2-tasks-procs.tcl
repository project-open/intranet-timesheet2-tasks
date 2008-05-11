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

ad_proc -public im_timesheet_task_status_active { } { return 9600 }
ad_proc -public im_timesheet_task_status_inactive { } { return 9602 }

ad_proc -public im_timesheet_task_type_standard { } { return 9500 }


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
# Permissions
# ---------------------------------------------------------------------

ad_proc -public im_timesheet_task_permissions {user_id task_id view_var read_var write_var admin_var} {
    Fill the "by-reference" variables read, write and admin
    with the permissions of $user_id on $project_id
} {
    upvar $view_var view
    upvar $read_var read
    upvar $write_var write
    upvar $admin_var admin

    # Search for the closest "real" project
    set ctr 0
    set project_id $task_id
    set project_type_id [db_string ttype "select project_type_id from im_projects where project_id = :project_id" -default 0]
    while {([im_project_type_task] == $project_type_id) && ("" != $project_id) && ($ctr < 100)} {
	set project_id [db_string ttype "select parent_id  from im_projects where project_id = :project_id" -default 0]
	set project_type_id [db_string ttype "select project_type_id from im_projects where project_id = :project_id" -default 0]
	incr ctr
    }

    set result [im_project_permissions $user_id $project_id view read write admin]
    return $result
}



# ----------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------

ad_proc -private im_timesheet_task_type_options { {-include_empty 1} } {

    set options [db_list_of_lists task_type_options "
        select	category, category_id
        from	im_categories
	where	category_type = 'Intranet Project Type'
		and category_id in ([join [im_sub_categories [im_project_type_task]] ","])
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}

ad_proc -private im_timesheet_task_status_options { {-include_empty 1} } {

    set options [db_list_of_lists task_status_options "
	select category, category_id
	from im_categories
	where category_type = 'Intranet Project Status'
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
    {-restrict_to_mine_p "all"} 
    {-restrict_to_with_member_id ""} 
    {-max_entries_per_page 50} 
    {-include_subprojects 1}
    {-export_var_list {} }
    -current_page_url 
    -return_url 
} {
    Creates a HTML table showing a table of Tasks 
} {
    # ---------------------- Security - Show the comp? -------------------------------
    set user_id [ad_get_user_id]

    # Is this a "Consulting Project"?
    if {0 != $restrict_to_project_id} {
	if {![im_project_has_type $restrict_to_project_id "Consulting Project"]} {
	    return ""
	}
    }
    
    # Check vertical permissions - 
    # Is this user allowed to see TS stuff at all?
    if {![im_permission $user_id "view_timesheet_tasks"]} {
	return ""
    }

    # Check horizontal permissions -
    # Is the user allowed to see this project?
    im_project_permissions $user_id $restrict_to_project_id view read write admin
    if {!$read && ![im_permission $user_id view_timesheet_tasks_all]} { return ""}

    # Check for Timesheet tasks of a certain status.
    # The status_id is only available in the previous screen.
    # Very Ugly!!
    upvar subproject_status_id subproject_status_id
    if {![info exists subproject_status_id]} { set subproject_status_id 0 }
    if {"" == $subproject_status_id} { set subproject_status_id 0 }
    set subproject_sql ""
    if {$subproject_status_id} {
	set subproject_sql "and p.project_status_id in ([join [im_sub_categories $subproject_status_id] ","])"
    }


    # -------- Get parameters from HTTP session -------
    # Don't trust the container page to pass-on that value...

    set form_vars [ns_conn form]
    if {"" == $form_vars} { set form_vars [ns_set create] }

    set start_idx [ns_set get $form_vars "task_start_idx"]
    if {"" == $start_idx} { set start_idx 0 }

    # ---------------------- Defaults ----------------------------------

    set bgcolor(0) " class=roweven"
    set bgcolor(1) " class=rowodd"
    set date_format "YYYY-MM-DD"

    set end_idx [expr $start_idx + $max_entries_per_page - 1]

    set timesheet_report_url "/intranet-timesheet2-tasks/report-timesheet"

    if {![info exists current_page_url]} { set current_page_url [ad_conn url] }
    if {![exists_and_not_null return_url]} { set return_url "[ns_conn url]?[ns_conn query]" }

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
    set extra_selects [list]
    set extra_froms [list]
    set extra_wheres [list]
    set view_order_by_clause ""

    set column_sql "
	select	*
	from	im_view_columns
	where	view_id=:view_id
		and group_id is null
	order by sort_order
    "
    db_foreach column_list_sql $column_sql {
	if {"" == $visible_for || [eval $visible_for]} {
	    lappend column_headers "$column_name"
	    lappend column_vars "$column_render_tcl"
	    if {"" != $extra_select} { lappend extra_selects $extra_select }
	    if {"" != $extra_from} { lappend extra_froms $extra_from }
	    if {"" != $extra_where} { lappend extra_wheres $extra_where }
	    if {"" != $order_by_clause && $order_by == $column_name} { set view_order_by_clause $order_by_clause }
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
    set order_by_clause "order by p.project_nr, t.task_id"
    set order_by_clause_ext "order by project_nr, task_id"
    switch $order_by {
	"Status" { 
	    set order_by_clause "order by t.task_status_id" 
	    set order_by_clause_ext "m.task_id"
	}
    }
	
    set criteria [list]

    set project_restriction "t.project_id = :restrict_to_project_id"
    if {$include_subprojects} {
	set subproject_list [list $restrict_to_project_id]
	db_foreach task_subprojects "" {
	    lappend subproject_list $subproject_id
	}
	set project_restriction "t.project_id in ([join $subproject_list ","])"
    }
    lappend criteria $project_restriction

    if {[string is integer $restrict_to_status_id] && $restrict_to_status_id > 0} {
	lappend criteria "t.task_status_id in ([join [im_sub_categories $restrict_to_status_id] ","])"
    }

    if {"mine" == $restrict_to_mine_p} {
	lappend criteria "t.task_id in (select object_id_one from acs_rels where object_id_two = [ad_get_user_id])"
    }

    if {[string is integer $restrict_to_with_member_id] && $restrict_to_with_member_id > 0} {
	lappend criteria "t.task_id in (select object_id_one from acs_rels where object_id_two = :restrict_to_with_member_id)"
    }

    if {[string is integer $restrict_to_type_id] && $restrict_to_type_id > 0} {
	lappend criteria "t.task_type_id in ([join [im_sub_categories $restrict_to_type_id] ","])"
    }

    set restriction_clause [join $criteria "\n\tand "]
    if {"" != $restriction_clause} { 
	set restriction_clause "and $restriction_clause" 
    }


    set extra_select [join $extra_selects ",\n\t"]
    if { ![empty_string_p $extra_select] } { set extra_select ",\n\t$extra_select" }

    set extra_from [join $extra_froms ",\n\t"]
    if { ![empty_string_p $extra_from] } { set extra_from ",\n\t$extra_from" }

    set extra_where [join $extra_wheres "and\n\t"]
    if { ![empty_string_p $extra_where] } { set extra_where ",\n\t$extra_where"	}


    # ---------------------- Inner Permission Query -------------------------

    # Check permissions for showing subprojects
    set children_perm_sql "
        (select p.*
        from    im_projects p,
                acs_rels r
        where   r.object_id_one = p.project_id
                and r.object_id_two = :user_id
        )
    "

    if {[im_permission $user_id "view_projects_all"]} { 
	set children_perm_sql "
	(select	t.*
	 from	im_projects t
	 where	$project_restriction
	)
	"
    }

    set projects_perm_sql "
	(select	t.*
	from	im_projects t,
		acs_rels r
	where	r.object_id_one = t.project_id
		and r.object_id_two = :user_id
		and $project_restriction
	)
    "

    if {[im_permission $user_id "view_projects_all"]} {
	set projects_perm_sql "
	(select	t.*
	 from	im_projects t
	 where	$project_restriction
	)
	"
    }

    # ---------------------- Get the SQL Query -------------------------
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
    set old_project_id 0

    db_foreach task_query_limited $selection {

	# Replace "0" by "" to make lists better readable
	if {0 == $reported_hours_cache} { set reported_hours_cache "" }
	if {0 == $reported_units_cache} { set reported_units_cache "" }

	# Compatibility...
	set description $note

	set new_task_url "/intranet-timesheet2-tasks/new?[export_url_vars project_id return_url]"

	# insert intermediate headers for every project!!!
	if {$include_subprojects} {
	    if {$old_project_id != $project_id} {
		append table_body_html "
    		    <tr><td colspan=$colspan>&nbsp;</td></tr>
    		    <tr><td class=rowtitle colspan=$colspan>
			<table cellspacing=0 cellpadding=0 width=\"100%\">
			<tr>
			  <td class=rowtitle>
	    		      <A href=/intranet/projects/view?project_id=$project_id>
    				$project_name
	    		      </A>
			  </td>
			  <td align=right><a href=\"$new_task_url\">Add a new task</a></td>
			</tr>
			</table>
    		    </td></tr>\n"
		set old_project_id $project_id
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
    
    set project_id $restrict_to_project_id

    if { $ctr == $max_entries_per_page && $end_idx < [expr $total_in_limited - 1] } {
	# This means that there are rows that we decided not to return
	# Include a link to go to the next page
	set next_start_idx [expr $end_idx + 1]
	set task_max_entries_per_page $max_entries_per_page
	set next_page_url  "$current_page_url?[export_url_vars project_id task_object_id task_max_entries_per_page order_by]&task_start_idx=$next_start_idx&$pass_through_vars_html"
	set next_page_html "($remaining_items more) <A href=\"$next_page_url\">&gt;&gt;</a>"
    } else {
	set next_page_html ""
    }
    
    if { $start_idx > 0 } {
	# This means we didn't start with the first row - there is
	# at least 1 previous row. add a previous page link
	set previous_start_idx [expr $start_idx - $max_entries_per_page]
	if { $previous_start_idx < 0 } { set previous_start_idx 0 }
	set previous_page_html "<A href=$current_page_url?[export_url_vars project_id]&$pass_through_vars_html&order_by=$order_by&task_start_idx=$previous_start_idx>&lt;&lt;</a>"
    } else {
	set previous_page_html ""
    }
    

    # ---------------------- Format the action bar at the bottom ------------

    set table_footer_action "
	<select name=action>
	<option value=save>[lang::message::lookup "" intranet-timesheet2-tasks.Save_Changes "Save Changes"]</option>
	<option value=delete>[_ intranet-timesheet2-tasks.Delete]</option>
	</select>
	<input type=submit name=submit value='[_ intranet-timesheet2-tasks.Apply]'>
    "
    if {!$write} { set table_footer_action "" }

    set table_footer "
	<tr>
	  <td class=rowplain colspan=$colspan align=right>
	    $previous_page_html
	    $next_page_html
	    $table_footer_action
	  </td>
	</tr>
    "

    # ---------------------- Join all parts together ------------------------

    # Restore the original value of project_id
    set project_id $restrict_to_project_id

    set component_html "
<form action=/intranet-timesheet2-tasks/task-action method=POST>
[export_form_vars project_id return_url]
<table bgcolor=white border=0 cellpadding=1 cellspacing=1>
  $table_header_html
  $table_body_html
  $table_footer
</table>
</form>
"

    return $component_html
}

# ----------------------------------------------------------------------
# Task List Tree Component
# ---------------------------------------------------------------------

ad_proc -public im_timesheet_task_list_tree_component {
    {-view_name "im_timesheet_task_list"} 
    {-restrict_to_project_id 0} 
    project_id
    return_url
} {
    # ---------------------- Security - Show the comp? -------------------------------
    set user_id [ad_get_user_id]

    # Is this a "Consulting Project"?
    if {0 != $restrict_to_project_id} {
	if {![im_project_has_type $restrict_to_project_id "Consulting Project"]} {
	    return ""
	}
    }
    
    # Check vertical permissions - 
    # Is this user allowed to see TS stuff at all?
    if {![im_permission $user_id "view_timesheet_tasks"]} {
	return ""
    }

    # Check horizontal permissions -
    # Is the user allowed to see this project?
    im_project_permissions $user_id $restrict_to_project_id view read write admin
    if {!$read && ![im_permission $user_id view_timesheet_tasks_all]} { 
	return ""
    }

    db_multirow tree tree "
      select 
        subtree.project_id AS task_id,
        subtree.parent_id AS parent_id,
        (repeat('- ',tree_level(subtree.tree_sortkey)-tree_level(parent.tree_sortkey)) 
         || subtree.project_nr) AS task_nr,
        subtree.project_name AS task_name,
        'add' AS add_subtask,
        subtree.sort_order
      from 
        im_projects parent, im_projects subtree
      where subtree.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey) 
        and parent.parent_id = :project_id
    "

    multirow_sort_tree -integer tree task_id parent_id sort_order

    template::list::create \
	-name tree \
	-key task_id \
	-pass_properties { return_url project_id } \
	-bulk_action_export_vars { return_url project_id action } \
	-elements {
	    task_nr {
		label "Task NR"
		link_url_eval { 
		    [return "/intranet-timesheet2-tasks/new?[export_vars -url { return_url project_id task_id } ]" ]
		} 
	    }
	    task_name {
		label "Task Name"
	    }
	    add_subtask {
		label "Add Subtask"
		link_url_eval { 
		    [return "/intranet-timesheet2-tasks/new?[export_vars -url -override {{project_id $task_id}} { return_url } ]" ]
		} 
	    }
	} \
	-bulk_actions {
	    "Delete" "/intranet-timesheet2-tasks/task-delete" "Delete selected task"
	} \
	-actions [list \
		  "Add Subtask" "/intranet-timesheet2-tasks/new?[export_vars -url { project_id return_url } ]" \
		  ]

    set tree_html [template::list::render -name tree]

    # this is ugly. but I haven't found a way to do this with template::list yet
    regsub -all {(<td class=\"list\">\s*)(<a href=\"[^\"]+\">)((- )+)} $tree_html {\1\3\2} tree_html 

    append html $tree_html

    return $html
}

# ----------------------------------------------------------------------
# Task Info Component
# ---------------------------------------------------------------------

ad_proc -public im_timesheet_task_info_component {
    project_id
    task_id
    return_url
} {
    set html ""

    #
    # small form to add new dependency
    #

    append html "<form action=\"/intranet-timesheet2-tasks/add-dependency\">"
    append html [export_vars -form { return_url task_id } ]
    append html "<select name=dependency_id><option value=\"0\">---</option>"
    db_foreach options "select 
        subtree.project_id AS id,
        (repeat('&nbsp;',tree_level(subtree.tree_sortkey)-tree_level(parent.tree_sortkey)) 
         || subtree.project_nr) AS task_nr
      from 
        im_projects parent, im_projects subtree 
      where subtree.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey) 
        and parent.parent_id = :project_id
        AND subtree.project_id != :task_id
      ORDER BY
        subtree.tree_sortkey
    " {
	append html "<option value=\"$id\">$task_nr</option>"
    }
    append html "</select><input type=submit value=\"add dependency\"></form>"
    
    #
    # the two dependency lists
    #

    foreach {a b info} {
	two  one "This task depends on"
	one  two "These tasks depend on this one"
    } {
	append html "<p>$info:"

	db_multirow delete_task_deps_$a delete_task_deps_$a "
            SELECT
                task_id_one,
                task_id_two,
                task_id_$a AS id,
                project_nr,
                project_name
            from 
                im_timesheet_task_dependencies,im_projects
	    where 
                task_id_$b = :task_id AND dependency_type_id=9650
                and task_id_$a = project_id
            "

	template::list::create \
	    -name delete_task_deps_$a \
	    -key task_id_$a \
	    -pass_properties { return_url project_id task_id } \
	    -elements {
		project_nr {
		    label "Task NR"
		    link_url_eval { 
			[return "/intranet-timesheet2-tasks/new?[export_vars -url -override {{ task_id $id }} { return_url project_id } ]" ]
		    }
		} 
		project_name {
		    label "Task Name"
		}
	    } \
	    -bulk_actions {
		"Delete" "/intranet-timesheet2-tasks/delete-dependency" "Delete selected task dependency"
	    } \
	    -bulk_action_export_vars { return_url project_id task_id } \
	    -bulk_action_method post

	    append html [template::list::render -name delete_task_deps_$a]
    }




    return $html
}

# ----------------------------------------------------------------------
# Task Resources Component
# ---------------------------------------------------------------------

ad_proc -public im_timesheet_task_members_component {
    project_id
    task_id
    return_url
} {
    set html ""

    db_multirow member_list member_list "
        SELECT 
            user_id,
            im_name_from_user_id(user_id) as name,
            percentage,
            im_biz_object_members.rel_id AS rel_id
        from 
            acs_rels,users,im_biz_object_members 
        where 
            object_id_two=user_id and object_id_one=:task_id
            and acs_rels.rel_id=im_biz_object_members.rel_id
            "

    template::list::create \
	-name member_list \
	-key user_id \
	-pass_properties { return_url project_id task_id } \
	-elements {
	    name {
		label "Name"
		link_url_eval { 
		    [ return "/intranet/users/view?user_id=$user_id" ]
		}
	    }
	    percentage {
		label "Percentage"
		link_url_eval {
		    [ return "/intranet-timesheet2-tasks/edit-resource?[export_vars -url { return_url rel_id }]" ]
		}
	    }
	} \
	-bulk_actions {
	    "Delete" "/intranet-timesheet2-tasks/delete-resource" "delete resources"
	} \
	-bulk_action_export_vars { return_url project_id task_id } \
	-bulk_action_method post
    
    append html [template::list::render -name member_list ]

    return $html
}


# -------------------------------------------------------------------
# Calculate Project Advance
# -------------------------------------------------------------------

ad_proc im_timesheet_project_advance { project_id } {
    Calculate the percentage of advance of the project.
    The query get a little bit more complex because we
    have to take into account the advance of the subprojects.

    This one only works if the current project is a non-task,
    and all of its children are tasks.
    Otherwise we might have a mixed project (translation + consulting).
} {
    # Don't update the % completed of a task
    set project_type_id [db_string ptype "select project_type_id from im_projects where project_id = :project_id" -default 0]
    if {$project_type_id == [im_project_type_task]} { return }

    # ToDo: Optimize:
    # This procedure is called multiple times for the vaious subtasks of a single project

    db_1row project_advance "
	select
		sum(s.planned_units) as planned_units,
		sum(s.advanced_units) as advanced_units
	from
		(select
		    t.task_id,
		    t.project_id,
		    t.planned_units,
		    t.planned_units * t.percent_completed / 100 as advanced_units
		from
		    im_timesheet_tasks_view t
		where
		    project_id in (
			select
				children.project_id as subproject_id
			from
				im_projects parent,
				im_projects children
			where
				children.project_status_id not in (82,83)
				and children.tree_sortkey between 
				parent.tree_sortkey and tree_right(parent.tree_sortkey)
				and parent.project_id = :project_id
		    )
		) s
    "

    db_dml update_project_advance "
	update im_projects
	set percent_completed = (:advanced_units::numeric / :planned_units::numeric) * 100
	where project_id = :project_id
    "

    # Write audit trail
    im_project_audit $project_id

}



ad_proc -public im_timesheet_next_task_nr { 
    -project_id
} {
    Returns the next free task_nr for the given project

    Returns "" if there was an error calculating the number.
} {
    set nr_digits [parameter::get -package_id [im_package_timesheet_task_id] -parameter "TaskNrDigits" -default "4"]

    # ----------------------------------------------------
    # Get project Info
    set project_nr [db_string project_nr "select project_nr from im_projects where project_id = :project_id" -default ""]

    # ----------------------------------------------------
    # Calculate the next Nr by finding out the last one +1

    set sql "
	select	p.project_nr
	from	im_projects p
	where	p.parent_id = 994
		and p.

    "


    # Adjust the position of the start of date and nr in the invoice_nr
    set date_format_len [string length $date_format]
    set nr_start_idx [expr 1+$date_format_len]
    set date_start_idx 1

    set num_check_sql ""
    set zeros ""
    for {set i 0} {$i < $nr_digits} {incr i} {
	set digit_idx [expr 1 + $i]
	append num_check_sql "
		and ascii(substr(p.nr,$digit_idx,1)) > 47
		and ascii(substr(p.nr,$digit_idx,1)) < 58
	"
	append zeros "0"
    }

    set sql "
	select
		trim(max(p.nr)) as last_project_nr
	from (
		 select substr(project_nr, :nr_start_idx, :nr_digits) as nr
		 from   im_projects
		 where  substr(project_nr, :date_start_idx, :date_format_len) = '$todate'
	     ) p
	where   1=1
		$num_check_sql
    "

    set last_project_nr [db_string max_project_nr $sql -default $zeros]
    set last_project_nr [string trimleft $last_project_nr "0"]
    if {[empty_string_p $last_project_nr]} { set last_project_nr 0 }
    set next_number [expr $last_project_nr + 1]

    # ----------------------------------------------------
    # Put together the new project_nr
    set nr_sql "select '$todate' || trim(to_char($next_number,:zeros)) as project_nr"
    set project_nr [db_string next_project_nr $nr_sql -default ""]
    return $project_nr
}


