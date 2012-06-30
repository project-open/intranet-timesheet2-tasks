ad_page_contract {

} {
    { task_id:optional,multiple "" }
    { assign_to:optional,array "" }
    project_id
    return_url
}

#
# move task related things before it gets deleted
#

foreach old_id $task_id {

    if {[info exists assign_to($old_id)]} {

	# Audit the action
	im_audit -object_type "im_timesheet_task" -object_id $old_id -action before_nuke


	set new_id $assign_to($old_id)

	# Delete dependencies. This may "split" the Gantt-network, but 
	# everything else would cause very funny results, probably.
	db_dml del_dependencies_one "DELETE from im_timesheet_task_dependencies WHERE task_id_one = :old_id"
	db_dml del_dependencies_two "DELETE from im_timesheet_task_dependencies WHERE task_id_two = :old_id"

	# Join logged hours.
	# This is complicated, because a user can only log 1 record per day and project.
	# We start by getting all the hours to move and then we add them to the new 
	# ones. We need to get a list_of_lists first, because we're going to delete stuff
	# inside the loop then.
	set old_hours_list_list [db_list_of_lists old_hours "
		select	h.user_id as old_user_id,
			h.project_id as old_project_id,
			h.day::date as old_day,
			h.hours as old_hours,
			h.billing_rate as old_billing_rate,
			h.billing_currency as old_billing_currency,
			h.note as old_note,
			h.cost_id as old_cost_id
		from	im_hours h
		where	h.project_id = :old_id
	"]

	foreach hours_tuple $old_hours_list_list {

	    set old_user_id [lindex $hours_tuple 0]
	    set old_project_id [lindex $hours_tuple 1]
	    set old_day [lindex $hours_tuple 2]
	    set old_hours [lindex $hours_tuple 3]
	    set old_billing_rate [lindex $hours_tuple 4]
	    set old_billing_currency [lindex $hours_tuple 5]
	    set old_note [lindex $hours_tuple 6]
	    set old_cost_id [lindex $hours_tuple 7]

	    ns_log Notice "task-delete: old_user_id=$old_user_id, old_project_id=$old_project_id, old_day=$old_day, old_hours=$old_hours, old_billing_rate=$old_billing_rate, old_billing_currency=$old_billing_currency, old_note=$old_note, old_cost_id=$old_cost_id"

	    # Reset the cost_id record of im_hours to null so that we can del the cost item
	    # and delete the cost item. The Timesheet sweeper will take care of it afterwards.
	    db_dml nul_cost_item "
		update	im_hours
		set	cost_id = null
		where	user_id = :old_user_id 
			and project_id = :old_project_id
			and day::date = :old_day::date
	    "
	    db_list del_cost_item "select im_cost__delete(cost_id) from im_costs where cost_id = :old_cost_id"

	    # Get the logged hours of the new task (if there were logged hours)
	    set new_hours 0
	    set new_note ""
	    set new_cost_id 0
	    set new_exists_p 0
	    db_0or1row new_hours "
		select	h.hours as new_hours,
			h.note as new_note,
			h.cost_id as new_cost_id,
			1 as new_exists_p
		from	im_hours h
		where	h.user_id = :old_user_id
			and h.project_id = :new_id
			and h.day::date = :old_day::date
	    "

	    # Reset the cost_id record of im_hours to null so that we can del the cost item
	    # and delete the cost item. The Timesheet sweeper will take care of it afterwards.
	    db_dml nul_cost_item "
		update	im_hours
		set	cost_id = null
		where	user_id = :old_user_id 
			and project_id = :new_id
			and day::date = :old_day::date
	    "
	    db_list del_cost_item "select im_cost__delete(cost_id) from im_costs where cost_id = :new_cost_id"

	    # Delete the "new" im_hours entries (if exists)
	    db_dml del_new_hours "
		delete from im_hours
		where	user_id = :old_user_id 
			and project_id = :new_id
			and day::date = :old_day::date
	    "

	    set hours [expr $old_hours + $new_hours]
	    set note [string trim [join [list $old_note $new_note] " "]]

	    # Insert a new im_hours entry with the summed up hours
	    db_dml insert "
		insert into im_hours (user_id, project_id, day, hours, billing_rate, billing_currency, note)
		values (:old_user_id, :new_id, :old_day::date, :hours, :old_billing_rate, :old_billing_currency, :note)
	    "
	}

	# Delete the old im_hours entries.
	db_dml del_hours "delete from im_hours where project_id = :old_id"


	# Move sub-projects and sub-tasks to the new project.
	# Financial caches are updated automatically (nice test for the trigger, actually...)
	db_dml move_children "UPDATE im_projects SET parent_id = :new_id WHERE parent_id = :old_id"

	# Delete membership relationships
	# The old task is gone, so user assignments to that task are also gone. Right?
	set rel_ids [db_list rels "select rel_id from acs_rels where object_id_one = :old_id"]
	foreach rel_id $rel_ids {
	    ns_log Notice "task-delete: acs_object__delete($rel_id)"
	    db_dml del_gantt "delete from im_gantt_assignment_timephases where rel_id = :rel_id"
	    db_dml del_gantt "delete from im_gantt_assignments where rel_id = :rel_id"
	    db_string del_rel "select acs_object__delete(:rel_id)"
	}

	# Move cost information
	db_dml move_costs "UPDATE im_costs SET project_id = :new_id WHERE project_id = :old_id"
	# ToDo: cost-project relationships with acs_rels


	# Audit the action on new_id
	im_audit -object_type "im_timesheet_task" -object_id $new_id -action after_update

    }
}


# Create the necessary cost items for the timesheet hours
im_timesheet2_sync_timesheet_costs

# Update timesheet caches
im_cost_cache_sweeper


#
# Using "/intranet-timesheet2-tasks/task-action" to the deletion
# 

# /task-action expects the task_id as an array
set tmp $task_id
unset task_id
array set task_id {}
foreach i $tmp {
    set task_id($i) $i
}

set vars [export_vars -url {task_id:array project_id return_url}]

ad_returnredirect "/intranet-timesheet2-tasks/task-action?action=delete&$vars"


