[
{
          'text' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<$MTPublishCharset$>" />

<title><$MTBlogName$></title>

<link rel="stylesheet" href="<$MTBlogURL$>styles-site.css" type="text/css" />
<link rel="alternate" type="application/rss+xml" title="RSS" href="<$MTBlogURL$>index.rdf" />
<link rel="EditURI" type="application/rsd+xml" title="RSD" href="<$MTBlogURL$>rsd.xml" />

<script language="javascript" type="text/javascript">
function OpenComments (c) {
    window.open(c,
                    \'comments\',
                    \'width=480,height=480,scrollbars=yes,status=yes\');
}

function OpenTrackback (c) {
    window.open(c,
                    \'trackback\',
                    \'width=480,height=480,scrollbars=yes,status=yes\');
}
</script>

<MTBlogIfCCLicense>
<$MTCCLicenseRDF$>
</MTBlogIfCCLicense>

</head>

<body>

<div id="banner">
<h1><a href="<$MTBlogURL$>" accesskey="1"><$MTBlogName$></a></h1>
<span class="description"><$MTBlogDescription$></span>
</div>

<div id="content">

<div class="blog">

<MTEntries>
<$MTEntryTrackbackData$>

	<MTDateHeader>
	<h2 class="date">
	<$MTEntryDate format="%x"$>
	</h2>
	</MTDateHeader>

	<div class="blogbody">
	
	<a name="<$MTEntryID pad="1"$>"></a>
	<h3 class="title"><$MTEntryTitle$></h3>
	
	<$MTEntryBody$>
	
	<MTEntryIfExtended>
	<span class="extended"><a href="<$MTEntryPermalink$>#more"><MT_TRANS phrase="Continue reading"> "<$MTEntryTitle$>"</a></span><br />
	</MTEntryIfExtended>
	
	<div class="posted"><MT_TRANS phrase="Posted by"> <$MTEntryAuthor$> <MT_TRANS phrase="at"> <a href="<$MTEntryPermalink$>"><$MTEntryDate format="%X"$></a>
	<MTEntryIfAllowComments>
	| <a href="<$MTCGIPath$><$MTCommentScript$>?entry_id=<$MTEntryID$>" onclick="OpenComments(this.href); return false"><MT_TRANS phrase="Comments"> (<$MTEntryCommentCount$>)</a>
	</MTEntryIfAllowComments>
	<MTEntryIfAllowPings>
	| <a href="<$MTCGIPath$><$MTTrackbackScript$>?__mode=view&amp;entry_id=<$MTEntryID$>" onclick="OpenTrackback(this.href); return false"><MT_TRANS phrase="TrackBack"> (<$MTEntryTrackbackCount$>)</a>
	</MTEntryIfAllowPings>
	</div>
	
	</div>
	


</MTEntries>

</div>

</div>


<div id="links">



<div align="center" class="calendar">

<table border="0" cellspacing="4" cellpadding="0" summary="<MT_TRANS phrase="Monthly calendar with links to each day\'s posts">">
<caption class="calendarhead"><$MTDate format="%B %Y"$></caption>
<tr>
<th abbr="<MT_TRANS phrase="Sunday">" align="center"><span class="calendar"><MT_TRANS phrase="Sun"></span></th>
<th abbr="<MT_TRANS phrase="Monday">" align="center"><span class="calendar"><MT_TRANS phrase="Mon"></span></th>
<th abbr="<MT_TRANS phrase="Tuesday">" align="center"><span class="calendar"><MT_TRANS phrase="Tue"></span></th>
<th abbr="<MT_TRANS phrase="Wednesday">" align="center"><span class="calendar"><MT_TRANS phrase="Wed"></span></th>
<th abbr="<MT_TRANS phrase="Thursday">" align="center"><span class="calendar"><MT_TRANS phrase="Thu"></span></th>
<th abbr="<MT_TRANS phrase="Friday">" align="center"><span class="calendar"><MT_TRANS phrase="Fri"></span></th>
<th abbr="<MT_TRANS phrase="Saturday">" align="center"><span class="calendar"><MT_TRANS phrase="Sat"></span></th>
</tr>

<MTCalendar>
<MTCalendarWeekHeader><tr></MTCalendarWeekHeader>

<td align="center"><span class="calendar">
<MTCalendarIfEntries><MTEntries lastn="1"><a href="<$MTEntryPermalink$>"><$MTCalendarDay$></a></MTEntries></MTCalendarIfEntries><MTCalendarIfNoEntries><$MTCalendarDay$></MTCalendarIfNoEntries><MTCalendarIfBlank>&nbsp;</MTCalendarIfBlank></span></td><MTCalendarWeekFooter></tr></MTCalendarWeekFooter></MTCalendar>
</table>

</div>

<div class="sidetitle">
<MT_TRANS phrase="Search">
</div>
 
<div class="side">
<form method="get" action="<$MTCGIPath$><$MTSearchScript$>">
<input type="hidden" name="IncludeBlogs" value="<$MTBlogID$>" />
<label for="search" accesskey="4"><MT_TRANS phrase="Search this site:"></label><br />
<input id="search" name="search" size="20" /><br />
<input type="submit" value="<MT_TRANS phrase="Search">" />
</form>
</div>

<div class="sidetitle">
<MT_TRANS phrase="Archives">
</div>

<div class="side">
<MTArchiveList archive_type="Monthly">
<a href="<$MTArchiveLink$>"><$MTArchiveTitle$></a><br />
</MTArchiveList>
</div>

<div class="sidetitle">
<MT_TRANS phrase="Recent Entries">
</div>

<div class="side">
<MTEntries lastn="10">
<a href="<$MTEntryPermalink$>"><$MTEntryTitle$></a><br />
</MTEntries>
</div>

<div class="sidetitle">
<MT_TRANS phrase="Links">
</div>

<div class="side">
<a href="">Add Your Links Here</a><br />
</div>

<div class="syndicate">
<a href="<$MTBlogURL$>index.rdf"><MT_TRANS phrase="Syndicate this site"> (XML)</a>
</div>

<MTBlogIfCCLicense>
<div class="syndicate">
<a href="<$MTBlogCCLicenseURL$>"><img alt="Creative Commons License" border="0" src="<$MTBlogCCLicenseImage$>" /></a><br />
<MT_TRANS phrase="This weblog is licensed under a"> <a href="<$MTBlogCCLicenseURL$>">Creative Commons License</a>.
</div>
</MTBlogIfCCLicense>

<div class="powered">
<MT_TRANS phrase="Powered by"><br /><a href="http://www.movabletype.org">Movable Type <$MTVersion$></a><br />    
</div>

</div>

<br clear="all" />

</body>
</html>
',
          'outfile' => 'index.html',
          'rebuild_me' => '1',
          'type' => 'index',
          'name' => 'Main Index'
        },

{
          'text' => '<?xml version="1.0"?> 
<rsd version="1.0" xmlns="http://archipelago.phrasewise.com/rsd">
  <service>
    <engineName>Movable Type <$MTVersion$></engineName> 
    <engineLink>http://www.movabletype.org/</engineLink>
    <homePageLink><$MTBlogURL$></homePageLink>
    <apis>
      <api name="MetaWeblog" preferred="true" apiLink="<$MTCGIPath$><$MTXMLRPCScript$>" blogID="<$MTBlogID$>" />
      <api name="Blogger" preferred="false" apiLink="<$MTCGIPath$><$MTXMLRPCScript$>" blogID="<$MTBlogID$>" />
    </apis>
  </service>
</rsd>',
          'outfile' => 'rsd.xml',
          'rebuild_me' => '1',
          'type' => 'index',
          'name' => 'RSD'
        },

{
          'text' => '<?xml version="1.0" encoding="<$MTPublishCharset$>"?>
<rss version="2.0" 
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:sy="http://purl.org/rss/1.0/modules/syndication/"
  xmlns:admin="http://webns.net/mvcb/"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">

<channel>
<title><$MTBlogName remove_html="1" encode_xml="1"$></title>
<link><$MTBlogURL$></link>
<description><$MTBlogDescription remove_html="1" encode_xml="1"$></description>
<dc:language>en-us</dc:language>
<dc:creator><MTEntries lastn="1"><$MTEntryAuthorEmail$></MTEntries></dc:creator>
<dc:date><MTEntries lastn="1"><$MTEntryDate format="%Y-%m-%dT%H:%M:%S"$><$MTBlogTimezone$></MTEntries></dc:date>
<admin:generatorAgent rdf:resource="http://www.movabletype.org/?v=<$MTVersion$>" />
<sy:updatePeriod>hourly</sy:updatePeriod>
<sy:updateFrequency>1</sy:updateFrequency>
<sy:updateBase>2000-01-01T12:00+00:00</sy:updateBase>

<MTEntries lastn="15">
<item>
<title><$MTEntryTitle remove_html="1" encode_xml="1"$></title>
<link><$MTEntryLink encode_xml="1"$></link>
<description><$MTEntryExcerpt remove_html="1" encode_xml="1"$></description>
<guid isPermaLink="false"><$MTEntryID$>@<$MTBlogURL$></guid>
<dc:subject><$MTEntryCategory remove_html="1" encode_xml="1"$></dc:subject>
<dc:date><$MTEntryDate format="%Y-%m-%dT%H:%M:%S"$><$MTBlogTimezone$></dc:date>
</item>
</MTEntries>

</channel>
</rss>',
          'outfile' => 'index.xml',
          'rebuild_me' => '1',
          'type' => 'index',
          'name' => 'RSS 2.0 Index'
        },

{
          'text' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<$MTPublishCharset$>" />
<title><$MTBlogName$> Archives</title>

<link rel="stylesheet" href="<$MTBlogURL$>styles-site.css" type="text/css" />
<link rel="alternate" type="application/rss+xml" title="RSS" href="<$MTBlogURL$>index.rdf" />

</head>

<body>	

<div id="banner">
<h1><a href="<$MTBlogURL$>" accesskey="1"><$MTBlogName$></a></h1>
<span class="description"><$MTBlogDescription$></span>
</div>
	
<div id="container">
<div class="blog">
<div class="blogbody">
<MTArchiveList>
<a href="<$MTArchiveLink$>"><$MTArchiveTitle$></a><br />
</MTArchiveList>
</div>
</div>
</div>

</body>
</html>',
          'outfile' => 'archives.html',
          'rebuild_me' => '1',
          'type' => 'index',
          'name' => 'Master Archive Index'
        },

{
          'text' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<$MTPublishCharset$>" />

<title><$MTBlogName$>: <MT_TRANS phrase="Comment Preview"></title>
<link rel="stylesheet" href="<$MTBlogURL$>styles-site.css" type="text/css" />
</head>

<body>

<div id="banner-commentspop">
<$MTBlogName$>
</div>

<div class="blog">

<div class="comments-head"><MT_TRANS phrase="Previewing your Comment"></div>

<div class="comments-body">
<$MTCommentPreviewBody$>
<span class="comments-post"><MT_TRANS phrase="Posted by"> <$MTCommentPreviewAuthorLink spam_protect="1"$> <MT_TRANS phrase="at"> <$MTCommentPreviewDate$></span>
</div>

<div class="comments-body">
<form method="post" action="<$MTCGIPath$><$MTCommentScript$>">
<input type="hidden" name="entry_id" value="<$MTEntryID$>" />
<input type="hidden" name="static" value="<$MTCommentPreviewIsStatic$>" />

<label for="author"><MT_TRANS phrase="Name:"></label><br />
<input id="author" name="author" value="<$MTCommentPreviewAuthor encode_html="1"$>" /><br /><br />

<label for="email"><MT_TRANS phrase="Email Address:"></label><br />
<input id="email" name="email" value="<$MTCommentPreviewEmail encode_html="1"$>" /><br /><br />

<label for="url"><MT_TRANS phrase="URL:"></label><br />
<input id="url" name="url" value="<$MTCommentPreviewURL encode_html="1"$>" /><br /><br />

<label for="text"><MT_TRANS phrase="Comments:"></label><br />
<textarea id="text" name="text" rows="10" cols="50"><$MTCommentPreviewBody convert_breaks="0" encode_html="1"$></textarea><br /><br />

<input type="submit" name="preview" value="&nbsp;<MT_TRANS phrase="Preview">&nbsp;" />
<input style="font-weight: bold;" type="submit" name="post" value="&nbsp;<MT_TRANS phrase="Post">&nbsp;" /><br /><br />

</form>
</div>

<div class="comments-head"><MT_TRANS phrase="Previous Comments"></div>

<MTComments>
<div class="comments-body">
<$MTCommentBody$>
<span class="comments-post"><MT_TRANS phrase="Posted by"> <$MTCommentAuthorLink spam_protect="1"$> <MT_TRANS phrase="at"> <$MTCommentDate$></span>
</div>
</MTComments>

</div>
</body>
</html>',
          'type' => 'comment_preview',
          'name' => 'Comment Preview Template'
        },

{
          'text' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<$MTPublishCharset$>" />

<title><$MTBlogName$>: <MT_TRANS phrase="Comment Submission Error"></title>

<link rel="stylesheet" href="<$MTBlogURL$>styles-site.css" type="text/css" />

</head>

<body>

<div id="banner-commentspop">
<$MTBlogName$>
</div>

<div class="blog">

<div class="comments-head"><MT_TRANS phrase="Comment Submission Error"></div>

<div class="comments-body">

<MT_TRANS phrase="Your comment submission failed for the following reasons:"><br /> <br />

<b><$MTErrorMessage$></b><br /><br />

<MT_TRANS phrase="Please correct the error in the form below, then press Post to post your comment.">
</div>

<div class="comments-body">
<form method="post" action="<$MTCGIPath$><$MTCommentScript$>">
<input type="hidden" name="entry_id" value="<$MTEntryID$>" />
<input type="hidden" name="static" value="<$MTCommentPreviewIsStatic$>" />

<label for="author"><MT_TRANS phrase="Name:"></label><br />
<input id="author" name="author" value="<$MTCommentPreviewAuthor encode_html="1"$>" /><br /><br />

<label for="email"><MT_TRANS phrase="Email Address:"></label><br />
<input id="email" name="email" value="<$MTCommentPreviewEmail encode_html="1"$>" /><br /><br />

<label for="url"><MT_TRANS phrase="URL:"></label><br />
<input id="url" name="url" value="<$MTCommentPreviewURL encode_html="1"$>" /><br /><br />

<label for="text"><MT_TRANS phrase="Comments:"></label><br />
<textarea id="text" name="text" rows="10" cols="50"><$MTCommentPreviewBody convert_breaks="0" encode_html="1"$></textarea><br /><br />

<input type="submit" name="preview" value="&nbsp;<MT_TRANS phrase="Preview">&nbsp;" />
<input style="font-weight: bold;" type="submit" name="post" value="&nbsp;<MT_TRANS phrase="Post">&nbsp;" /><br /><br />

</form>
</div>
</div>
</body>
</html>',
          'type' => 'comment_error',
          'name' => 'Comment Error Template'
        },

{
          'text' => '<html>
<body topmargin="0" leftmargin="0" marginheight="0" marginwidth="0">

<img src="<$MTImageURL$>" width="<$MTImageWidth$>" height="<$MTImageHeight$>" border="0">

</body>
</html>',
          'type' => 'popup_image',
          'name' => 'Uploaded Image Popup Template'
        },

{
          'text' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<$MTPublishCharset$>" />

<title><$MTBlogName$>: <MT_TRANS phrase="Comment on"> <$MTEntryTitle$></title>

<link rel="stylesheet" href="<$MTBlogURL$>styles-site.css" type="text/css" />

<script type="text/javascript" language="javascript">
<!--

var HOST = \'<$MTBlogHost$>\';

// Copyright (c) 1996-1997 Athenia Associates.
// http://www.webreference.com/js/
// License is granted if and only if this entire
// copyright notice is included. By Tomer Shiran.

function setCookie (name, value, expires, path, domain, secure) {
    var curCookie = name + "=" + escape(value) + ((expires) ? "; expires=" + expires.toGMTString() : "") + ((path) ? "; path=" + path : "") + ((domain) ? "; domain=" + domain : "") + ((secure) ? "; secure" : "");
    document.cookie = curCookie;
}

function getCookie (name) {
    var prefix = name + \'=\';
    var c = document.cookie;
    var nullstring = \'\';
    var cookieStartIndex = c.indexOf(prefix);
    if (cookieStartIndex == -1)
        return nullstring;
    var cookieEndIndex = c.indexOf(";", cookieStartIndex + prefix.length);
    if (cookieEndIndex == -1)
        cookieEndIndex = c.length;
    return unescape(c.substring(cookieStartIndex + prefix.length, cookieEndIndex));
}

function deleteCookie (name, path, domain) {
    if (getCookie(name))
        document.cookie = name + "=" + ((path) ? "; path=" + path : "") + ((domain) ? "; domain=" + domain : "") + "; expires=Thu, 01-Jan-70 00:00:01 GMT";
}

function fixDate (date) {
    var base = new Date(0);
    var skew = base.getTime();
    if (skew > 0)
        date.setTime(date.getTime() - skew);
}

function rememberMe (f) {
    var now = new Date();
    fixDate(now);
    now.setTime(now.getTime() + 365 * 24 * 60 * 60 * 1000);
    setCookie(\'mtcmtauth\', f.author.value, now, \'\', HOST, \'\');
    setCookie(\'mtcmtmail\', f.email.value, now, \'\', HOST, \'\');
    setCookie(\'mtcmthome\', f.url.value, now, \'\', HOST, \'\');
}

function forgetMe (f) {
    deleteCookie(\'mtcmtmail\', \'\', HOST);
    deleteCookie(\'mtcmthome\', \'\', HOST);
    deleteCookie(\'mtcmtauth\', \'\', HOST);
    f.email.value = \'\';
    f.author.value = \'\';
    f.url.value = \'\';
}

//-->
</script>
</head>

<body>

<div id="banner-commentspop">
<$MTBlogName$>
</div>

<div class="blog">

<div class="comments-head"><MT_TRANS phrase="Comments:"> <$MTEntryTitle$></div>


<MTComments>
<div class="comments-body">
<$MTCommentBody$>
<span class="comments-post"><MT_TRANS phrase="Posted by"> <$MTCommentAuthorLink spam_protect="1"$> <MT_TRANS phrase="at"> <$MTCommentDate$></span>
</div>
</MTComments>

<MTEntryIfCommentsOpen>

<div class="comments-head"><MT_TRANS phrase="Post a comment"></div>

<div class="comments-body">
<form method="post" action="<$MTCGIPath$><$MTCommentScript$>" name="comments_form" onsubmit="if (this.bakecookie[0].checked) rememberMe(this)">
<input type="hidden" name="entry_id" value="<$MTEntryID$>" />

<div style="width:180px; padding-right:15px; margin-right:15px; float:left; text-align:left; border-right:1px dotted #bbb;">
	<label for="author"><MT_TRANS phrase="Name:"></label><br />
	<input tabindex="1" id="author" name="author" /><br /><br />

	<label for="email"><MT_TRANS phrase="Email Address:"></label><br />
	<input tabindex="2" id="email" name="email" /><br /><br />

	<label for="url"><MT_TRANS phrase="URL:"></label><br />
	<input tabindex="3" id="url" name="url" /><br /><br />
</div>

<MT_TRANS phrase="Remember personal info?"><br />
<input type="radio" id="bakecookie" name="bakecookie" /><label for="bakecookie"><MT_TRANS phrase="Yes"></label><input type="radio" id="forget" name="bakecookie" onclick="forgetMe(this.form)" value="Forget Info" style="margin-left: 15px;" /><label for="forget"><MT_TRANS phrase="No"></label><br style="clear: both;" />

<label for="text"><MT_TRANS phrase="Comments:"></label><br />
<textarea tabindex="4" id="text" name="text" rows="10" cols="50"></textarea><br /><br />

<input type="button" onclick="window.close()" value="&nbsp;<MT_TRANS phrase="Cancel">&nbsp;" />
<input type="submit" name="preview" value="&nbsp;<MT_TRANS phrase="Preview">&nbsp;" />
<input style="font-weight: bold;" type="submit" name="post" value="&nbsp;<MT_TRANS phrase="Post">&nbsp;" /><br /><br />

</form>

<script type="text/javascript" language="javascript">
<!--
document.comments_form.email.value = getCookie("mtcmtmail");
document.comments_form.author.value = getCookie("mtcmtauth");
document.comments_form.url.value = getCookie("mtcmthome");
if (getCookie("mtcmtauth")) {
    document.comments_form.bakecookie[0].checked = true;
} else {
    document.comments_form.bakecookie[1].checked = true;
}
//-->
</script>
</div>

</MTEntryIfCommentsOpen>

</div>

</body>
</html>',
          'type' => 'comments',
          'name' => 'Comment Listing Template'
        },

{
          'text' => '<?xml version="1.0" encoding="<$MTPublishCharset$>"?>

<rdf:RDF
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:sy="http://purl.org/rss/1.0/modules/syndication/"
  xmlns:admin="http://webns.net/mvcb/"
  xmlns:cc="http://web.resource.org/cc/"
  xmlns="http://purl.org/rss/1.0/">

<channel rdf:about="<$MTBlogURL$>">
<title><$MTBlogName encode_xml="1"$></title>
<link><$MTBlogURL$></link>
<description><$MTBlogDescription encode_xml="1"$></description>
<dc:language>en-us</dc:language>
<dc:creator></dc:creator>
<dc:date><MTEntries lastn="1"><$MTEntryDate format="%Y-%m-%dT%H:%M:%S" language="en"$><$MTBlogTimezone$></MTEntries></dc:date>
<admin:generatorAgent rdf:resource="http://www.movabletype.org/?v=<$MTVersion$>" />
<MTBlogIfCCLicense>
<cc:license rdf:resource="<$MTBlogCCLicenseURL$>" />
</MTBlogIfCCLicense>

<items>
<rdf:Seq><MTEntries lastn="15">
<rdf:li rdf:resource="<$MTEntryPermalink encode_xml="1"$>" />
</MTEntries></rdf:Seq>
</items>

</channel>

<MTEntries lastn="15">
<item rdf:about="<$MTEntryPermalink encode_xml="1"$>">
<title><$MTEntryTitle encode_xml="1"$></title>
<link><$MTEntryPermalink encode_xml="1"$></link>
<description><$MTEntryExcerpt encode_xml="1"$></description>
<dc:subject><$MTEntryCategory encode_xml="1"$></dc:subject>
<dc:creator><$MTEntryAuthor encode_xml="1"$></dc:creator>
<dc:date><$MTEntryDate format="%Y-%m-%dT%H:%M:%S" language="en"$><$MTBlogTimezone$></dc:date>
</item>
</MTEntries>

</rdf:RDF>',
          'outfile' => 'index.rdf',
          'rebuild_me' => '1',
          'type' => 'index',
          'name' => 'RSS 1.0 Index'
        },

{
          'text' => '
	body {
		margin:0px 0px 20px 0px;
		background:#FFF;		
		}
	A 			{ color: #003366; text-decoration: underline; }
	A:link		{ color: #003366; text-decoration: underline; }
	A:visited	{ color: #003366; text-decoration: underline; }
	A:active	{ color: #999999;  }
	A:hover		{ color: #999999;  }

	h1, h2, h3 {
		margin: 0px;
		padding: 0px;
	}

	#banner {
		font-family:palatino,  georgia, verdana, arial, sans-serif;
		color:#333;
		font-size:x-large;
		font-weight:normal;	
  		padding:15px;
                border-top:4px double #666;
		}

	#banner a,
        #banner a:link,
        #banner a:visited,
        #banner a:active,
        #banner a:hover {
		font-family: palatino,  georgia, verdana, arial, sans-serif;
		font-size: xx-large;
		color: #333;
		text-decoration: none;
		}

	.description {
		font-family:palatino,  georgia, times new roman, serif;
		color:#333;
		font-size:small;
  		text-transform:none;	
		}
				
	#content {
		position:absolute;
		background:#FFF;
		margin-right:20px;
		margin-left:225px;
		margin-bottom:20px;
		border:1px solid #FFF;
		width: 70%;
		}

	#container {
		background:#FFF;
		border:1px solid #FFF;		
		}

	#links {	
		padding:15px;				
		border:1px solid #FFF;
		width:200px;			
		}
		
	.blog {
  		padding:15px;
		background:#FFF; 
		}

	.blogbody {
		font-family:palatino, georgia, verdana, arial, sans-serif;
		color:#333;
		font-size:small;
		font-weight:normal;
  		background:#FFF;
  		line-height:200%;
		}

	.blogbody a,
	.blogbody a:link,
	.blogbody a:visited,
	.blogbody a:active,
	.blogbody a:hover {
		font-weight: normal;
		text-decoration: underline;
	}

	.title	{
		font-family: palatino, georgia, times new roman, serif;
		font-size: medium;
		color: #666;
		}			

	#menu {
  		margin-bottom:15px;
		background:#FFF;
		text-align:center;
		}		

	.date	{ 
		font-family:palatino, georgia, times new roman, serif; 
		font-size: large; 
		color: #333; 
		border-bottom:1px solid #999;
		margin-bottom:10px;
		font-weight:bold;
		}			
		
	.posted	{ 
		font-family:verdana, arial, sans-serif; 
		font-size: x-small; 
		color: #000000; 
		margin-bottom:25px;
		}
		
		
	.calendar {
		font-family:verdana, arial, sans-serif;
		color:#666;
		font-size:x-small;
		font-weight:normal;
  		background:#FFF;
  		line-height:140%;
  		padding:2px;
                text-align:left;
		}
	
	.calendarhead {	
		font-family:palatino, georgia, times new roman, serif;
		color:#666600;
		font-size:small;
		font-weight:normal;
  		padding:2px;
		letter-spacing: .3em;
  		background:#FFF;
  		text-transform:uppercase;
		text-align:left;			
		}	
	
	.side {
		font-family:verdana, arial, sans-serif;
		color:#333;
		font-size:x-small;
		font-weight:normal;
  		background:#FFF;
  		line-height:140%;
  		padding:2px;				
		}	
		
	.sidetitle {
		font-family:palatino, georgia, times new roman, serif;
		color:#666600;
		font-size:small;
		font-weight:normal;
  		padding:2px;
  		margin-top:30px;
		letter-spacing: .3em;
  		background:#FFF;
  		text-transform:uppercase;		
		}		
	
	.syndicate {
		font-family:verdana, arial, sans-serif;
		font-size:xx-small;		
  		line-height:140%;
  		padding:2px;
  		margin-top:15px;
  		background:#FFF;  		
 		}	
		
	.powered {
		font-family:palatino, georgia, times new roman, serif;
		color:#666;
		font-size:x-small;		
		line-height:140%;
		text-transform:uppercase; 
		padding:2px;
		margin-top:50px;
		letter-spacing: .2em;					
  		background:#FFF;		
		}	
		
	
	.comments-body {
		font-family:palatino, georgia, verdana, arial, sans-serif;
		color:#666;
		font-size:small;
		font-weight:normal;
  		background:#FFF;
  		line-height:140%;
 		padding-bottom:10px;
  		padding-top:10px;		
 		border-bottom:1px dotted #999; 					
		}		

	.comments-post {
		font-family:verdana, arial, sans-serif;
		color:#666;
		font-size:x-small;
		font-weight:normal;
  		background:#FFF;		
		}	
			
	
	.trackback-url {
		font-family:palatino, georgia, verdana, arial, sans-serif;
		color:#666;
		font-size:small;
		font-weight:normal;
  		background:#FFF;
  		line-height:140%;
 		padding:5px;		
 		border:1px dotted #999; 					
		}


	.trackback-body {
		font-family:palatino, georgia, verdana, arial, sans-serif;
		color:#666;
		font-size:small;
		font-weight:normal;
  		background:#FFF;
  		line-height:140%;
 		padding-bottom:10px;
  		padding-top:10px;		
 		border-bottom:1px dotted #999; 					
		}		

	.trackback-post {
		font-family:verdana, arial, sans-serif;
		color:#666;
		font-size:x-small;
		font-weight:normal;
  		background:#FFF;		
		}	

		
	.comments-head	{ 
		font-family:palatino, georgia, verdana, arial, sans-serif; 
		font-size:small; 
		color: #666; 
		border-bottom:1px solid #999;
		margin-top:20px;
		font-weight:bold;
  		background:#FFF;		
		}		

	#banner-commentspop {
		font-family:palatino, georgia, verdana, arial, sans-serif;
		color:#FFF;
		font-size:large;
		font-weight:bold;
		border-left:1px solid #FFF;	
		border-right:1px solid #FFF;  		
		border-top:1px solid #FFF;  		
  		background:#003366;
  		padding-left:15px;
  		padding-right:15px;
  		padding-top:5px;
  		padding-bottom:5px;  		  		  			 
		}
',
          'outfile' => 'styles-site.css',
          'rebuild_me' => '1',
          'type' => 'index',
          'name' => 'Stylesheet'
        },

{
          'text' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<$MTPublishCharset$>" />

<title><$MTBlogName$>: <$MTArchiveTitle$> <MT_TRANS phrase="Archives"></title>

<link rel="stylesheet" href="<$MTBlogURL$>styles-site.css" type="text/css" />
<link rel="alternate" type="application/rss+xml" title="RSS" href="<$MTBlogURL$>index.rdf" />
<link rel="start" href="<$MTBlogURL$>" title="Home" />
<MTArchivePrevious>
<link rel="prev" href="<$MTArchiveLink$>" title="<$MTArchiveTitle encode_html="1"$>" />
</MTArchivePrevious>
<MTArchiveNext>
<link rel="next" href="<$MTArchiveLink$>" title="<$MTArchiveTitle encode_html="1"$>" />
</MTArchiveNext>

<script language="javascript" type="text/javascript">
function OpenComments (c) {
    window.open(c,
                    \'comments\',
                    \'width=480,height=480,scrollbars=yes,status=yes\');
}

function OpenTrackback (c) {
    window.open(c,
                    \'trackback\',
                    \'width=480,height=480,scrollbars=yes,status=yes\');
}
</script>

</head>

<body>	

<div id="banner">
<h1><a href="<$MTBlogURL$>" accesskey="1"><$MTBlogName$></a></h1>
<span class="description"><$MTBlogDescription$></span>
</div>

<div id="container">

<div class="blog">

<div id="menu">
<MTArchivePrevious>
<a href="<$MTArchiveLink$>">&laquo; <$MTArchiveTitle$></a> |
</MTArchivePrevious>
<a href="<$MTBlogURL$>"><MT_TRANS phrase="Main"></a>
<MTArchiveNext>
| <a href="<$MTArchiveLink$>"><$MTArchiveTitle$> &raquo;</a>
</MTArchiveNext>
</div>

</div>

<div class="blog">
<MTEntries>
<$MTEntryTrackbackData$>

<MTDateHeader>
<h2 class="date"><$MTEntryDate format="%x"$></h2>
</MTDateHeader>

<div class="blogbody">
<a name="<$MTEntryID pad="1"$>"></a>
<h3 class="title"><$MTEntryTitle$></h3>

<$MTEntryBody$>

<MTEntryIfExtended>
<$MTEntryMore$>
</MTEntryIfExtended>

<div class="posted">
	<MT_TRANS phrase="Posted by"> <$MTEntryAuthor$> <MT_TRANS phrase="at"> <a href="<$MTEntryPermalink$>"><$MTEntryDate format="%X"$></a>
	<MTEntryIfAllowComments>
	| <a href="<$MTCGIPath$><$MTCommentScript$>?entry_id=<$MTEntryID$>" onclick="OpenComments(this.href); return false"><MT_TRANS phrase="Comments"> (<$MTEntryCommentCount$>)</a>
	</MTEntryIfAllowComments>
	<MTEntryIfAllowPings>
	| <a href="<$MTCGIPath$><$MTTrackbackScript$>?__mode=view&amp;entry_id=<$MTEntryID$>" onclick="OpenTrackback(this.href); return false"><MT_TRANS phrase="TrackBack"></a>
	</MTEntryIfAllowPings>
</div>

</div>

</MTEntries>
</div>
</div>

</body>
</html>
',
          'type' => 'archive',
          'name' => 'Date-Based Archive'
        },

{
          'text' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<$MTPublishCharset$>" />

<title><$MTBlogName$>: <$MTArchiveTitle$> <MT_TRANS phrase="Archives"></title>

<link rel="stylesheet" href="<$MTBlogURL$>styles-site.css" type="text/css" />
<link rel="alternate" type="application/rss+xml" title="RSS" href="<$MTBlogURL$>index.rdf" />

<script language="javascript" type="text/javascript">
function OpenComments (c) {
    window.open(c,
                    \'comments\',
                    \'width=480,height=480,scrollbars=yes,status=yes\');
}

function OpenTrackback (c) {
    window.open(c,
                    \'trackback\',
                    \'width=480,height=480,scrollbars=yes,status=yes\');
}
</script>

</head>

<body>

<div id="banner">
<h1><a href="<$MTBlogURL$>" accesskey="1"><$MTBlogName$></a></h1>
<span class="description"><$MTBlogDescription$></span>
</div>

<div id="container">

<div class="blog">
<MTEntries>
<$MTEntryTrackbackData$>

<MTDateHeader>
<h2 class="date"><$MTEntryDate format="%x"$></h2>
</MTDateHeader>

<div class="blogbody">

<a name="<$MTEntryID pad="1"$>"></a>
<h3 class="title"><$MTEntryTitle$></h3>

<$MTEntryBody$>

<MTEntryIfExtended>
<$MTEntryMore$>
</MTEntryIfExtended>

<div class="posted">
	<MT_TRANS phrase="Posted by"> <$MTEntryAuthor$> <MT_TRANS phrase="at"> <a href="<$MTEntryPermalink$>"><$MTEntryDate format="%X"$></a>
	<MTEntryIfAllowComments>
	| <a href="<$MTCGIPath$><$MTCommentScript$>?entry_id=<$MTEntryID$>" onclick="OpenComments(this.href); return false"><MT_TRANS phrase="Comments"> (<$MTEntryCommentCount$>)</a>
	</MTEntryIfAllowComments>
	<MTEntryIfAllowPings>
	| <a href="<$MTCGIPath$><$MTTrackbackScript$>?__mode=view&amp;entry_id=<$MTEntryID$>" onclick="OpenTrackback(this.href); return false"><MT_TRANS phrase="TrackBack"></a>
	</MTEntryIfAllowPings>
</div>

</div>

</MTEntries>
</div>

</div>

</body>
</html>
',
          'type' => 'category',
          'name' => 'Category Archive'
        },

{
          'text' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<$MTPublishCharset$>" />

<title><$MTBlogName$>: <$MTEntryTitle$></title>

<link rel="stylesheet" href="<$MTBlogURL$>styles-site.css" type="text/css" />
<link rel="alternate" type="application/rss+xml" title="RSS" href="<$MTBlogURL$>index.rdf" />

<link rel="start" href="<$MTBlogURL$>" title="Home" />
<MTEntryPrevious>
<link rel="prev" href="<$MTEntryPermalink$>" title="<$MTEntryTitle encode_html="1"$>" />
</MTEntryPrevious>
<MTEntryNext>
<link rel="next" href="<$MTEntryPermalink$>" title="<$MTEntryTitle encode_html="1"$>" />
</MTEntryNext>

<script type="text/javascript" language="javascript">
<!--

function OpenTrackback (c) {
    window.open(c,
                    \'trackback\',
                    \'width=480,height=480,scrollbars=yes,status=yes\');
}

var HOST = \'<$MTBlogHost$>\';

// Copyright (c) 1996-1997 Athenia Associates.
// http://www.webreference.com/js/
// License is granted if and only if this entire
// copyright notice is included. By Tomer Shiran.

function setCookie (name, value, expires, path, domain, secure) {
    var curCookie = name + "=" + escape(value) + ((expires) ? "; expires=" + expires.toGMTString() : "") + ((path) ? "; path=" + path : "") + ((domain) ? "; domain=" + domain : "") + ((secure) ? "; secure" : "");
    document.cookie = curCookie;
}

function getCookie (name) {
    var prefix = name + \'=\';
    var c = document.cookie;
    var nullstring = \'\';
    var cookieStartIndex = c.indexOf(prefix);
    if (cookieStartIndex == -1)
        return nullstring;
    var cookieEndIndex = c.indexOf(";", cookieStartIndex + prefix.length);
    if (cookieEndIndex == -1)
        cookieEndIndex = c.length;
    return unescape(c.substring(cookieStartIndex + prefix.length, cookieEndIndex));
}

function deleteCookie (name, path, domain) {
    if (getCookie(name))
        document.cookie = name + "=" + ((path) ? "; path=" + path : "") + ((domain) ? "; domain=" + domain : "") + "; expires=Thu, 01-Jan-70 00:00:01 GMT";
}

function fixDate (date) {
    var base = new Date(0);
    var skew = base.getTime();
    if (skew > 0)
        date.setTime(date.getTime() - skew);
}

function rememberMe (f) {
    var now = new Date();
    fixDate(now);
    now.setTime(now.getTime() + 365 * 24 * 60 * 60 * 1000);
    setCookie(\'mtcmtauth\', f.author.value, now, \'\', HOST, \'\');
    setCookie(\'mtcmtmail\', f.email.value, now, \'\', HOST, \'\');
    setCookie(\'mtcmthome\', f.url.value, now, \'\', HOST, \'\');
}

function forgetMe (f) {
    deleteCookie(\'mtcmtmail\', \'\', HOST);
    deleteCookie(\'mtcmthome\', \'\', HOST);
    deleteCookie(\'mtcmtauth\', \'\', HOST);
    f.email.value = \'\';
    f.author.value = \'\';
    f.url.value = \'\';
}

//-->
</script>

<$MTEntryTrackbackData$>

<MTBlogIfCCLicense>
<$MTCCLicenseRDF$>
</MTBlogIfCCLicense>

</head>

<body>

<div id="banner">
<h1><a href="<$MTBlogURL$>" accesskey="1"><$MTBlogName$></a></h1>
<span class="description"><$MTBlogDescription$></span>
</div>

<div id="container">

<div class="blog">

<div id="menu">
<MTEntryPrevious>
<a href="<$MTEntryPermalink$>">&laquo; <$MTEntryTitle$></a> |
</MTEntryPrevious>
<a href="<$MTBlogURL$>"><MT_TRANS phrase="Main"></a>
<MTEntryNext>
| <a href="<$MTEntryPermalink$>"><$MTEntryTitle$> &raquo;</a>
</MTEntryNext>
</div>

</div>


<div class="blog">

<h2 class="date"><$MTEntryDate format="%x"$></h2>

<div class="blogbody">

<h3 class="title"><$MTEntryTitle$></h3>

<$MTEntryBody$>

<a name="more"></a>
<$MTEntryMore$>

<span class="posted"><MT_TRANS phrase="Posted by"> <$MTEntryAuthor$> <MT_TRANS phrase="at"> <$MTEntryDate$>
<MTEntryIfAllowPings>
| <a href="<$MTCGIPath$><$MTTrackbackScript$>?__mode=view&amp;entry_id=<$MTEntryID$>" onclick="OpenTrackback(this.href); return false"><MT_TRANS phrase="TrackBack"></a>
</MTEntryIfAllowPings>
<br /></span>

</div>

<MTEntryIfAllowComments>

<div class="comments-head"><a name="comments"></a><MT_TRANS phrase="Comments"></div>

<MTComments>
<div class="comments-body">
<$MTCommentBody$>
<span class="comments-post"><MT_TRANS phrase="Posted by:"> <$MTCommentAuthorLink spam_protect="1"$> <MT_TRANS phrase="at"> <$MTCommentDate$></span>
</div>
</MTComments>

<MTEntryIfCommentsOpen>

<div class="comments-head"><MT_TRANS phrase="Post a comment"></div>

<div class="comments-body">
<form method="post" action="<$MTCGIPath$><$MTCommentScript$>" name="comments_form" onsubmit="if (this.bakecookie[0].checked) rememberMe(this)">
<input type="hidden" name="static" value="1" />
<input type="hidden" name="entry_id" value="<$MTEntryID$>" />

<div style="width:180px; padding-right:15px; margin-right:15px; float:left; text-align:left; border-right:1px dotted #bbb;">
	<label for="author"><MT_TRANS phrase="Name:"></label><br />
	<input tabindex="1" id="author" name="author" /><br /><br />

	<label for="email"><MT_TRANS phrase="Email Address:"></label><br />
	<input tabindex="2" id="email" name="email" /><br /><br />

	<label for="url"><MT_TRANS phrase="URL:"></label><br />
	<input tabindex="3" id="url" name="url" /><br /><br />
</div>

<MT_TRANS phrase="Remember personal info?"><br />
<input type="radio" id="bakecookie" name="bakecookie" /><label for="bakecookie"><MT_TRANS phrase="Yes"></label><input type="radio" id="forget" name="bakecookie" onclick="forgetMe(this.form)" value="Forget Info" style="margin-left: 15px;" /><label for="forget"><MT_TRANS phrase="No"></label><br style="clear: both;" />

<label for="text"><MT_TRANS phrase="Comments:"></label><br />
<textarea tabindex="4" id="text" name="text" rows="10" cols="50"></textarea><br /><br />

<input type="submit" name="preview" value="&nbsp;<MT_TRANS phrase="Preview">&nbsp;" />
<input style="font-weight: bold;" type="submit" name="post" value="&nbsp;<MT_TRANS phrase="Post">&nbsp;" /><br /><br />

</form>

<script type="text/javascript" language="javascript">
<!--
document.comments_form.email.value = getCookie("mtcmtmail");
document.comments_form.author.value = getCookie("mtcmtauth");
document.comments_form.url.value = getCookie("mtcmthome");
if (getCookie("mtcmtauth")) {
    document.comments_form.bakecookie[0].checked = true;
} else {
    document.comments_form.bakecookie[1].checked = true;
}
//-->
</script>
</div>
</MTEntryIfCommentsOpen>
</MTEntryIfAllowComments>
</div>
</div>
</body>
</html>
',
          'type' => 'individual',
          'name' => 'Individual Entry Archive'
        },

{
          'text' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<$MTPublishCharset$>" />

<title><$MTBlogName$>: <MT_TRANS phrase="Discussion on"> <$MTEntryTitle$></title>

<link rel="stylesheet" href="<$MTBlogURL$>styles-site.css" type="text/css" />

</head>

<body onload="window.focus()">
<div id="banner-commentspop"><MT_TRANS phrase="Continuing the discussion..."></div>

<div class="blog">

<div class="trackback-url"><MT_TRANS phrase="TrackBack URL for this entry:"><br /><$MTEntryTrackbackLink$> <br /><br /> <MT_TRANS phrase="Listed below are links to weblogs that reference"> <a href="<$MTEntryPermalink$>">\'<$MTEntryTitle$>\'</a> <MT_TRANS phrase="from"> <a href="<$MTBlogURL$>"><$MTBlogName$></a>.</div>

<MTPings>
<div class="trackback-body">
<a name="<$MTPingID$>"></a>
<span class="trackback-post"><a href="<$MTPingURL$>" target="new"><$MTPingTitle$></a><br />
<b><MT_TRANS phrase="Excerpt:"></b> <$MTPingExcerpt$><br />
<b><MT_TRANS phrase="Weblog:"></b> <$MTPingBlogName$><br />
<b><MT_TRANS phrase="Tracked:"></b> <$MTPingDate$></span>
</div>
</MTPings>

</div>

</div>

</body>
</html>',
          'rebuild_me' => '0',
          'type' => 'pings',
          'name' => 'TrackBack Listing Template'
        },
]
