SELECT acs_log__debug('/packages/intranet-timesheet2-tasks/sql/postgresql/upgrade/upgrade-5.0.3.0.3-5.0.3.0.4.sql','');

delete from im_view_columns where column_id = 91112;

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (91112,911,NULL, 
'"<input id=list_check_all type=checkbox name=_dummy"',
'"<input type=checkbox name=task_id.$task_id id=tasks,$task_id>"', '', '', -1, '');
