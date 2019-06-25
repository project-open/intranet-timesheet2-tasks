ad_page_contract {

} {
    task_id
    dependency_id
    return_url
    { dependency_type_id 9662 }
}

set current_user_id [auth::require_login]
im_timesheet_task_permissions $current_user_id $task_id view read write admin
if {!$write} {
    ad_return_complaint 1 "You don't have sufficient permissions to perform this operation"
    ad_script_abort
}


# Default is 9662 = FS (finish-to-start) dependency
db_dml insert_dependency "
		insert into im_timesheet_task_dependencies 
		(task_id_one, task_id_two, dependency_type_id) values (:task_id, :dependency_id, :dependency_type_id)
"

ad_returnredirect $return_url


