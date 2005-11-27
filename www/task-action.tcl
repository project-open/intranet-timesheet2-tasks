# /packages/intranet-timesheet2-tasks/www/task-action.tcl
#
# Copyright (C) 2003-2005 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Purpose: Takes commands from the /intranet/projects/view
    page and saves changes, deletes tasks etc.

    @param return_url the url to return to
    @param action "delete" and other actions.
    @param submit Not used (may be localized!)
    @task_id List of tasks to be processes

    @author frank.bergmann@project-open.com
} {
    submit
    action
    project_id:integer
    task_id:array,optional
    percent_completed:array,float,optional
    return_url
}

# ----------------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------------

# ToDo: Permissions on hierarchical projects

set current_user_id [ad_maybe_redirect_for_registration]
im_project_permissions $current_user_id $project_id view read write admin
if {!$read} {
    ad_return_complaint 1 "<li>[_ intranet-core.lt_You_have_insufficient_6]"
    return
}



# ----------------------------------------------------------------------
# Batch-process the tasks
# ---------------------------------------------------------------------

set error_list [list]
switch $action {

    save {
    
	set perc_list [array names percent_completed]
	foreach task_id $perc_list {
	    
	    set completed $percent_completed($task_id)

	    if {"" != $completed} {

		if {$completed > 100 || $completed < 0} {
   		    ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2-tasks.Percent_completed_between_0_and_100 "Completion percentage must be a value between 0 and 100"]"
		    return
		}

		if {[catch {
		    set sql "
			update	im_timesheet_tasks
			set	percent_completed = :completed
			where
				task_id = :task_id
		    "
		    db_dml save_tasks $sql
		} errmsg]} {
		    ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2-tasks.Unable_Update_Task "Unable to update task"]"
		    return
		}
	    }
	}


	# Update the total advance of the project

    }

    delete {
    
	set task_list [array names task_id]
	ns_log Notice "task-action: delete: task_list=$task_list"
	
	if {0 == [llength $task_list]} {
	    ad_returnredirect $return_url
	}
	
	# Convert the list of selected tasks into a
	# "task_id in (1,2,3,4...)" clause
	#
	set task_in_clause "and task_id in ([join $task_list ", "])\n"
	ns_log Notice "task-action: delete: task_in_clause=$task_in_clause"
	
    	if {[catch {
	    set sql "
		delete from im_timesheet_tasks
		where
			project_id = :project_id
			$task_in_clause"
	    db_dml delete_tasks $sql
	} errmsg]} {
		
	    set task_list [db_list task_names "select task_name from im_timesheet_tasks where project_id = :project_id $task_in_clause"]
	    set task_names [join $task_list "<li>"]
	    ad_return_complaint 1 "<li><B>[_ intranet-timesheet2-tasks.Unable_to_delete_tasks]</B>:<br>
	    	[_ intranet-timesheet2-tasks.Dependent_Objects_Exist]"
	    return
	}
    }

    default {
	ad_return_complaint 1 "<li>[_ intranet-timesheet2-tasks.Unknown_action_value]: '$action'"
    }
}


ad_returnredirect $return_url

