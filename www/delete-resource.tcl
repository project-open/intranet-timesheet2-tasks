ad_page_contract {

} {
    { user_id:multiple "" }
    task_id
    return_url
}


set current_user_id [ad_maybe_redirect_for_registration]
im_timesheet_task_permissions $current_user_id $task_id view read write admin
if {!$write} {
    ad_return_complaint 1 "You don't have sufficient permissions to perform this operation"
    ad_script_abort
}

# Check if we've got a list of lists, instead of a simple list
set sub_list_len [llength [lindex $user_id 0]]
if {$sub_list_len > 1} {
    set user_id [lindex $user_id 0]
}


if { $user_id != "" } {
    foreach i $user_id {
	db_string delete_resource "select im_biz_object_member__delete (:task_id, :i);"
    }
}

ad_returnredirect $return_url


