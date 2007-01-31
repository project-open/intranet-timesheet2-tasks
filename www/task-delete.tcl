ad_page_contract {

} {
    { task_id:optional,multiple "" }
    project_id
    return_url
}

#
# Using "/intranet-timesheet2-tasks/task-action"
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


