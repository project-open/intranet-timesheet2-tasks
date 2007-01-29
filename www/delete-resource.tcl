ad_page_contract {

} {
    { user_id:multiple "" }
    task_id
    return_url
}

if { $user_id != "" } {
    foreach i $user_id {
	db_string delete_resource "select im_biz_object_member__delete (:task_id, :user_id);"
    }
}

ad_returnredirect $return_url


