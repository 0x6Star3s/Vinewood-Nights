local Translations = {
    labels = {
        engine = 'Silnik',
        bodsy = 'Karoseria',
        radiator = 'Chłodnica',
        axle = 'Wał napędowy',
        brakes = 'Hamulce',
        clutch = 'Sprzęgło',
        fuel = 'Zbiornik paliwa',
        sign_in = 'Wejdź na służbę',
        sign_off = 'Zejdź ze służby',
        o_stash = '[E] Otwórz magazyn',
        h_vehicle = '[E] Schowaj pojazd',
        g_vehicle = '[E] Wyciągnij pojazd',
        o_menu = '[E] Otwórz menu',
        work_v = '[E] Wjedź na podnośnik',
        progress_bar = 'Naprawa: ',
        veh_status = 'Stan pojazdu:',
        job_blip = 'Warsztat LS Customs',
    },

    lift_menu = {
        header_menu = 'Podnośnik',
        header_vehdc = 'Zdejmij pojazd',
        desc_vehdc = 'Zjedź z podnośnika',
        header_stats = 'Sprawdź stan',
        desc_stats = 'Stan wszystkich części',
        header_parts = 'Części pojazdu',
        desc_parts = 'Naprawa części za materiały z magazynu',
        c_menu = 'Zamknij'
    },

    parts_menu = {
        status = 'Stan: ',
        menu_header = 'Część',
        repair_op = 'Naprawa za: ',
        b_menu = 'Wróć',
        d_menu = 'Powrót do listy części',
        c_menu = 'Zamknij'
    },

    nodamage_menu = {
        header = 'Bez uszkodzeń',
        bh_menu = 'Wróć',
        bd_menu = 'Ta część nie jest uszkodzona',
        c_menu = 'Zamknij'
    },

    notifications = {
        not_enough = 'Masz za mało: ',
        not_have = 'Nie masz: ',
        not_materials = 'W magazynie nie ma wystarczająco materiałów',
        rep_canceled = 'Naprawa przerwana',
        repaired = 'naprawione!',
        uknown = 'Stan nieznany',
        not_valid = 'To nie jest właściwy pojazd',
        not_close = 'Jesteś za daleko od pojazdu',
        veh_first = 'Najpierw musisz być w pojeździe',
        outside = 'Musisz być poza pojazdem',
        wrong_seat = 'Nie jesteś kierowcą albo to rower',
        not_vehicle = 'Nie jesteś w pojeździe',
        progress_bar = 'Naprawa pojazdu...',
        process_canceled = 'Przerwano',
        not_part = 'Nieprawidłowa część',
        partrep = '%{value}: naprawione!',
    }
}

if GetConvar('qb_locale', 'en') == 'pl' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
