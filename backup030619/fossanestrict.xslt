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
				<!-- concats the $documenthref variable -->
				<xsl:variable name="documenthref">
					<xsl:value-of select="concat($languagefolder,$relativelocation)"/>
				</xsl:variable>
				<xsl:document method="html" href="{$documenthref}">
					<!-- html code starts here -->
					<html lang="{/fossane/languages/language[@lang=$currentlang]/@shortname}">
						<head>
							<title>Fossane: <xsl:value-of select="text/browsertitle[@lang=$currentlang]"/>
							</title>
							<!-- creates link element with link to equivalent file in other language -->
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
							<meta name="robots" content="all"/>
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
							<link rel="stylesheet" type="text/css" href="{$backtoroot}fossane.css"/>
							<style type="text/css"><![CDATA[<!--]]>
								#header .backgroundpic {
									background-image: url("http://www.fossane.no/<xsl:value-of select="//graphicsfolder"></xsl:value-of>/<xsl:value-of select="pics/header"></xsl:value-of>"); 
									position:relative;
									height:145px;
									}
							<![CDATA[-->]]></style>
						</head>
						<body id="LMR">
							<!-- BEGIN header -->
							<div id="header">
								<div class="backgroundpic"/>
								<span class="logo"/>
								<div id="headingwrap">
									<div class="contactdetails">
										<xsl:value-of select="//contactdetails/address/name[@lang=$currentlang]"/>
										<br>
											<xsl:value-of select="//contactdetails/address/addressline1[@lang=$currentlang]"/>
										</br>
										<br>
											<xsl:value-of select="//contactdetails/address/postcode"/>&#160;<xsl:value-of select="//contactdetails/address/place"/>
										</br>
										<br>
											<xsl:value-of select="//contactdetails/address/country[@lang=$currentlang]"/>
										</br>
										<br/>
										<br>
											<xsl:value-of select="//contactdetails/e-mail/heading[@lang=$currentlang]"/>: <a href="mailto:{//contactdetails/e-mail/e-mail}">
												<xsl:value-of select="//contactdetails/e-mail/e-mail"/>
											</a>
										</br>
										<br>
											<xsl:value-of select="//contactdetails/phone/heading[@lang=$currentlang]"/>: <xsl:value-of select="//contactdetails/phone/phone[@lang=$currentlang]"/>
										</br>
									</div>
									<div class="heading">
										<div class="pre-emphasize">
											<xsl:value-of select="text/heading/alt-text[@lang=$currentlang]/pre-emphasize"/>&#160;</div>
										<div class="emphasize">
											<xsl:value-of select="text/heading/alt-text[@lang=$currentlang]/emphasize"/>&#160;</div>
										<div class="post-emphasize">
											<xsl:value-of select="text/heading/alt-text[@lang=$currentlang]/post-emphasize"/>&#160;</div>
									</div>
								</div>
							</div>
							<!-- END header -->
							<!-- BEGIN navigationbar -->
							<div id="nav">
								<!-- BEGIN language section -->
								<span class="lang">
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
													<img src="{$backtoroot}{//graphicsfolder}/{/fossane/languages/language[@lang=$link-lang2]/@shortname}.gif" alt="{/fossane/languages/language[@lang=$link-lang2]/@longname}" hspace="2" border="0"/>
												</a>
											</xsl:when>
											<xsl:otherwise>
												<img src="{$backtoroot}{//graphicsfolder}/{/fossane/languages/language[@lang=$link-lang2]/@shortname}.gif" alt="{/fossane/languages/language[@lang=$link-lang2]/@longname}" hspace="2" border="0"/>
											</xsl:otherwise>
										</xsl:choose>
									</xsl:for-each>
								</span>
								<!-- END language section -->
								<!-- BEGIN navigation tree -->
								<div class="tree">
									<table cellspacing="0" cellpadding="0">
										<tbody>
											<tr>
												<td>
													<xsl:for-each select="//file[@id=$currentid]/ancestor::file">
														<xsl:choose>
															<xsl:when test="./@id=//filestructure/file/@id">
																<xsl:choose>
																	<xsl:when test="$currentlang=1">
																		<a href="{$backtoroot}{//filestructure/file/filename[@lang=$currentlang]}.html">
																			<xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
																		</a> &gt; </xsl:when>
																	<xsl:otherwise>
																		<a href="{$backtoroot}{$languagefolder}{//filestructure/file/filename[@lang=$currentlang]}.html">
																			<xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
																		</a> &gt; </xsl:otherwise>
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
																</a> &gt; </xsl:otherwise>
														</xsl:choose>
													</xsl:for-each>
													<xsl:value-of select="//file[@id=$currentid]/altname[@lang=$currentlang]"/>
												</td>
											</tr>
										</tbody>
									</table>
								</div>
								<!-- END Navigation tree -->
								<!-- BEGIN Updated -->
								<div class="updated">
									<xsl:value-of select="//updated[@lang=$currentlang]"/>
									<xsl:value-of select="document('CurrentTime.xml')/calendar-time/date/day"/>.<xsl:value-of select="document('CurrentTime.xml')/calendar-time/date/month"/>.<xsl:value-of select="document('CurrentTime.xml')/calendar-time/date/year"/>
								</div>
								<!-- END Updated -->
							</div>
							<!-- END navigation bar -->
							<!-- BEGIN wrap -->
							<div id="wrap">
								<!-- BEGIN left column -->
								<div id="subwrap">
									<div id="colL">
										<!-- link back to 2nd level file when on 2nd, 3rd, or 4th level file OR links to 2nd level files when on 1st level-->
										<xsl:choose>
											<xsl:when test="@id=//filestructure/file/@id">
												<xsl:for-each select="//filestructure/file/file">
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
															<xsl:choose>
																<xsl:when test="position()=1">
																	<a href="{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link1}">
																		<img src="{$backtoroot}{//graphicsfolder}/{gifname[@lang=$currentlang]}.gif" alt="{altname[@lang=$currentlang]}" border="0"/>
																	</a>
																</xsl:when>
																<xsl:otherwise>
																	<p>
																		<a href="{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link1}">
																			<img src="{$backtoroot}{//graphicsfolder}/{gifname[@lang=$currentlang]}.gif" alt="{altname[@lang=$currentlang]}" border="0"/>
																		</a>
																	</p>
																</xsl:otherwise>
															</xsl:choose>
														</xsl:when>
														<xsl:otherwise>
															<xsl:choose>
																<xsl:when test="position()=1">
																	<a href="{$link1}">
																		<img src="{$backtoroot}{//graphicsfolder}/{gifname[@lang=$currentlang]}.gif" alt="{altname[@lang=$currentlang]}" border="0"/>
																	</a>
																</xsl:when>
																<xsl:otherwise>
																	<p>
																		<a href="{$link1}">
																			<img src="{$backtoroot}{//graphicsfolder}/{gifname[@lang=$currentlang]}.gif" alt="{altname[@lang=$currentlang]}" border="0"/>
																		</a>
																	</p>
																</xsl:otherwise>
															</xsl:choose>
														</xsl:otherwise>
													</xsl:choose>
												</xsl:for-each>
											</xsl:when>
											<xsl:otherwise>
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
													<img src="{$backtoroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link1-id]/gifname[@lang=$currentlang]}.gif" alt="{/descendant::node()/file[@id=$link1-id]/altname[@lang=$currentlang]}" border="0"/>
												</a>
											</xsl:otherwise>
										</xsl:choose>
										<!-- links to 3rd level files when on 2nd, 3rd or 4th level file -->
										<xsl:choose>
											<xsl:when test="$currentid=//filestructure/file/file/descendant-or-self::node()/@id">
												<xsl:for-each select="//filestructure/file/file[descendant-or-self::node()/@id=$currentid]/file">
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
													<p>
														<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link2}">
															<xsl:choose>
																<xsl:when test="$currentid=//file[ancestor-or-self::file[@id=$link2-id]]/@id">
																	<xsl:value-of select="/descendant::node()/file[@id=$link2-id]/altname[@lang=$currentlang]"/>
																</xsl:when>
																<xsl:otherwise>
																	<xsl:value-of select="/descendant::node()/file[@id=$link2-id]/altname[@lang=$currentlang]"/>
																</xsl:otherwise>
															</xsl:choose>
														</a>
													</p>
												</xsl:for-each>
												<xsl:if test="normalize-space(//filestructure/file/file[descendant-or-self::node()/@id=$currentid]/file)">
													<p>
														<img src="{$backtoroot}{//graphicsfolder}/bullet.gif" alt="o" border="0"/>
													</p>
												</xsl:if>
											</xsl:when>
											<xsl:otherwise/>
										</xsl:choose>
										<!-- link to 1st level file (if not at 1st level file) -->
										<xsl:if test="not($currentid=//filestructure/file/@id)">
											<xsl:choose>
												<xsl:when test="$currentlang=1">
													<p>
														<a href="{$backtoroot}{//filestructure/file/filename[@lang=$currentlang]}.html">
															<xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
														</a>
													</p>
												</xsl:when>
												<xsl:otherwise>
													<p>
														<a href="{$backtoroot}{$languagefolder}{//filestructure/file/filename[@lang=$currentlang]}.html">
															<xsl:value-of select="//filestructure/file/altname[@lang=$currentlang]"/>
														</a>
													</p>
												</xsl:otherwise>
											</xsl:choose>
										</xsl:if>
									</div>
									<!-- END left column -->
									<!-- BEGIN right column -->
									<!-- creates links to 4th level files when on 3rd and 4th level -->
									<xsl:if test="$currentid=//filestructure/file/file/file/descendant-or-self::node()/@id">
										<div id="colR">
											<xsl:if test="normalize-space(//filestructure/file/file/file[descendant-or-self::node()/@id=$currentid]/file)">
												<strong>
													<xsl:value-of select="//filestructure/file/file/file[descendant-or-self::node()/@id=$currentid]/iconheading[@lang=$currentlang]"/>
												</strong>
												<p/>
											</xsl:if>
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
															<img src="{$backtoroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link3-id]/gifname[@lang=$currentlang]}_.gif" alt="* {/descendant::node()/file[@id=$link3-id]/altname[@lang=$currentlang]} *" border="0"/>
														</xsl:when>
														<xsl:otherwise>
															<img src="{$backtoroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link3-id]/gifname[@lang=$currentlang]}.gif" alt="{/descendant::node()/file[@id=$link3-id]/altname[@lang=$currentlang]}" border="0"/>
														</xsl:otherwise>
													</xsl:choose>
												</a>
												<br/>
												<a href="{$backtoroot}{/fossane/languages/language[@lang=$currentlang]/@shortname}/{$link3}">
													<xsl:value-of select="/descendant::node()/file[@id=$link3-id]/altname[@lang=$currentlang]"/>
												</a>
												<br/>
												<br/>
											</xsl:for-each>
										</div>
									</xsl:if>
									<!-- END right column -->
								</div>
								<!-- START main column -->
								<div id="colM">
										<div class="introduction">
											<xsl:if test="normalize-space(//page[@id=$currentid]/pics/introduction/UL) or normalize-space(//page[@id=$currentid]/pics/introduction/UR)">
												<div class="pics">
													<xsl:if test="normalize-space(//page[@id=$currentid]/pics/introduction/UL)">
														<div class="UL">
															<img src="{$backtoroot}{//graphicsfolder}/{//page[@id=$currentid]/pics/introduction/UL}.{//page[@id=$currentid]/pics/introduction/UL/@type}" alt=""/>
														</div>
													</xsl:if>
													<xsl:if test="normalize-space(//page[@id=$currentid]/pics/introduction/UR)">
														<div class="UR">
															<img src="{$backtoroot}{//graphicsfolder}/{//page[@id=$currentid]/pics/introduction/UR}.{//page[@id=$currentid]/pics/introduction/UR/@type}" alt=""/>
														</div>
													</xsl:if>
												</div>
											</xsl:if>
											<strong>
												<xsl:value-of select="text/introduction[@lang=$currentlang]"/>
											</strong>
										</div>
										<xsl:for-each select="text/maintext[@lang=$currentlang]/para">
											<xsl:variable name="paranumber" select="position()"/>
											<p>
												<xsl:if test="$paranumber=//page[@id=$currentid]/pics/para[UL]/@number or $paranumber=//page[@id=$currentid]/pics/para[UR]/@number">
													<div class="pics">
														<xsl:if test="$paranumber=//page[@id=$currentid]/pics/para[UL]/@number">
															<div class="UL">
																<img src="{$backtoroot}{//graphicsfolder}/{//page[@id=$currentid]/pics/para[@number=$paranumber]/UL}.{//page[@id=$currentid]/pics/para[@number=$paranumber]/UL/@type}" alt=""/>
															</div>
														</xsl:if>
														<xsl:if test="$paranumber=//page[@id=$currentid]/pics/para[UR]/@number">
															<div class="UR">
																<img src="{$backtoroot}{//graphicsfolder}/{//page[@id=$currentid]/pics/para[@number=$paranumber]/UR}.{//page[@id=$currentid]/pics/para[@number=$paranumber]/UR/@type}" alt=""/>
															</div>
														</xsl:if>
													</div>
												</xsl:if>
												<div class="maintext">
													<xsl:value-of select="."/>
												</div>
											</p>
										</xsl:for-each>
										<xsl:for-each select="text/prices">
											<div class="pricetable">
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
																<td>
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
											</div>
										</xsl:for-each>
										<xsl:for-each select="text/bulletlist">
											<div class="bulletlist">
												<xsl:for-each select="listitem">
													<ul>
														<li>
															<xsl:value-of select="itemtext[@lang=$currentlang]"/>
														</li>
													</ul>
												</xsl:for-each>
											</div>
										</xsl:for-each>
										<xsl:for-each select="text/map">
											<div class="maparea">
												<strong>
													<xsl:value-of select="heading[@lang=$currentlang]"/>
												</strong>
												<p/>
												<span class="map">
													<img src="{$backtoroot}{//graphicsfolder}/{gifname[@lang=$currentlang]}.gif" usemap="#{name}" width="260"/>
												</span>
												<span class="iframe">
													<iframe src="{$backtoroot}{//graphicsfolder}/{starthref}" name="picture" marginheight="0" marginwidth="0" scrolling="no" width="260" height="300" frameborder="0"/>
												</span>
												<map name="{name}">
													<xsl:for-each select="area">
														<area href="{$backtoroot}{//graphicsfolder}/{href}" alt="{alt[@lang=$currentlang]}" shape="{shape}" coords="{coords}" target="picture"/>
													</xsl:for-each>
												</map>
											</div>
										</xsl:for-each>
										<xsl:for-each select="text/gallery">
											<div class="galleryarea">
												<strong>
													<xsl:value-of select="heading[@lang=$currentlang]"/>
												</strong>
												<p/>
												<span class="thumbs">
													<xsl:for-each select="picture">
														<a href="{$backtoroot}{//graphicsfolder}/{picture}" target="picture">
															<img src="{$backtoroot}{//graphicsfolder}/{thumb}" alt=""/>
														</a>&#160;</xsl:for-each>
												</span><p></p>
												<span class="iframe">
													<iframe src="{$backtoroot}{//graphicsfolder}/{picture/picture}" name="picture" marginheight="0" marginwidth="0" scrolling="no" width="360" height="240" frameborder="0"/>
												</span>
											</div>
										</xsl:for-each>
										<xsl:if test="$currentid=//filestructure/file/file/file/file/descendant-or-self::node()/@id">
											<p/>
											<div class="fifthlevel">
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
																				<img src="{$backtoroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link5-id]/gifname[@lang=$currentlang]}_.gif" alt="* {/descendant::node()/file[@id=$link5-id]/altname[@lang=$currentlang]} *" border="0"/>
																			</xsl:when>
																			<xsl:otherwise>
																				<img src="{$backtoroot}{//graphicsfolder}/{/descendant::node()/file[@id=$link5-id]/gifname[@lang=$currentlang]}.gif" alt="{/descendant::node()/file[@id=$link5-id]/altname[@lang=$currentlang]}" border="0"/>
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
											</div><p></p>
										</xsl:if>
										<div id="footer">
											<p/>
											<h6>
												<br>
													<xsl:value-of select="/fossane/universal/text/footer/translator[@lang=$currentlang]"/>
												</br>
												<br>
													<a href="mailto:{/fossane/universal/text/footer/webmaster/e-mail}">Webmaster</a>
												</br>
												<br>© <xsl:value-of select="document(CurrentTime.xml)/calendar-time/date/year"/>
													<a href="mailto:{/fossane/universal/text/contactdetails/e-mail/e-mail}">
														<xsl:value-of select="/fossane/universal/text/footer/copyright[@lang=$currentlang]"/>
													</a>
												</br>
											</h6>
										</div>
								</div>
								<!-- END main column -->
							</div>
							<!-- END wrap -->
						</body>
					</html>
				</xsl:document>
			</xsl:for-each>
			<xsl:call-template name="recursion-main">
				<xsl:with-param name="currentlang" select="number($currentlang) -1"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>
</xsl:stylesheet>
