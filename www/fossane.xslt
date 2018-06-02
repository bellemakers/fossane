<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.1" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="xml" version="1.0" doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd" encoding="UTF-8" indent="yes" omit-xml-declaration="no"/>
	<xsl:template match="/">
		<xsl:call-template name="recursion-main">
			<xsl:with-param name="currentlang" select="count(/fossane/languages/language)"/>
		</xsl:call-template>
	</xsl:template>
	<xsl:template name="recursion-main">
		<xsl:param name="currentlang"/>
		<xsl:if test="number($currentlang) > 0">
			<xsl:for-each select="fossane/page">
				<!-- Variable contains @id of current <page> -->
				<xsl:variable name="currentid">
					<xsl:value-of select="./@id"/>
				</xsl:variable>
				<!-- Variable contains relative location after language folder to be used as part of the documenthref variable (used with xsl:document element) -->
				<xsl:variable name="relativelocation">
					<xsl:for-each select="//fileid[@id=$currentid]">
						<xsl:for-each select="ancestor::folder">
							<xsl:value-of select="foldername[@lang=$currentlang]"/>/</xsl:for-each>
						<xsl:value-of select="//file[@id=$currentid]/filename[@lang=$currentlang]"/>.html</xsl:for-each>
				</xsl:variable>
				<!-- Variable contains string to get back to the root (e.g. '../../../') -->
				<xsl:variable name="backtoroot">
					<xsl:for-each select="//fileid[@id=$currentid]">
						<xsl:choose>
							<xsl:when test="@id=//filestructure/file/@id and $currentlang=1">
						</xsl:when>
							<xsl:otherwise>
								<xsl:for-each select="ancestor::folder[//fileid[@id=$currentid]]">../</xsl:for-each>../</xsl:otherwise>
						</xsl:choose>
					</xsl:for-each>
				</xsl:variable>
				<!-- Variable adds the name of the respective language folder in front of $relativelocation, unless it is highermost level file with filename@lang=1 -->
				<xsl:variable name="languagefolder">
					<xsl:choose>
						<xsl:when test="@id=//filestructure/file/@id and $currentlang=1"/>
						<xsl:otherwise>
							<xsl:value-of select="/fossane/languages/language[@lang=$currentlang]/@shortname"/>/</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>
				<!-- variable contains the relative location of the graphicsfolder -->
				<xsl:variable name="graphicsfolder" select="concat(//graphicsfolder,'/')"/>
				<!-- concats the $documenthref variable -->
				<xsl:variable name="documenthref">
					<xsl:value-of select="concat($languagefolder,$relativelocation)"/>
				</xsl:variable>
				<!-- ******** -->
				<!-- ******** -->
				<!-- ******** -->
				<!-- ******** -->
				<!-- ******** -->
				<!-- ******** -->
				<!-- documents below contain html code for xhtml strict dtd (apart from use of iframe) files for use with css2 document -->
				<!-- ******** -->
				<!-- ******** -->
				<!-- ******** -->
				<!-- ******** -->
				<!-- ******** -->
				<!-- ******** -->
				<xsl:document method="html" href="{$documenthref}">
					<html lang="{/fossane/languages/language[@lang=$currentlang]/@shortname}">
						<head>
							<title>
								<xsl:call-template name="title">
									<xsl:with-param name="currentlang" select="$currentlang"/>
									<xsl:with-param name="currentid" select="$currentid"/>
								</xsl:call-template>
							</title>
							<!-- creates link element with link to equivalent file in other language -->
							<xsl:call-template name="link-language">
								<xsl:with-param name="currentlang" select="$currentlang"/>
								<xsl:with-param name="currentid" select="$currentid"/>
								<xsl:with-param name="backtoroot" select="$backtoroot"/>
								<xsl:with-param name="pastalternateroot"/>
								<xsl:with-param name="languagefolder" select="$languagefolder"/>
							</xsl:call-template>
							<meta name="robots" content="all"/>
							<xsl:call-template name="author">
								<xsl:with-param name="currentlang" select="$currentlang"/>
								<xsl:with-param name="currentid" select="$currentid"/>
								<xsl:with-param name="backtoroot" select="$backtoroot"/>
								<xsl:with-param name="pastalternateroot"/>
								<xsl:with-param name="languagefolder" select="$languagefolder"/>
							</xsl:call-template>
							<xsl:call-template name="keywords">
								<xsl:with-param name="currentlang" select="$currentlang"/>
								<xsl:with-param name="currentid" select="$currentid"/>
								<xsl:with-param name="backtoroot" select="$backtoroot"/>
								<xsl:with-param name="pastalternateroot"/>
								<xsl:with-param name="languagefolder" select="$languagefolder"/>
							</xsl:call-template>
							<xsl:call-template name="description">
								<xsl:with-param name="currentlang" select="$currentlang"/>
								<xsl:with-param name="currentid" select="$currentid"/>
								<xsl:with-param name="backtoroot" select="$backtoroot"/>
								<xsl:with-param name="pastalternateroot"/>
								<xsl:with-param name="languagefolder" select="$languagefolder"/>
							</xsl:call-template>
							<link rel="stylesheet" type="text/css" href="{$backtoroot}fosscss2.css"/>
							<style type="text/css"><![CDATA[<!--]]>
									.backgroundpic {
									background-image: url("http://www.fossane.no/<xsl:value-of select="//graphicsfolder"/>/<xsl:value-of select="pics/header"/>.<xsl:value-of select="pics/header/@type"/>"); 
									position:relative;
									height:122px;
									}
							<![CDATA[-->]]></style>
							<xsl:if test="$currentid=//filestructure/file/@id and $currentlang=1">
								<script src="{$backtoroot}sniffer2.js" type="text/javascript">

							</script>
							</xsl:if>
						</head>
						<body id="LMR">
							<div id="frame">
								<div id="colL">
									<!-- link back to 2nd level file when on 2nd, 3rd, or 4th level file OR links to 2nd level files when on 1st level-->
									<div class="lang">
										<xsl:call-template name="languagesection">
											<xsl:with-param name="currentlang" select="$currentlang"/>
											<xsl:with-param name="currentid" select="$currentid"/>
											<xsl:with-param name="backtoroot" select="$backtoroot"/>
											<xsl:with-param name="pastalternateroot"/>
										</xsl:call-template>
									</div>
									<xsl:call-template name="currentsection">
										<xsl:with-param name="currentlang" select="$currentlang"/>
										<xsl:with-param name="currentid" select="$currentid"/>
										<xsl:with-param name="backtoroot" select="$backtoroot"/>
										<xsl:with-param name="pastalternateroot"/>
										<xsl:with-param name="languagefolder" select="$languagefolder"/>
									</xsl:call-template>
									<xsl:call-template name="colL">
										<xsl:with-param name="currentlang" select="$currentlang"/>
										<xsl:with-param name="currentid" select="$currentid"/>
										<xsl:with-param name="backtoroot" select="$backtoroot"/>
										<xsl:with-param name="pastalternateroot"/>
										<xsl:with-param name="languagefolder" select="$languagefolder"/>
									</xsl:call-template>
									<xsl:call-template name="home">
										<xsl:with-param name="currentlang" select="$currentlang"/>
										<xsl:with-param name="currentid" select="$currentid"/>
										<xsl:with-param name="backtoroot" select="$backtoroot"/>
										<xsl:with-param name="pastalternateroot"/>
										<xsl:with-param name="languagefolder" select="$languagefolder"/>
									</xsl:call-template>
								</div>
								<!-- BEGIN wrap -->
								<div id="wrap">
									<!-- BEGIN left column -->
									<!-- START main column -->
									<div id="colM">
										<div class="backgroundpic"/>
										<!-- BEGIN navigationbar -->
										<div id="nav">
											<div class="tree">
												<table cellspacing="0" cellpadding="0">
													<tbody>
														<tr>
															<td>
																<xsl:call-template name="tree">
																	<xsl:with-param name="currentlang" select="$currentlang"/>
																	<xsl:with-param name="currentid" select="$currentid"/>
																	<xsl:with-param name="backtoroot" select="$backtoroot"/>
																	<xsl:with-param name="pastalternateroot"/>
																	<xsl:with-param name="languagefolder" select="$languagefolder"/>
																</xsl:call-template>
															</td>
														</tr>
													</tbody>
												</table>
											</div>
											<div class="updated">
												<xsl:call-template name="updated">
													<xsl:with-param name="currentlang" select="$currentlang"/>
												</xsl:call-template>
											</div>
										</div>
										<!-- END navigation bar -->
										<div class="heading">
											<span class="pre-emphasize">
												<xsl:call-template name="pre-emphasize">
													<xsl:with-param name="currentlang" select="$currentlang"/>
												</xsl:call-template>&#160;</span>
											<span class="emphasize">
												<xsl:call-template name="emphasize">
													<xsl:with-param name="currentlang" select="$currentlang"/>
												</xsl:call-template>&#160;</span>
											<span class="post-emphasize">
												<xsl:call-template name="post-emphasize">
													<xsl:with-param name="currentlang" select="$currentlang"/>
												</xsl:call-template>&#160;</span>
										</div>
										<div class="text">
											<div class="introduction">
												<xsl:call-template name="introduction">
													<xsl:with-param name="currentlang" select="$currentlang"/>
													<xsl:with-param name="currentid" select="$currentid"/>
													<xsl:with-param name="backtoroot" select="$backtoroot"/>
													<xsl:with-param name="pastalternateroot"/>
												</xsl:call-template>
											</div>
											<div class="maintext">
												<xsl:call-template name="maintext">
													<xsl:with-param name="currentlang" select="$currentlang"/>
													<xsl:with-param name="currentid" select="$currentid"/>
													<xsl:with-param name="backtoroot" select="$backtoroot"/>
													<xsl:with-param name="pastalternateroot"/>
												</xsl:call-template>
											</div>
											<div class="link">
												<xsl:call-template name="link">
													<xsl:with-param name="currentlang" select="$currentlang"/>
													<xsl:with-param name="currentid" select="$currentid"/>
													<xsl:with-param name="backtoroot" select="$backtoroot"/>
													<xsl:with-param name="pastalternateroot"/>
												</xsl:call-template>
											</div>
											<div class="pricetable">
												<xsl:call-template name="pricetable">
													<xsl:with-param name="currentlang" select="$currentlang"/>
													<xsl:with-param name="currentid" select="$currentid"/>
												</xsl:call-template>
											</div>
											<div class="bulletlist">
												<xsl:call-template name="bulletlist">
													<xsl:with-param name="currentlang" select="$currentlang"/>
													<xsl:with-param name="currentid" select="$currentid"/>
												</xsl:call-template>
											</div>
											<xsl:if test="text/contactdetails='true'">
												<em>
													<xsl:value-of select="//namecontact[@lang=$currentlang]"/>:<p/>
												</em>
												<xsl:call-template name="contactdetails">
													<xsl:with-param name="currentlang" select="$currentlang"/>
												</xsl:call-template>
											</xsl:if>
											<div class="maparea">
												<xsl:call-template name="maparea">
													<xsl:with-param name="currentlang" select="$currentlang"/>
													<xsl:with-param name="currentid" select="$currentid"/>
													<xsl:with-param name="backtoroot" select="$backtoroot"/>
													<xsl:with-param name="pastalternateroot"/>
												</xsl:call-template>
											</div>
											<div class="galleryarea">
												<xsl:call-template name="galleryarea">
													<xsl:with-param name="currentlang" select="$currentlang"/>
													<xsl:with-param name="currentid" select="$currentid"/>
													<xsl:with-param name="backtoroot" select="$backtoroot"/>
													<xsl:with-param name="pastalternateroot"/>
												</xsl:call-template>
											</div>
											<div class="fifthlevel">
												<xsl:call-template name="fifthlevel">
													<xsl:with-param name="currentlang" select="$currentlang"/>
													<xsl:with-param name="currentid" select="$currentid"/>
													<xsl:with-param name="backtoroot" select="$backtoroot"/>
													<xsl:with-param name="pastalternateroot"/>
												</xsl:call-template>
											</div>
										</div>
										<div id="footer">
											<xsl:call-template name="footer">
												<xsl:with-param name="currentlang" select="$currentlang"/>
												<xsl:with-param name="currentid" select="$currentid"/>
												<xsl:with-param name="backtoroot" select="$backtoroot"/>
												<xsl:with-param name="pastalternateroot"/>
											</xsl:call-template>
										</div>
									</div>
									<!-- END main column -->
								</div>
								<!-- END wrap -->
							</div>
						</body>
					</html>
				</xsl:document>
			</xsl:for-each>
			<xsl:call-template name="recursion-main">
				<xsl:with-param name="currentlang" select="number($currentlang) -1"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>
	<xsl:template name="link-language">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:param name="languagefolder"/>
		<xsl:for-each select="//file[@id=$currentid]/filename">
			<xsl:variable name="link-lang">
				<xsl:value-of select="./@lang"/>
			</xsl:variable>
			<!-- Variable contains relative location after language folder to be used as part of the languagelink variable (used with xsl:document element) -->
			<xsl:variable name="relativelocation-otherlang">
				<xsl:for-each select="//fileid[@id=$currentid]">
					<xsl:for-each select="ancestor::folder">
						<xsl:value-of select="foldername[@lang=$link-lang]"/>/</xsl:for-each>
					<xsl:choose>
						<xsl:when test="//file[@id=$currentid]/filename[@lang=$link-lang]='index'"/>
						<xsl:otherwise>
							<xsl:value-of select="//file[@id=$currentid]/filename[@lang=$link-lang]"/>.html</xsl:otherwise>
					</xsl:choose>
				</xsl:for-each>
			</xsl:variable>
			<!-- Variable adds the name of the respective language folder in front of $relativelocation, unless it is highermost level file with filename@lang=1 -->
			<xsl:variable name="languagefolder-otherlang">
				<xsl:choose>
					<xsl:when test="../@id=//filestructure/file/@id and $link-lang=1"/>
					<xsl:otherwise>
						<xsl:value-of select="/fossane/languages/language[@lang=$link-lang]/@shortname"/>/</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
			<!-- concats the $languagelink variable -->
			<xsl:variable name="languagelink">
				<xsl:value-of select="concat($languagefolder-otherlang,$relativelocation-otherlang)"/>
			</xsl:variable>
			<xsl:if test="not($link-lang=$currentlang)">
				<link rel="alternate" type="text/html" href="{$backtoroot}{$languagelink}" hreflang="{/fossane/languages/language[@lang=$link-lang]/@shortname}" lang="{/fossane/languages/language[@lang=$link-lang]/@shortname}" title="{//page[@id=$currentid]/text/browsertitle[@lang=$link-lang]}"/>
			</xsl:if>
		</xsl:for-each>
	</xsl:template>
	<xsl:template name="author">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:param name="languagefolder"/>
		<xsl:variable name="author">
			<xsl:choose>
				<xsl:when test="normalize-space(//page[@id=$currentid]/meta/author[@lang=$currentlang])">
					<xsl:value-of select="//page[@id=$currentid]/meta/author[@lang=$currentlang]"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="//universal/text/meta/author[@lang=$currentlang]"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<meta name="author" content="{$author}"/>
	</xsl:template>
	<xsl:template name="title">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:param name="languagefolder"/>Fossane: <xsl:value-of select="text/browsertitle[@lang=$currentlang]"/>
	</xsl:template>
	<xsl:template name="keywords">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:param name="languagefolder"/>
		<xsl:variable name="keywords">
			<xsl:choose>
				<xsl:when test="normalize-space(//page[@id=$currentid]/meta/keywords[@lang=$currentlang])">
					<xsl:value-of select="//page[@id=$currentid]/meta/keywords[@lang=$currentlang]"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="//universal/text/meta/keywords[@lang=$currentlang]"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<meta name="keywords" content="{$keywords}"/>
	</xsl:template>
	<xsl:template name="description">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:param name="languagefolder"/>
		<xsl:variable name="description">
			<xsl:choose>
				<xsl:when test="normalize-space(//page[@id=$currentid]/meta/description[@lang=$currentlang])">
					<xsl:value-of select="//page[@id=$currentid]/meta/description[@lang=$currentlang]"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="//universal/text/meta/description[@lang=$currentlang]"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<meta name="description" content="{$description}"/>
	</xsl:template>
	<xsl:template name="contactdetails">
		<xsl:param name="currentlang"/>
		<xsl:value-of select="//contactdetails/address/name[@lang=$currentlang]"/>
		<br>
			<xsl:value-of select="//contactdetails/address/addressline1[@lang=$currentlang]"/>
		</br>
		<br>
			<xsl:value-of select="//contactdetails/address/addressline2[@lang=$currentlang]"/>
		</br>
		<br>
			<xsl:value-of select="//contactdetails/address/postcode"/>&#160;<xsl:value-of select="//contactdetails/address/place"/>
		</br>
		<xsl:if test="normalize-space(//contactdetails/address/country[@lang=$currentlang])">
			<br>
				<xsl:value-of select="//contactdetails/address/country[@lang=$currentlang]"/>
			</br>
		</xsl:if>
		<br/>
		<br>
			<xsl:value-of select="//contactdetails/e-mail/heading[@lang=$currentlang]"/>: <a href="mailto:{//contactdetails/e-mail/e-mail}">
				<xsl:value-of select="//contactdetails/e-mail/e-mail"/>
			</a>
		</br>
		<br>
			<xsl:value-of select="//contactdetails/phone/heading[@lang=$currentlang]"/>: <xsl:value-of select="//contactdetails/phone/phone[@lang=$currentlang]"/>
		</br>
	</xsl:template>
	<xsl:template name="pre-emphasize">
		<xsl:param name="currentlang"/>
		<xsl:value-of select="text/heading/alt-text[@lang=$currentlang]/pre-emphasize"/>
	</xsl:template>
	<xsl:template name="emphasize">
		<xsl:param name="currentlang"/>
		<xsl:value-of select="text/heading/alt-text[@lang=$currentlang]/emphasize"/>
	</xsl:template>
	<xsl:template name="post-emphasize">
		<xsl:param name="currentlang"/>
		<xsl:value-of select="text/heading/alt-text[@lang=$currentlang]/post-emphasize"/>
	</xsl:template>
	<xsl:template name="languagesection">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:for-each select="//file[@id=$currentid]/filename">
			<xsl:variable name="link-lang2">
				<xsl:value-of select="./@lang"/>
			</xsl:variable>
			<!-- Variable contains relative location after language folder to be used as part of the languagelink2 variable (used with xsl:document element) -->
			<xsl:variable name="relativelocation-otherlang">
				<xsl:for-each select="//fileid[@id=$currentid]">
					<xsl:for-each select="ancestor::folder">
						<xsl:value-of select="foldername[@lang=$link-lang2]"/>/</xsl:for-each>
					<xsl:choose>
						<xsl:when test="//file[@id=$currentid]/filename[@lang=$link-lang2]='index'"/>
						<xsl:otherwise>
							<xsl:value-of select="//file[@id=$currentid]/filename[@lang=$link-lang2]"/>.html</xsl:otherwise>
					</xsl:choose>
				</xsl:for-each>
			</xsl:variable>
			<!-- Variable adds the name of the respective language folder in front of $relativelocation, unless it is highermost level file with filename@lang=1 -->
			<xsl:variable name="languagefolder-otherlang">
				<xsl:choose>
					<xsl:when test="../@id=//filestructure/file/@id and $link-lang2=1"/>
					<xsl:otherwise>
						<xsl:value-of select="/fossane/languages/language[@lang=$link-lang2]/@shortname"/>/</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
			<!-- concats the $languagelink2 variable -->
			<xsl:variable name="languagelink2">
				<xsl:value-of select="concat($languagefolder-otherlang,$relativelocation-otherlang)"/>
			</xsl:variable>
			<!-- Language links -->
			<xsl:choose>
				<xsl:when test="not($link-lang2=$currentlang)">
					<a href="{$backtoroot}{$languagelink2}" hreflang="{/fossane/languages/language[@lang=$link-lang2]/@shortname}">
						<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{/fossane/languages/language[@lang=$link-lang2]/@shortname}.gif" alt="{/fossane/languages/language[@lang=$link-lang2]/longname[@lang=$link-lang2]} ({/fossane/languages/language[@lang=$link-lang2]/longname[@lang=$currentlang]})"/>
					</a>
				</xsl:when>
				<xsl:otherwise>
					<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{/fossane/languages/language[@lang=$link-lang2]/@shortname}.gif" alt="{/fossane/languages/language[@lang=$link-lang2]/longname[@lang=$link-lang2]}"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:for-each>
	</xsl:template>
	<xsl:template name="tree">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:param name="languagefolder"/>
		<xsl:for-each select="//file[@id=$currentid]/ancestor::file">
			<xsl:choose>
				<xsl:when test="./@id=//filestructure/file/@id">
					<xsl:choose>
						<xsl:when test="$currentlang=1">
							<xsl:choose>
								<xsl:when test="//filestructure/file/filename[@lang=$currentlang]='index'">
									<a href="{$backtoroot}">
										<xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
									</a> &#187; </xsl:when>
								<xsl:otherwise>
									<a href="{$backtoroot}{//filestructure/file/filename[@lang=$currentlang]}.html">
										<xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
									</a> &#187; </xsl:otherwise>
							</xsl:choose>
						</xsl:when>
						<xsl:otherwise>
							<xsl:choose>
								<xsl:when test="//filestructure/file/filename[@lang=$currentlang]='index'">
									<a href="{$backtoroot}{$languagefolder}">
										<xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
									</a> &#187; </xsl:when>
								<xsl:otherwise>
									<a href="{$backtoroot}{$languagefolder}{//filestructure/file/filename[@lang=$currentlang]}.html">
										<xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
									</a> &#187; </xsl:otherwise>
							</xsl:choose>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="link4-id" select="./@id"/>
					<xsl:variable name="link4">
						<xsl:for-each select="//fileid[@id=$link4-id]">
							<xsl:for-each select="ancestor::folder">
								<xsl:value-of select="foldername[@lang=$currentlang]"/>/</xsl:for-each>
							<xsl:choose>
								<xsl:when test="//file[@id=$link4-id]/filename[@lang=$currentlang]='index'"/>
								<xsl:otherwise>
									<xsl:value-of select="//file[@id=$link4-id]/filename[@lang=$currentlang]"/>.html</xsl:otherwise>
							</xsl:choose>
						</xsl:for-each>
					</xsl:variable>
					<a href="{$backtoroot}{$languagefolder}{$link4}">
						<xsl:value-of select="./altname[@lang=$currentlang]"/>
					</a> &#187; </xsl:otherwise>
			</xsl:choose>
		</xsl:for-each>
		<xsl:value-of select="//file[@id=$currentid]/altname[@lang=$currentlang]"/>
	</xsl:template>
	<xsl:template name="updated">
		<xsl:param name="currentlang"/>
		<xsl:value-of select="//updated[@lang=$currentlang]"/>
		<xsl:value-of select="document('CurrentTime.xml')/calendar-time/date/day"/>/<xsl:value-of select="document('CurrentTime.xml')/calendar-time/date/month"/>/<xsl:value-of select="document('CurrentTime.xml')/calendar-time/date/year"/>
	</xsl:template>
	<xsl:template name="currentsection">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="languagefolder"/>
		<xsl:param name="graphicsfolder"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:variable name="link4-id" select="//filestructure/file/file[descendant-or-self::node()[@id=$currentid]]/@id"/>
		<xsl:variable name="link4">
			<xsl:for-each select="//fileid[@id=$link4-id]">
				<xsl:for-each select="ancestor::folder">
					<xsl:value-of select="foldername[@lang=$currentlang]"/>/</xsl:for-each>
				<xsl:choose>
					<xsl:when test="//file[@id=$link4-id]/filename[@lang=$currentlang]='index'"/>
					<xsl:otherwise>
						<xsl:value-of select="//file[@id=$link4-id]/filename[@lang=$currentlang]"/>.html</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
		</xsl:variable>
		<xsl:if test="$currentid=//filestructure/file/file/descendant-or-self::node()/@id">
			<div class="currentsection">
				<a href="{$backtoroot}{$languagefolder}{$link4}">
					<xsl:value-of select="//filestructure/file/file[descendant-or-self::node()[@id=$currentid]]/altname[@lang=$currentlang]"/>
				</a>
			</div>
		</xsl:if>
	</xsl:template>
	<xsl:template name="colL">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:param name="languagefolder"/>
		<xsl:choose>
			<xsl:when test="@id=//filestructure/file/@id">
				<xsl:for-each select="//filestructure/file/file[filename/@lang=$currentlang]">
					<xsl:variable name="link1-id" select="./@id"/>
					<xsl:variable name="link1">
						<xsl:for-each select="//fileid[@id=$link1-id]">
							<xsl:for-each select="ancestor::folder">
								<xsl:value-of select="foldername[@lang=$currentlang]"/>/</xsl:for-each>
							<xsl:choose>
								<xsl:when test="//file[@id=$link1-id]/filename[@lang=$currentlang]='index'"/>
								<xsl:otherwise>
									<xsl:value-of select="//file[@id=$link1-id]/filename[@lang=$currentlang]"/>.html</xsl:otherwise>
							</xsl:choose>
						</xsl:for-each>
					</xsl:variable>
					<xsl:choose>
						<xsl:when test="$currentlang=1">
							<div class="longlink">
								<a href="{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link1}">
									<xsl:value-of select="altname[@lang=$currentlang]"/>
								</a>
							</div>
						</xsl:when>
						<xsl:otherwise>
							<div class="longlink">
								<a href="{$link1}">
									<xsl:value-of select="altname[@lang=$currentlang]"/>
								</a>
							</div>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:for-each>
			</xsl:when>
			<xsl:otherwise>
				<!--					<div class="logo">
					<xsl:variable name="link1-id" select="//filestructure/file/file[descendant-or-self::file[@id=$currentid]]/@id"/>
					<xsl:variable name="link1">
						<xsl:for-each select="/descendant::node()/fileid[@id=$link1-id]">
							<xsl:for-each select="ancestor::folder">
								<xsl:value-of select="foldername[@lang=$currentlang]"/>/</xsl:for-each>
							<xsl:choose>
								<xsl:when test="//file[@id=$link1-id]/filename[@lang=$currentlang]='index'"/>
								<xsl:otherwise>
									<xsl:value-of select="/descendant::node()/file[@id=$link1-id]/filename[@lang=$currentlang]"/>.html</xsl:otherwise>
							</xsl:choose>
						</xsl:for-each>
					</xsl:variable>
					<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link1}">
						<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link1-id]/gifname[@lang=$currentlang]}.gif" alt="{/descendant::node()/file[@id=$link1-id]/altname[@lang=$currentlang]}"/>
					</a>
				</div> -->
			</xsl:otherwise>
		</xsl:choose>
		<!-- links to 3rd level files when on 2nd, 3rd or 4th level file -->
		<xsl:choose>
			<xsl:when test="$currentid=//filestructure/file/file/descendant-or-self::node()/@id">
				<xsl:for-each select="//filestructure/file/file[descendant-or-self::node()/@id=$currentid]/file[filename[@lang=$currentlang]]">
					<xsl:variable name="link2-id" select="./@id"/>
					<xsl:variable name="link2">
						<xsl:for-each select="/descendant::node()/fileid[@id=$link2-id]">
							<xsl:for-each select="ancestor::folder">
								<xsl:value-of select="foldername[@lang=$currentlang]"/>/</xsl:for-each>
							<xsl:choose>
								<xsl:when test="//file[@id=$link2-id]/filename[@lang=$currentlang]='index'"/>
								<xsl:otherwise>
									<xsl:value-of select="//file[@id=$link2-id]/filename[@lang=$currentlang]"/>.html</xsl:otherwise>
							</xsl:choose>
						</xsl:for-each>
					</xsl:variable>
					<xsl:choose>
						<xsl:when test="//file[@id=$currentid]=.//file or //file[@id=$currentid]=.">
							<div class="currentlink">
								<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link2}">
									<xsl:value-of select="/descendant::node()/file[@id=$link2-id]/altname[@lang=$currentlang]"/>
								</a>
							</div>
						</xsl:when>
						<xsl:otherwise>
							<div class="link">
								<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link2}">
									<xsl:value-of select="/descendant::node()/file[@id=$link2-id]/altname[@lang=$currentlang]"/>
								</a>
							</div>
						</xsl:otherwise>
					</xsl:choose>
					<xsl:if test="//file[@id=$currentid]=.//file or //file[@id=$currentid]=.">
						<!--			<xsl:if test="normalize-space(//filestructure/file/file/file[descendant-or-self::node()/@id=$currentid]/file)">
				<strong>
					<xsl:value-of select="//filestructure/file/file/file[descendant-or-self::node()/@id=$currentid]/iconheading[@lang=$currentlang]"/>
				</strong>
				<p/>
			</xsl:if> -->
						<xsl:if test="normalize-space(//filestructure/file/file/file[descendant-or-self::node()/@id=$currentid]/file)">
							<div class="colR">
								<xsl:for-each select="//filestructure/file/file/file[descendant-or-self::node()/@id=$currentid]/file">
									<xsl:variable name="link3-id" select="./@id"/>
									<xsl:variable name="link3">
										<xsl:for-each select="/descendant::node()/fileid[@id=$link3-id]">
											<xsl:for-each select="ancestor::folder">
												<xsl:value-of select="foldername[@lang=$currentlang]"/>/</xsl:for-each>
											<xsl:choose>
												<xsl:when test="//file[@id=$link3-id]/filename[@lang=$currentlang]='index'"/>
												<xsl:otherwise>
													<xsl:value-of select="//file[@id=$link3-id]/filename[@lang=$currentlang]"/>.html</xsl:otherwise>
											</xsl:choose>
										</xsl:for-each>
									</xsl:variable>
									<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link3}">
										<xsl:choose>
											<xsl:when test="$currentid=//file[ancestor-or-self::file[@id=$link3-id]]/@id">
												<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link3-id]/gifname[@lang=$currentlang]}_.gif" alt="* {/descendant::node()/file[@id=$link3-id]/altname[@lang=$currentlang]} *"/>
											</xsl:when>
											<xsl:otherwise>
												<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link3-id]/gifname[@lang=$currentlang]}.gif" alt="{/descendant::node()/file[@id=$link3-id]/altname[@lang=$currentlang]}"/>
											</xsl:otherwise>
										</xsl:choose>
									</a>
									<br/>
									<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link3}">
										<xsl:choose>
											<xsl:when test="$currentid=//file[ancestor-or-self::file[@id=$link3-id]]/@id">
												<span class="current">
													<xsl:value-of select="/descendant::node()/file[@id=$link3-id]/altname[@lang=$currentlang]"/>
												</span>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="/descendant::node()/file[@id=$link3-id]/altname[@lang=$currentlang]"/>
											</xsl:otherwise>
										</xsl:choose>
									</a>
									<br/>
									<br/>
								</xsl:for-each>
							</div>
						</xsl:if>
					</xsl:if>
				</xsl:for-each>
			</xsl:when>
			<xsl:otherwise/>
		</xsl:choose>
	</xsl:template>
	<xsl:template name="home">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:param name="languagefolder"/>
		<xsl:if test="not($currentid=//filestructure/file/@id)">
			<div class="home">
				<xsl:choose>
					<xsl:when test="$currentlang=1">
						<p>
							<xsl:choose>
								<xsl:when test="//filestructure/file/filename[@lang=$currentlang]='index'">
									<a href="{$backtoroot}">&#171; <xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
									</a>
								</xsl:when>
								<xsl:otherwise>
									<a href="{$backtoroot}{//filestructure/file/filename[@lang=$currentlang]}.html">&#171; <xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
									</a>
								</xsl:otherwise>
							</xsl:choose>
						</p>
					</xsl:when>
					<xsl:otherwise>
						<p>
							<xsl:choose>
								<xsl:when test="//filestructure/file/filename[@lang=$currentlang]='index'">
									<a href="{$backtoroot}{$languagefolder}">&#171; <xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
									</a>
								</xsl:when>
								<xsl:otherwise>
									<a href="{$backtoroot}{$languagefolder}{//filestructure/file/filename[@lang=$currentlang]}.html">&#171; <xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
									</a>
								</xsl:otherwise>
							</xsl:choose>
						</p>
					</xsl:otherwise>
				</xsl:choose>
			</div>
		</xsl:if>
	</xsl:template>
	<xsl:template name="colR">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:param name="languagefolder"/>
		<xsl:if test="$currentid=//filestructure/file/file/file/descendant-or-self::node()/@id">
			<!--			<xsl:if test="normalize-space(//filestructure/file/file/file[descendant-or-self::node()/@id=$currentid]/file)">
				<strong>
					<xsl:value-of select="//filestructure/file/file/file[descendant-or-self::node()/@id=$currentid]/iconheading[@lang=$currentlang]"/>
				</strong>
				<p/>
			</xsl:if> -->
			<xsl:for-each select="//filestructure/file/file/file[descendant-or-self::node()/@id=$currentid]/file">
				<xsl:variable name="link3-id" select="./@id"/>
				<xsl:variable name="link3">
					<xsl:for-each select="/descendant::node()/fileid[@id=$link3-id]">
						<xsl:for-each select="ancestor::folder">
							<xsl:value-of select="foldername[@lang=$currentlang]"/>/</xsl:for-each>
						<xsl:choose>
							<xsl:when test="//file[@id=$link3-id]/filename[@lang=$currentlang]='index'"/>
							<xsl:otherwise>
								<xsl:value-of select="//file[@id=$link3-id]/filename[@lang=$currentlang]"/>.html</xsl:otherwise>
						</xsl:choose>
					</xsl:for-each>
				</xsl:variable>
				<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link3}">
					<xsl:choose>
						<xsl:when test="$currentid=//file[ancestor-or-self::file[@id=$link3-id]]/@id">
							<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link3-id]/gifname[@lang=$currentlang]}_.gif" alt="* {/descendant::node()/file[@id=$link3-id]/altname[@lang=$currentlang]} *"/>
						</xsl:when>
						<xsl:otherwise>
							<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link3-id]/gifname[@lang=$currentlang]}.gif" alt="{/descendant::node()/file[@id=$link3-id]/altname[@lang=$currentlang]}"/>
						</xsl:otherwise>
					</xsl:choose>
				</a>
				<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link3}">
					<xsl:value-of select="/descendant::node()/file[@id=$link3-id]/altname[@lang=$currentlang]"/>
				</a>
				<br/>
			</xsl:for-each>
		</xsl:if>
	</xsl:template>
	<xsl:template name="introduction">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:if test="normalize-space(//page[@id=$currentid]/pics/introduction/UL/filename) or normalize-space(//page[@id=$currentid]/pics/introduction/UR/filename)">
			<div class="pics">
				<xsl:if test="normalize-space(//page[@id=$currentid]/pics/introduction/UL/filename)">
					<div class="UL">
						<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{//page[@id=$currentid]/pics/introduction/UL/filename}.{//page[@id=$currentid]/pics/introduction/UL/filename/@type}" alt="{//page[@id=$currentid]/pics/introduction/UL/caption[@lang=$currentlang]}"/>
					</div>
				</xsl:if>
				<xsl:if test="normalize-space(//page[@id=$currentid]/pics/introduction/UR/filename)">
					<div class="UR">
						<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{//page[@id=$currentid]/pics/introduction/UR/filename}.{//page[@id=$currentid]/pics/introduction/UR/filename/@type}" alt="{//page[@id=$currentid]/pics/introduction/UR/caption[@lang=$currentlang]}"/>
					</div>
				</xsl:if>
			</div>
		</xsl:if>
		<xsl:value-of select="text/introduction[@lang=$currentlang]"/>
	</xsl:template>
	<xsl:template name="maintext">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:for-each select="text/maintext[@lang=$currentlang]/para">
			<xsl:variable name="paranumber" select="position()"/>
			<p>
				<xsl:if test="$paranumber=//page[@id=$currentid]/pics/para[UL]/@number or $paranumber=//page[@id=$currentid]/pics/para[UR]/@number">
					<div class="pics">
						<xsl:if test="$paranumber=//page[@id=$currentid]/pics/para[UL]/@number">
							<div class="UL">
								<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{//page[@id=$currentid]/pics/para[@number=$paranumber]/UL/filename}.{//page[@id=$currentid]/pics/para[@number=$paranumber]/UL/filename/@type}" alt="{//page[@id=$currentid]/pics/para[@number=$paranumber]/UL/caption[@lang=$currentlang]}"/>
							</div>
						</xsl:if>
						<xsl:if test="$paranumber=//page[@id=$currentid]/pics/para[UR]/@number">
							<div class="UR">
								<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{//page[@id=$currentid]/pics/para[@number=$paranumber]/UR/filename}.{//page[@id=$currentid]/pics/para[@number=$paranumber]/UR/filename/@type}" alt="{//page[@id=$currentid]/pics/para[@number=$paranumber]/UR/caption[@lang=$currentlang]}"/>
							</div>
						</xsl:if>
					</div>
				</xsl:if>
				<div class="maintext">
					<xsl:value-of select="."/>
				</div>
			</p>
		</xsl:for-each>
	</xsl:template>
	<xsl:template name="link">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:for-each select="text/link[@lang=$currentlang]">
			<p>
				<a href="{./@href}" target="_blank">
					<xsl:value-of select="."/>
				</a>
			</p>
		</xsl:for-each>
	</xsl:template>
	<xsl:template name="pricetable">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:for-each select="text/prices">
			<table border="1">
				<tbody>
					<tr>
						<th align="left">
							<xsl:value-of select="headings/productcolumn/description[@lang=$currentlang]"/>
						</th>
						<xsl:for-each select="headings/pricecolumn">
							<th align="left">
								<xsl:value-of select="description[@lang=$currentlang]"/>
							</th>
						</xsl:for-each>
					</tr>
					<xsl:for-each select="product">
						<tr>
							<td width="155">
								<xsl:value-of select="description/descriptiontext[@lang=$currentlang]"/>
							</td>
							<xsl:for-each select="price">
								<td>
									<xsl:value-of select="/fossane/page/text/prices/headings/priceformat/before[@lang=$currentlang]"/>
									<xsl:value-of select="."/>
									<xsl:value-of select="/fossane/page/text/prices/headings/priceformat/after[@lang=$currentlang]"/>
								</td>
							</xsl:for-each>
						</tr>
					</xsl:for-each>
				</tbody>
			</table>
		</xsl:for-each>
	</xsl:template>
	<xsl:template name="bulletlist">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:for-each select="text/bulletlist">
			<xsl:for-each select="listitem">
				<ul>
					<li>
						<xsl:value-of select="itemtext[@lang=$currentlang]"/>
					</li>
				</ul>
			</xsl:for-each>
		</xsl:for-each>
	</xsl:template>
	<xsl:template name="maparea">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:for-each select="text/map">
			<strong>
				<xsl:value-of select="heading[@lang=$currentlang]"/>
			</strong>
			<p/>
			<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{gifname[@lang=$currentlang]}.gif" usemap="#{name}"/>
			<iframe src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{starthref}" name="picture" marginheight="0" marginwidth="0" scrolling="no" width="300" height="225" frameborder="0"/>
			<map name="{name}">
				<xsl:for-each select="area">
					<area href="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{href}" alt="{alt[@lang=$currentlang]}" shape="{shape}" coords="{coords}" target="picture"/>
				</xsl:for-each>
			</map>
		</xsl:for-each>
	</xsl:template>
	<xsl:template name="galleryarea">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:for-each select="text/gallery">
			<strong>
				<xsl:value-of select="heading[@lang=$currentlang]"/>
			</strong>
			<table>
				<tbody>
					<tr>
						<td>
							<div class="thumbs">
								<xsl:for-each select="picture">
									<a href="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{picture}" target="picture">
										<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{thumb}" alt=""/>
									</a>&#160;<br />
								</xsl:for-each>
							</div>
						</td>
						<td valign="top">
							<span class="iframe">
								<iframe src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{picture/picture}" name="picture" marginheight="0" marginwidth="0" scrolling="no" width="360" height="240" frameborder="0"/>
							</span>
						</td>
					</tr>
				</tbody>
			</table>
		</xsl:for-each>
	</xsl:template>
	<xsl:template name="fifthlevel">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<xsl:if test="$currentid=//filestructure/file/file/file/file/descendant-or-self::node()/@id">
			<p/>
			<table>
				<tbody>
					<tr>
						<xsl:for-each select="//filestructure/file/file/file/file[descendant-or-self::node()/@id=$currentid]/file">
							<td>
								<xsl:variable name="link5-id" select="./@id"/>
								<xsl:variable name="link5">
									<xsl:for-each select="/descendant::node()/fileid[@id=$link5-id]">
										<xsl:for-each select="ancestor::folder">
											<xsl:value-of select="foldername[@lang=$currentlang]"/>/</xsl:for-each>
										<xsl:choose>
											<xsl:when test="//file[@id=$link5-id]/filename[@lang=$currentlang]='index'"/>
											<xsl:otherwise>
												<xsl:value-of select="//file[@id=$link5-id]/filename[@lang=$currentlang]"/>.html</xsl:otherwise>
										</xsl:choose>
									</xsl:for-each>
								</xsl:variable>
								<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link5}">
									<xsl:choose>
										<xsl:when test="$currentid=//file[ancestor-or-self::file[@id=$link5-id]]/@id">
											<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link5-id]/gifname[@lang=$currentlang]}_.gif" alt="* {/descendant::node()/file[@id=$link5-id]/altname[@lang=$currentlang]} *"/>
										</xsl:when>
										<xsl:otherwise>
											<img src="{$backtoroot}{$pastalternateroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link5-id]/gifname[@lang=$currentlang]}.gif" alt="{/descendant::node()/file[@id=$link5-id]/altname[@lang=$currentlang]}"/>
										</xsl:otherwise>
									</xsl:choose>
								</a>
								<br/>
								<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link5}">
									<xsl:value-of select="/descendant::node()/file[@id=$link5-id]/altname[@lang=$currentlang]"/>
								</a>
							</td>
						</xsl:for-each>
					</tr>
				</tbody>
			</table>
			<p/>
		</xsl:if>
	</xsl:template>
	<xsl:template name="footer">
		<xsl:param name="currentlang"/>
		<xsl:param name="currentid"/>
		<xsl:param name="backtoroot"/>
		<xsl:param name="pastalternateroot"/>
		<p/>
		<div class="contactdetails">
			<xsl:call-template name="contactdetails">
				<xsl:with-param name="currentlang" select="$currentlang"/>
			</xsl:call-template>
		</div>
		<xsl:if test="normalize-space(/fossane/universal/text/footer/translator[@lang=$currentlang])">
			<br>
				<xsl:value-of select="/fossane/universal/text/footer/translator[@lang=$currentlang]"/>
			</br>
		</xsl:if>
		<br>
			<a href="mailto:{/fossane/universal/text/footer/webmaster/e-mail}">Webmaster</a>
		</br>
		<br>© <xsl:value-of select="document(CurrentTime.xml)/calendar-time/date/year"/>
			<a href="mailto:{/fossane/universal/text/contactdetails/e-mail/e-mail}">
				<xsl:value-of select="/fossane/universal/text/footer/copyright[@lang=$currentlang]"/>
			</a>
		</br>
	</xsl:template>
</xsl:stylesheet>
