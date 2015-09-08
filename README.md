# joszolgalat2

Jószolgálati mobil app és api fejlesztése

Az API a backend directoryban található

A mobil appok a frontend directoryban találhatók.
Először a HTML5-el kezdünk, hogy legyen kattintható kliens, amin majd az alkalmazás tesztelhető.
Az első körös UAT után készülnek el a native kliensek Androidra és IOS-re.

A projekt ütemezése very rapid ütemezése

API leírás, tesztesetek hétfő éjfél.
Backend prototípus szerda éjfélre készül el, 
UI prototípus csütörtök éjfél.

A specifikációkat a doc könyvtárban lehet elérni.

A design-hoz szükséges minden elem a design könyvtárban lesz. A régi Design elemek 
itt-itt

A kiindulás:
Tegnap beszéltünk a Migration Aid vezetőjével.
Nincs semmi logisztikai támogatásuk
Az összes AID app infót oszt, de nem koordinál.
Ezért a Mokusfa App ( ha nem tudtok jobbat, ez lesz majd a brand ), egy elosztott logisztikai rendszer lesz mobilra.
Specifikáció elérhető
- https://trello.com/c/CNH3SJ55/98-specifikacio
- doc könyvtárba itt
GIT
https://github.com/zuzmo/joszolgalat2

Bárki, aki tud segíteni welcome

##Model

Teljesen elosztott a gyűjtés, szállítás: AirBnB és Über modell, csak pull és ritkán Push mivel a Gyüjtői kapacitás dönti el, mit lehet tenni a Felajánlással.
Minden Gyűjtő Befogadással indítja a Felajánlás elfogadását.

Teljesen elosztott Inventory van, nincs különbség a nagy raktárház és a segítő között a gyűjtés szempontjából ( majd funkciókban lesz, de ez most nem számít ): a raktárak egyben speciális Gyűjtők, az Elosztó, akik tudnak egymást közt pusholni ( mozgatni )
Minden a Helper az Gyűjtő, de van Gyűjtő, aki nem helper ( pl a Raktár, vagy olyan felhasználó, aki nem osztja a Felajánlásokat )

A Felajánló, aki Felajánl.
A rendszer összeköti a Felajánlást az Igénnyel úgy, hogy ha lehet akkor a Segítő (Gyűjtő )-höz közvetlen, ha nincs ilyen, akkor a csak Gyűjtőhöz. Az "összekötés"ből keletkezik a Szállítási Igény, amit a Felajánló majd Gyűjtő magára vállalhat, ha egyik sem, akkor kerül a Szállítókhoz, akik közül egy vagy több elvégzi a feladatot.
Nincs végig gondolva, hogy kezeljük, ha egy Igényt akár több Szállító is végezhet, és az se, hogy egyszerre Több Szállítási Igényt is egy Szállító kezel


