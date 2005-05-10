<?xml version="1.0"?>
<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>


<fullquery name="task_insert">
    <querytext>
    BEGIN
	PERFORM im_timesheet_task__new (
		:task_id,		-- p_task_id
		'im_timesheet_task',	-- object_type
		now(),			-- creation_date
		null,			-- creation_user
		null,			-- creation_ip
		null,			-- context_id

		:task_nr,
		:task_name,
		:project_id,
		:material_id,
		:cost_center_id,
		:uom_id,
		:task_type_id,
		:task_status_id,
		:description
	);
	return 0;
    END;
    </querytext>
</fullquery>


<fullquery name="task_delete">
    <querytext>
    BEGIN
	PERFORM im_task__delete (:task_id);
	return 0;
    END;
    </querytext>
</fullquery>


<fullquery name="task_update">
    <querytext>
	update im_timesheet_tasks set
                task_name	= :task_name,
                task_nr		= :task_nr,
		project_id	= :project_id,
		material_id	= :material_id,
		cost_center_id	= :cost_center_id,
                task_type_id	= :task_type_id,
                task_status_id	= :task_status_id,
		uom_id 		= :uom_id,
		planned_units	= :planned_units,
		billable_units	= :billable_units,
                description	= :description
        where
		task_id = :task_id;
    </querytext>
</fullquery>


</queryset>
