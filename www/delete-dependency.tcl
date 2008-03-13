ad_page_contract {

} {
    { task_id_one:multiple,optional "" }
    { task_id_two:multiple,optional "" }
    task_id
    return_url
}

set current_user_id [ad_maybe_redirect_for_registration]
im_timesheet_task_permissions $current_user_id $task_id view read write admin
if {!$write} {
    ad_return_complaint 1 "You don't have sufficient permissions to perform this operation"
    ad_script_abort
}


if { $task_id_one != "" } {
    foreach i $task_id_one {
	db_dml delete_dependency1 "delete from im_timesheet_task_dependencies where task_id_one=:i and task_id_two=:task_id"
    }
} elseif { $task_id_two != "" } {
    foreach i $task_id_two {
	db_dml delete_dependency2 "delete from im_timesheet_task_dependencies where task_id_one=:task_id and task_id_two=:i"
    }
}

ad_returnredirect $return_url


