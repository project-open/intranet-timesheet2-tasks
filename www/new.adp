<master src="../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="context">@context;noquote@</property>
<property name="main_navbar_label">projects</property>
<property name="focus">@focus;noquote@</property>

<br>
@project_menu;noquote@

<h2>@page_title@</h2>

<if @message@ not nil>
  <div class="general-message">@message@</div>
</if>

<% set return_url [im_url_with_query] %>

<table width="100%">
  <tr valign="top">
    <td width="50%">

      <table cellpadding=2 cellspacing=0 border=1 frame=void width='100%'>
        <tr>
         <td class=tableheader align=left width='99%'>Task</td>
        </tr>
        <tr>
          <td class=tablebody><font size="-1"><formtemplate id="task"></formtemplate></font></td>
        </tr>
      </table>
      <br>

<if @form_mode@ eq "display" >
      <%= [im_component_bay left] %>
</if>

    </td>
    <td width="50%">

<if @form_mode@ eq "display" >
      <%= [im_component_bay right] %>
</if>


    </td>
  </tr>
</table>
