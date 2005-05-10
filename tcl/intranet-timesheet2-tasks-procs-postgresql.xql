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
	p.*,
	im_category_from_id(t.task_type_id) as task_type,
	im_category_from_id(t.task_status_id) as task_status,
	im_category_from_id(t.uom_id) as uom,
	im_material_nr_from_id(t.material_id) as material_nr
from
        im_timesheet_tasks t,
	im_projects p
where
	t.project_id = p.project_id and
	$project_restriction
	$restriction_clause
$order_by_clause

    </querytext>
  </fullquery>


  <fullquery name="im_timesheet_task_list_component.task_subprojects">
    <querytext>

select
	children.project_id as subproject_id,
	children.project_nr as subproject_nr,
	children.project_name as subproject_name,
	tree_level(children.tree_sortkey) -
	tree_level(parent.tree_sortkey) as subproject_level
from
	im_projects parent,
	im_projects children
where
	children.project_status_id not in ([im_project_status_deleted],[im_project_status_canceled])
	and children.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)
	and parent.project_id = :restrict_to_project_id
order by 
	children.tree_sortkey

      </querytext>
    </fullquery>


</queryset>
