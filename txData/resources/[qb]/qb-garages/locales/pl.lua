local Translations = {
    error = {
        no_vehicles = "Nie masz tu żadnych pojazdów!",
        not_impound = "Twój pojazd nie jest na parkingu policyjnym",
        not_owned = "Tego pojazdu nie da się tu schować",
        not_correct_type = "Tego typu pojazdu nie schowasz w tym miejscu",
        not_enough = "Za mało pieniędzy",
        no_garage = "Brak",
        vehicle_occupied = "Nie schowasz pojazdu, w którym ktoś siedzi",
    },
    success = {
        vehicle_parked = "Pojazd schowany",
    },
    menu = {
        header = {
            house_car = "Garaż domowy %{value}",
            public_car = "Garaż publiczny %{value}",
            public_sea = "Przystań publiczna %{value}",
            public_air = "Hangar publiczny %{value}",
            public_rig = "Parking ciężarówek %{value}",
            job_car = "Garaż służbowy %{value}",
            job_sea = "Przystań służbowa %{value}",
            job_air = "Hangar służbowy %{value}",
            job_rig = "Parking ciężarówek %{value}",
            gang_car = "Garaż gangu %{value}",
            gang_sea = "Przystań gangu %{value}",
            gang_air = "Hangar gangu %{value}",
            gang_rig = "Parking ciężarówek gangu %{value}",
            depot_car = "Parking odzyskiwania %{value}",
            depot_sea = "Parking odzyskiwania %{value}",
            depot_air = "Parking odzyskiwania %{value}",
            depot_rig = "Parking odzyskiwania %{value}",
            vehicles = "Dostępne pojazdy",
            depot = "%{value} [ $%{value2} ]",
            garage = "%{value} [ %{value2} ]",
            unavailable_vehicle_model = "%{vehicle} | Pojazd niedostępny",
        },
        leave = {
            car = "Wyjdź z garażu",
            sea = "Wyjdź z przystani",
            air = "Wyjdź z hangaru",
            rig = "Wyjdź z parkingu",
        },
        text = {
            vehicles = "Zobacz schowane pojazdy",
            depot = "Tablica: %{value}<br>Paliwo: %{value2} | Silnik: %{value3} | Karoseria: %{value4}",
            garage = "Stan: %{value}<br>Paliwo: %{value2} | Silnik: %{value3} | Karoseria: %{value4}",
        }
    },
    status = {
        out = "Na zewnątrz",
        garaged = "W garażu",
        impound = "Zajęty przez policję",
    },
    info = {
        car_e = "E - Garaż",
        sea_e = "E - Przystań",
        air_e = "E - Hangar",
        rig_e = "E - Parking ciężarówek",
        park_e = "E - Schowaj pojazd",
        house_garage = "Garaż domowy",
    }
}

if GetConvar('qb_locale', 'en') == 'pl' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
