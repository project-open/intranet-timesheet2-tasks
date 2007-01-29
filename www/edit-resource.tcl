ad_page_contract {
} {
    rel_id
    return_url
}

set action_url "xxx"

ad_form \
    -name edit_resource \
    -cancel_url $return_url \
    -action "/intranet-timesheet2-tasks/edit-resource" \
    -actions { edit } \
    -mode edit \
    -export {next_url user_id return_url} \
    -form {
	rel_id:key
	{percentage:float(text),optional {label "Percentage"} {html {size 10}}}
    }


ad_form -extend -name edit_resource -on_request {

} -select_query {

  select 
    percentage
  from
    im_biz_object_members
  where
    rel_id=:rel_id

} -edit_data {

    db_dml edit_resource "UPDATE im_biz_object_members SET percentage=:percentage WHERE rel_id=:rel_id"

} -after_submit {
    
    ad_returnredirect $return_url
    ad_script_abort
    
}

