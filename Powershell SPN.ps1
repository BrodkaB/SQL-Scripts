#Listowanie wszystkich SPN

setspn -L

#Listowanie SPN dla danego użytkownika

setspn -L nazwa_domeny\nazwa_konta

#Listowanie SPN dla danego servera (network server name i OS cluster name w przypadku klastra)

setspn -L nazwa

#Dodawanie SPN dla użytkownika (SQL service account)

setspn -A MSSQLSvc/nazwa_klastra nazwa_domeny\nazwa_użytkownika
setspn -A MSSQLSvc/nazwa_klastra.cho.corp.ryanair.com nazwa_domeny\nazwa_uzytkownika

#Dodawanie SPN dla konkretnej instancji

setspn -A MSSQLSvc/nazwa_klastra:nazwa_instancji nazwa_domeny\nazwa_użytkownika
setspn -A MSSQLSvc/nazwa_klastra.cho.corp.ryanair.com:nazwa_instancji nazwa_domeny\nazwa_uzytkownika

#W celu usunięcia danego SPN (w przypadku pojawienia się duplikatu), parametr -A zamieniamy na parametr -D
