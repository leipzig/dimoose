(function () {
  var doc = document;
  var body = doc.body;
  var root = body.getAttribute("data-root");
  var sections = Array.prototype.slice.call(doc.querySelectorAll("main .couplet, main .taxon"));
  var byId = {};
  sections.forEach(function (s) { byId[s.id] = s; });
  if (!root || !byId[root]) return;

  body.classList.add("js", "wizard");
  var trail = []; // [{ id, via }] from the first couplet shown to the current one
  var trailEl = doc.getElementById("mk-trail");
  var backBtn = doc.getElementById("mk-back");
  var modeBtn = doc.getElementById("mk-mode");

  function currentId() {
    var id = decodeURIComponent(location.hash.slice(1));
    return byId[id] ? id : root;
  }

  // The lead in section `fromId` that points at `toId`, as "1a Text of lead".
  function via(fromId, toId) {
    var from = byId[fromId];
    if (!from) return null;
    var links = from.querySelectorAll("a.choose");
    for (var i = 0; i < links.length; i++) {
      if (links[i].getAttribute("href") === "#" + toId) {
        return {
          lead: links[i].getAttribute("data-lead"),
          text: links[i].querySelector(".text").textContent
        };
      }
    }
    return null;
  }

  function renderTrail() {
    trailEl.innerHTML = "";
    for (var k = 1; k < trail.length; k++) {
      var v = trail[k].via;
      if (!v) continue;
      var li = doc.createElement("li");
      var a = doc.createElement("a");
      a.href = "#" + trail[k - 1].id;
      a.title = "Go back to this choice: " + v.lead + " " + v.text;
      var b = doc.createElement("b");
      b.textContent = v.lead;
      a.appendChild(b);
      a.appendChild(doc.createTextNode(v.text));
      li.appendChild(a);
      trailEl.appendChild(li);
    }
    trailEl.scrollLeft = trailEl.scrollWidth; // keep the latest choice in view on narrow screens
  }

  function update(moveFocus) {
    var id = currentId();
    var seen = -1;
    for (var k = 0; k < trail.length; k++) if (trail[k].id === id) seen = k;
    if (seen >= 0) {
      trail = trail.slice(0, seen + 1);
    } else {
      var last = trail.length ? trail[trail.length - 1].id : null;
      var step = last ? via(last, id) : null;
      if (last && !step) trail = []; // jumped somewhere unrelated: start a new trail
      trail.push({ id: id, via: step });
    }
    sections.forEach(function (s) { s.classList.toggle("active", s.id === id); });
    body.classList.toggle("stepping", id !== root);
    renderTrail();
    backBtn.disabled = trail.length < 2;
    if (moveFocus && body.classList.contains("wizard")) {
      window.scrollTo(0, 0);
      var h = byId[id].querySelector("h2");
      if (h) h.focus({ preventScroll: true });
    }
  }

  backBtn.addEventListener("click", function () {
    if (trail.length > 1) location.hash = "#" + trail[trail.length - 2].id;
  });

  modeBtn.addEventListener("click", function () {
    var stepping = body.classList.toggle("wizard");
    modeBtn.textContent = stepping ? "Show full key" : "Step through";
    modeBtn.setAttribute("aria-pressed", stepping ? "false" : "true");
    var active = byId[currentId()];
    if (!stepping && active) active.scrollIntoView();
    if (stepping) window.scrollTo(0, 0);
  });

  // Keyboard: a/b/c... or 1/2/3... picks a lead of the current couplet.
  doc.addEventListener("keydown", function (e) {
    if (!body.classList.contains("wizard") || e.altKey || e.ctrlKey || e.metaKey) return;
    var tag = (e.target.tagName || "").toLowerCase();
    if (tag === "input" || tag === "textarea" || tag === "select") return;
    var active = byId[currentId()];
    if (!active || !active.classList.contains("couplet")) return;
    var links = active.querySelectorAll("a.choose");
    var key = e.key.toLowerCase();
    var n = /^[1-9]$/.test(key) ? parseInt(key, 10) - 1 : "abcdefghi".indexOf(key);
    if (n >= 0 && n < links.length) {
      e.preventDefault();
      links[n].click();
    }
  });

  // Figures come from the web; drop any that fail to load (e.g. offline in the field)
  function dropImage(img) {
    var item = img.closest(".figs > a, .figs > span") || img;
    var fig = img.closest(".figs");
    if (item.parentNode) item.parentNode.removeChild(item);
    if (fig && !fig.children.length && fig.parentNode) fig.parentNode.removeChild(fig);
  }
  doc.addEventListener("error", function (e) {
    var t = e.target;
    if (t && t.tagName === "IMG" && t.closest(".figs")) dropImage(t);
  }, true);
  Array.prototype.forEach.call(doc.querySelectorAll(".figs img"), function (img) {
    if (img.complete && img.naturalWidth === 0) dropImage(img);
  });

  window.addEventListener("hashchange", function () { update(true); });
  update(false);
})();
