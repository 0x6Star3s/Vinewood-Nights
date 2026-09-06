local Translations = {
    error = {
        finish_work = "Najpierw zakończ bieżące holowanie",
        vehicle_not_correct = "To nie jest pojazd ze zlecenia",
        failed = "Nie udało się",
        not_towing_vehicle = "Potrzebujesz lawety obok (najpierw z niej wysiądź)",
        leave_truck = "Najpierw wysiądź z lawety",
        no_vehicle_in_front = "Nie ma przed Tobą pojazdu do podczepienia",
        too_far_away = "Jesteś za daleko",
        no_work_done = "Nie wykonałeś jeszcze żadnego zlecenia",
        no_deposit = "Potrzebna kaucja $%{value}",
        no_vehicle_nearby = "Brak pojazdu w pobliżu",
        no_tow_online = "Żadna laweta nie jest teraz na służbie",
    },
    success = {
        paid_with_cash = "Kaucja $%{value} zapłacona gotówką",
        paid_with_bank = "Kaucja $%{value} zapłacona z banku",
        refund = "Zwrócono kaucję $%{value}",
        you_earned = "Zarobiłeś $%{value}",
    },
    menu = {
        header = "Pomoc drogowa",
        rent_txt = "Wypożycz lawetę. Kaucja $%{value}, zwrot przy oddaniu w tym miejscu.",
        npc_on = "Zlecenia NPC: włącz",
        npc_off = "Zlecenia NPC: wyłącz",
        npc_txt = "Na mapie pojawia się porzucone auto do odholowania na depot.",
        close_menu = "Zamknij",
    },
    mission = {
        delivered_vehicle = "Dostarczyłeś pojazd",
        get_new_vehicle = "Nowe zlecenie na mapie",
        towing_vehicle = "Podczepianie pojazdu...",
        goto_depot = "Zawieź pojazd do depot Hayes",
        vehicle_towed = "Pojazd podczepiony",
        untowing_vehicle = "Zdejmowanie pojazdu...",
        vehicle_takenoff = "Pojazd zdjęty z lawety",
        npc_started = "Zlecenia NPC włączone, jedź po trasie",
        npc_stopped = "Zlecenia NPC wyłączone",
    },
    info = {
        tow = "Podczep auto do lawety",
        toggle_npc = "Włącz / wyłącz zlecenia NPC",
        skick = "Próba exploita",
        tow_request_sent = "Wezwanie lawety wysłane",
        tow_request_title = "Wezwanie lawety",
        tow_request_received = "Pojazd %{plate}, pozycja na mapie przez 2 minuty",
    },
    label = {
        payslip = "Wypłata",
        vehicle = "Laweta: wypożycz",
        return_vehicle = "[E] Oddaj lawetę (zwrot kaucji)",
        attach = "Podczep do lawety",
        detach = "Zdejmij pojazd z lawety",
        npcz = "Strefa NPC",
    }
}

if GetConvar('qb_locale', 'en') == 'pl' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
