let buttonParams = [];
let activeId = null;
let navTimer = null;

const applyMenuPosition = (position) => {
    const container = document.getElementById("container");
    container.classList.remove("position-right");
    if (position === "right") {
        container.classList.add("position-right");
    }
};

const selectableIds = () =>
    $("#buttons .button")
        .not(".disabled")
        .map(function () {
            return parseInt(this.id);
        })
        .get();

// fire = true -> jeśli pozycja ma params.navSelect, odpal ją od razu (podgląd auta
// bez klikania). Debounce, żeby szybkie przewijanie strzałkami nie zasypało Lua.
const setActive = (id, fire) => {
    const el = document.getElementById(String(id));
    if (!el) return;
    activeId = id;
    $("#buttons .button").removeClass("active");
    el.classList.add("active");
    el.scrollIntoView({ block: "nearest" });

    const params = buttonParams[id];
    if (fire && params && params.navSelect) {
        clearTimeout(navTimer);
        navTimer = setTimeout(() => postData(String(id)), 140);
    }
};

const moveActive = (dir) => {
    const ids = selectableIds();
    if (!ids.length) return;
    const pos = ids.indexOf(activeId);
    const next = pos === -1 ? (dir > 0 ? 0 : ids.length - 1) : (pos + dir + ids.length) % ids.length;
    setActive(ids[next], true);
};

const openMenu = (data = null, interactive = true) => {
    let html = "";
    let navActiveId = null;
    data.forEach((item, index) => {
        if(!item.hidden) {
            let header = item.header;
            let message = item.txt || item.text;
            let isMenuHeader = item.isMenuHeader;
            let isDisabled = item.disabled;
            let icon = item.icon;
            let color = item.color;
            html += getButtonRender(header, message, index, isMenuHeader, isDisabled, icon, color);
            if (item.params) buttonParams[index] = item.params;
            if (item.params && item.params.navActive) navActiveId = index;
        }
    });

    $("#buttons").html(html);
    $("#hint").toggle(interactive);

    $('.button').click(function() {
        const target = $(this)
        if (!target.hasClass('title') && !target.hasClass('disabled')) {
            postData(target.attr('id'));
        }
    });

    $('.button').not('.disabled').on('mouseenter', function () {
        setActive(parseInt(this.id), false);
    });

    activeId = null;
    if (!interactive) return; // SHOW_HEADER: brak focusu NUI, brak nawigacji
    const ids = selectableIds();
    if (navActiveId !== null) {
        setActive(navActiveId, false);
    } else if (ids.length) {
        setActive(ids[0], false);
    }
};

const getButtonRender = (header, message = null, id, isMenuHeader, isDisabled, icon, color) => {
    const colorClass = color ? ` ${color}` : "";
    return `
        <div class="${isMenuHeader ? "title" : "button"}${colorClass} ${isDisabled ? "disabled" : ""}" id="${id}">
            <div class="icon"> <img src=nui://${icon} width=30px onerror="this.onerror=null; this.remove();"> <i class="${icon}" onerror="this.onerror=null; this.remove();"></i> </div>
            <div className="column">
            <div class="header"> ${header}</div>
            ${message ? `<div class="text">${message}</div>` : ""}
            </div>
        </div>
    `;
};

const closeMenu = () => {
    $("#buttons").html(" ");
    $("#hint").hide();
    buttonParams = [];
    activeId = null;
    clearTimeout(navTimer);
    applyMenuPosition(null);
};

const postData = (id) => {
    const params = buttonParams[parseInt(id)];
    $.post(`https://${GetParentResourceName()}/clickedButton`, JSON.stringify(parseInt(id) + 1));
    if (!params || !params.keepOpen) {
        return closeMenu();
    }
};

const cancelMenu = () => {
    $.post(`https://${GetParentResourceName()}/closeMenu`);
    return closeMenu();
};



window.addEventListener("message", (event) => {
    const data = event.data;
    const buttons = data.data;
    const action = data.action;
    switch (action) {
        case "OPEN_MENU":
            applyMenuPosition(data.position);
            return openMenu(buttons);
        case "SHOW_HEADER":
            return openMenu(buttons, false);
        case "CLOSE_MENU":
            return closeMenu();
        default:
            return;
    }
});

// Nawigacja klawiaturą. Niektóre buildy CEF w FiveM nie dostarczają keydown dla
// strzałek - dlatego jest fallback na keyup (odpalany tylko gdy keydown milczy).
let keydownSeen = false;

const handleNav = (event) => {
    const key = event.key;
    const code = event.keyCode || event.which;
    let dir = 0;
    if (key === "ArrowDown" || code === 40) dir = 1;
    if (key === "ArrowUp" || code === 38) dir = -1;

    if (dir !== 0) {
        if (!selectableIds().length) return;
        event.preventDefault();
        return moveActive(dir);
    }
    if ((key === "Enter" || code === 13) && activeId !== null) {
        event.preventDefault();
        clearTimeout(navTimer);
        postData(String(activeId));
    }
};

document.addEventListener("keydown", (event) => {
    keydownSeen = true;
    handleNav(event);
});

document.addEventListener("keyup", (event) => {
    if (event.key === "Escape" || event.keyCode === 27) return cancelMenu();
    if (!keydownSeen) handleNav(event);
});
