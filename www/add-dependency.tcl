ad_page_contract {

} {
    task_id
    dependency_id
    return_url
}

# TODO: security

db_dml insert_dependency "
		insert into im_timesheet_task_dependencies 
		(task_id_one, task_id_two, dependency_type_id) values (:task_id, :dependency_id, 9650)
 	"



ad_returnredirect $return_url


