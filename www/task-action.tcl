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

set org_project_id $project_id

set current_user_id [ad_maybe_redirect_for_registration]
im_project_permissions $current_user_id $project_id view read write admin
if {!$read} {
    ad_return_complaint 1 "<li>[_ intranet-core.lt_You_have_insufficient_6]"
    return
}

set all_task_list [array names task_id]
# Append dummy task in case the list is empty
lappend all_task_list 0
set all_task_list [concat $all_task_list [array names percent_completed]]
ns_log Notice "task-action: all_task_list=$all_task_list"


set perm_sql "
	select distinct
		project_id
	from	im_timesheet_tasks t
	where	t.task_id in ([join $all_task_list ", "])
"
db_foreach perm $perm_sql {

    im_project_permissions $current_user_id $project_id view read write admin
    set write_project($project_id) $write

}

# ----------------------------------------------------------------------
# Batch-process the tasks
# ---------------------------------------------------------------------

set error_list [list]
switch $action {

    save {
    
	set perc_list [array names percent_completed]
	foreach save_task_id $perc_list {

	    set completed $percent_completed($save_task_id)
	    set project_id_sql "select project_id from im_timesheet_tasks where task_id = :save_task_id"
	    set project_id [db_string project_id $project_id_sql -default 0]

	    if {"" != $completed && [info exists write_project($project_id)]} {

		if {$completed > 100 || $completed < 0} {
   		    ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2-tasks.Percent_completed_between_0_and_100 "Completion percentage must be a value between 0 and 100"]"
		    return
		}

		if {[catch {
		    set sql "
			update	im_timesheet_tasks
			set	percent_completed = :completed
			where
				task_id = :save_task_id
		    "
		    db_dml save_tasks $sql
		} errmsg]} {
		    ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2-tasks.Unable_Update_Task "Unable to update task"]"
		    return
		}
	    }
	}
    }

    delete {
    
	set delete_task_list [array names task_id]
	set task_names [join $delete_task_list "<li>"]
	if {0 == [llength $delete_task_list]} {
	    ad_returnredirect $return_url
	}
	
	# Convert the list of selected tasks into a
	# "task_id in (1,2,3,4...)" clause
	#
	set timesheet_task_list "([join $delete_task_list ", "])\n"
	ns_log Notice "task-action: delete: timesheet_task_list=$timesheet_task_list"
	
	# Check if timesheet entries exist
	# We don't want to delete them...
	set timesheet_sql "
		select count(*) 
		from im_hours 
		where timesheet_task_id in $timesheet_task_list"
	set timesheet_hours_exist_p [db_string timesheet_hours_exist $timesheet_sql]
	if {$timesheet_hours_exist_p} {
	    ad_return_complaint 1 "<li><B>[_ intranet-timesheet2-tasks.Unable_to_delete_tasks]</B>:<br>
                [_ intranet-timesheet2-tasks.Dependent_Objects_Exist]"
            return
	}

    	if {[catch {
	    set sql "
		delete	from im_timesheet_tasks
		where	task_id in $timesheet_task_list"
	    db_dml delete_tasks $sql
	} errmsg]} {
		
	    set task_names [join $delete_task_list "<li>"]
	    ad_return_complaint 1 "<li><B>[_ intranet-timesheet2-tasks.Unable_to_delete_tasks]</B>:<br>
	    	[_ intranet-timesheet2-tasks.Dependent_Objects_Exist]<br>
		<pre>$errmsg</pre>"
	    return
	}
    }

    default {
	ad_return_complaint 1 "<li>[_ intranet-timesheet2-tasks.Unknown_action_value]: '$action'"
	return
    }
}

# Update the total advance of the project
im_timesheet_project_advance $org_project_id

ad_returnredirect $return_url

