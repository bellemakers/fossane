# fossane.no

All tekst for nettstedet er lagret i fossane.xml. Denne kan redigeres med en tekst-editor, eller med et skreddersydd verktøy for XML-redigering, f.eks. [Oxygen XML Editor](https://www.oxygenxml.com)

Nettstedet 'batch'-genereres ved hjelp av XSLT. Hovedstilarket er fossane.xsl

Når en har gjort en endring, typisk i fossane.xml, så regenereres hele nettstedet ved hjelp av en XSLT-prosessor. Det er nødvendig å ha java-runtime installert. Følgende kommando vil fungere fra kommandolinjen på de leste plattormer.

    java -jar saxon.jar fossane.xml fossane.xslt

Genereringen tar noen sekunder. Når genereringen er gjennomført må en kjøre `git commit -am "endringsmelding" `og `git push`for at sidene skal bli synlige på Github Pages.

----------------------------------------------------------

MB: 07.02.2020:
old website fossane.no
<ol>
<li>copieer alles naar deze repository
<li>kijk of bellemakers.github.io/fossane.no werkt.
</ol>

1 lijkt gelukt; https://bellemakers.github.io/fossane geeft 404: file not found :(

2 ook gelukt: in setting master aangepast.

<ul>
<li>engels (index.html in root) adres aangepast
<li>duits (index.html in root/de) adres aangepast
</ul>

https://bellemakers.github.io/fossane/nl/

Gegevens van ons aangepast voor de hele Nederlands site (wijst naar onze emailadressen) en de updatedatum (14/02/2020)
