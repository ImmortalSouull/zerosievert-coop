# ZERO Sievert CO-OP

[English](README.md) · [Русский](README.ru.md) · **Polski**

Nieoficjalny mod, który dodaje do **ZERO Sievert** tryb kooperacji dla **maksymalnie 8 graczy**: wspólne rajdy
przez Steam lub przez IP, wspólny świat, powalenie i podnoszenie towarzyszy, rozszerzone ustawienia trudności.

> Mod został zrobiony przy pomocy AI (Claude) według projektu gracza. Nie jest powiązany z twórcami gry
> (CABO Studio / Modern Wolf). Pliki gry nie są tu przechowywane ani rozpowszechniane: wydanie zawiera łatkę
> i instalator, które modyfikują Twoją własną kopię gry.
>
> Tłumaczenie przygotowane przy pomocy AI — jeśli coś brzmi dziwnie, daj znać.

**Aktualna wersja: v2.0.0** — do pobrania w sekcji [Releases](../../releases). Opisy wszystkich wersji
(nowości, poprawki, znane błędy) są w [docs/releases](docs/releases).

## Możliwości
- Przycisk „Kooperacja” w menu głównym i menu pauzy (lub F7): gra przez Steam (zaproszenie do 7 znajomych)
  lub przez IP.
- Wspólne rajdy: wzdłuż pociągu hosta pojawia się strefa z odliczaniem — kto stoi w strefie, jedzie razem;
  pozostali dołączają do trwającego rajdu później (pociągiem lub z panelu). Nigdy dwa osobne rajdy.
- Ta sama mapa dla wszystkich; wrogowie, strzały, granaty, ciała, łup na żywo, wyrzucone przedmioty, drzwi,
  pora dnia, pogoda i emisje są zsynchronizowane. Nowa SI wrogów (gra 1.4) widzi, słyszy i atakuje każdego
  gracza.
- Bunkier jako lobby: gracze widzą się nawzajem w swoich bunkrach, a „Odwiedź” pokazuje bunkier znajomego
  (jego moduły i stanowiska), przy czym Twój schowek, przedmioty i zapis pozostają Twoje. Pogoda w bunkrze
  jest taka jak u hosta.
- Powalenie zamiast śmierci i podnoszenie towarzysza: wybór przedmiotu ikoną (bez przedmiotów / bandaż /
  apteczka) z podpisem, ile HP i sekund.
- [X] — przekaż przedmiot towarzyszowi, na rajdzie i w bunkrze; wymiana między graczami (U), wyposażenie
  towarzysza (I).
- Sesja przetrwa wyjście hosta: przejmuje ją inny gracz. Powrót do sesji po awarii.
- Czat głosowy z bliska i krótkofalówka z kanałami; czat tekstowy (Enter) i koło komend (Z).
- Panel grupy, wspólna ewakuacja z podsumowaniem rajdu, obserwowanie po ostatecznej śmierci, czołganie
  i ciągnięcie rannego.
- Wspólny postęp zadań z podziałem nagrody według pracy, zadania grupowe u barmana, wydarzenia w rajdzie, arena
  w bunkrze, ustawienia osobnego łupu i ognia sojuszniczego, wygląd widoczny dla towarzyszy.
- Zarządzanie lobby (usuń gracza, znajomi / zaproszenie / publiczne), lista otwartych gier i znajomych, sprawdzanie modów.
- Kopie zapasowe zapisów, osobne postacie co-op, aktualizacja jednym kliknięciem, „Zbierz logi”, tryb streamera,
  samouczek co-op.
- Znaczniki środkowym przyciskiem myszy (drugie kliknięcie w to samo miejsce usuwa Twój znacznik), towarzysze
  na mapie PDA.
- Doświadczenie, zadania i reputacja trafiają do tego, kto zabił.
- Animacje, latarki, lasery i dźwięki towarzyszy są widoczne i słyszalne.
- Gdy host się ewakuuje, świat rajdu przejmuje następny gracz i nadal można do niego dołączyć; po zerwaniu
  połączenia mod sam łączy się ponownie.
- Balans dla grupy: więcej wrogów i (opcjonalnie) więcej zdrowia wrogów za każdego dodatkowego gracza.
- Bez limitu 60 FPS: płynny obraz z częstotliwością monitora przy tej samej prędkości gry.
- Mod mówi w każdym języku gry (13) i sam przełącza się za językiem ustawionym w grze.
- Interfejs kooperacji w stylu gry; obsługa pada w menu kooperacji i przy podnoszeniu; sprawdzanie
  aktualizacji moda.

## Instalacja
1. Wymagane ZERO Sievert 1.4.13 (Steam build 26317366). Zamknij grę.
2. Pobierz `ZS-Coop-v<wersja>.zip` z najnowszego [wydania](../../releases/latest), rozpakuj i uruchom
   `install.bat` — sam znajdzie grę, zrobi kopię zapasową i nałoży łatkę na Twoją kopię gry.
3. Odinstalowanie: `uninstall.bat` lub Steam → „Zweryfikuj spójność plików gry”.
4. W grze: „Kooperacja” w menu głównym (lub F7). Wszyscy gracze muszą mieć tę samą wersję moda. Wersja moda
   jest widoczna w rogu menu głównego.

Pełna instrukcja: `README.txt` w archiwum wydania (sekcja POLSKI).

## Dla programistów
- `mod/gml` — kod moda (GML), `mod/hooks.txt` — miejsca wpięcia w kod gry.
- Budowanie: UndertaleModTool CLI (`tools/build.sh`, `tools/utmt/build.csx`) z Twojej własnej kopii
  `data.win`; wydanie to łatka xdelta (`tools/make_dist.sh`).
- Testy: `python tools/regress.py all` (scenariusze na 1–8 oknach gry, wszystkie mapy), `python tools/soak.py`.
- Dziennik prac i wszystkie znalezione osobliwości silnika — `MODLOG.md` (po angielsku).

Narzędzia zewnętrzne: UndertaleModTool (Underminers), xdelta3 (GPL v2, zob. THIRD_PARTY.txt w wydaniu).

## Licencja
Kod moda jest udostępniony na licencji [MIT](LICENSE): można go swobodnie używać, zmieniać i rozpowszechniać, zachowując informację o autorze.
Licencja obejmuje tylko kod tego moda. Sama gra ZERO Sievert i fragmenty jej kodu w `mod/hooks.txt` (punkty zaczepienia łatek) należą do ich właścicieli; xdelta3 w wydaniach ma własną licencję GPL v2.
