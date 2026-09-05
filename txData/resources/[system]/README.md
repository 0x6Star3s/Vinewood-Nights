# System Resources

Ten folder zawiera podstawowe zasoby FiveM/Cfx.re. To nie są auta, mapy ani zwykłe dodatki gameplay, tylko skrypty techniczne używane przez serwer lub inne resource'y.

## Foldery

- `sessionmanager` - obsługuje mechanikę sesji i host lock dla serwera GTA/FiveM. Zostawić włączone.
- `hardcap` - pilnuje limitu graczy ustawionego w `sv_maxclients`.
- `baseevents` - udostępnia podstawowe eventy dla innych skryptów, np. eventy śmierci gracza i pojazdów.
- `rconlog` - starsza obsługa komend/logowania RCON. Zwykle nie jest potrzebna, jeśli nie używasz starego RCON.
- `runcode` - narzędzie developerskie do uruchamiania kodu Lua/JS na serwerze lub kliencie. Nie włączać na publicznym serwerze bez potrzeby.
- `[builders]` - narzędzia buildowania (`yarn`, `webpack`) używane przez resource'y wymagające budowania frontendu/skryptów.

## Usunięte

- `sessionmanager-rdr3` - resource dla RedM/RDR3, nie dla GTA5. Został usunięty z lokalnych zasobów, bo ten serwer działa jako FiveM/GTA5.

## Wskazówki

- W `server.cfg` powinny zostać co najmniej `ensure sessionmanager` i `ensure hardcap`.
- Nie edytuj tych zasobów bez potrzeby. Jeśli jakiś skrypt wymaga `baseevents`, można go dodać do `server.cfg`.
