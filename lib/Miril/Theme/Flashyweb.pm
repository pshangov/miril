package Miril::Theme::Flashyweb;

use strict;
use warnings;

### TEMPLATES ###

my $account = <<EndOfHTML;

<TMPL_VAR NAME="header">

	<TMPL_LOOP NAME="user">
	<!-- start content -->
	<div id="content">
		<div class="post">
			<h2 class="title"><span class="dingbat">&#x273b;</span> <TMPL_VAR NAME="username"></h2>
			<div class="edit">
				<form method="POST">
					<p class="edit">Name <span class="required">*</span>:<br>
					<input type="text" name="name" class="textbox" value='<TMPL_VAR NAME="name">' /></p>

					<p class="edit">Email: <span class="required">*</span><br>
					<input type="text" name="email" class="textbox" value='<TMPL_VAR NAME="email">' /></p>

					<p class="edit">New password:<br>
					<input type="password" name="new_password" class="textbox" />
					</p>

					<p class="edit">Retype new password:<br>
					<input type="password" name="new_password_2" class="textbox" />
					</p>

					<p class="edit">Existing password: <span class="required">*</span><br>
					<input type="password" name="password" class="textbox" />
					</p>

					<input type="hidden" name="username" value='<TMPL_VAR NAME="username">' />

					<button type="submit" id="x" name="action" value="update_user">Save</button>&nbsp;&nbsp;&nbsp;&nbsp;
					<button type="submit" id="x" name="action" value="list">Cancel</button>

					<p class="edit"><span class="required">* - Required fields</span></p>
				</form>
			</div>
		</div>
	</div>
	<!-- end content -->
	</TMPL_LOOP>


<TMPL_VAR NAME="footer">

EndOfHTML

my $edit = <<EndOfHTML;

<TMPL_VAR NAME="header">

	<TMPL_LOOP NAME="item">
	<!-- start content -->
	<div id="content">
		<div class="post">
			<h2 class="title"><TMPL_IF NAME="selected"><TMPL_VAR NAME="title"><TMPL_ELSE>New Article</TMPL_IF></h2>
			<div class="edit">
				<form method="POST">
					<p class="edit">Title:<br>
					<input type="text" name="title" class="textbox" value='<TMPL_VAR NAME="title">' /></p>

					<p class="edit">ID:<br>
					<input type="text" name="id" class="textbox" value='<TMPL_VAR NAME="id">' /></p>
					
					<p class="edit">Type:<br>
					<select name="type">
					<TMPL_LOOP NAME="types">
						<option value='<TMPL_VAR NAME="cfg_m_type">'<TMPL_IF NAME="selected"> selected="selected"</TMPL_IF>><TMPL_VAR NAME="cfg_type"></option>
					</TMPL_LOOP>
					</select>
					</p>

					<TMPL_IF NAME="has_authors">
					<p class="edit">Author:<br>
					<select name="author">
					<TMPL_LOOP NAME="authors">
						<option value='<TMPL_VAR NAME="cfg_author">'><TMPL_VAR NAME="cfg_author"></option>
					</TMPL_LOOP>
					</select>
					</p>
					</TMPL_IF>

					<p class="edit">Status:<br>
					<select name="status">
					<TMPL_LOOP NAME="statuses">
						<option value='<TMPL_VAR NAME="cfg_status">'<TMPL_IF NAME="selected"> selected="selected"</TMPL_IF>><TMPL_VAR NAME="cfg_status"></option>
					</TMPL_LOOP>
					</select>
					</p>

					<TMPL_IF NAME="has_topics">
					<p class="edit">Topic:<br>
					<select name="topic">
					<TMPL_LOOP NAME="topics">
						<option value='<TMPL_VAR NAME="cfg_topic_id">'<TMPL_IF NAME="selected"> selected="selected"</TMPL_IF>><TMPL_VAR NAME="cfg_topic"></option>
					</TMPL_LOOP>
					</select>
					</p>
					</TMPL_IF>

					<p class="edit" name="text">Text:<br>
					<textarea name="text"><TMPL_VAR NAME="text"></textarea></p>

					<input type="hidden" name="o_id" value='<TMPL_VAR NAME="id">' />

					<button type="submit" id="x" name="action" value="update">Save</button>&nbsp;&nbsp;&nbsp;&nbsp;
					<button type="submit" id="x" name="action" value="update_cont">Save and continue editing</button>&nbsp;&nbsp;&nbsp;&nbsp;
					<button type="submit" id="x" name="action" value="delete">Delete</button>&nbsp;&nbsp;&nbsp;&nbsp;
					<button type="submit" id="x" name="action" value="view">Cancel</button>
				</form>
			</div>
		</div>
	</div>
	<!-- end content -->
	</TMPL_LOOP>


<TMPL_VAR NAME="footer">

EndOfHTML

my $files = <<EndOfHTML;

<TMPL_VAR NAME="header">

<div id="content">
	<div class="post">
		<h2 class="title"><span class="dingbat">&#x273b;</span> Files</h2>
		<div class="meta">
			<p class="links"><a href="?action=upload" class="more">Upload files</a></p>
		</div>
		<div class="entry">
		
		<form method="POST">
		<TMPL_LOOP NAME="files">
			<h3><input type="checkbox" name="file" value='<TMPL_VAR NAME="name">'> <a href='<TMPL_VAR NAME="href">' target="_blank"><TMPL_VAR NAME="name"></a></h3>
			<p class="item-desc">
				<b>Size:</b> <TMPL_VAR NAME="size">,&nbsp; 
				<b>Modified:</b> <TMPL_VAR NAME="modified">
			</p>
		</TMPL_LOOP>
		<div class="pager">
			<TMPL_VAR NAME="pager">
		</div>
		<button type="submit" id="x" name="action" value="delete_files">Delete selected</button>
		</form>
	
		</div>
	</div>
</div>

<TMPL_VAR NAME="footer">

EndOfHTML


my $upload = <<EndOfHTML;

<TMPL_VAR NAME="header">

<div id="content">
	<div class="post">
		<h2 class="title"><span class="dingbat">&#x273b;</span> Upload Files</h2>
		<form method="POST" enctype="multipart/form-data">
			<div>
				<p class="edit"><input type="file" name="file" />
				<p class="edit"><input type="file" name="file" />
				<p class="edit"><input type="file" name="file" />
				<p class="edit"><input type="file" name="file" />
				<p class="edit"><input type="file" name="file" />
			</div>
			<button type="submit" id="x" name="action" value="upload_files">Upload files</button>
			<button name="action" value="files" id="x">Cancel</button>
			</p>
		</form>
	</div>
</div>

<TMPL_VAR NAME="footer">

EndOfHTML

my $footer = <<EndOfHTML;

<TMPL_IF NAME="authenticated"><TMPL_VAR NAME="sidebar"></TMPL_IF>
<div style="clear: both;">&nbsp;</div>
</div>
<!-- end page -->
<!-- start footer -->
<div id="footer">
	<!--
	<div id="footer-menu">
		<ul>
			<li class="active"><a href="#">homepage</a></li>
			<li><a href="#">photo gallery</a></li>
			<li><a href="#">about us</a></li>
			<li><a href="#">links</a></li>
			<li><a href="#">contact us</a></li>
		</ul>
	</div>
	-->
	<p id="legal">Powered by <a href="http://www.miril.org">Miril</a></p>
</div>
<!-- end footer -->
</body>
</html>

EndOfHTML

my $header = <<EndOfHTML;

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<!--

Design by Free CSS Templates
http://www.freecsstemplates.org
Released for free under a Creative Commons Attribution 2.5 License

Title      : FlashyWeb
Version    : 1.0
Released   : 20081102
Description: A two-column, fixed-width and lightweight template ideal for 1024x768 resolutions. Suitable for blogs and small websites.

-->
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<title>Miril</title>
<meta name="keywords" content="" />
<meta name="description" content="" />
<style><TMPL_VAR NAME="css"></style>
</head>
<body>
<!-- start header -->
<div id="header">
	<div id="logo">
		<h1><a href="?">Miril</a></h1>
		<h2>Static Content Publishing</h2>
	</div>
	<TMPL_IF NAME="authenticated">
	<div id="menu">
		<ul>
			<li class="active"><a href="?action=list">articles</a></li>
			<li><a href="?action=files">files</a></li>
			<li><a href="?action=publish">publish</a></li>
			<li><a href="?action=account">account</a></li>
			<li><a href="?action=logout">logout</a></li>
		</ul>
	</div>
	</TMPL_IF>
</div>
<!-- end header -->

<!-- start page -->
<div id="page">

<TMPL_IF NAME="has_error">
	<div id="error">
	<h2>miril encountered problems:</h2>
		<ul>
			<TMPL_LOOP NAME="error"><li><TMPL_VAR NAME="miril_msg">: <TMPL_VAR NAME="perl_msg"></li></TMPL_LOOP>
		</ul>
	</div>
</TMPL_IF>

EndOfHTML

my $list = <<EndOfHTML;

<TMPL_VAR NAME="header">

<div id="content">
	<div class="post">
		<h2 class="title"><span class="dingbat">&#x273b;</span> List of entries</h2>
		<div class="meta">
			<p class="links"><a href="?action=search" class="more">Search</a></p>
			<p class="links"><a href="?action=create" class="more">Post new article</a></p>
		</div>
		<div class="entry">
				
		<TMPL_LOOP NAME="items">
			<h3><span class="dingbat">&#8226;</span><a href='?action=view&id=<TMPL_VAR NAME="id">'><TMPL_VAR NAME="title"></a></h3>
			<p class="item-desc">
				<b>Status:</b> <TMPL_VAR NAME="status">,&nbsp; 
				<b>Modified:</b> <TMPL_VAR NAME="modified.slash">
			</p>
		</TMPL_LOOP>

		</div>
		<div class="pager">
			<TMPL_VAR NAME="pager">
		</div>
	</div>
</div>

<TMPL_VAR NAME="footer">

EndOfHTML

my $search = <<EndOfHTML;

<TMPL_VAR NAME="header">

<div id="content">
	<div class="post">
		<h2 class="title"><span class="dingbat">&#x273b;</span> Search entries</h2>
		<div class="entry">
				
			<form>
					
				<p class="edit">Title contains:<br />
				<input type="text" name="title" />
				</p>
				<p class="edit">Type:<br>
				<select name="type">
				<TMPL_LOOP NAME="types">
					<option value='<TMPL_VAR NAME="cfg_m_type">'><TMPL_VAR NAME="cfg_type"></option>
				</TMPL_LOOP>
				</select>
				</p>

				<TMPL_IF NAME="has_authors">
				<p class="edit">Author:<br>
				<select name="author">
				<TMPL_LOOP NAME="authors">
					<option value='<TMPL_VAR NAME="cfg_author">'><TMPL_VAR NAME="cfg_author"></option>
				</TMPL_LOOP>
				</select>
				</p>
				</TMPL_IF>
				
				<p class="edit">Status:<br>
				<select name="status">
				<TMPL_LOOP NAME="statuses">
					<option value='<TMPL_VAR NAME="cfg_status">'><TMPL_VAR NAME="cfg_status"></option>
				</TMPL_LOOP>
				</select>
				</p>

				<TMPL_IF NAME="has_topics">
				<p class="edit">Topic:<br>
				<select name="topic">
				<TMPL_LOOP NAME="topics">
					<option value='<TMPL_VAR NAME="cfg_topic_id">'><TMPL_VAR NAME="cfg_topic"></option>
				</TMPL_LOOP>
				</select>
				</p>
				</TMPL_IF>

				<button id="x" name="action" value="list">search</button>

			</form>
		</div>
	</div>
</div>

<TMPL_VAR NAME="footer">

EndOfHTML

my $login = <<EndOfHTML;

<TMPL_VAR NAME="header">

<div id="content">
	<div class="post">
		<h2 class="title"><span class="dingbat">&#x273b;</span> Sign in</h2>

			<div class="login">
				<form method="POST">

					<p class="edit">Username:<br>
					<input type="text" name="authen_username" class="textbox" value='<TMPL_VAR NAME="title">' /></p>

					<p class="edit">Password:<br>
					<input type="password" name="authen_password" class="textbox" value='<TMPL_VAR NAME="id">' /></p>

					<p><input type="checkbox" name="authen_rememberuser" />Remember me!</p>

					<button type="submit" id="x" name="action" value="list">Sign in</button>
  
				</form>
			</div>
	</div>
</div>

<TMPL_VAR NAME="footer">

EndOfHTML

my $publish = <<EndOfHTML;

<TMPL_VAR NAME="header">

<div id="content">
	<div class="post">
		<h2 class="title"><span class="dingbat">&#x273b;</span> Publish</h2>
		
		<form method="POST">
			<input type="hidden" name="action" value="publish">
			<p>
			<select name="rebuild">
				<option value="">Publish new and modified content</option>
				<option value="1">Rebuild the whole website</option>
			</select>
			</p>
			<input type="hidden" name="action" value="publish">
			<p><button type="submit" id="x" name="do" value="1">Publish</button></p>
		</form>
		
		
	</div>
</div>

<TMPL_VAR NAME="footer">

EndOfHTML

my $sidebar = <<EndOfHTML;

	<!-- start sidebar -->
	<div id="sidebar">
		<ul>
			<li id="search">
				<h2><b class="text1">Quick Open</b></h2>
				<form method="get">
					<fieldset>
					<input type="text" id="s" name="id" />
					<button id="x" name="action" value="view" />Go</button>
					</fieldset>
				</form>
			</li>
			<li>
				<h2 class="bold">Last edited</h2>
				<ul>
				<TMPL_LOOP NAME="latest">
					<li><div class="dingbat">&#x2726;</div>
						<a href="?action=view&id=<TMPL_VAR NAME="id">">
						<TMPL_VAR NAME="title">
						</a>
					</li>
				</TMPL_LOOP>
				</ul>
			</li>
		</ul>
	</div>
	<!-- end sidebar -->

EndOfHTML

my $css = <<EndOfHTML;

/*
Design by Free CSS Templates
http://www.freecsstemplates.org
Released for free under a Creative Commons Attribution 2.5 License
*/

body {
	margin-top: 20px;
	padding: 0;
	background: #FDF9EE;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	color: #6D6D6D;
}

h1, h2, h3 {
	margin: 0;
	font-family: Georgia, "Times New Roman", Times, serif;
	font-weight: normal;
	color: #006EA6;
}

h1, h2 {
	text-transform: lowercase;
}

h1 {
	letter-spacing: -1px;
	font-size: 35px;
}

h2 {
	font-size: 26px;
}

p, ul, ol {
	margin: 0 0 1.5em 0;
	text-align: justify;
	line-height: 26px;
}

a:link {
	color: #0094E0;
}

a:hover, a:active {
	text-decoration: none;
	color: #0094E0;
}

a:visited {
	color: #0094E0;
}

img {
	border: none;
}

img.left {
	float: left;
	margin: 7px 15px 0 0;
}

img.right {
	float: right;
	margin: 7px 0 0 15px;
}

/* Form */

form {
	margin: 0;
	padding: 0;
}

fieldset {
	margin: 0;
	padding: 0;
	border: none;
}

legend {
	display: none;
}

input, textarea, select, button {
	font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
	font-size: 13px;
	color: #333333;
}

#wrapper {
}

/* Header */

#header {
	width: 900px;
	min-height: 40px;
	margin: 0 auto 20px auto;
	padding-top: 10px;
}

#logo {
	float: left;
	height: 40px;
	margin-left: 10px;
}

#logo h1 {
	float: left;
	margin: 0;
	font-size: 38px;
	color: #0099E8;
}

#logo h1 sup {
	vertical-align: text-top;
	font-size: 24px;
}

#logo h1 a {
	color: #0099E8;
}

#logo h2 {
	float: left;
	margin: 0;
	padding: 20px 0 0 10px;
	text-transform: uppercase;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 10px;
	color: #6D6D6D;
}

#logo a {
	text-decoration: none;
	color: #FFFFFF;
}

/* Menu */

#menu {
	float: right;
}

#menu ul {
	margin: 0;
	padding: 0;
	list-style: none;
}

#menu li {
	display: inline;
}

#menu a {
	display: block;
	float: left;
	margin-left: 5px;
	background: #0094E0;
	border: 1px dashed #FFFFFF;
	padding: 1px 10px;
	text-decoration: none;
	font-size: 12px;
	color: #FFFFFF;
}

#menu a:hover {
	text-decoration: underline;
}

#menu .active a {
}

/* Page */

#page {
	width: 900px;
	margin: 0 auto;
	background: #FFFFFF;
	border: 1px #F0E9D6 solid;
	padding: 20px 20px;
}

/* Content */

#content {
	float: left;
	width: 600px;
	padding-left: 10px;
}

/* Post */

.post {
}

.post .title {
	margin-bottom: 20px;
	padding-bottom: 5px;
	/* padding-left: 40px; */
	border-bottom: 1px dashed #D1D1D1;
	color: #8BCB2F;
}

.post .title b {
	font-weight: normal;
	color: #0094E0;
}

.post .entry {
}

.post .meta {
	margin: 0;
	padding: 15px 0 60px 0;
}

.post .meta p {
	margin: 0;
	line-height: normal;
}

.post .meta .byline {
	float: left;
	color: #0000FF;
}

.post .meta .links {
	float: left;
}

.post .meta .more {
	width: 185px;
	height: 35px;
	padding: 5px 10px;
	background: #8BCB2F;
	border: 1px dashed #FFFFFF;
	text-transform: uppercase;
	text-decoration: none;
	font-size: 9px;
}

.post .meta .comments {
	padding: 5px 10px;
	text-transform: uppercase;
	text-decoration: none;
	background: #0094E0;
	border: 1px dashed #FFFFFF;
	font-size: 9px;
}

.post .meta b {
	display: none;
}

.post .meta a {
	color: #FFFFFF;
}
/* Sidebar */

#sidebar {
	float: right;
	width: 230px;
	padding-right: 10px;
}

#sidebar ul {
	margin: 0;
	padding: 10px 0 0 0;
	list-style: none;
}

#sidebar li {
	margin-bottom: 40px;
}

#sidebar li ul {
}

#sidebar li li {
	margin: 0;
	padding: 6px 0;
	border-bottom: 1px dashed #D1D1D1;
	display: block;
}

#sidebar li li a {
	margin: 0;
	padding-left: 1.5em;
	display: block;
	line-height: 20px;
}

#sidebar h2 {
	padding-bottom: 5px;
	font-size: 18px;
	font-weight: normal;
	color: #0094E0;
}

#sidebar strong, #sidebar b {
	color: #8BCB2F;
}

#sidebar a {
	text-decoration: none;
	color: #6D6D6D;
}

/* Search */

#search {
}

#search h2 {
}

#s {
	width: 80%;
	margin-right: 5px;
	padding: 3px;
	border: 1px solid #F0F0F0;
}

#x {
	padding: 3px;
	background: #ECECEC repeat-x left bottom;
	border: none;
	text-transform: lowercase;
	font-size: 11px;
	color: #4F4F4F;
}

/* Boxes */

.box1 {
	padding: 20px;
}

.box2 {
	color: #BABABA;
}

.box2 h2 {
	margin-bottom: 15px;
	font-size: 16px;
	color: #FFFFFF;
}

.box2 ul {
	margin: 0;
	padding: 0;
	list-style: none;
}

.box2 a:link, .box2 a:hover, .box2 a:active, .box2 a:visited  {
	color: #EDEDED;
}

/* Footer */

#footer {
	width: 880px;
	margin: 0 auto;
	padding: 10px 0 0 0;
	color: #353535;
}

html>body #footer {
	height: auto;
}

#footer-menu {
}

#legal {
	clear: both;
	font-size: 11px;
	color: #6D6D6D;
}

#legal a {
	color: #0094E0;
}

#footer-menu {
	float: left;
	color: #353535;
	text-transform: capitalize;
}

#footer-menu ul {
	margin: 0;
	padding: 0;
	list-style: none;
}

#footer-menu li {
	display: inline;
}

#footer-menu a {
	display: block;
	float: left;
	padding: 1px 15px 1px 15px;
	text-decoration: none;
	font-size: 11px;
	color: #6D6D6D;
}

#footer-menu a:hover {
	text-decoration: underline;
}

#footer-menu .active a {
	padding-left: 0;
}

/* Petar's additions! */

.edit input.textbox {
	width: 50%;
}

.edit textarea {
	width: 100%;
	height: 250px;
}

.edit p.edit {
	margin-top: 5px;
	margin-bottom: 5px;
}

.post h2 {
	text-transform: none;
}

.dingbat {
	color: #006EA6;
}

#sidebar h2.bold {
	font-weight: bold;
}

div.entry * {
	color: #6D6D6D;
}

span.required {
	color: red;
}

p.item-desc {
	font-family: Georgia,"Times New Roman",Times,serif;
}

h3 .dingbat {
	margin-right: 10px;
}

div#error {
	border: 1px solid #F0E9D6;
	margin-bottom: 10px;
}

#error ul {
	margin: 1em 0 1em;
}

#error h2 {
	margin-top: 0.5em;
	margin-left: 1em;
	color: red;
	font-size: 18px;
	font-weight: bold;
}

.more {
	margin-right: 5px;
}

div.entry p {
	line-height: 1.8em;
	font-family: Georgia,"Times New Roman",Times,serif;
	text-align: left;
}

div.entry li {
	line-height: 1.8em;
	font-family: Georgia,"Times New Roman",Times,serif;
	text-align: left;
}

div.entry h1, h2, h3 {
	margin-top: 0.7em;
	margin-bottom: 0.3em;
}

div.pager {
	text-align: center;
}

div.dingbat {
	float: left;
	width: 1.5em;
}


EndOfHTML

my $view = <<EndOfHTML;

<TMPL_VAR NAME="header">

	<!-- start content -->
	<div id="content">
		<div class="post">
			<h2 class="title"><span class="dingbat">&#x273b;</span> <TMPL_VAR NAME="item.title"></h2>
			<div class="entry">
				<TMPL_VAR NAME="item.text">
			</div>
			<form method="get">
			<input type="hidden" name="id" value='<TMPL_VAR NAME="item.id">' />
			<button name="action" value="edit" id="x">Edit</button>&nbsp;&nbsp;&nbsp;&nbsp;
			<button name="action" value="list" id="x">Cancel</button>
			</form>
		</div>
	</div>
	<!-- end content -->

<TMPL_VAR NAME="footer">

EndOfHTML


my $error = <<EndOfHTML;

<TMPL_VAR NAME="header">
<TMPL_VAR NAME="footer">

EndOfHTML

my $pager = <<EndOfHTML;

<TMPL_IF NAME="first"><a class='pager' href='<TMPL_VAR NAME="first">'>first</a><TMPL_ELSE>first</TMPL_IF>
<TMPL_IF NAME="previous"><a class='pager' href='<TMPL_VAR NAME="previous">'>&laquo;previous</a><TMPL_ELSE>&laquo;previous</TMPL_IF>
<TMPL_IF NAME="next"><a class='pager' href='<TMPL_VAR NAME="next">'>next&raquo;</a><TMPL_ELSE>next&raquo;</TMPL_IF>
<TMPL_IF NAME="last"><a class='pager' href='<TMPL_VAR NAME="last">'>last</a><TMPL_ELSE>last</TMPL_IF>

EndOfHTML

### METHODS ###

sub new {
	return bless {}, shift;
}

sub get {
	my $self = shift;
	my $name = shift;

	$name eq "account"  && return $account;
	$name eq "css"      && return $css;
	$name eq "edit"     && return $edit;
	$name eq "files"    && return $files;
	$name eq "footer"   && return $footer;
	$name eq "header"   && return $header;
	$name eq "list"     && return $list;
	$name eq "login"    && return $login;
	$name eq "publish"  && return $publish;
	$name eq "sidebar"  && return $sidebar;
	$name eq "view"     && return $view;
	$name eq "upload"   && return $upload;
	$name eq "error"    && return $error;
	$name eq "search"   && return $search;
	$name eq "pager"    && return $pager;
}

1;
