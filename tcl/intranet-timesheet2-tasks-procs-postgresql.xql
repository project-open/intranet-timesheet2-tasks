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

  <fullquery name="im_material_list_component.material_query">
    <querytext>
select
	m.*,
	im_category_from_id(m.material_type_id) as material_type,
	im_category_from_id(m.material_status_id) as material_status,
	im_category_from_id(m.material_uom_id) as uom
from
        im_materials m
where
	$restriction_clause
$order_by_clause

    </querytext>
  </fullquery>

</queryset>
