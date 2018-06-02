<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.1" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
	<xsl:template match="/">
		<xsl:call-template name="recursion-main">
			<xsl:with-param name="currentlang" select="count(/fossane/languages/language)"/>
		</xsl:call-template>
	</xsl:template>
	<xsl:template name="recursion-main">
		<xsl:param name="currentlang"/>
		<xsl:if test="number($currentlang) > 0">
			<!-- This variable contains the HTML code for the links to the other languages. Icons for these links must be in the short form of the language as specified in the XML-file -->
			<xsl:for-each select="fossane/page">
				<xsl:variable name="currentid">
					<xsl:value-of select="./@id"/>
				</xsl:variable>
				<xsl:variable name="round10000" select="(round($currentid div 10000)*10000)"/>
				<xsl:variable name="round1000" select="(round($currentid div 1000)*1000)"/>
				<xsl:variable name="round100" select="(round($currentid div 100)*100)"/>
				<xsl:variable name="documenthref">
					<xsl:choose>
						<xsl:when test="$currentid = $round10000">
							<xsl:value-of select="concat(/fossane/languages/language[@lang=$currentlang]/@shortname,'/',//object[@id=$currentid]/name[@lang=$currentlang],'.html')"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="concat(/fossane/languages/language[@lang=$currentlang]/@shortname,'/',//object[@id=($round1000+10000)]/name[@lang=$currentlang],'/',//object[@id=$currentid]/name[@lang=$currentlang],'.html')"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>
				<xsl:document method="html" href="{$documenthref}">
					<html>
						<head>
							<title>
								Fossane: <xsl:value-of select="text/title[@lang=$currentlang]"/>
							</title>
						</head>
						<body text="#000000" bgcolor="#AABFFA">
							<table cellpadding="3" width="100%" border="0">
								<tr>
									<td valign="top" rowspan="3" align="left" bgcolor="#4B77F5">
										<table cellpadding="3" border="0" width="125">
											<tbody>
												<tr>
													<td align="center">
														<xsl:for-each select="//object[@id=$currentid]/name">
															<xsl:variable name="link-lang">
																<xsl:value-of select="./@lang"/>
															</xsl:variable>
															<a href="../../{/fossane/languages/language[@lang=$link-lang]/@shortname}/{//object[@id=$round1000+10000]/name[@lang=$link-lang]}/{//object[@id=$currentid]/name[@lang=$link-lang]}.html">
																<img src="../../grafikk/{/fossane/languages/language[@lang=$link-lang]/@shortname}.gif" alt="{/fossane/languages/language[@lang=$link-lang]/@longname}" vspace="2" border="0" hspace="2"/>
															</a>
														</xsl:for-each>
													</td>
												</tr>
												<tr>
													<td align="center">
														<xsl:for-each select="..//object[@id=$currentid]">
															<a href="{.}"><xsl:value-of select="."></xsl:value-of>test</a><p></p>
														</xsl:for-each>
													</td>
												</tr>
											</tbody>
										</table>
									</td>
									<td valign="top">
									</td>
									<td valign="top" rowspan="3" align="right" bgcolor="#4B77F5">
									</td>
								</tr>
								<tr>
									<td valign="top">
										<h1>
											<xsl:value-of select="text/title[@lang=$currentlang]"/>
										</h1>
										<p>
											<b>
												<xsl:value-of select="text/introduction[@lang=$currentlang]"/>
											</b>
										</p>
										<xsl:for-each select="text/maintext[@lang=$currentlang]/para">
											<p>
												<xsl:value-of select="."/>
											</p>
										</xsl:for-each>
									</td>
								</tr>
								<tr>
									<td align="right">
										<h6>
											<xsl:value-of select="/fossane/universal/text/footer/updated[@lang=$currentlang]"/>
											<script language="Javascript"><![CDATA[
												// please keep these lines on when you copy the source
												// made by: Nicolas - http://www.javascript-page.com
												var default_date = "01/02/01"
												var lm = new Date(document.lastModified);
													 y = lm.getYear();
													 t = lm.getTime();
													if (y>100) {y=y+1900};
													 m1 = lm.getMonth() +1; 
													 if (m1<10) m="0"+m1 
													 else m=""+m1;
													 d1 = lm.getDate(); 
													 if (d1<10) d="0"+d1
													 else d=""+d1;
													document.write(d+"."+m+"."+y)
													//document.write(document.lastModified);
													]]></script>
											<br>
												<xsl:value-of select="/fossane/universal/text/footer/translator[@lang=$currentlang]"/>
											</br>
											<br>
												<a href="mailto:{/fossane/universal/text/footer/webmaster}">Webmaster</a>
											</br>
											<br>
												© <script language="Javascript"><![CDATA[
												// please keep these lines on when you copy the source
												// made by: Nicolas - http://www.javascript-page.com
												var default_date = "01/02/01"
												var lm = new Date(document.lastModified);
													 y = lm.getYear();
													 t = lm.getTime();
													if (y<2000) {y=y+1900};
 													document.write(y)
													//document.write(document.lastModified);
													]]></script>,
												<a href="mailto:{/fossane/universal/e-mail}">
													<xsl:value-of select="/fossane/universal/text/footer/copyright[@lang=$currentlang]"/>
												</a>
											</br>
										</h6>
									</td>
								</tr>
							</table>
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
