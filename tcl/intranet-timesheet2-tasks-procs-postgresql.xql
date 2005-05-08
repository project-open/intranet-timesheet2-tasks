<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-material/tcl/intranet-material-procs-postgresql.xql -->
<!-- @author  (frank.bergmann@project-open.com) -->
<!-- @creation-date 2005-05-14 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>

  <fullquery name="im_timesheet_task_list_component.task_query">
    <querytext>
select
	t.*,
	im_category_from_id(t.task_type_id) as task_type,
	im_category_from_id(t.task_status_id) as task_status,
	im_material_nr_from_id(t.material_id) as material_nr
from
        im_timesheet_tasks t
where
	t.project_id = :restrict_to_project_id
	$restriction_clause
$order_by_clause

    </querytext>
  </fullquery>

</queryset>
