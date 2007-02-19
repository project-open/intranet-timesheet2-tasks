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
	set new_id $assign_to($old_id)

	db_dml move_hours "UPDATE im_hours SET project_id=:new_id WHERE project_id=:old_id"
	
	db_dml move_dependencies_one "UPDATE im_timesheet_task_dependencies SET task_id_one=:new_id WHERE task_id_one=:old_id"
	db_dml move_dependencies_two "UPDATE im_timesheet_task_dependencies SET task_id_two=:new_id WHERE task_id_two=:old_id"

	db_dml move_children "UPDATE im_projects SET parent_id=:new_id WHERE parent_id=:old_id"

	db_dml move_resources "UPDATE acs_rels SET object_id_one=:new_id WHERE object_id_one=:old_id"
    }
}

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


