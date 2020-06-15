-- 5.0.3.0.2-5.0.3.0.3.sql
SELECT acs_log__debug('/packages/intranet-timesheet2-tasks/sql/postgresql/upgrade/upgrade-5.0.3.0.2-5.0.3.0.3.sql','');



-- Add difference_format_id to im_timesheet_task_dependencies
--
create or replace function inline_0 () 
returns integer as $body$
DECLARE
	v_count			integer;
BEGIN
	-- Check if colum exists in the database
	select	count(*) into v_count from user_tab_columns 
	where lower(table_name) = 'im_timesheet_task_dependencies' and lower(column_name) = 'difference_format_id';
	IF v_count > 0  THEN return 1; END IF; 

	alter table im_timesheet_task_dependencies add difference_format_id integer
		constraint im_timesheet_task_dep_diff_format_fk references im_categories;    

	return 0;
END;$body$ language 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();


