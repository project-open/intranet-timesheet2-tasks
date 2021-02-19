# /packages/intranet-timesheet2-tasks/www/task-action.tcl
#
# Copyright (c) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {
    Purpose: Takes commands from the /intranet/projects/view
    page and saves changes, deletes tasks etc.

    @param return_url the url to return to
    @param action "delete" and other actions.
    @param submit Not used (may be localized!)
    @task_id List of tasks to be processes

    @author frank.bergmann@project-open.com
} {
    submit:optional
    action
    project_id:integer
    task_id:array,optional
    task_id_form:array,optional
    percent_completed:array,float,optional
    planned_units:array,float,optional
    billable_units:array,float,optional
    task_status_id:array,integer,optional
    start_date:array,optional
    end_date:array,optional
    return_url
}

# ----------------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------------

set org_project_id $project_id
set current_user_id [auth::require_login]
set all_task_list [array names task_id]

# Append dummy task in case the list is empty
lappend all_task_list 0
set all_task_list [concat $all_task_list [array names task_status_id]]
ns_log Notice "task-action: all_task_list=$all_task_list"

set task_mark_as_closed_workflow_key "task_close_approval_wf"



# ----------------------------------------------------------------------
# Get a hash of all HTTP variables for DynField processing
# ---------------------------------------------------------------------

# Get all variables passed thought the POST
set query_set [ns_parsequery [ns_conn query]]
set form_set [ns_getform]
array set query_hash [ns_set array [ns_set merge $query_set $form_set]]

# ad_return_complaint 1 "[array names query_hash]<br>&nbsp;<br>[llength [array names query_hash]]<br>[array get query_hash]"


# ----------------------------------------------------------------------
# Batch-process the tasks
# ---------------------------------------------------------------------

# Get permissions for the main project
im_project_permissions $current_user_id $project_id view read write admin
set edit_task_estimates_p [im_permission $current_user_id edit_timesheet_task_estimates]
set edit_task_completion_p [im_permission $current_user_id edit_timesheet_task_completion]

set error_list [list]
switch $action {
    save {
	set task_id_list [array names task_status_id]
	if { "" eq $task_id_list } { 
	    ad_return_complaint 1 "Unable to save tasks due to missing variable 'task_id_list'. Please inform your SysAdmin." 
	}

	foreach save_task_id $task_id_list {

	    set task_name [db_string tname "select project_name from im_projects where project_id = :save_task_id" -default ""]
	    set assigned_member_p [db_string assigned_member_p "select count(*) from acs_rels where object_id_one = :save_task_id and object_id_two = :current_user_id" -default 0]
	    set completed ""
	    if {[info exists percent_completed($save_task_id)]} {
		set completed $percent_completed($save_task_id)
	    }
	    set start_date_ansi ""
	    set end_date_ansi ""

	    if { [info exists start_date($save_task_id)] && "" != $start_date($save_task_id) } { 
		if { [catch { set start_date_ansi [clock format [clock scan $start_date($save_task_id)] -format %Y-%m-%d] } ""] } {
		    ad_return_complaint 1 "Wrong date format: $start_date($save_task_id)"
		}
	    }

            if { [info exists end_date($save_task_id)] && "" != $end_date($save_task_id) } {
                if { [catch { set end_date_ansi [clock format [clock scan $end_date($save_task_id)] -format %Y-%m-%d] } ""] } {
                    ad_return_complaint 1 "Wrong date format: $end_date($save_task_id)"
                }
            }

	    # start date > end date ?  
            if { "" != $start_date_ansi && "" != $end_date_ansi } {
		# fraber 120425: https://sourceforge.net/projects/project-open/forums/forum/295937/topic/5217586
		# Adding default values to avoid errors
		if {![info exists start_date($save_task_id)]} { set start_date($save_task_id) "undefined" }
		if {![info exists end_date($save_task_id)]} { set end_date($save_task_id) "undefined" }
		if { [clock scan $end_date_ansi] < [clock scan $start_date_ansi] } {
	            ad_return_complaint 1 "<br>Start Date ($start_date($save_task_id)) is earlier than end date ($end_date($save_task_id)).<br><br>"
		    ad_script_abort
                }
            }

	    if {"" != $completed} {
		if {$completed > 100 || $completed < 0} {
		    ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2-tasks.Percent_completed_between_0_and_100 "Completion percentage '%completed%' for task '%task_name%' must be a value between 0 and 100."]"
		    ad_script_abort
		}
	    }

	    set planned ""
	    if {[info exists planned_units($save_task_id)]} { set planned $planned_units($save_task_id) }
	    if {"" != $planned} {
		if {$planned < 0} {
		    ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2-tasks.Planned_units_positive "Planned Units needs to be a positive number"]"
		    ad_script_abort
		}
	    }

	    set billable ""
	    if {[info exists billable_units($save_task_id)]} { set billable $billable_units($save_task_id) }
	    if {"" != $billable} {
		if {$billable < 0} {
		    ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2-tasks.Billable_units_positive "Billable Units needs to be a positive number"]"
		    ad_script_abort
		}
	    }

	    set status_id ""
	    if {[info exists task_status_id($save_task_id)]} { set status_id $task_status_id($save_task_id) }
	    if {![string is integer $status_id]} {
		set status_id ""
	    }

	    if {[catch {

		# Exception: Allow to write %completed to certain assigned users
		if {$write || ($assigned_member_p && $edit_task_completion_p)} {
		    db_dml save_tasks_to_project "
			update	im_projects
			set	percent_completed = :completed
			where	project_id = :save_task_id
		    "
		}

		# Writing any other values requires write permissions on the main project:

		if {$write} {
		    if {"" != $planned || "" != $billable} {
			db_dml save_tasks_to_ts_task "
			update	im_timesheet_tasks
			set	planned_units = :planned,
				billable_units = :billable
			where	task_id = :save_task_id
		        "
		    }

		    if {"" != $status_id} {
			db_dml save_project_status "
			update	im_projects
			set	project_status_id = :status_id
			where	project_id = :save_task_id
		        "
		    }

		    # Writing Start Date 
		    if { "" != $start_date_ansi } {
                	db_dml save_project_start_date "
                        	update  im_projects
	                        set     start_date = '$start_date_ansi'
                                where   project_id = :save_task_id
        	         "
		    }

		    # Writing End Date 
		    if { "" != $end_date_ansi } {
                        db_dml save_project_end_date "
                                update  im_projects
                                set     end_date = '$end_date_ansi'
                                where   project_id = :save_task_id
                         "
		    }

		}

	    } errmsg]} {
		ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2-tasks.Unable_Update_Task "Unable to update task:<br><pre>$errmsg</pre>"]"
		ad_script_abort
	    }


	    # -----------------------------------------------
	    # Save DynFields
	    set dynfield_tuples [im_sencha_dynfields -object_type "im_timesheet_task"]
	    # ad_return_complaint 1 $dynfield_tuples

	    foreach dynfield_tuple $dynfield_tuples {
		set dynfield_name [lindex $dynfield_tuple 0]
		set var_name "$dynfield_name.$save_task_id"
		if {[info exists query_hash($var_name)]} {
		    set new_val $query_hash($var_name)
		    set cur_val [db_string cur "select $dynfield_name from im_timesheet_tasks where task_id = :save_task_id" -default ""]
		    if {$cur_val != $new_val} {
			db_dml update "update im_timesheet_tasks set $dynfield_name = :new_val where task_id = :save_task_id"
		    }
		}
	    }

	    # Audit the action
	    im_audit -action after_update -object_id $save_task_id
	}
    }

    delete {
	# Check permissions on the enclosing project
	if {!$write} {
	    ad_return_complaint 1 "<li>[_ intranet-core.lt_You_have_insufficient_6]"
	    ad_script_abort
	}

	# We need to sort the task_ids in reverse order of their tree_sortkey,
	# so that we delete the sub-tasks first before deleting their parents...
	set task_id_names [array names task_id]
	lappend task_id_names 0
	set task_list_sql "
		select	project_id
		from	im_projects p
		where	project_id in ([join $task_id_names ","])
		order by tree_sortkey DESC
        "
	set delete_task_list [db_list task_list $task_list_sql]

	
	set task_names [join $delete_task_list "<li>"]
	ns_log Notice "task-action: delete_task_list='$delete_task_list'"
	if {0 == [llength $delete_task_list]} { ad_returnredirect $return_url }
	
	# Check if timesheet entries exist. We don't want to delete them...
	set timesheet_sql "
		select	hour_id
		from	im_hours 
		where	project_id in ([join $delete_task_list ", "])
	    UNION
		select	cost_id
		from	im_costs
		where	project_id in ([join $delete_task_list ", "])
        "
	set timesheet_hours_exist_p [db_string timesheet_hours_exist "select count(*) from ($timesheet_sql) t"]
	if {$timesheet_hours_exist_p} {
	    ad_return_complaint 1 "<li><B>[_ intranet-timesheet2-tasks.Unable_to_delete_tasks]</B>:<br>
                [_ intranet-timesheet2-tasks.Dependent_Objects_Exist]"
            ad_script_abort
	}

    	if {[catch {
	    foreach del_task_id $delete_task_list {
		set task_parent_id [db_string task_parent_id "select parent_id from im_projects where project_id = :del_task_id" -default ""]
		if {"" == $task_parent_id} {
		    # Found the main project. We don't want to delete this project.
		    continue 
		}
		im_project_nuke $del_task_id
	    }
	} errmsg]} {
	    set task_names [join $delete_task_list "<li>"]
	    ad_return_complaint 1 "<li><B>[_ intranet-timesheet2-tasks.Unable_to_delete_tasks]</B>:<br>
	    	[_ intranet-timesheet2-tasks.Dependent_Objects_Exist]<br>
		<pre>$errmsg</pre>"
	    ad_script_abort
	}
    }

    close {
	# Close the task if permissions are OK, or start a workflow
	set mark_as_done_html ""
	set task_list [array names task_id]
	set task_names [join $task_list "<li>"]
	if {0 == [llength $task_list]} { ad_returnredirect $return_url }

	set task_list_sql "
		select	p.project_id,
			o.object_type,
			p.project_type_id,
			(	select count(*) from acs_rels r, im_biz_object_members bom 
				where r.rel_id = bom.rel_id and r.object_id_two = :current_user_id and r.object_id_one = :project_id
			) as assigned_p
		from	im_projects p,
			acs_objects o
		where	p.project_id = o.object_id and
			p.project_id in ([join $task_list ","])
	"
	set tuples [db_list_of_lists tasks $task_list_sql]

	foreach tuple $tuples {
	    # Extract the paramters from the tuple
	    set project_id [lindex $tuple 0]
	    set object_type [lindex $tuple 1]
	    set project_type_id [lindex $tuple 2]
	    set assigned_p [lindex $tuple 3]

	    # Get the general object permissions
	    set perm_cmd "${object_type}_permissions \$current_user_id \$project_id object_view object_read object_write object_admin"
	    eval $perm_cmd

	    # Close the ticket
	    switch $project_type_id {
		100 - 101 {
		    # 100=task, 101=ticket

		    # Close the task if the user has write permissions or is explicitely assigned to the task
		    if {$write || $assigned_p} {
			db_dml close_task "update im_projects set project_status_id = [im_project_status_closed] where project_id = :project_id"
			im_audit -object_id $project_id
		    } else {
			append mark_as_done_html "<li>You don't have permission to close project/task #$project_id.\n"
		    }
		}
		default {
		    # "Normal" projects
		    if {$write} {
			# The user has direct write permissions on the object - just close
			db_dml close_task "update im_projects set project_status_id = [im_project_status_closed] where project_id = :project_id"
			im_audit -object_id $project_id
		    } else {
			append mark_as_done_html "<li>You don't have permission to close project #$project_id.\n"
		    }
		}
	    }

	    # Check if the user was asigned but has no write permission.
	    # Start a workflow in this case
	    switch $project_type_id {
		100 - 101 {
		    # 100=task, 101=ticket
		    if {$assigned_p && !$write && [im_table_exists wf_workflows]} {
			# Check if there is a WF associated with the project type
			set workflow_key $task_mark_as_closed_workflow_key
			set wf_exists_p [db_string wf_exists "select count(*) from wf_workflows where workflow_key = :workflow_key"]
			
			# Check if there is a running WF already
			set wf_already_running_p [db_string wf_exists "
				select count(*) from wf_cases where workflow_key = :workflow_key and object_id = :project_id and state != 'finished'
			" -default 0]

			if {$wf_exists_p && !$wf_already_running_p} {
			    # Create a new workflow case (instance)
			    set context_key ""
			    set case_id [wf_case_new \
					     $workflow_key \
					     $context_key \
					     $project_id \
					    ]
			    # Determine the first task in the case to be executed and start+finisch the task.
			    im_workflow_skip_first_transition -case_id $case_id
			}
		    }		    
		}
		default {
		    # Ignore the normal projects
		}
	    }
	}
	if {"" != $mark_as_done_html} {
	    ad_return_complaint 1 "$mark_as_done_html"
	}
    }

    default {
	ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2-tasks.Unknown_action_value "Unknown action value"]: '$action'"
	ad_script_abort
    }
}

# Update the total advance of the project. Includes audit
if {"" != $org_project_id && 0 != $org_project_id} {
    im_timesheet_project_advance $org_project_id
}


ad_returnredirect $return_url

