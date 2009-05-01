<master src="../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="context">@context;noquote@</property>
<property name="main_navbar_label">projects</property>
<property name="focus">@focus;noquote@</property>
<property name="sub_navbar">@sub_navbar;noquote@</property>


<if @message@ not nil>
  <div class="general-message">@message@</div>
</if>

<% set return_url [im_url_with_query] %>

<table width="100%">
  <tr valign="top">
    <td width="50%">
      <%= [im_box_header $base_component_title] %>
      <formtemplate id="task"></formtemplate>
      <%= [im_box_footer] %>

<if @form_mode@ eq "display" >
      <%= [im_component_bay left] %>
</if>

    </td>

<if @form_mode@ eq "display" >
    <td width="50%">
      <%= [im_component_bay right] %>
    </td>
</if>

  </tr>
</table>
