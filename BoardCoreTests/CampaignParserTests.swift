//
//  CampaignParserTests.swift
//  BoardCoreTests
//

import Testing
@testable import BoardCore

struct CampaignParserTests {

    @Test func parsesFullElarionCampaignStructure() throws {
        let sample = """
        ZARYG_FABULARNY<<
        W krainie Elarion proroctwo wiąże czterech nieznajomych.
        KONIEC_ZARYG_FABULARNY<<

        SCENY<<

        PĘKNIĘTY KRĄG

        [SCENA 1] Cisza Żaru
        Narracja sceny pierwszej.

        [SCENA 2] Strażnik bez Imienia
        Narracja sceny drugiej.

        [SCENA 3] Miasto, które nie pamięta
        Narracja sceny trzeciej.

        [SCENA 4] Echo Vael-Tora
        Narracja sceny czwartej.

        [SCENA 5] Rozpad Kręgu
        Narracja sceny piątej.

        [SCENA 6] Pierwsze Zaklęcie
        Narracja sceny szóstej.

        KONIEC_SCEN<<

        DECYZJE<<

        * [DECYZJA 1 | SCENA 1] *
        PYTANIE<<
        Pytanie pierwszej decyzji?
        KONIEC_PYTANIA<<
        WYBORY_GRACZA_1<<
        1. Opcja A
            [ZALETA: a]
            [WADA: b]
            [SKUTKI: MONETY:+1]
        2. Opcja B
            [ZALETA: c]
            [WADA: d]
            [SKUTKI: ZDROWIE:+1]
        3. Opcja C
            [ZALETA: e]
            [WADA: f]
            [SKUTKI: SIŁA:+1]
        4. Opcja D
            [ZALETA: g]
            [WADA: h]
            [SKUTKI: MANA:+1]
        KONIEC_WYBOROW_GRACZA_1<<
        WYBORY_GRACZA_2<<
        1. Opcja A2
            [ZALETA: a]
            [WADA: b]
            [SKUTKI: MONETY:+2]
        2. Opcja B2
            [ZALETA: c]
            [WADA: d]
            [SKUTKI: ZDROWIE:+2]
        3. Opcja C2
            [ZALETA: e]
            [WADA: f]
            [SKUTKI: SIŁA:+2]
        4. Opcja D2
            [ZALETA: g]
            [WADA: h]
            [SKUTKI: MANA:+2]
        KONIEC_WYBOROW_GRACZA_2<<
        WYBORY_GRACZA_3<<
        1. A3 [ZALETA: a] [WADA: b] [SKUTKI: MONETY:+3]
        2. B3 [ZALETA: c] [WADA: d] [SKUTKI: ZDROWIE:+3]
        3. C3 [ZALETA: e] [WADA: f] [SKUTKI: SIŁA:+3]
        4. D3 [ZALETA: g] [WADA: h] [SKUTKI: MANA:+3]
        KONIEC_WYBOROW_GRACZA_3<<
        WYBORY_GRACZA_4<<
        1. A4 [ZALETA: a] [WADA: b] [SKUTKI: MONETY:+4]
        2. B4 [ZALETA: c] [WADA: d] [SKUTKI: ZDROWIE:+4]
        3. C4 [ZALETA: e] [WADA: f] [SKUTKI: SIŁA:+4]
        4. D4 [ZALETA: g] [WADA: h] [SKUTKI: MANA:+4]
        KONIEC_WYBOROW_GRACZA_4<<

        * [DECYZJA 2 | SCENA 2] *
        PYTANIE<<
        Pytanie drugiej decyzji?
        KONIEC_PYTANIA<<
        WYBORY_GRACZA_1<<
        1. Walka [ZALETA: a] [WADA: b] [SKUTKI: SIŁA:+1]
        2. Analiza [ZALETA: c] [WADA: d] [SKUTKI: MANA:+1]
        3. Ucieczka [ZALETA: e] [WADA: f] [SKUTKI: PLANSZA:-1]
        4. Negocjacje [ZALETA: g] [WADA: h] [SKUTKI: ZDOLNOŚCI:+1]
        KONIEC_WYBOROW_GRACZA_1<<
        WYBORY_GRACZA_2<<
        1. W2a [ZALETA: a] [WADA: b] [SKUTKI: SIŁA:+2]
        2. W2b [ZALETA: c] [WADA: d] [SKUTKI: MANA:+2]
        3. W2c [ZALETA: e] [WADA: f] [SKUTKI: PLANSZA:-2]
        4. W2d [ZALETA: g] [WADA: h] [SKUTKI: ZDOLNOŚCI:+2]
        KONIEC_WYBOROW_GRACZA_2<<
        WYBORY_GRACZA_3<<
        1. W3a [ZALETA: a] [WADA: b] [SKUTKI: SIŁA:+3]
        2. W3b [ZALETA: c] [WADA: d] [SKUTKI: MANA:+3]
        3. W3c [ZALETA: e] [WADA: f] [SKUTKI: PLANSZA:-3]
        4. W3d [ZALETA: g] [WADA: h] [SKUTKI: ZDOLNOŚCI:+3]
        KONIEC_WYBOROW_GRACZA_3<<
        WYBORY_GRACZA_4<<
        1. W4a [ZALETA: a] [WADA: b] [SKUTKI: SIŁA:+4]
        2. W4b [ZALETA: c] [WADA: d] [SKUTKI: MANA:+4]
        3. W4c [ZALETA: e] [WADA: f] [SKUTKI: PLANSZA:-4]
        4. W4d [ZALETA: g] [WADA: h] [SKUTKI: ZDOLNOŚCI:+4]
        KONIEC_WYBOROW_GRACZA_4<<

        KONIEC_DECYZJI<<
        """

        let parsed = CampaignParser.parse(sample)

        #expect(parsed.title == "PĘKNIĘTY KRĄG")
        #expect(parsed.scenes.count == 6)
        #expect(parsed.scenes[5].title == "Pierwsze Zaklęcie")
        #expect(parsed.decisions.count == 2)
        #expect(parsed.decisions[0].sceneTitle == "Cisza Żaru")
        #expect(parsed.decisions[1].sceneTitle == "Strażnik bez Imienia")
        #expect(parsed.decisions[0].choiceDetailsByPlayer.count == 4)
        #expect(parsed.decisions[0].choiceDetailsByPlayer[0].count == 4)
        #expect(parsed.decisions[1].choiceDetailsByPlayer[3].count == 4)
    }

    @Test func parsesKoronaPopiolowWithMixedDecisionHeaders() throws {
        let sample = """
        //ZARYG_FABULARNY<<
        Królestwo Aeltharion stoi na krawędzi wojny.
        KONIEC_ZARYG_FABULARNY<<

        SCENY<<

        KORONA POPIOŁÓW

        [SCENA 1] Miasto, które zapomniało króla
        Narracja sceny pierwszej.

        [SCENA 2] Relikwia, która nie powinna istnieć
        Narracja sceny drugiej.

        [SCENA 3] Kronika bez autora
        Narracja sceny trzeciej.

        [SCENA 4] Wędrowiec Bez Imienia
        Narracja sceny czwartej.

        [SCENA 5] Rozpad pamięci królestwa
        Narracja sceny piątej.

        [SCENA 6] Korona Popiołów
        Narracja sceny szóstej.

        KONIEC_SCEN<<

        DECYZJE<<

        * [DECYZJA 1 | SCENA 1] *
        PYTANIE<<
        Czy zaufacie Arcykapłance?
        KONIEC_PYTANIA<<
        WYBORY_GRACZA_1<<
        1. Eskorta
            [ZALETA: ochrona]
            [WADA: kontrola]
            [SKUTKI: SIŁA:+1 | MANA:+2]
        2. Przejęcie
            [ZALETA: władza]
            [WADA: wrogość]
            [SKUTKI: SIŁA:+3 | ZDROWIE:-2]
        3. Zniszczenie
            [ZALETA: brak wpływu]
            [WADA: ryzyko]
            [SKUTKI: MANA:+1 | ZDOLNOŚCI:+1]
        4. Obserwacja
            [ZALETA: wiedza]
            [WADA: wymazanie]
            [SKUTKI: MANA:+2 | BLOKADA:1]
        KONIEC_WYBOROW_GRACZA_1<<
        WYBORY_GRACZA_2<<
        1. A [ZALETA: a] [WADA: b] [SKUTKI: MANA:+2]
        2. B [ZALETA: c] [WADA: d] [SKUTKI: SIŁA:+3]
        3. C [ZALETA: e] [WADA: f] [SKUTKI: ZDOLNOŚCI:+2]
        4. D [ZALETA: g] [WADA: h] [SKUTKI: ZDROWIE:-1]
        KONIEC_WYBOROW_GRACZA_2<<
        WYBORY_GRACZA_3<<
        1. A3 [ZALETA: a] [WADA: b] [SKUTKI: MANA:+2]
        2. B3 [ZALETA: c] [WADA: d] [SKUTKI: SIŁA:+2]
        3. C3 [ZALETA: e] [WADA: f] [SKUTKI: ZDOLNOŚCI:+2]
        4. D3 [ZALETA: g] [WADA: h] [SKUTKI: MONETY:+2]
        KONIEC_WYBOROW_GRACZA_3<<
        WYBORY_GRACZA_4<<
        1. A4 [ZALETA: a] [WADA: b] [SKUTKI: MANA:+2]
        2. B4 [ZALETA: c] [WADA: d] [SKUTKI: SIŁA:+3]
        3. C4 [ZALETA: e] [WADA: f] [SKUTKI: MANA:+1]
        4. D4 [ZALETA: g] [WADA: h] [SKUTKI: ZDOLNOŚCI:+2]
        KONIEC_WYBOROW_GRACZA_4<<

        DECYZJA 2 | SCENA 2<<
        PYTANIE<<
        Czy pozwolicie Koronie na stabilizację historii?
        KONIEC_PYTANIA<<
        WYBORY_GRACZA_1<<
        1. Stabilizacja [ZALETA: porządek] [WADA: utrata prawdy] [SKUTKI: MANA:+2]
        2. Wiele wersji [ZALETA: pełnia] [WADA: chaos] [SKUTKI: SIŁA:+2]
        3. Kradzież [ZALETA: kontrola] [WADA: pościg] [SKUTKI: SIŁA:+3]
        4. Zniszczenie [ZALETA: wolność] [WADA: nieznane] [SKUTKI: MANA:+1]
        KONIEC_WYBOROW_GRACZA_1<<
        WYBORY_GRACZA_2<<
        1. W2a [ZALETA: a] [WADA: b] [SKUTKI: MANA:+2]
        2. W2b [ZALETA: c] [WADA: d] [SKUTKI: SIŁA:+3]
        3. W2c [ZALETA: e] [WADA: f] [SKUTKI: MANA:+2]
        4. W2d [ZALETA: g] [WADA: h] [SKUTKI: ZDOLNOŚCI:+2]
        KONIEC_WYBOROW_GRACZA_2<<
        WYBORY_GRACZA_3<<
        1. W3a [ZALETA: a] [WADA: b] [SKUTKI: MANA:+2]
        2. W3b [ZALETA: c] [WADA: d] [SKUTKI: SIŁA:+2]
        3. W3c [ZALETA: e] [WADA: f] [SKUTKI: MANA:+2]
        4. W3d [ZALETA: g] [WADA: h] [SKUTKI: ZDOLNOŚCI:+2]
        KONIEC_WYBOROW_GRACZA_3<<
        WYBORY_GRACZA_4<<
        1. W4a [ZALETA: a] [WADA: b] [SKUTKI: MANA:+2]
        2. W4b [ZALETA: c] [WADA: d] [SKUTKI: SIŁA:+3]
        3. W4c [ZALETA: e] [WADA: f] [SKUTKI: ZDOLNOŚCI:+2]
        4. W4d [ZALETA: g] [WADA: h] [SKUTKI: MANA:+3]
        KONIEC_WYBOROW_GRACZA_4<<

        KONIEC_DECYZJI<<//podaje mi 6 scen i jedną decyzję
        """

        let parsed = CampaignParser.parse(sample)

        #expect(parsed.title == "KORONA POPIOŁÓW")
        #expect(parsed.scenes.count == 6)
        #expect(parsed.decisions.count == 2)
        #expect(parsed.decisions[0].sceneTitle == "Miasto, które zapomniało króla")
        #expect(parsed.decisions[1].sceneTitle == "Relikwia, która nie powinna istnieć")
        #expect(parsed.decisions[0].choiceDetailsByPlayer.count == 4)
        #expect(parsed.decisions[1].choiceDetailsByPlayer[0].count == 4)
    }

    @Test func parsesBranchingCampaignWithNextSceneTags() throws {
        let sample = """
        SCENY<<
        TEST GAŁĘZI
        [SCENA 1] Start
        Wspólny początek.
        [SCENA 2A] Gałąź A
        Po wyborze A.
        [SCENA 2B] Gałąź B
        Po wyborze B.
        KONIEC_SCEN<<
        DECYZJE<<
        * [DECYZJA 1 | SCENA 1] *
        PYTANIE<<
        Co robisz?
        KONIEC_PYTANIA<<
        WYBORY_GRACZA_1<<
        1. Idź na północ
           [NASTĘPNA_SCENA: 2A]
           [ZALETA: a] [WADA: b] [SKUTKI: SIŁA:+1]
        2. Idź na południe
           [NASTĘPNA_SCENA: 2B]
           [ZALETA: c] [WADA: d] [SKUTKI: MONETY:+1]
        KONIEC_WYBOROW_GRACZA_1<<
        KONIEC_DECYZJI<<
        """

        let parsed = CampaignParser.parse(sample)
        #expect(parsed.scenes.count == 3)
        #expect(parsed.scenes[0].sceneTag == "1")
        #expect(parsed.scenes[1].sceneTag == "2A")
        #expect(parsed.decisions[0].choiceDetailsByPlayer[0][0].nextSceneTag == "2A")
        #expect(parsed.resolveNextSceneIndex(
            choice: parsed.decisions[0].choiceDetailsByPlayer[0][0],
            decisionRound: 0,
            choiceIndex: 0
        ) == 1)
    }

    @Test func dedupesRepeatedChoicesInSinglePlayerBlock() throws {
        let sample = """
        DECYZJE<<
        * [DECYZJA 1 | SCENA 1] *
        PYTANIE<<
        Co robisz?
        KONIEC_PYTANIA<<
        WYBORY_GRACZA_1<<
        1) Atak frontalny
           [ZALETA: siła] [WADA: ryzyko] [SKUTKI: SIŁA:+1]
        2) Ukrycie
           [ZALETA: spokój] [WADA: strata czasu] [SKUTKI: ZDROWIE:+1]
        3) Negocjacje
           [ZALETA: wpływ] [WADA: zobowiązanie] [SKUTKI: MONETY:+1]
        4) Ucieczka
           [ZALETA: życie] [WADA: hańba] [SKUTKI: PLANSZA:-1]
        1) Atak frontalny
           [ZALETA: duplikat] [WADA: x] [SKUTKI: SIŁA:+2]
        2) Ukrycie
           [ZALETA: duplikat] [WADA: x] [SKUTKI: ZDROWIE:+2]
        3) Negocjacje
           [ZALETA: duplikat] [WADA: x] [SKUTKI: MONETY:+2]
        KONIEC_WYBOROW_GRACZA_1<<
        KONIEC_DECYZJI<<
        """

        let parsed = CampaignParser.parse(sample)
        #expect(parsed.decisions.count == 1)
        #expect(parsed.decisions[0].choiceDetailsByPlayer[0].count == 4)
        #expect(parsed.decisions[0].question == "Co robisz?")
        #expect(
            parsed.choiceLabels(forPlayerIndex: 0, decisionIndex: 0)
            == ["Atak frontalny", "Ukrycie", "Negocjacje", "Ucieczka"]
        )
    }

    @Test func questionStopsBeforeChoiceMetadataLines() throws {
        let sample = """
        DECYZJE<<
        * [DECYZJA 2 | SCENA 2] *
        PYTANIE<<
        Czy ufasz strażnikowi?
        KONIEC_PYTANIA<<
        [ZALETA: nie powinno być w pytaniu]
        WYBORY_GRACZA_1<<
        1) Zaufaj
           [ZALETA: a] [WADA: b] [SKUTKI: SIŁA:+1]
        2) Odmów
           [ZALETA: c] [WADA: d] [SKUTKI: MONETY:+1]
        3) Czekaj
           [ZALETA: e] [WADA: f] [SKUTKI: ZDROWIE:+1]
        4) Ucieknij
           [ZALETA: g] [WADA: h] [SKUTKI: MANA:+1]
        KONIEC_WYBOROW_GRACZA_1<<
        KONIEC_DECYZJI<<
        """

        let parsed = CampaignParser.parse(sample)
        #expect(parsed.decisions[0].question == "Czy ufasz strażnikowi?")
    }
}
