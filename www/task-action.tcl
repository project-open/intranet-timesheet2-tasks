# /packages/intranet-forum/www/intranet/forum/forum-action.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Purpose: Takes commands from the /intranet/projects/view
    page and saves changes, deletes tasks and scans for Trados
    files.

    @param return_url the url to return to
    @param group_id group id

    @author frank.bergmann@project-open.com
} {
    submit
    action
    topic_id:array,optional
    {return_url ""}
}

set user_id [ad_maybe_redirect_for_registration]
set page_body "<PRE>\n"

if {$return_url == ""} {
    set return_url "/intranet-forum/"
}

set topic_list [array names topic_id]
ns_log Notice "forum-action: topic_list=$topic_list"

if {0 == [llength $topic_list]} {
    ad_returnredirect $return_url
}

# Make sure the respective im_forum_topic_user_map entries exist:
foreach topic_insert_id $topic_list {
    if { [catch {
	db_dml insert_forum_topic_map "insert into im_forum_topic_user_map 
        (topic_id, user_id) values ($topic_insert_id, $user_id)"
    } err_msg] } {
	# nothing - probably existed before
    }
}


# Convert the list of selected topics into a
# "topic_id in (1,2,3,4...)" clause
#
set topic_in_clause "and topic_id in ("
append topic_in_clause [join $topic_list ", "]
append topic_in_clause ")\n"
ns_log Notice "forum-action: topic_in_clause=$topic_in_clause"

switch $action {

    move_to_deleted {
	set sql "
			update im_forum_topic_user_map
			set folder_id = 1
			where
				user_id=:user_id
				$topic_in_clause"
	db_dml mark_topics $sql
    }

    move_to_inbox {
	set sql "
			update im_forum_topic_user_map
			set folder_id = 0
			where	user_id=:user_id
				$topic_in_clause"
	db_dml mark_topics $sql
    }

    mark_as_read {
	set sql "
			update im_forum_topic_user_map
			set read_p = 't'
			where	user_id=:user_id
				$topic_in_clause"
	db_dml mark_topics $sql
    }

    mark_as_unread {
	set sql "
			update im_forum_topic_user_map
			set read_p = 'f'
			where	user_id=:user_id
				$topic_in_clause"
	db_dml mark_topics $sql
    }

    default {
	ad_return_complaint 1 "<li>[_ intranet-forum.lt_Unknown_value_for_act]: '$action'"
    }
}

ad_returnredirect $return_url

