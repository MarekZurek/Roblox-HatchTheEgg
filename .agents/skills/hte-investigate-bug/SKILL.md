---
name: hte-investigate-bug
description: Diagnose reported HatchTheEgg gameplay defects or failing implementation tests using a minimal reproduction and root-cause evidence. Not for balance tuning or feature design.
---

# Diagnoza błędu HatchTheEgg

Przyjmij opis objawu w języku użytkownika. Nie wymagaj gotowej diagnozy ani technicznego promptu. Z [workflow](../../../docs/workflow/WORKFLOW.md) dobierz źródła danego podsystemu; [CURRENT_SPEC](../../../docs/CURRENT_SPEC.md) określa status reguł.

## Procedura

1. Zidentyfikuj: co się stało, po jakiej czynności, stan początkowy i oczekiwane zachowanie. Brakujące informacje najpierw odtwórz z dostępnego repo/logów; pytaj o rzeczy, których nie można ustalić.
2. Sprawdź wersję faktycznie testowanego kodu/sceny i znajdź najmniejszą reprodukcję. Rozdziel hipotezy: domena, czas, replikacja, zapis, prezentacja. Sam opis „podwójne pieniądze” nie dowodzi błędu wzoru.
3. Porównaj z właściwą regułą R lub źródłem N/S. Jeżeli wymagane zachowanie jest otwartą decyzją produktu, wskaż tę jedną lukę; nie wymyślaj go w poprawce.
4. W zakresie zleconej naprawy usuń przyczynę najmniejszą spójną zmianą. Gdy zlecono tylko analizę, zwróć diagnozę i proponowaną korektę, bez implementacji.
5. Zweryfikuj zmienione zachowanie i właściwe granice. Dodaj trwały test regresji, gdy daje realną ochronę; nie twórz testu, który jedynie powtarza implementację lub zmieniony tekst.

## Wynik i granice

Zapisz objaw, dowód, przyczynę/hipotezę, zmianę i zakres weryfikacji według [szablonu](../../../docs/workflow/TASK_TEMPLATES.md). Po próbach bez nowego dowodu zbierz minimalne wejście i dotychczasowe ustalenia zamiast powtarzać to samo. Nie zatrzymuj niezależnej zleconej pracy.

Nie zmieniaj ceny, szansy, receptury ani zasady R, by ukryć błąd. Bilans i docs/17–21 pozostają odłożone; nie otwieraj ponownie zamkniętych ustaleń bez związku ze zgłoszeniem. Skill nie nadaje uprawnień do Studio, chmury, delegacji lub publikacji.
