(function () {
  var doc = document;
  var body = doc.body;
  var root = body.getAttribute("data-root");
  var sections = Array.prototype.slice.call(doc.querySelectorAll("main .couplet, main .taxon, main .glossary"));
  var byId = {};
  sections.forEach(function (s) { byId[s.id] = s; });
  if (!root || !byId[root]) return;

  body.classList.add("js", "wizard");
  var trail = []; // [{ id, via }] from the first couplet shown to the current one
  var trailEl = doc.getElementById("mk-trail");
  var backBtn = doc.getElementById("mk-back");
  var modeBtn = doc.getElementById("mk-mode");

  // Map of the key (optional)
  var mapEl = doc.getElementById("mk-map");
  var mapSvg = mapEl ? mapEl.querySelector("svg.keymap") : null;
  var mapScroll = doc.getElementById("mk-map-scroll");
  var mapLeft = doc.getElementById("mk-left");
  var mapBtn = doc.getElementById("mk-maptoggle");
  var mapNodes = mapSvg ? Array.prototype.slice.call(mapSvg.querySelectorAll(".mnode")) : [];
  var mapEdges = mapSvg ? Array.prototype.slice.call(mapSvg.querySelectorAll(".medge")) : [];
  var totalTaxa = {};
  var mapKids = {}; // parent couplet id -> map nodes directly below it
  mapNodes.forEach(function (n) {
    if (n.classList.contains("mleaf")) totalTaxa[n.getAttribute("data-id")] = true;
    var p = n.getAttribute("data-p");
    if (p) (mapKids[p] = mapKids[p] || []).push(n);
  });
  totalTaxa = Object.keys(totalTaxa).length;
  var smooth = !(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);

  // Where the reader is. The page keeps this itself and does not depend on
  // the address bar: in a preview pane or an embedded frame a "#..." link
  // often goes nowhere, and the key must still work there.
  var here = "";

  function readHash() {
    try { return decodeURIComponent(location.hash.slice(1)); } catch (e) { return ""; }
  }

  // The section an anchor belongs to: itself, the glossary for a glossary
  // entry, or null when the page has no such anchor.
  function sectionOf(anchor) {
    if (byId[anchor]) return anchor;
    var el = anchor && doc.getElementById(anchor);
    if (el && el.closest && el.closest(".glossary")) return "glossary";
    return null;
  }

  function currentId() { return sectionOf(here) || root; }

  // Go to an anchor of this page. Returns false if it is not one of ours.
  function go(anchor) {
    if (!sectionOf(anchor)) return false;
    here = anchor;
    try {
      if (readHash() !== anchor) history.pushState({ moose: anchor }, "", "#" + encodeURIComponent(anchor));
    } catch (e) { /* no history here (sandboxed frame): the page still moves */ }
    update(true);
    if (!body.classList.contains("wizard")) {   // the full key: jump to the place
      var el = doc.getElementById(anchor);
      if (el) el.scrollIntoView();
    }
    return true;
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

  function mark(el, cls, on) { el.classList[on ? "add" : "remove"](cls); }

  function centerMap(id) {
    if (!mapScroll || !mapScroll.clientHeight) return; // hidden
    var n = mapSvg.querySelector('.mnode[data-id="' + id + '"]');
    if (!n) return;
    var x = +n.getAttribute("data-x"), y = +n.getAttribute("data-y");
    var opts = { left: x - mapScroll.clientWidth / 2, top: y - mapScroll.clientHeight / 2 };
    if (smooth) opts.behavior = "smooth";
    mapScroll.scrollTo(opts);
  }

  function renderMap(id) {
    if (!mapSvg) return;
    mapSvg.classList.add("live");
    var onTrail = {}, steps = {};
    for (var k = 0; k < trail.length; k++) {
      onTrail[trail[k].id] = true;
      if (k > 0) steps[trail[k - 1].id + ">" + trail[k].id] = true;
    }
    // everything below the current position is still possible
    var ahead = {}, aheadCouplets = {}, left = {};
    ahead[id] = true;
    aheadCouplets[id] = true;
    var queue = [id];
    while (queue.length) {
      (mapKids[queue.pop()] || []).forEach(function (n) {
        var nid = n.getAttribute("data-id");
        ahead[nid] = true;
        if (n.classList.contains("mleaf")) {
          left[nid] = true;
        } else if (!aheadCouplets[nid]) {
          aheadCouplets[nid] = true;
          queue.push(nid);
        }
      });
    }
    if (byId[id] && byId[id].classList.contains("taxon")) left[id] = true;
    mapNodes.forEach(function (n) {
      var nid = n.getAttribute("data-id");
      var here = nid === id;
      mark(n, "here", here);
      mark(n, "done", !here && !!onTrail[nid]);
      mark(n, "ahead", !!ahead[nid]);
    });
    mapEdges.forEach(function (e) {
      var from = e.getAttribute("data-from");
      mark(e, "done", !!steps[from + ">" + e.getAttribute("data-to")]);
      mark(e, "ahead", !!aheadCouplets[from]);
    });
    var n = Object.keys(left).length;
    if (mapLeft) {
      mapLeft.textContent = byId[id].classList.contains("taxon")
        ? "Identified \u00b7 1 of " + totalTaxa + " taxa"
        : n + " of " + totalTaxa + " taxa still possible";
    }
    centerMap(id);
  }

  // For large keys the path to each result is built here, when it is shown
  var leadTo = null;
  function fillDiagnosis(section) {
    var ol = section.querySelector("ol.diagnosis[data-auto]");
    if (!ol || ol.getAttribute("data-done")) return;
    if (!leadTo) {
      leadTo = {};
      Array.prototype.forEach.call(doc.querySelectorAll("main a.choose"), function (a) {
        var t = a.getAttribute("href").slice(1);
        if (!leadTo[t]) leadTo[t] = a;
      });
    }
    var path = [], target = section.id, guard = 0;
    while (leadTo[target] && guard++ < 1000) {
      var a = leadTo[target];
      var from = a.closest("section");
      path.unshift({ from: from.id, lead: a.getAttribute("data-lead"), text: a.querySelector(".text").textContent });
      if (from.id === root) break;
      target = from.id;
    }
    ol.innerHTML = "";
    path.forEach(function (st) {
      var li = doc.createElement("li");
      var link = doc.createElement("a");
      link.className = "step";
      link.href = "#" + st.from;
      link.textContent = st.lead;
      li.appendChild(link);
      li.appendChild(doc.createTextNode(st.text));
      ol.appendChild(li);
    });
    ol.setAttribute("data-done", "1");
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
      if (last && !step && id !== "glossary") trail = []; // jumped somewhere unrelated: start a new trail
      trail.push({ id: id, via: step });
    }
    if (byId[id].classList.contains("taxon")) fillDiagnosis(byId[id]);
    sections.forEach(function (s) { s.classList.toggle("active", s.id === id); });
    body.classList.toggle("stepping", id !== root);
    renderTrail();
    if (id !== "glossary") renderMap(id);
    backBtn.disabled = trail.length < 2;
    if (moveFocus && body.classList.contains("wizard")) {
      window.scrollTo(0, 0);
      var h = byId[id].querySelector("h2");
      if (h) h.focus({ preventScroll: true });
    }
    if (id === "glossary") {
      var target = doc.getElementById(here);
      if (target && target !== byId[id]) target.scrollIntoView();
    }
  }

  backBtn.addEventListener("click", function () {
    if (trail.length > 1) go(trail[trail.length - 2].id);
  });

  modeBtn.addEventListener("click", function () {
    var stepping = body.classList.toggle("wizard");
    modeBtn.innerHTML = stepping
      ? '<span class="long">Show full key</span><span class="short">Full key</span>'
      : '<span class="long">Step through</span><span class="short">Steps</span>';
    modeBtn.setAttribute("aria-pressed", stepping ? "false" : "true");
    if (!stepping) sections.forEach(function (sec) { if (sec.classList.contains("taxon")) fillDiagnosis(sec); });
    var active = byId[currentId()];
    if (!stepping && active) active.scrollIntoView();
    if (stepping) window.scrollTo(0, 0);
  });

  if (mapBtn && mapEl) {
    var setMap = function (open) {
      body.classList.toggle("map-open", open);
      mapBtn.setAttribute("aria-expanded", open ? "true" : "false");
      mapBtn.textContent = open ? "Hide map" : "Map";
      try { localStorage.setItem("moose-map-open", open ? "1" : "0"); } catch (e) { /* storage unavailable */ }
      if (open) centerMap(currentId());
    };
    var saved = null;
    try { saved = localStorage.getItem("moose-map-open"); } catch (e) { /* storage unavailable */ }
    mapBtn.addEventListener("click", function () { setMap(!body.classList.contains("map-open")); });
    if (saved === "1") setMap(true);
  }

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

  // Links within the page are followed here; see `here` above.
  doc.addEventListener("click", function (ev) {
    if (ev.defaultPrevented || ev.button || ev.metaKey || ev.ctrlKey || ev.shiftKey || ev.altKey) return;
    var a = ev.target.closest && ev.target.closest("a");
    var href = a && (a.getAttribute("href") || a.getAttribute("xlink:href"));
    if (!href || href.charAt(0) !== "#") return;
    var anchor;
    try { anchor = decodeURIComponent(href.slice(1)); } catch (e) { return; }
    if (!sectionOf(anchor)) return;
    ev.preventDefault();
    go(anchor);
  });

  // Back and forward buttons, and an address typed by hand
  function fromAddress(ev) {
    var anchor = ev && ev.state && ev.state.moose ? ev.state.moose : readHash();
    here = sectionOf(anchor) ? anchor : "";
    update(true);
    // the browser may still jump to the anchor after this; a step starts at the top
    if (body.classList.contains("wizard") && currentId() !== "glossary" && window.requestAnimationFrame) {
      window.requestAnimationFrame(function () { window.scrollTo(0, 0); });
    }
  }
  window.addEventListener("popstate", fromAddress);
  window.addEventListener("hashchange", function () { if (readHash() !== here) fromAddress(); });

  doc.addEventListener("click", function (ev) {
    var fig = ev.target.closest && ev.target.closest(".fig");
    if (fig && !fig.closest("a")) fig.classList.toggle("big");
  });

  here = sectionOf(readHash()) ? readHash() : "";
  update(false);
})();
