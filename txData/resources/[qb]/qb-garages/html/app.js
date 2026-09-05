(function () {
    const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "qb-garages";

    function fetchNui(eventName, data) {
        return fetch(`https://${resourceName}/${eventName}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(data || {}),
        }).then((resp) => resp.json()).catch(() => null);
    }

    const overlay = document.getElementById("overlay");
    const garageListEl = document.getElementById("garageList");
    const searchEl = document.getElementById("search");
    const emptyState = document.getElementById("emptyState");
    const form = document.getElementById("garageForm");
    const toastsEl = document.getElementById("toasts");

    let garages = {};
    let selectedKey = null;
    let searchTerm = "";
    const dirtyKeys = new Set();

    function confirmDiscardIfDirty(nextKey) {
        if (!selectedKey || !dirtyKeys.has(selectedKey) || selectedKey === nextKey) return true;
        return confirm(`Masz niezapisane zmiany w "${garages[selectedKey]?.label || selectedKey}". Odrzucić je?`);
    }

    const fields = {
        key: document.getElementById("fKey"),
        label: document.getElementById("fLabel"),
        type: document.getElementById("fType"),
        vehicle: document.getElementById("fVehicle"),
        job: document.getElementById("fJob"),
        jobType: document.getElementById("fJobType"),
        showBlip: document.getElementById("fShowBlip"),
        blipName: document.getElementById("fBlipName"),
        blipNumber: document.getElementById("fBlipNumber"),
        blipColor: document.getElementById("fBlipColor"),
    };

    function showToast(message, ok) {
        const el = document.createElement("div");
        el.className = "toast " + (ok ? "success" : "error");
        el.textContent = message;
        toastsEl.appendChild(el);
        setTimeout(() => el.remove(), 4000);
    }

    function slugify(label, existing) {
        let base = (label || "garaz")
            .toLowerCase()
            .normalize("NFD").replace(/[̀-ͯ]/g, "")
            .replace(/[^a-z0-9]+/g, "")
            .slice(0, 24) || "garaz";
        let key = base;
        let i = 1;
        while (existing[key]) {
            key = base + i;
            i++;
        }
        return key;
    }

    function renderList() {
        garageListEl.innerHTML = "";
        const term = searchTerm.trim().toLowerCase();
        const keys = Object.keys(garages).sort((a, b) => {
            const la = (garages[a].label || a).toLowerCase();
            const lb = (garages[b].label || b).toLowerCase();
            return la.localeCompare(lb);
        });

        for (const key of keys) {
            const g = garages[key];
            const label = g.label || key;
            if (term && !label.toLowerCase().includes(term) && !key.toLowerCase().includes(term)) continue;

            const dirtyMark = dirtyKeys.has(key) ? ' <span class="dirty-dot" title="Niezapisane zmiany">●</span>' : "";
            const item = document.createElement("div");
            item.className = "garage-item" + (key === selectedKey ? " active" : "");
            item.innerHTML = `<span class="g-label">${escapeHtml(label)}${dirtyMark}</span><span class="g-meta">${key} · ${g.type || "?"} · ${g.vehicle || "?"}</span>`;
            item.addEventListener("click", () => {
                if (!confirmDiscardIfDirty(key)) return;
                if (selectedKey) dirtyKeys.delete(selectedKey);
                selectGarage(key);
            });
            garageListEl.appendChild(item);
        }
    }

    function escapeHtml(str) {
        const div = document.createElement("div");
        div.textContent = str;
        return div.innerHTML;
    }

    function setCoordGroup(field, coords) {
        const group = form.querySelector(`.pos-group[data-field="${field}"]`);
        const inputs = group.querySelectorAll(".coord-inputs input");
        inputs.forEach((input) => {
            const axis = input.dataset.axis;
            input.value = coords && coords[axis] !== undefined && coords[axis] !== null ? coords[axis] : "";
        });
    }

    function getCoordGroup(field) {
        const group = form.querySelector(`.pos-group[data-field="${field}"]`);
        const inputs = group.querySelectorAll(".coord-inputs input");
        const out = {};
        let hasAny = false;
        inputs.forEach((input) => {
            const axis = input.dataset.axis;
            if (input.value !== "") {
                out[axis] = parseFloat(input.value);
                hasAny = true;
            }
        });
        return hasAny ? out : null;
    }

    function selectGarage(key) {
        selectedKey = key;
        const g = garages[key] || {};

        emptyState.classList.add("hidden");
        form.classList.remove("hidden");

        fields.key.value = key;
        fields.label.value = g.label || "";
        fields.type.value = g.type || "public";
        fields.vehicle.value = g.vehicle || "car";
        fields.job.value = g.job || "";
        fields.jobType.value = g.jobType || "";
        fields.showBlip.checked = !!g.showBlip;
        fields.blipName.value = g.blipName || "";
        fields.blipNumber.value = g.blipNumber != null ? g.blipNumber : 357;
        fields.blipColor.value = g.blipColor != null ? g.blipColor : 3;

        setCoordGroup("takeVehicle", g.takeVehicle);
        setCoordGroup("spawnPoint", g.spawnPoint);
        setCoordGroup("putVehicle", g.putVehicle);
        setCoordGroup("previewPoint", g.previewPoint);
        setCoordGroup("previewCamPoint", g.previewCamPoint);

        updateJobFieldsVisibility();
        renderList();
    }

    function updateJobFieldsVisibility() {
        const show = fields.type.value === "job" || fields.type.value === "gang";
        document.getElementById("jobFields").classList.toggle("hidden", !show);
    }

    function createNewGarage() {
        if (!confirmDiscardIfDirty(null)) return;
        if (selectedKey) dirtyKeys.delete(selectedKey);
        const key = slugify("nowy-garaz", garages);
        garages[key] = {
            label: "Nowy Garaż",
            type: "public",
            vehicle: "car",
            showBlip: true,
            blipName: "Parking",
            blipNumber: 357,
            blipColor: 3,
            takeVehicle: null,
            spawnPoint: null,
            putVehicle: null,
            previewPoint: null,
            previewCamPoint: null,
        };
        selectGarage(key);
    }

    function closePanel() {
        if (dirtyKeys.size > 0 && !confirm(`Masz niezapisane zmiany w ${dirtyKeys.size} garażu/ach. Zamknąć bez zapisywania?`)) {
            return;
        }
        fetchNui("close");
    }

    document.getElementById("btnClose").addEventListener("click", closePanel);
    document.getElementById("btnAdd").addEventListener("click", createNewGarage);
    searchEl.addEventListener("input", (e) => { searchTerm = e.target.value; renderList(); });
    fields.type.addEventListener("change", updateJobFieldsVisibility);
    form.addEventListener("input", () => {
        if (!selectedKey || dirtyKeys.has(selectedKey)) return;
        dirtyKeys.add(selectedKey);
        renderList();
    });

    form.querySelectorAll(".pos-group").forEach((group) => {
        const field = group.dataset.field;
        group.querySelectorAll("button[data-action]").forEach((btn) => {
            btn.addEventListener("click", async () => {
                const action = btn.dataset.action;
                if (action === "here") {
                    const pos = await fetchNui("getPosition");
                    if (pos) setCoordGroup(field, pos);
                } else if (action === "goto") {
                    const coords = getCoordGroup(field);
                    if (!coords || coords.x === undefined) {
                        showToast("Brak współrzędnych do teleportacji.", false);
                        return;
                    }
                    fetchNui("teleport", coords);
                } else if (action === "clear") {
                    setCoordGroup(field, null);
                }
            });
        });
    });

    let deleteArmed = false;
    document.getElementById("btnDelete").addEventListener("click", () => {
        const btn = document.getElementById("btnDelete");
        if (!deleteArmed) {
            deleteArmed = true;
            const original = btn.textContent;
            btn.textContent = "Kliknij ponownie, aby potwierdzić";
            setTimeout(() => { deleteArmed = false; btn.textContent = original; }, 3000);
            return;
        }
        deleteArmed = false;
        btn.textContent = "Usuń garaż";
        if (!selectedKey) return;
        fetchNui("deleteGarage", { key: selectedKey });
        delete garages[selectedKey];
        dirtyKeys.delete(selectedKey);
        selectedKey = null;
        form.classList.add("hidden");
        emptyState.classList.remove("hidden");
        renderList();
    });

    document.getElementById("btnSave").addEventListener("click", () => {
        if (!selectedKey) return;

        const takeVehicle = getCoordGroup("takeVehicle");
        const spawnPoint = getCoordGroup("spawnPoint");
        if (!takeVehicle || takeVehicle.x === undefined || takeVehicle.y === undefined || takeVehicle.z === undefined) {
            showToast("Ustaw miejsce interakcji (mapa) przed zapisem.", false);
            return;
        }
        if (!spawnPoint || spawnPoint.x === undefined || spawnPoint.y === undefined || spawnPoint.z === undefined) {
            showToast("Ustaw miejsce spawnu pojazdu przed zapisem.", false);
            return;
        }

        const garage = {
            label: fields.label.value.trim() || selectedKey,
            type: fields.type.value,
            vehicle: fields.vehicle.value,
            job: fields.job.value.trim() || null,
            jobType: fields.jobType.value.trim() || null,
            showBlip: fields.showBlip.checked,
            blipName: fields.blipName.value.trim() || "Parking",
            blipNumber: parseInt(fields.blipNumber.value, 10) || 357,
            blipColor: parseInt(fields.blipColor.value, 10) || 3,
            takeVehicle: takeVehicle,
            spawnPoint: { ...spawnPoint, w: spawnPoint.w || 0 },
            putVehicle: getCoordGroup("putVehicle"),
            previewPoint: getCoordGroup("previewPoint"),
            previewCamPoint: getCoordGroup("previewCamPoint"),
        };

        garages[selectedKey] = garage;
        fetchNui("saveGarage", { key: selectedKey, garage: garage });
        dirtyKeys.delete(selectedKey);
        renderList();
    });

    document.addEventListener("keydown", (e) => {
        if (e.key === "Escape") closePanel();
    });

    window.addEventListener("message", (event) => {
        const data = event.data;
        if (!data || !data.action) return;

        if (data.action === "open") {
            garages = data.garages || {};
            selectedKey = null;
            dirtyKeys.clear();
            searchTerm = "";
            searchEl.value = "";
            form.classList.add("hidden");
            emptyState.classList.remove("hidden");
            overlay.classList.remove("hidden");
            renderList();
        } else if (data.action === "close") {
            overlay.classList.add("hidden");
        } else if (data.action === "toast") {
            showToast(data.message, data.ok);
        }
    });
})();
