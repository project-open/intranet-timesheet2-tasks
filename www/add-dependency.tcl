ad_page_contract {

} {
    task_id
    dependency_id
    return_url
}

set current_user_id [ad_maybe_redirect_for_registration]
im_timesheet_task_permissions $current_user_id $task_id view read write admin
if {!$write} {
    ad_return_complaint 1 "You don't have sufficient permissions to perform this operation"
    ad_script_abort
}


db_dml insert_dependency "
		insert into im_timesheet_task_dependencies 
		(task_id_one, task_id_two, dependency_type_id) values (:task_id, :dependency_id, 9650)
 	"



ad_returnredirect $return_url


