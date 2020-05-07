# Projektplan

## 1. Projektbeskrivning (Beskriv vad sidan ska kunna göra)
En webbshop där användare ska kunna ha en egen kundvagn. Ifall man inte är inloggad kan man bara se på varorna och ifall man är Admin så kan man lägga till nya varor samt se de andra användarnas kundvagnar. Man ska kunna handla olika citat från olika människor. "Pengarna" eller Quota som det kommer heta tjänas genom att säga de olika quotsen du har köpt. Man börjar alltså med ett gratis qoute så att man kan säga det och får mer Quota (pengarna) så du kan köpa bättre qoutes som i sin tur ger dig yttligare mer pengar när du säger dem. Admin ska kunna lägga till eller ändra Quotes medan en vanlig användare kan bara göra det som jag beskrev innan. Ifall man inte är innloggad så ska man bara kunna se de olika quotsen som existerar.
## 2. Vyer (visa bildskisser på dina sidor)
## 3. Databas med ER-diagram (Bild)
![ER-diagram](ER-diagram quotable Joel Hilmersson.png)
## 4. Arkitektur (Beskriv filer och mappar - vad gör/inehåller de?)
Mappar:
db: Mappen där databasen ligger
doc: Mappen tillhörande yardoc
public: Mappen där css, javascript och bilder
views: Mappen där alla olika slimfiler ligger. Följer RESTFUL-routes.
yardoc: Mappen innehåller mer filer till yardocprogrammet

Filer:
quotables.db: Är själva databasen där all databas data sparas
.slim: Är alla de olika slimfilerna som visar de olika sidorna genom att skapa html
app.rb: Filen där sessions och alla GET/POST routes ligger. Anropar funktioner från model .rb
model.rb: Filen där alla funktioner som tar kontakt med databasen finns. Funktionerna anropas av app.rb
