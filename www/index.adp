<!-- packages/intranet-forum/www/index.adp -->
<!-- @author Frank Bergmann (frank.bergmann@project-open.com) -->

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<master src="../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="context">@context_bar@</property>
<property name="main_navbar_label">projects</property>
<property name="sub_navbar">@sub_navbar;noquote@</property>


<table border=0 cellpadding=0 cellspacing=0>
<tr>
  <td> <!-- TD for the left hand filter HTML -->

	    <table border=0 cellpadding=0 cellspacing=0>
	    <tr>
	      <td class=rowtitle align=center>
		<%= [lang::message::lookup "" intranet-timesheet2.Filter_Tasks "Filter Tasks"] %>
	      </td>
	    </tr>
	    <tr>
	      <td>
		<formtemplate id=@form_id@</formtemplate>
	      </td>
	    </tr>
	    </table>

  </td> <!-- end of left hand filter TD -->
  <td>&nbsp;</td>
  <td valign=top width='30%'>

	    <table border=0 cellpadding=0 cellspacing=0>
	    <tr>
	      <td class=rowtitle align=center>
	        #intranet-core.Admin_Links#
	      </td>
	    </tr>
	    <tr>
	      <td>
		@admin_links;noquote@
	      </td>
	    </tr>
	    </table>

  </td>
</tr>
</table>

<br>

@task_content;noquote@
