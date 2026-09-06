local Translations = {
    error = {
        finish_work = "Finish all of your work first",
        vehicle_not_correct = "This is not the right Vehicle",
        failed = "You have failed",
        not_towing_vehicle = "You need a flatbed nearby (get out of it first)",
        leave_truck = "Get out of the flatbed first",
        no_vehicle_in_front = "No vehicle in front of you to hook up",
        too_far_away = "You are too far away",
        no_work_done = "You have not done any work yet",
        no_deposit = "$%{value} Deposit required",
        no_vehicle_nearby = "No vehicle nearby",
        no_tow_online = "No tow driver is on duty right now",
    },
    success = {
        paid_with_cash = "$%{value} Deposit Paid With Cash",
        paid_with_bank = "$%{value} Deposit Paid From Bank",
        refund = "$%{value} deposit refunded",
        you_earned = "You Earned $%{value}",
    },
    menu = {
        header = "Towing Service",
        rent_txt = "Rent a truck. Deposit $%{value}, refunded when you return it here.",
        npc_on = "NPC jobs: start",
        npc_off = "NPC jobs: stop",
        npc_txt = "The map shows an abandoned car to tow to the depot.",
        close_menu = "Close",
    },
    mission = {
        delivered_vehicle = "You Have Delivered A Vehicle",
        get_new_vehicle = "A New Vehicle Can Be Picked Up",
        towing_vehicle = "Hoisting the Vehicle...",
        goto_depot = "Take The Vehicle To Hayes Depot",
        vehicle_towed = "Vehicle Towed",
        untowing_vehicle = "Unloading the vehicle...",
        vehicle_takenoff = "Vehicle Taken Off",
        npc_started = "NPC jobs started, follow the route",
        npc_stopped = "NPC jobs stopped",
    },
    info = {
        tow = "Place A Car On The Back Of Your Flatbed",
        toggle_npc = "Toggle Npc Job",
        skick = "Attempted exploit abuse",
        tow_request_sent = "Tow request sent",
        tow_request_title = "Tow request",
        tow_request_received = "Vehicle %{plate}, location marked on the map for 2 minutes",
    },
    label = {
        payslip = "Payslip",
        vehicle = "Flatbed: rent",
        return_vehicle = "[E] Return the flatbed (deposit refund)",
        attach = "Hook up to the flatbed",
        detach = "Unload the vehicle",
        npcz = "NPCZone",
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
