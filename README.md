# fossane.no

All tekst for nettstedet er lagret i fossane.xml. Denne kan redigeres med en tekst-editor, eller med et skreddersydd verktøy for XML-redigering, .eks. [Oxygen XML Editor](https://www.oxygenxml.com)

Nettstedet 'batch'-genereres ved hjelp av XSLT. Hovedstilarket er fossane.xsl

Når en har gjort en endring, typisk i fossane.xml, så regenereres hele nettstedet ved hjelp av en XSLT-prosessor. Det er nødvendig å ha java-runtime installert. Følgende kommando vil fungere fra kommandolinjen på de leste plattormer.

    java -jar saxon.jar fossane.xml fossane.xslt

Genereringen tar noen sekunder. Når genereringen er gjennomført må en kjøre `git commit -am "endringsmelding" `og `git push`for at sidene skal bli synlige på Github Pages.
