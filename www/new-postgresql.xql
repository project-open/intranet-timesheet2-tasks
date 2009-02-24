<?xml version="1.0"?>
<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>


<fullquery name="task_insert">
    <querytext>
	SELECT im_timesheet_task__new (
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
		:note
	);

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
		material_id	= :material_id,
		cost_center_id	= :cost_center_id,
		uom_id 		= :uom_id,
		planned_units	= :planned_units,
		billable_units	= :billable_units
	where
		task_id = :task_id;
    </querytext>
</fullquery>


<fullquery name="project_update">
    <querytext>
	update im_projects set
		project_name	= :task_name,
                parent_id       = :project_id,
		project_nr	= :task_nr,
		project_type_id	= :task_type_id,
		project_status_id = :task_status_id,
		note		= :note,
		percent_completed = :percent_completed,
		start_date      = $start_date_sql,
                end_date        = $end_date_sql

	where
		project_id = :task_id;
    </querytext>
</fullquery>


</queryset>
