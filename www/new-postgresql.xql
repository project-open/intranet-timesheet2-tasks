<?xml version="1.0"?>
<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>


<fullquery name="material_insert">
    <querytext>
    BEGIN
	PERFORM im_material__new (
		:material_id,		-- p_material_id
		'im_material',		-- object_type
		now(),			-- creation_date
		null,			-- creation_user
		null,			-- creation_ip
		null,			-- context_id
		:material_name,
		:material_nr,
		:material_type_id,
		:material_status_id,
		:material_uom_id,
		:description
	);
	return 0;
    END;
    </querytext>
</fullquery>


<fullquery name="material_delete">
    <querytext>
    BEGIN
	PERFORM im_material__delete (:material_id);
	return 0;
    END;
    </querytext>
</fullquery>


<fullquery name="material_update">
    <querytext>
	update im_materials set
                material_name	= :material_name,
                material_nr	= :material_nr,
                material_type_id= :material_type_id,
                material_status_id=material_status_id,
		material_uom_id = :material_uom_id,
                description	= :description
        where
		material_id = :material_id;
    </querytext>
</fullquery>


</queryset>
