(function () {
  var doc = document;
  var body = doc.body;
  var win = window;

  // Offline copy: exportWizard(offline = TRUE) names a service worker here.
  // Browsers only allow one on https or localhost, never on file://.
  var swFile = body.getAttribute("data-sw");
  if (swFile && win.navigator && "serviceWorker" in win.navigator && /^https?:$/.test(location.protocol)) {
    win.addEventListener("load", function () {
      try {
        win.navigator.serviceWorker.register(swFile, { scope: body.getAttribute("data-sw-scope") || "./" })
          .then(function () { return win.navigator.serviceWorker.ready; })
          .then(function () {
            var note = doc.getElementById("mk-offline");
            if (note) { note.textContent = "Saved for use without a connection. "; note.hidden = false; }
          })["catch"](function () { /* the page works without it */ });
      } catch (e) { /* the page works without it */ }
    });
  }

  var root = body.getAttribute("data-root");
  var sections = Array.prototype.slice.call(doc.querySelectorAll("main .couplet, main .taxon, main .glossary, main .matrix"));
  var byId = {};
  sections.forEach(function (s) { byId[s.id] = s; });
  if (!root || !byId[root]) return;
  var hasKey = root !== "matrix";   // a page made from a character matrix alone has no couplets
  var CAND = "mk-candidates";

  body.classList.add("js", "wizard");
  var mainEl = doc.querySelector("main");
  var trailEl = doc.getElementById("mk-trail");
  var backBtn = doc.getElementById("mk-back");
  var modeBtn = doc.getElementById("mk-mode");
  var pickBtn = doc.getElementById("mk-pick");

  // Panels the script adds above the key, kept in a fixed order
  var topEl = null;
  function addTop(e, rank) {
    if (!topEl) {
      topEl = doc.createElement("div");
      topEl.id = "mk-top";
      mainEl.insertBefore(topEl, mainEl.firstChild);
    }
    e.setAttribute("data-rank", rank);
    var after = null;
    Array.prototype.forEach.call(topEl.children, function (c) {
      if (!after && +c.getAttribute("data-rank") > rank) after = c;
    });
    topEl.insertBefore(e, after);
  }

  function el(tag, cls, text) {
    var e = doc.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function mark(e, cls, on) { e.classList[on ? "add" : "remove"](cls); }
  function isCouplet(id) { return !!byId[id] && byId[id].classList.contains("couplet"); }
  function isTaxon(id) { return !!byId[id] && byId[id].classList.contains("taxon"); }
  function leadLinks(id) { return byId[id] ? byId[id].querySelectorAll("a.choose") : []; }
  function coupletName(id) {
    return (byId[id] && byId[id].getAttribute("data-name")) || id;
  }

  // The key as a graph, read from the page: where each lead of a couplet goes.
  var kids = {};      // couplet id -> section ids its leads go to, in lead order
  var parentOf = {};  // section id -> the first couplet with a lead to it
  var taxa = [];      // [{ id, name }]
  var taxonName = {};
  sections.forEach(function (s) {
    if (s.classList.contains("couplet")) {
      kids[s.id] = Array.prototype.map.call(s.querySelectorAll("a.choose"), function (a) {
        var to = a.getAttribute("href").slice(1);
        if (!parentOf[to]) parentOf[to] = s.id;
        return to;
      });
    } else if (s.classList.contains("taxon")) {
      var h = s.querySelector("h2");
      taxonName[s.id] = h ? h.textContent : s.id;
      taxa.push({ id: s.id, name: taxonName[s.id] });
    }
  });
  var totalTaxa = taxa.length;

  // Map of the key (optional)
  var mapEl = doc.getElementById("mk-map");
  var mapSvg = mapEl ? mapEl.querySelector("svg.keymap") : null;
  var mapScroll = doc.getElementById("mk-map-scroll");
  var mapLeft = doc.getElementById("mk-left");
  var mapBtn = doc.getElementById("mk-maptoggle");
  var mapNodes = mapSvg ? Array.prototype.slice.call(mapSvg.querySelectorAll(".mnode")) : [];
  var mapEdges = mapSvg ? Array.prototype.slice.call(mapSvg.querySelectorAll(".medge")) : [];
  var smooth = !(win.matchMedia && win.matchMedia("(prefers-reduced-motion: reduce)").matches);

  // ---- character matrix (optional): "pick any character you can see" --------

  // Read from the table the page carries, so the page has the data only once.
  // A cell lists the states of a taxon separated by "/"; a cell marked data-na
  // is unknown and matches every state.
  var mx = null;
  (function () {
    var sec = byId.matrix;
    var table = sec && sec.querySelector("table.cmatrix");
    if (!table) return;
    var chars = Array.prototype.map.call(table.querySelectorAll("thead th[data-char]"), function (th) {
      var cost = th.getAttribute("data-cost");
      return {
        name: th.getAttribute("data-char"),
        cost: cost === null || cost === "" || isNaN(+cost) ? null : +cost,
        season: th.getAttribute("data-season") || "",
        needs: th.getAttribute("data-needs") || "",
        states: []
      };
    });
    var rows = Array.prototype.map.call(table.querySelectorAll("tbody tr"), function (tr) {
      var head = tr.querySelector("th");
      var cells = tr.querySelectorAll("td");
      var v = chars.map(function (ch, c) {
        var td = cells[c];
        if (!td || td.hasAttribute("data-na")) return null;
        var out = [];
        td.textContent.split("/").forEach(function (s) {
          s = s.replace(/^\s+|\s+$/g, "");
          if (!s) return;
          var k = ch.states.indexOf(s);
          if (k < 0) { ch.states.push(s); k = ch.states.length - 1; }
          if (out.indexOf(k) < 0) out.push(k);
        });
        return out.length ? out : null;
      });
      var id = tr.getAttribute("data-taxon");
      var name = head ? head.textContent : id;
      if (!taxonName[id]) { taxonName[id] = name; taxa.push({ id: id, name: name }); }
      return { id: id, name: name, v: v };
    });
    mx = { chars: chars, taxa: rows };
    var whole = sec.querySelector("details.matrix-table");
    if (whole) whole.removeAttribute("open");
  })();

  function validPick(p) {
    if (!mx || !Array.isArray(p)) return null;
    var out = [], seen = {};
    for (var i = 0; i < p.length; i++) {
      var c = +p[i][0], s = +p[i][1];
      if (!mx.chars[c] || !mx.chars[c].states[s] || seen[c]) continue;
      seen[c] = true;
      out.push([c, s]);
    }
    return out;
  }

  // Taxa of the matrix that fit every state picked. A taxon with several
  // states fits any of them; an unknown fits all.
  function pickRemaining(p) {
    return mx.taxa.filter(function (t) {
      for (var i = 0; i < p.length; i++) {
        var v = t.v[p[i][0]];
        if (v && v.indexOf(p[i][1]) < 0) return false;
      }
      return true;
    });
  }

  // ---- state ----------------------------------------------------------------

  // Where the reader is. The page keeps this itself and does not depend on
  // the address bar: in a preview pane or an embedded frame a "#..." link
  // often goes nowhere, and the key must still work there.
  //
  // `stack` holds one entry per step taken; Back removes the last one. An
  // entry is { o, s, g, p }:
  //   o  the open set: the couplets still to answer and the results reached.
  //      One id for a reader who answered every couplet; several after
  //      "I'm not sure", which follows all leads of a couplet at once.
  //   s  the step that led here: { c, l } lead number l of couplet c chosen,
  //      { c, u } not sure at couplet c, { t } one result picked from several,
  //      { j } a jump (the trail starts again), { v } only the view changed.
  //   g  a glossary anchor, while the glossary is shown.
  //   p  the states picked in the character list, [[character, state], ...],
  //      while that view is shown.
  // The address carries the last entry ("#c-3", "#open=c-3,c-9,t-2",
  // "#pick=0.1,4.0"), so a reload or a shared link comes back to the same
  // place; the whole stack travels in history.state, so the browser's Back and
  // Forward undo and redo one step with the trail intact.
  var stack = [];
  var replaceNext = false;
  var lastPick = [];

  function top() { return stack[stack.length - 1]; }
  // The states picked in the character list, or null when an entry is a step of the key
  function picksOf(st) { return !mx ? null : st.p || (hasKey ? null : []); }
  function baseEntry() { return hasKey ? { o: [root] } : { o: [], p: [] }; }

  function readHash() {
    try { return decodeURIComponent(location.hash.slice(1)); } catch (e) { return ""; }
  }

  // The section an anchor belongs to: itself, the glossary for a glossary
  // entry, or null when the page has no such anchor.
  function sectionOf(anchor) {
    if (byId[anchor]) return anchor;
    var e = anchor && doc.getElementById(anchor);
    if (e && e.closest && e.closest(".glossary")) return "glossary";
    return null;
  }

  // The section an entry shows
  function shown(st) {
    if (st.g) return "glossary";
    if (st.p || !hasKey) return "matrix";
    for (var i = 0; i < st.o.length; i++) if (isCouplet(st.o[i])) return st.o[i];
    if (st.o.length === 1) return st.o[0];
    return st.o.length ? CAND : root;
  }
  function currentId() { return shown(top()); }

  function hashOf(st) {
    if (st.g) return st.g;
    if (st.p || !hasKey) {
      var p = st.p || [];
      return p.length ? "pick=" + p.map(function (x) { return x[0] + "." + x[1]; }).join(",") : "pick";
    }
    return st.o.length === 1 ? st.o[0] : "open=" + st.o.join(",");
  }
  function enc(h) { return encodeURIComponent(h).replace(/%3D/g, "=").replace(/%2C/g, ","); }

  function cleanOpen(ids) {
    var out = [];
    (Array.isArray(ids) ? ids : []).forEach(function (id) {
      if ((isCouplet(id) || isTaxon(id)) && sectionOf(id) === id && out.indexOf(id) < 0 && id !== "matrix") out.push(id);
    });
    return out;
  }

  // An entry from an address typed, shared or reloaded; null if it is not ours.
  function parseHash(h) {
    var open = stack.length ? top().o.slice() : baseEntry().o;
    if (!h) return null;
    if (h.indexOf("open=") === 0) {
      var ids = cleanOpen(h.slice(5).split(","));
      return ids.length ? { o: ids } : null;
    }
    if (h === "pick" || h === "matrix" || h.indexOf("pick=") === 0) {
      if (!mx) return null;
      var pairs = h.indexOf("pick=") === 0 ? h.slice(5).split(",").map(function (x) { return x.split("."); }) : [];
      return { o: open, p: validPick(pairs) };
    }
    if (isCouplet(h) || isTaxon(h)) return { o: [h] };
    if (sectionOf(h) === "glossary") return { o: open, g: h };
    return null;
  }

  // A stack kept in history.state, checked before it is trusted
  function validStack(s) {
    if (!Array.isArray(s) || !s.length) return null;
    var out = [];
    for (var k = 0; k < s.length; k++) {
      var e = s[k];
      if (!e || !Array.isArray(e.o)) return null;
      var o = cleanOpen(e.o);
      if (o.length !== e.o.length || (hasKey && !o.length)) return null;
      var entry = { o: o };
      if (e.s && typeof e.s === "object") {
        entry.s = {};
        if (e.s.c != null) {
          if (!isCouplet(e.s.c)) return null;
          entry.s.c = e.s.c;
          if (e.s.u) entry.s.u = 1;
          else if (kids[e.s.c][+e.s.l] != null) entry.s.l = +e.s.l;
          else return null;
        } else if (e.s.t != null) {
          if (!isTaxon(e.s.t)) return null;
          entry.s.t = e.s.t;
        } else if (e.s.j) entry.s.j = 1;
        else entry.s.v = 1;
      }
      if (e.g != null) {
        if (sectionOf(e.g) !== "glossary") return null;
        entry.g = String(e.g);
      }
      if (e.p != null) {
        entry.p = validPick(e.p);
        if (!entry.p) return null;
      }
      out.push(entry);
    }
    return out;
  }

  // Record the top of the stack in the address and the history, then show it
  function commit() {
    var replace = replaceNext;
    replaceNext = false;
    try {
      history[replace ? "replaceState" : "pushState"]({ dimoose: { stack: stack.slice() } }, "", "#" + enc(hashOf(top())));
    } catch (e) { /* no history here (sandboxed frame): the page still moves */ }
    update(true);
  }
  function push(entry) { stack.push(entry); commit(); }
  function truncate(k) { stack = stack.slice(0, k + 1); commit(); }

  // `open` with couplet `c` replaced by where its leads go
  function replaceIn(open, c, tos) {
    var out = [];
    open.forEach(function (x) {
      (x === c ? tos : [x]).forEach(function (y) { if (out.indexOf(y) < 0) out.push(y); });
    });
    return out;
  }

  // Lead number i of open couplet c is chosen
  function choose(c, i) {
    push({ o: replaceIn(top().o, c, [kids[c][i]]), s: { c: c, l: i } });
  }

  // Not sure at open couplet c: follow all of its leads
  function unsure(c) {
    var st = top();
    if (st.g || st.p || st.o.indexOf(c) < 0 || !kids[c] || kids[c].length < 2) return false;
    push({ o: replaceIn(st.o, c, kids[c]), s: { c: c, u: 1 } });
    return true;
  }

  // Among several open couplets, answer this one next. Not a step: nothing
  // has been decided, so Back does not stop here.
  function focusOn(id) {
    var st = top();
    stack[stack.length - 1] = { o: [id].concat(st.o.filter(function (x) { return x !== id; })), s: st.s };
    replaceNext = true;
    commit();
  }

  // Go to an anchor of this page. Returns false if it is not one of ours.
  function jump(anchor) {
    var sec = sectionOf(anchor);
    if (!sec || sec === CAND) return false;
    var st = top(), k, i, j;
    if (sec === "glossary") {
      push({ o: st.o.slice(), g: anchor, s: { v: 1 } });
      return true;
    }
    if (sec === "matrix") {
      if (!mx) return false;
      for (k = 0; k < stack.length; k++) {
        if (stack[k].p && !stack[k].p.length && !stack[k].g) {
          if (k < stack.length - 1) truncate(k);
          return true;
        }
      }
      push({ o: st.o.slice(), p: [], s: { v: 1 } });
      return true;
    }
    // a place already passed: go back to it
    for (k = stack.length - 1; k >= 0; k--) {
      var e = stack[k];
      if (!e.g && !e.p && e.o.length === 1 && e.o[0] === sec) {
        if (k < stack.length - 1) truncate(k);
        else if (replaceNext) { replaceNext = false; update(true); }
        return true;
      }
    }
    if (!st.g && !st.p) {
      // the next step from an open couplet (e.g. clicked on the map)
      for (i = 0; i < st.o.length; i++) {
        j = isCouplet(st.o[i]) ? kids[st.o[i]].indexOf(sec) : -1;
        if (j >= 0) { choose(st.o[i], j); return true; }
      }
      if (st.o.length > 1 && st.o.indexOf(sec) >= 0) {
        if (isTaxon(sec)) push({ o: [sec], s: { t: sec } });
        else focusOn(sec);
        return true;
      }
    }
    push({ o: [sec], s: { j: 1 } });   // somewhere unrelated: a new trail
    return true;
  }

  function settle(anchor) {
    if (!body.classList.contains("wizard")) {   // the full key: jump to the place
      var e = doc.getElementById(anchor);
      if (e && e.scrollIntoView) e.scrollIntoView();
    }
  }

  function go(anchor) {
    if (!jump(anchor)) return false;
    settle(anchor);
    return true;
  }

  // ---- what is still possible -------------------------------------------------

  // From an entry: `left` the results still possible, `ahead` every section
  // on the way to them.
  // Taxa the reader narrowed the key to (window.dimoose.narrow, "Narrow the
  // key" after a photo), or null. It is a hint laid over the key, not a step:
  // the leads that reach none of these taxa are greyed and the map and the
  // count show the rest, but every lead still works and Back ignores it.
  var narrowed = null;

  function narrowTo(st, poss) {
    if (!narrowed) return poss;
    var left = {}, n = 0, reach = {}, ahead = {};
    Object.keys(poss.left).forEach(function (id) { if (narrowed[id]) { left[id] = true; n++; } });
    if (!n) return poss;   // the reader has left those taxa behind: show what is really ahead
    function can(id) {
      if (isTaxon(id)) return !!left[id];
      if (id in reach) return reach[id];
      reach[id] = false;
      var any = false;
      (kids[id] || []).forEach(function (k) { if (can(k)) any = true; });
      reach[id] = any;
      return any;
    }
    Object.keys(poss.ahead).forEach(function (id) { if (can(id)) ahead[id] = true; });
    return { left: left, ahead: ahead, narrowed: true };
  }

  function possible(st) {
    var left = {}, ahead = {}, queue = [], p = picksOf(st);
    if (p) {
      // character list: the matching taxa, and the way to each through the key
      pickRemaining(p).forEach(function (t) {
        if (!isTaxon(t.id)) return;
        left[t.id] = true;
        for (var id = t.id, guard = 0; id && !ahead[id] && guard++ < 10000; id = parentOf[id]) ahead[id] = true;
      });
      return { left: left, ahead: ahead };
    }
    st.o.forEach(function (id) {
      ahead[id] = true;
      if (isTaxon(id)) left[id] = true; else queue.push(id);
    });
    while (queue.length) {
      (kids[queue.pop()] || []).forEach(function (id) {
        if (isTaxon(id)) { left[id] = true; ahead[id] = true; }
        else if (!ahead[id]) { ahead[id] = true; queue.push(id); }
      });
    }
    return narrowTo(st, { left: left, ahead: ahead });
  }

  function countText(st, n) {
    var p = picksOf(st);
    if (p) return pickRemaining(p).length + " of " + mx.taxa.length + " taxa match";
    if (st.o.length === 1 && isTaxon(st.o[0])) return "Identified · 1 of " + totalTaxa + " taxa";
    return n + " of " + totalTaxa + " taxa still possible" + (narrowed && n <= Object.keys(narrowed).length ? " (narrowed)" : "");
  }

  // The note above the key while it is narrowed, and the greyed leads
  var narrowEl = null;
  function renderNarrow(st, id, poss) {
    Array.prototype.forEach.call(doc.querySelectorAll("main li.lead.unlikely"), function (li) { mark(li, "unlikely", false); });
    var on = !!narrowed && !st.g && !picksOf(st);
    if (!narrowEl) {
      if (!on) return;
      narrowEl = el("div", "narrow");
      narrowEl.id = "mk-narrow";
      narrowEl.appendChild(el("p", "narrow-status"));
      var b = el("button", "narrow-clear", "Show all taxa");
      b.type = "button";
      narrowEl.appendChild(b);
      addTop(narrowEl, 2);
    }
    narrowEl.hidden = !on;
    if (!on) return;
    var n = Object.keys(narrowed).length;
    narrowEl.firstChild.textContent = poss.narrowed
      ? "Narrowed to " + n + (n === 1 ? " taxon" : " taxa") + ". Leads that reach none of them are greyed; they still work, and the key decides."
      : "Your answers lead away from the " + n + (n === 1 ? " taxon" : " taxa") + " the key was narrowed to.";
    if (poss.narrowed && isCouplet(id)) {
      Array.prototype.forEach.call(leadLinks(id), function (a, i) {
        if (!poss.ahead[kids[id][i]]) mark(a.closest("li"), "unlikely", true);
      });
    }
  }

  function setNarrow(ids) {
    var set = {}, n = 0;
    (ids || []).forEach(function (x) {
      var id = taxonIdOf(x);
      if (id && isTaxon(id) && !set[id]) { set[id] = true; n++; }
    });
    narrowed = n ? set : null;
    // from a place that cannot reach them, start again at the first couplet
    var st = top();
    if (narrowed && hasKey && !st.g && !picksOf(st) && (!possible(st).narrowed || !isCouplet(shown(st)))) {
      if (!jump(root)) update(false);
    } else {
      update(false);
    }
    return narrowed ? Object.keys(narrowed) : [];
  }

  // Steps since the trail last started: [{ k, s }]
  function trailSteps() {
    var start = 0, k, out = [];
    for (k = 0; k < stack.length; k++) if (stack[k].s && stack[k].s.j) start = k;
    for (k = start + 1; k < stack.length; k++) {
      var s = stack[k].s;
      if (s && !s.v && !s.j) out.push({ k: k, s: s });
    }
    return out;
  }

  function renderTrail() {
    trailEl.innerHTML = "";
    trailSteps().forEach(function (step) {
      var s = step.s, label, text;
      if (s.t) {
        label = "→";
        text = taxonName[s.t];
      } else if (s.u) {
        label = "?";
        text = coupletName(s.c) + ": not sure";
      } else {
        var a0 = leadLinks(s.c)[s.l];
        if (!a0) return;
        label = a0.getAttribute("data-lead");
        text = a0.querySelector(".text").textContent;
      }
      var li = el("li", s.u ? "unsure" : "");
      var a = el("a");
      a.href = "#" + enc(hashOf(stack[step.k - 1]));
      a.setAttribute("data-step", step.k - 1);
      a.title = "Go back to this choice: " + label + " " + text;
      a.appendChild(el("b", "", label));
      a.appendChild(doc.createTextNode(text));
      li.appendChild(a);
      trailEl.appendChild(li);
    });
    trailEl.scrollLeft = trailEl.scrollWidth; // keep the latest choice in view on narrow screens
  }

  function centerMap(id) {
    if (!mapScroll || !mapScroll.clientHeight) return; // hidden
    var n = mapSvg.querySelector('.mnode[data-id="' + id + '"]');
    if (!n) return;
    var x = +n.getAttribute("data-x"), y = +n.getAttribute("data-y");
    var opts = { left: x - mapScroll.clientWidth / 2, top: y - mapScroll.clientHeight / 2 };
    if (smooth) opts.behavior = "smooth";
    mapScroll.scrollTo(opts);
  }

  function renderMap(st, id, poss) {
    if (mapLeft) mapLeft.textContent = countText(st, Object.keys(poss.left).length);
    if (!mapSvg) return;
    mapSvg.classList.add("live");
    var onTrail = {}, steps = {}, open = {};
    trailSteps().forEach(function (step) {
      var s = step.s;
      if (!s.c) return;
      onTrail[s.c] = true;
      (s.u ? kids[s.c] : [kids[s.c][s.l]]).forEach(function (to) { steps[s.c + ">" + to] = true; });
    });
    // Tab stops only at the place shown, the open branches and the next
    // steps, so the keyboard does not have to cross the whole map to reach
    // the leads; every node stays clickable.
    var stop = {};
    if (!picksOf(st)) {
      st.o.forEach(function (x) {
        open[x] = true;
        stop[x] = true;
        (kids[x] || []).forEach(function (k) { stop[k] = true; });
      });
    }
    mapNodes.forEach(function (n) {
      var nid = n.getAttribute("data-id");
      var here = nid === id;
      var tab = here || stop[nid] ? "0" : "-1";
      if (n.getAttribute("tabindex") !== tab) n.setAttribute("tabindex", tab);
      mark(n, "here", here);
      mark(n, "open", !here && !!open[nid]);
      mark(n, "done", !here && !open[nid] && !!onTrail[nid]);
      mark(n, "ahead", !!poss.ahead[nid]);
    });
    mapEdges.forEach(function (e) {
      var from = e.getAttribute("data-from"), to = e.getAttribute("data-to");
      mark(e, "done", !!steps[from + ">" + to]);
      mark(e, "ahead", !!poss.ahead[from] && !!poss.ahead[to]);
    });
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
      var extra = a.querySelector(".note");
      path.unshift({ from: from.id, lead: a.getAttribute("data-lead"), text: a.querySelector(".text").textContent,
                     note: extra });
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
      if (st.note) li.appendChild(st.note.cloneNode(true));
      ol.appendChild(li);
    });
    ol.setAttribute("data-done", "1");
  }

  // ---- "I'm not sure" -----------------------------------------------------------

  // The button is added when a couplet is first shown, so the plain document
  // (and a key of thousands of couplets) does not carry one per couplet.
  function addUnsure(section) {
    if (section.querySelector(".unsure") || !kids[section.id] || kids[section.id].length < 2) return;
    var p = el("p", "unsure");
    var b = el("button", "unsure-btn", "I’m not sure");
    b.type = "button";
    b.appendChild(el("span", "", kids[section.id].length === 2 ? " \u2013 follow both leads" : " \u2013 follow all " + kids[section.id].length + " leads"));
    p.appendChild(b);
    section.appendChild(p);
  }

  // The branches being followed, above the couplet shown
  var openEl = null, openStatus = null, openList = null;
  function renderOpen(st, id, poss) {
    var on = !st.g && !st.p && st.o.length > 1 && id !== CAND;
    if (!openEl) {
      if (!on) return;
      openEl = el("div", "open");
      openEl.id = "mk-open";
      openStatus = el("p", "open-status");
      openStatus.setAttribute("role", "status");
      openList = el("ul", "open-list");
      openList.setAttribute("aria-label", "Branches you are following");
      openEl.appendChild(openStatus);
      openEl.appendChild(openList);
      addTop(openEl, 4);
    }
    openEl.hidden = !on;
    if (!on) { openStatus.textContent = ""; return; }
    var nq = st.o.filter(isCouplet).length;
    openStatus.textContent = "Not sure: following " + st.o.length + " branches, " + nq +
      (nq === 1 ? " question" : " questions") + " still open · " + countText(st, Object.keys(poss.left).length);
    openList.innerHTML = "";
    st.o.forEach(function (x) {
      var li = el("li"), item;
      if (isCouplet(x)) {
        item = el("button", "", coupletName(x));
        item.type = "button";
        item.setAttribute("data-focus", x);
        item.setAttribute("aria-pressed", x === id ? "true" : "false");
        item.title = x === id ? "The question shown now" : "Answer this one next";
      } else {
        item = el("a", "", taxonName[x]);
        item.href = "#" + x;
        item.title = "A possible result: " + taxonName[x];
        li.setAttribute("data-taxon", x);
      }
      li.appendChild(item);
      openList.appendChild(li);
    });
  }

  // Several results left and no couplet to answer: show them all
  var candEl = null;
  function renderCandidates(st) {
    if (!candEl) {
      candEl = el("section", "candidates");
      candEl.id = CAND;
      candEl.setAttribute("aria-labelledby", "h-" + CAND);
      candEl.appendChild(el("p", "eyebrow", "Not sure"));
      var h = el("h2", "", "It could be one of these");
      h.id = "h-" + CAND;
      h.tabIndex = -1;
      candEl.appendChild(h);
      candEl.appendChild(el("p", "cand-note"));
      candEl.appendChild(el("ul", "cand-list"));
      var actions = el("p", "actions");
      var again = el("a", "", "Identify another specimen");
      again.href = "#" + root;
      actions.appendChild(again);
      candEl.appendChild(actions);
      mainEl.appendChild(candEl);
      sections.push(candEl);
      byId[CAND] = candEl;
    }
    var n = 0;
    trailSteps().forEach(function (step) { if (step.s.u) n++; });
    candEl.querySelector(".cand-note").textContent = st.o.length + " of " + totalTaxa + " taxa fit your answers" +
      (n ? ". You were not sure at " + n + (n === 1 ? " couplet" : " couplets") +
        ", so the key cannot narrow it further. Open each one to compare, or go back and answer a couplet." : ".");
    var list = candEl.querySelector(".cand-list");
    list.innerHTML = "";
    st.o.forEach(function (x) {
      var li = el("li");
      li.setAttribute("data-taxon", x);
      var a = el("a", "", taxonName[x]);
      a.href = "#" + x;
      li.appendChild(a);
      list.appendChild(li);
    });
  }

  // ---- character list -------------------------------------------------------------

  var pick = null;
  function buildPick() {
    var sec = byId.matrix;
    pick = { box: el("div", "pick") };
    pick.status = el("p", "pick-status");
    pick.status.setAttribute("role", "status");
    pick.chosen = el("ul", "pick-chosen");
    pick.chosen.setAttribute("aria-label", "States you picked");
    pick.cont = el("p", "pick-continue");
    pick.charsHead = el("h3");
    pick.chars = el("ul", "pick-chars");
    pick.rest = el("details", "pick-rest");
    pick.restSummary = el("summary");
    pick.restList = el("ul", "pick-chars");
    pick.rest.appendChild(pick.restSummary);
    pick.rest.appendChild(pick.restList);
    pick.taxaHead = el("h3");
    pick.taxa = el("ul", "pick-taxa");
    [pick.status, pick.chosen, pick.cont, pick.charsHead, pick.chars, pick.rest, pick.taxaHead, pick.taxa]
      .forEach(function (e) { pick.box.appendChild(e); });
    var h = sec.querySelector("h2");
    sec.insertBefore(pick.box, h ? h.nextSibling : sec.firstChild);
  }

  // The deepest couplet all of these results lie under
  function commonCouplet(ids) {
    var chain = [], id, guard = 0, k;
    for (id = parentOf[ids[0]]; id && guard++ < 10000; id = parentOf[id]) chain.push(id);
    for (k = 1; k < ids.length && chain.length; k++) {
      var set = {};
      for (id = parentOf[ids[k]], guard = 0; id && guard++ < 10000; id = parentOf[id]) set[id] = true;
      chain = chain.filter(function (c) { return set[c]; });
    }
    return chain.length ? chain[0] : null;
  }

  function charItem(c, counts, n) {
    var ch = mx.chars[c];
    var li = el("li", "pick-char");
    var group = el("div");
    group.setAttribute("role", "group");
    group.setAttribute("aria-label", ch.name);
    group.appendChild(el("span", "pick-name", ch.name));
    var meta = [];
    if (ch.needs) meta.push("needs " + ch.needs);
    if (ch.season) meta.push(ch.season);
    if (meta.length) group.appendChild(el("span", "pick-meta", meta.join(" · ")));
    var states = el("span", "pick-states");
    ch.states.forEach(function (name, s) {
      var b = el("button", "pick-state", name);
      b.type = "button";
      b.setAttribute("data-char", c);
      b.setAttribute("data-state", s);
      b.setAttribute("aria-label", ch.name + ": " + name + ", " + counts[s] + " of " + n + " remaining taxa");
      b.appendChild(el("span", "n", String(counts[s])));
      if (!counts[s]) b.disabled = true;
      states.appendChild(b);
    });
    group.appendChild(states);
    li.appendChild(group);
    return li;
  }

  function renderPick(st) {
    if (!pick) buildPick();
    var p = st.p || [];
    lastPick = p;
    var left = pickRemaining(p);
    var n = left.length, total = mx.taxa.length;
    pick.status.textContent = n === 0 ? "No taxon has all of these states. Take one of them back."
      : n === 1 ? "One taxon matches: " + left[0].name
      : n + " of " + total + " taxa match";

    pick.chosen.innerHTML = "";
    p.forEach(function (x) {
      var li = el("li");
      var b = el("button", "pick-remove", mx.chars[x[0]].name + ": " + mx.chars[x[0]].states[x[1]]);
      b.type = "button";
      b.setAttribute("data-char", x[0]);
      b.setAttribute("aria-label", "Remove " + b.textContent);
      b.appendChild(el("span", "x", "×"));
      li.appendChild(b);
      pick.chosen.appendChild(li);
    });
    if (p.length > 1) {
      var li = el("li");
      var clear = el("button", "pick-clear", "Clear all");
      clear.type = "button";
      li.appendChild(clear);
      pick.chosen.appendChild(li);
    }
    pick.chosen.hidden = !p.length;

    // back into the key, at the couplet all remaining taxa share
    pick.cont.innerHTML = "";
    var inKey = left.filter(function (t) { return isTaxon(t.id); }).map(function (t) { return t.id; });
    var at = hasKey && p.length && inKey.length > 1 && inKey.length === n ? commonCouplet(inKey) : null;
    if (at && at !== root) {
      var a = el("a", "", "Continue step by step from " + coupletName(at));
      a.href = "#" + at;
      pick.cont.appendChild(a);
    }
    pick.cont.hidden = !pick.cont.firstChild;

    // Characters not yet answered: those that still split the remaining taxa
    // first, cheapest first, then the ones that leave fewest taxa on average.
    var used = {}, useful = [], rest = [];
    p.forEach(function (x) { used[x[0]] = true; });
    mx.chars.forEach(function (ch, c) {
      if (used[c]) return;
      var counts = ch.states.map(function () { return 0; });
      left.forEach(function (t) {
        var v = t.v[c];
        if (v) v.forEach(function (s) { counts[s]++; });
        else counts.forEach(function (x, s) { counts[s]++; });
      });
      var splits = false, sum = 0, sq = 0;
      counts.forEach(function (k) {
        if (k > 0 && k < n) splits = true;
        sum += k;
        sq += k * k;
      });
      (splits ? useful : rest).push({ c: c, counts: counts, cost: ch.cost === null ? Infinity : ch.cost, expect: sum ? sq / sum : n });
    });
    useful.sort(function (a, b) {
      if (a.cost !== b.cost) return a.cost < b.cost ? -1 : 1;
      return (a.expect - b.expect) || (a.c - b.c);
    });
    pick.charsHead.textContent = n < 2 ? "" : !useful.length ? "No character here separates the remaining taxa"
      : p.length ? "Most useful next" : "Pick any character you can see";
    pick.charsHead.hidden = !pick.charsHead.textContent;
    pick.chars.innerHTML = "";
    if (n > 1) useful.forEach(function (u) { pick.chars.appendChild(charItem(u.c, u.counts, n)); });
    pick.restList.innerHTML = "";
    rest.forEach(function (u) { pick.restList.appendChild(charItem(u.c, u.counts, n)); });
    pick.restSummary.textContent = rest.length + (rest.length === 1 ? " character that does" : " characters that do") +
      " not separate the remaining taxa";
    pick.rest.hidden = !rest.length;

    pick.taxaHead.textContent = n === 1 ? "Result" : "Remaining taxa";
    pick.taxaHead.hidden = !n;
    pick.taxa.innerHTML = "";
    left.forEach(function (t) {
      var li = el("li");
      li.setAttribute("data-taxon", t.id);
      if (isTaxon(t.id)) {
        var a = el("a", "", t.name);
        a.href = "#" + t.id;
        li.appendChild(a);
      } else {
        li.appendChild(el("span", "", t.name));
      }
      pick.taxa.appendChild(li);
    });
  }

  function setPick(p) {
    var st = top();
    push({ o: st.o.slice(), p: p, s: { v: 1 } });
  }

  // ---- hook for other scripts: window.dimoose -------------------------------------
  //
  // A later script (e.g. one that scores a photo in the browser) can mark the
  // taxa it finds likely and send the reader to one, without knowing how this
  // page is built:
  //   dimoose.taxa                      [{ id, name }] every result of the page
  //   dimoose.highlight(scores, opts)   scores: { "<name or id>": number } or
  //                                     [{ taxon, score }]; null clears. Marks
  //                                     the taxa on the map and in every list
  //                                     of candidates, and lists the best ones
  //                                     above the key under opts.label.
  //                                     Returns the ids marked, best first.
  //   dimoose.goToTaxon(nameOrId)       shows that result; false if unknown
  //   dimoose.narrow(namesOrIds)        restricts the taxa counted as still
  //                                     possible to these and greys the leads
  //                                     that reach none of them; null undoes
  //                                     it. Returns the ids it kept.
  //   dimoose.state()                   { shown, open, remaining, picks, narrowed }
  //   dimoose.onChange(fn)              fn(state) after every step
  var likely = [];       // [{ id, score }] best first
  var likelyLabel = "Suggested";
  var likelyEl = null;
  var listeners = [];

  function taxonIdOf(x) {
    if (x == null) return null;
    x = String(x);
    if (taxonName[x]) return x;
    var want = x.replace(/^\s+|\s+$/g, "").toLowerCase(), i;
    for (i = 0; i < taxa.length; i++) if (taxa[i].name === x) return taxa[i].id;
    for (i = 0; i < taxa.length; i++) if (taxa[i].name.replace(/^\s+|\s+$/g, "").toLowerCase() === want) return taxa[i].id;
    return null;
  }

  function scoreText(v, percent) {
    return percent ? Math.round(v * 100) + "%" : String(Math.round(v * 100) / 100);
  }

  function applyHighlight() {
    var score = {}, percent = true;
    likely.forEach(function (x) {
      score[x.id] = x.score;
      if (!(x.score >= 0 && x.score <= 1)) percent = false;
    });
    var best = likely.length ? likely[0].id : null;
    mapNodes.forEach(function (n) {
      if (!n.classList.contains("mleaf")) return;
      var id = n.getAttribute("data-id");
      mark(n, "likely", id in score);
      mark(n, "best", id === best);
      if (id in score) n.setAttribute("data-score", score[id]); else n.removeAttribute("data-score");
    });
    Array.prototype.forEach.call(doc.querySelectorAll("main li[data-taxon]"), function (li) {
      var id = li.getAttribute("data-taxon");
      var old = li.querySelector(".score");
      if (old) li.removeChild(old);
      mark(li, "likely", id in score);
      mark(li, "best", id === best);
      if (id in score) li.appendChild(el("span", "score", scoreText(score[id], percent)));
    });
    if (!likelyEl) {
      if (!likely.length) return;
      likelyEl = el("div", "likely");
      likelyEl.id = "mk-likely";
      likelyEl.setAttribute("role", "status");
      addTop(likelyEl, 3);
    }
    likelyEl.innerHTML = "";
    likelyEl.hidden = !likely.length;
    if (!likely.length) return;
    likelyEl.appendChild(el("span", "eyebrow", likelyLabel));
    var ul = el("ul");
    likely.slice(0, 5).forEach(function (x) {
      var li = el("li", x.id === best ? "best" : "");
      var item = isTaxon(x.id) ? el("a", "", taxonName[x.id]) : el("span", "", taxonName[x.id]);
      if (isTaxon(x.id)) item.href = "#" + x.id;
      li.appendChild(item);
      li.appendChild(el("span", "score", scoreText(x.score, percent)));
      ul.appendChild(li);
    });
    likelyEl.appendChild(ul);
  }

  function publicState() {
    var st = top(), p = picksOf(st);
    var out = {
      shown: currentId(),
      open: st.o.slice(),
      remaining: p ? pickRemaining(p).map(function (t) { return t.id; }) : Object.keys(possible(st).left),
      picks: (p || []).map(function (x) { return { character: mx.chars[x[0]].name, state: mx.chars[x[0]].states[x[1]] }; }),
      narrowed: narrowed ? Object.keys(narrowed) : null
    };
    return out;
  }

  win.dimoose = {
    version: 1,
    taxa: taxa,
    highlight: function (scores, opts) {
      var seen = {}, list = [];
      var add = function (key, value) {
        var id = taxonIdOf(key);
        value = +value;
        if (!id || seen[id] || isNaN(value)) return;
        seen[id] = true;
        list.push({ id: id, score: value });
      };
      if (Array.isArray(scores)) {
        scores.forEach(function (x) { if (x) add(x.taxon != null ? x.taxon : x.id != null ? x.id : x.name, x.score); });
      } else if (scores && typeof scores === "object") {
        Object.keys(scores).forEach(function (k) { add(k, scores[k]); });
      }
      list.sort(function (a, b) { return b.score - a.score; });
      likely = list;
      likelyLabel = opts && opts.label ? String(opts.label) : "Suggested";
      applyHighlight();
      return list.map(function (x) { return x.id; });
    },
    goToTaxon: function (x) {
      var id = taxonIdOf(x);
      return !!id && isTaxon(id) && go(id);
    },
    narrow: setNarrow,
    state: publicState,
    onChange: function (fn) { if (typeof fn === "function") listeners.push(fn); }
  };

  // ---- identify from a photo (optional) ---------------------------------------------
  //
  // exportWizard(photoModel = ) names a folder written by exportBrowserModel():
  // model.json, the text embeddings of the key's taxa and an image encoder
  // (ONNX). The reader picks or takes a photo; the page then loads
  // onnxruntime-web and the encoder (once, after saying how big they are),
  // prepares the picture as model.json says, runs the encoder here in the
  // browser and compares the result with the text embeddings. The photo never
  // leaves the device. The scores go to dimoose.highlight(); the reader can
  // jump to a result or narrow the key to the best ones and confirm with the
  // couplets. The key stays the authority: the photo is a hint.
  //
  // For other scripts and for tests, dimoose.photo has:
  //   identify(file)                 the whole run, without the question about
  //                                  the download; a promise of
  //                                  [{ taxon, id, score, similarity }], best first
  //   preprocess(rgba, w, h, spec)   Float32Array, 3 x size x size, as the
  //                                  `preprocess` entry of model.json says
  //   score(embedding, text, n, dim, scale)   softmax(scale x cosine) per row
  //   decode(file)                   promise of { data, width, height } (RGBA);
  //                                  may be replaced
  //   result()                       the last ranked list, or null
  //   state()                        "idle", "ask", "loading", "running",
  //                                  "done" or "error"
  var photo = null;

  // Python's round(): halves go to the even number
  function pyRound(x) {
    var r = Math.round(x);
    return Math.abs(x % 1) === 0.5 && r % 2 !== 0 ? r - 1 : r;
  }

  // The resampling filters of Pillow, which the models were trained and are
  // run with in R: [support, f(x)]
  var photoFilters = {
    bicubic: [2, function (x) {
      var a = -0.5;
      if (x < 0) x = -x;
      if (x < 1) return ((a + 2) * x - (a + 3)) * x * x + 1;
      if (x < 2) return (((x - 5) * x + 8) * x - 4) * a;
      return 0;
    }],
    bilinear: [1, function (x) {
      if (x < 0) x = -x;
      return x < 1 ? 1 - x : 0;
    }],
    lanczos: [3, function (x) {
      if (x === 0) return 1;
      if (x <= -3 || x >= 3) return 0;
      var p = Math.PI * x;
      return 3 * Math.sin(p) * Math.sin(p / 3) / (p * p);
    }]
  };

  // For `count` pixels of the resized axis, starting at `from`: the first
  // source pixel and the weights of the source pixels each one is made of.
  // Pixels outside the resized image get no weights. The arithmetic is
  // Pillow's, down to its whole-number weights (22 bits), so that the page
  // feeds the model the very values R does: the int8 encoders are touchy, and
  // a difference in the last bit of one input value moves the embedding.
  var PHOTO_ONE = 4194304;   // 1 << 22
  function photoWeights(inSize, outSize, from, count, filter) {
    var scale = inSize / outSize;
    var fscale = scale < 1 ? 1 : scale;
    var support = filter[0] * fscale, ss = 1 / fscale;
    var out = [];
    for (var i = 0; i < count; i++) {
      var xx = from + i;
      if (xx < 0 || xx >= outSize) { out.push({ min: 0, w: [] }); continue; }
      var center = (xx + 0.5) * scale;
      var xmin = Math.floor(center - support + 0.5);
      if (xmin < 0) xmin = 0;
      var xmax = Math.floor(center + support + 0.5);
      if (xmax > inSize) xmax = inSize;
      var w = [], sum = 0, x;
      for (x = 0; x < xmax - xmin; x++) {
        var v = filter[1]((x + xmin - center + 0.5) * ss);
        w.push(v);
        sum += v;
      }
      for (x = 0; x < w.length; x++) {
        if (sum !== 0) w[x] /= sum;
        v = w[x] * PHOTO_ONE + (w[x] < 0 ? -0.5 : 0.5);
        w[x] = v < 0 ? Math.ceil(v) : Math.floor(v);
      }
      out.push({ min: xmin, w: w });
    }
    return out;
  }
  // a weighted sum of whole-number weights, back to 0..255
  function photoByte(v) { v = Math.floor((v + PHOTO_ONE / 2) / PHOTO_ONE); return v < 0 ? 0 : v > 255 ? 255 : v; }

  // RGBA pixels -> the model's input. Resizes the shorter side to
  // `resize_to` with Pillow's filter, cuts the middle square, scales and
  // normalises, channel by channel (NCHW).
  function photoPreprocess(rgba, w, h, spec) {
    var S = +spec.image_size;
    var filter = photoFilters[spec.interpolation] || photoFilters.bicubic;
    var nw = w, nh = h, left = 0, top = 0;
    if ((spec.resize || "shortest") === "shortest") {
      var to = +(spec.resize_to || S);
      if (w <= h) { nw = to; nh = Math.floor(to * h / w); } else { nw = Math.floor(to * w / h); nh = to; }
    }
    if ((spec.crop || "center") === "center") {
      left = pyRound((nw - S) / 2);
      top = pyRound((nh - S) / 2);
    } else {
      nw = S;
      nh = S;
    }
    var cols = photoWeights(w, nw, left, S, filter);
    var rows = photoWeights(h, nh, top, S, filter);
    var y0 = h, y1 = 0, i, j, k, c;
    rows.forEach(function (r) {
      if (!r.w.length) return;
      if (r.min < y0) y0 = r.min;
      if (r.min + r.w.length > y1) y1 = r.min + r.w.length;
    });
    // across first, rounded to whole values as Pillow does, then down
    var same = nw === w, tall = y1 > y0 ? y1 - y0 : 0;
    var mid = new Uint8Array(tall * S * 3);
    for (j = 0; j < tall; j++) {
      var src = (y0 + j) * w * 4;
      for (i = 0; i < S; i++) {
        var col = cols[i], o = (j * S + i) * 3;
        if (!col.w.length) continue;
        if (same) {
          mid[o] = rgba[src + (left + i) * 4];
          mid[o + 1] = rgba[src + (left + i) * 4 + 1];
          mid[o + 2] = rgba[src + (left + i) * 4 + 2];
          continue;
        }
        var r = 0, g = 0, b = 0;
        for (k = 0; k < col.w.length; k++) {
          var q = src + (col.min + k) * 4, wt = col.w[k];
          r += rgba[q] * wt;
          g += rgba[q + 1] * wt;
          b += rgba[q + 2] * wt;
        }
        mid[o] = photoByte(r);
        mid[o + 1] = photoByte(g);
        mid[o + 2] = photoByte(b);
      }
    }
    var out = new Float32Array(3 * S * S);
    // in single precision step by step, as numpy does it
    var f32 = Math.fround || function (v) { return v; };
    var rescale = f32(spec.rescale == null ? 1 / 255 : +spec.rescale);
    var mean = (spec.mean || [0, 0, 0]).map(f32), std = (spec.std || [1, 1, 1]).map(f32);
    var sameH = nh === h, px = [0, 0, 0];
    for (j = 0; j < S; j++) {
      var row = rows[j];
      for (i = 0; i < S; i++) {
        px[0] = px[1] = px[2] = 0;
        if (row.w.length && cols[i].w.length) {
          if (sameH) {
            for (c = 0; c < 3; c++) px[c] = mid[((top + j - y0) * S + i) * 3 + c];
          } else {
            var acc = [0, 0, 0];
            for (k = 0; k < row.w.length; k++) {
              var m = ((row.min + k - y0) * S + i) * 3;
              acc[0] += mid[m] * row.w[k];
              acc[1] += mid[m + 1] * row.w[k];
              acc[2] += mid[m + 2] * row.w[k];
            }
            for (c = 0; c < 3; c++) px[c] = photoByte(acc[c]);
          }
        }
        for (c = 0; c < 3; c++) out[c * S * S + j * S + i] = f32(f32(px[c] * rescale) - mean[c]) / std[c];
      }
    }
    return out;
  }

  // softmax(scale x cosine similarity) of an image embedding with each of the
  // `n` rows of `text` (unit vectors of length `dim`)
  function photoScore(emb, text, n, dim, scale) {
    var norm = 0, i, j, sims = [], best = -Infinity, sum = 0;
    for (j = 0; j < dim; j++) norm += emb[j] * emb[j];
    norm = Math.sqrt(norm) || 1;
    for (i = 0; i < n; i++) {
      var dot = 0;
      for (j = 0; j < dim; j++) dot += emb[j] * text[i * dim + j];
      sims.push(dot / norm);
      if (sims[i] > best) best = sims[i];
    }
    var p = sims.map(function (s) { var e = Math.exp(scale * (s - best)); sum += e; return e; });
    return sims.map(function (s, k) { return { similarity: s, score: p[k] / sum }; });
  }

  (function () {
    var base = body.getAttribute("data-photo-model");
    if (!base) return;
    var runtime = body.getAttribute("data-photo-runtime") || "";
    var runtimeBytes = +body.getAttribute("data-photo-runtime-bytes") || 0;
    var kept = body.hasAttribute("data-sw");   // the service worker keeps what is fetched
    var LABEL = "From your photo";
    var state = "idle", manifestP = null, runtimeP = null, modelP = null;
    var file = null, thumbUrl = null, result = null, cands = [], message = "", progress = null;
    // model.json may give `min_similarity`: under it, the best match is said
    // to be unlike every taxon of the key, whatever its share of the softmax
    var minSim = 0;

    function problem(kind, text) {
      var e = new Error(text);
      e.kind = kind;
      return e;
    }
    function mb(bytes) { return bytes >= 1e6 ? Math.round(bytes / 1e6) + " MB" : Math.max(1, Math.round(bytes / 1e3)) + " kB"; }
    function get(url) {
      if (!win.fetch) return Promise.reject(problem("old", "no fetch"));
      return win.fetch(url).then(function (r) {
        if (!r.ok) throw problem("fetch", url + " (" + r.status + ")");
        return r;
      }, function (e) { throw problem("fetch", url + ": " + (e && e.message)); });
    }

    function manifest() {
      if (!manifestP) {
        manifestP = get(base + "model.json").then(function (r) { return r.json(); }).then(function (m) {
          if (!m || m.format !== "dimoose-browser-model" || !m.labels || !m.preprocess || !m.text_embeddings || !m.image_encoder) {
            throw problem("model", "model.json is not a model written by exportBrowserModel()");
          }
          return m;
        });
        manifestP["catch"](function () { manifestP = null; });
      }
      return manifestP;
    }
    function encoderUrl(m) { return m.image_encoder.url || base + (m.image_encoder.file || "image_encoder.onnx"); }

    // Whether the encoder is already on this device (kept by the service worker)
    function stored(url) {
      try {
        if (!kept || !win.caches) return Promise.resolve(false);
        return win.caches.match(url).then(function (hit) { return !!hit; }, function () { return false; });
      } catch (e) { return Promise.resolve(false); }
    }

    function loadRuntime() {
      if (win.ort && win.ort.InferenceSession) return Promise.resolve(win.ort);
      if (typeof win.WebAssembly !== "object") return Promise.reject(problem("wasm", "no WebAssembly"));
      if (!runtimeP) {
        runtimeP = new Promise(function (resolve, reject) {
          var s = doc.createElement("script");
          s.src = runtime + "ort.wasm.min.js";
          s.crossOrigin = "anonymous";
          s.onload = function () {
            if (!win.ort || !win.ort.InferenceSession) { reject(problem("fetch", "onnxruntime-web did not start")); return; }
            try {
              win.ort.env.wasm.wasmPaths = runtime;
              // more than one thread needs a cross-origin isolated page
              win.ort.env.wasm.numThreads = win.crossOriginIsolated ? Math.min(4, win.navigator.hardwareConcurrency || 1) : 1;
            } catch (e) { /* defaults */ }
            resolve(win.ort);
          };
          s.onerror = function () { reject(problem("fetch", s.src)); };
          doc.head.appendChild(s);
        });
        runtimeP["catch"](function () { runtimeP = null; });
      }
      return runtimeP;
    }

    // A large file, with its progress. `expected` (from model.json) sizes the
    // buffer, so the file is held once and not twice.
    function getBytes(url, expected, onProgress) {
      return get(url).then(function (r) {
        if (!r.body || !r.body.getReader) {
          return r.arrayBuffer().then(function (b) { return new Uint8Array(b); });
        }
        var reader = r.body.getReader();
        var buf = new Uint8Array(expected || 1 << 20), got = 0;
        function pump() {
          return reader.read().then(function (x) {
            if (x.done) return got === buf.length ? buf : buf.subarray(0, got);
            if (got + x.value.length > buf.length) {
              var bigger = new Uint8Array(Math.max(buf.length * 2, got + x.value.length));
              bigger.set(buf.subarray(0, got));
              buf = bigger;
            }
            buf.set(x.value, got);
            got += x.value.length;
            if (onProgress) onProgress(got, expected || 0);
            return pump();
          }, function (e) { throw problem("fetch", url + ": " + (e && e.message)); });
        }
        return pump();
      });
    }

    // The model, ready to run: { m, text, session }
    function model() {
      if (!modelP) {
        modelP = manifest().then(function (m) {
          var te = m.text_embeddings, n = +te.shape[0], dim = +te.shape[1];
          return loadRuntime().then(function () {
            return get(base + (te.file || "text_embeddings.bin"));
          }).then(function (r) { return r.arrayBuffer(); }).then(function (b) {
            var text = new Float32Array(b);
            if (text.length !== n * dim || m.labels.length !== n) throw problem("model", "the text embeddings do not have the size model.json gives");
            setState("loading", "Downloading the model", { got: 0, total: +m.image_encoder.bytes || 0 });
            return getBytes(encoderUrl(m), +m.image_encoder.bytes || 0, function (got, total) {
              progress = { got: got, total: total };
              render();
            }).then(function (bytes) {
              setState("loading", "Starting the model", null);
              return win.ort.InferenceSession.create(bytes, { executionProviders: ["wasm"] });
            }).then(function (session) {
              return { m: m, text: text, n: n, dim: dim, session: session };
            });
          });
        });
        modelP["catch"](function () { modelP = null; });
      }
      return modelP;
    }

    function decode(f) {
      var limit = 16e6;   // pixels: more than this fails on some phones
      function draw(src, w, h) {
        if (!w || !h) throw problem("image", "empty picture");
        var k = w * h > limit ? Math.sqrt(limit / (w * h)) : 1;
        var canvas = doc.createElement("canvas");
        canvas.width = Math.max(1, Math.floor(w * k));
        canvas.height = Math.max(1, Math.floor(h * k));
        var ctx = canvas.getContext("2d", { willReadFrequently: true });
        if (!ctx) throw problem("memory", "no canvas");
        ctx.drawImage(src, 0, 0, canvas.width, canvas.height);
        var d = ctx.getImageData(0, 0, canvas.width, canvas.height);
        var out = { data: d.data, width: canvas.width, height: canvas.height };
        canvas.width = canvas.height = 0;
        return out;
      }
      if (win.createImageBitmap) {
        return win.createImageBitmap(f).then(function (bmp) {
          var out = draw(bmp, bmp.width, bmp.height);
          if (bmp.close) bmp.close();
          return out;
        }, function () { throw problem("image", "not a picture"); });
      }
      return new Promise(function (resolve, reject) {
        var img = new win.Image(), url = win.URL.createObjectURL(f);
        img.onload = function () {
          try { resolve(draw(img, img.naturalWidth, img.naturalHeight)); } catch (e) { reject(e); }
          win.URL.revokeObjectURL(url);
        };
        img.onerror = function () { win.URL.revokeObjectURL(url); reject(problem("image", "not a picture")); };
        img.src = url;
      });
    }

    // The whole run for one photo; resolves to the ranked labels
    function identify(f) {
      file = f;
      result = null;
      return model().then(function (md) {
        setState("running", "Looking at the photo", null);
        return api.decode(f).then(function (px) {
          var spec = md.m.preprocess, S = +spec.image_size;
          var x = photoPreprocess(px.data, px.width, px.height, spec);
          px = null;
          var feeds = {};
          feeds[md.m.image_encoder.input || "pixel_values"] = new win.ort.Tensor("float32", x, [1, 3, S, S]);
          return md.session.run(feeds);
        }).then(function (out) {
          var t = out[md.m.image_encoder.output] || out[Object.keys(out)[0]];
          var scores = photoScore(t.data, md.text, md.n, md.dim, +md.m.logit_scale || 100);
          minSim = +md.m.min_similarity || 0;
          var list = md.m.labels.map(function (lab, i) {
            return { taxon: lab.taxon, id: taxonIdOf(lab.taxon), score: scores[i].score, similarity: scores[i].similarity };
          });
          list.sort(function (a, b) { return b.score - a.score; });
          return list;
        });
      }).then(function (list) {
        result = list;
        // the candidates: the five best, without those under 1%. They are
        // marked and listed, and are what the key can be narrowed to.
        var best = list.filter(function (x) { return x.id; }).slice(0, 5).filter(function (x, i) { return i === 0 || x.score >= 0.01; });
        win.dimoose.highlight(best.map(function (x) { return { taxon: x.id, score: x.score }; }), { label: LABEL });
        cands = best.map(function (x) { return x.id; });
        setState("done", "", null);
        return list;
      }, function (e) {
        fail(e);
        throw e;
      });
    }

    function fail(e) {
      var kind = e && e.kind, text = String(e && e.message ? e.message : e);
      if (!kind && (e instanceof RangeError || /memory|alloc|OOM/i.test(text))) kind = "memory";
      message = kind === "wasm" || kind === "old" ? "This browser cannot run the model (it lacks WebAssembly or fetch)."
        : kind === "fetch" ? (location.protocol === "file:"
            ? "The model cannot be loaded by a page opened from disk. Open the page from a web address."
            : win.navigator.onLine === false ? "The model is not on this device yet and there is no connection."
            : "The model could not be downloaded. Check the connection and try again.")
        : kind === "memory" ? "This device ran out of memory running the model. Closing other tabs may help."
        : kind === "image" ? "That file could not be read as a picture."
        : kind === "model" ? "The model files do not fit this page: " + text + "."
        : "The photo could not be identified (" + text + ").";
      message += " The key works as before.";
      progress = null;
      state = "error";
      render();
    }

    function setState(s, text, prog) {
      state = s;
      message = text;
      progress = prog;
      render();
    }

    // ---- the panel -------------------------------------------------------------

    var box = el("div", "photo");
    box.id = "mk-photo";
    var input = el("input"), input2 = null;
    input.type = "file";
    input.accept = "image/*";
    input.hidden = true;
    input.id = "mk-photo-file";
    var coarse = !!(win.matchMedia && win.matchMedia("(pointer: coarse)").matches);
    if (coarse) {
      // a phone or tablet: the main button opens the camera, a second one the saved photos
      input.setAttribute("capture", "environment");
      input2 = el("input");
      input2.type = "file";
      input2.accept = "image/*";
      input2.hidden = true;
      input2.id = "mk-photo-saved";
    }
    var thumb = el("img", "photo-thumb");
    thumb.alt = "Your photo";
    var statusEl = el("p", "photo-status");
    statusEl.setAttribute("role", "status");
    var bar = el("progress", "photo-progress");
    var hint = el("p", "photo-hint");
    var actions = el("p", "photo-actions");
    [input, input2, thumb, statusEl, bar, hint, actions].forEach(function (e) { if (e) box.appendChild(e); });
    addTop(box, 1);

    function button(cls, text) {
      var b = el("button", cls, text);
      b.type = "button";
      actions.appendChild(b);
      return b;
    }
    function shortName(id) { return taxonName[id].replace(/\s*\(.*\)\s*$/, "") || taxonName[id]; }

    var where = root;
    function render() {
      var idle = state === "idle";
      box.setAttribute("data-state", state);
      // while nothing is going on, the button shows at the start only
      box.hidden = idle && where !== root && where !== CAND;
      thumb.hidden = !thumbUrl || idle;
      if (thumbUrl && thumb.getAttribute("src") !== thumbUrl) thumb.src = thumbUrl;
      bar.hidden = state !== "loading";
      if (progress && progress.total) { bar.max = progress.total; bar.value = Math.min(progress.got, progress.total); }
      else bar.removeAttribute("value");
      actions.innerHTML = "";
      hint.textContent = "";
      var text = message;
      if (idle) {
        text = "";
        button("photo-pick", coarse ? "Identify from a photo: open the camera" : "Identify from a photo");
        if (coarse) button("photo-saved", "Use a saved photo");
        hint.textContent = "The photo stays on this device.";
      } else if (state === "ask") {
        button("photo-load", "Download " + message);
        button("photo-clear", "Cancel");
        text = "To identify the photo, this page first downloads a model: " + message + ".";
        hint.textContent = kept ? "It is then kept on this device and works without a connection."
          : "The photo stays on this device.";
      } else if (state === "loading") {
        if (progress && progress.total) text += ": " + mb(progress.got) + " of " + mb(progress.total);
        text += "…";
      } else if (state === "running") {
        text += "…";
      } else if (state === "done") {
        var best = result && result.filter(function (x) { return x.id; })[0];
        if (!best) {
          text = "The model knows none of the taxa of this page.";
        } else {
          var pct = Math.round(best.score * 100) + "%";
          text = best.similarity < minSim ? "Not much like any taxon of this key. Closest: " + taxonName[best.id]
            : best.score >= 0.5 ? "Most like " + taxonName[best.id] + " (" + pct + ")"
            : "Not clear. Best guess: " + taxonName[best.id] + " (" + pct + ")";
          hint.textContent = "A photo is a hint, not an identification. Check it against the key.";
          var go1 = button("photo-go", "Go to " + shortName(best.id));
          go1.setAttribute("data-taxon", best.id);
          if (hasKey && !(narrowed && cands.every(function (id) { return narrowed[id]; }) && Object.keys(narrowed).length === cands.length)) {
            button("photo-narrow", cands.length > 1 ? "Narrow the key to the top " + cands.length : "Follow the key to it");
          }
        }
        button("photo-pick", "Another photo");
        button("photo-clear", "Clear");
      } else if (state === "error") {
        if (file) button("photo-retry", "Try again");
        button("photo-clear", "Close");
      }
      statusEl.textContent = text;
      statusEl.hidden = !text;
      hint.hidden = !hint.textContent;
    }

    function clear() {
      file = null;
      result = null;
      cands = [];
      if (thumbUrl && win.URL && win.URL.revokeObjectURL) win.URL.revokeObjectURL(thumbUrl);
      thumbUrl = null;
      win.dimoose.highlight(null);
      state = "idle";
      if (narrowed) setNarrow(null); else render();
    }

    // A photo was chosen: say what has to be downloaded first, unless it is here already
    function chosen(f) {
      if (!f) return;
      file = f;
      result = null;
      win.dimoose.highlight(null);
      if (thumbUrl && win.URL && win.URL.revokeObjectURL) win.URL.revokeObjectURL(thumbUrl);
      thumbUrl = null;
      try { thumbUrl = win.URL.createObjectURL(f); } catch (e) { /* no preview */ }
      if (modelP) { run(); return; }
      if (!(win.ort && win.ort.InferenceSession) && typeof win.WebAssembly !== "object") {
        fail(problem("wasm", "no WebAssembly"));   // before asking for a download that cannot be used
        return;
      }
      setState("loading", "Checking the model", null);
      manifest().then(function (m) {
        return stored(encoderUrl(m)).then(function (have) {
          if (have) { run(); return; }
          var bytes = (+m.image_encoder.bytes || 0) + (win.ort ? 0 : runtimeBytes);
          setState("ask", bytes ? mb(bytes) : "of unknown size", null);
        });
      })["catch"](fail);
    }
    function run() {
      setState("loading", "Getting ready", null);
      identify(file)["catch"](function () { /* shown by fail() */ });
    }

    box.addEventListener("change", function (ev) {
      var t = ev.target;
      if (t !== input && t !== input2) return;
      var f = t.files && t.files[0];
      chosen(f);
      try { t.value = ""; } catch (e) { /* the same photo can be chosen again */ }
    });
    box.addEventListener("click", function (ev) {
      var t = ev.target.closest && ev.target.closest("button");
      if (!t) return;
      if (t.classList.contains("photo-pick")) input.click();
      else if (t.classList.contains("photo-saved")) input2.click();
      else if (t.classList.contains("photo-load") || t.classList.contains("photo-retry")) run();
      else if (t.classList.contains("photo-clear")) clear();
      else if (t.classList.contains("photo-go")) win.dimoose.goToTaxon(t.getAttribute("data-taxon"));
      else if (t.classList.contains("photo-narrow")) setNarrow(cands);
    });

    var api = {
      identify: identify,
      preprocess: photoPreprocess,
      score: photoScore,
      decode: decode,
      result: function () { return result; },
      state: function () { return state; }
    };
    photo = { show: function (id) { where = id; render(); } };
    win.dimoose.photo = api;
  })();

  // ---- showing a step ---------------------------------------------------------------

  function update(moveFocus) {
    var st = top();
    var id = shown(st);
    if (id === CAND) renderCandidates(st);
    if (id === "matrix") renderPick(st);
    if (isTaxon(id)) fillDiagnosis(byId[id]);
    if (isCouplet(id)) addUnsure(byId[id]);
    sections.forEach(function (s) { s.classList.toggle("active", s.id === id); });
    body.classList.toggle("stepping", id !== root);
    body.classList.toggle("picking", id === "matrix");
    renderTrail();
    var poss = possible(st);
    renderOpen(st, id, poss);
    renderNarrow(st, id, poss);
    if (photo) photo.show(id);
    if (id !== "glossary") renderMap(st, id, poss);
    backBtn.disabled = stack.length < 2;
    if (pickBtn) {
      pickBtn.setAttribute("aria-pressed", st.p ? "true" : "false");
      pickBtn.innerHTML = st.p
        ? '<span class="long">Step by step</span><span class="short">Steps</span>'
        : '<span class="long">Pick characters</span><span class="short">Pick</span>';
    }
    applyHighlight();
    if (moveFocus && body.classList.contains("wizard")) {
      win.scrollTo(0, 0);
      var h = byId[id].querySelector("h2");
      if (h) h.focus({ preventScroll: true });
    }
    if (id === "glossary") {
      var target = doc.getElementById(st.g);
      if (target && target !== byId[id] && target.scrollIntoView) target.scrollIntoView();
    }
    if (listeners.length) {
      var snapshot = publicState();
      listeners.forEach(function (fn) { try { fn(snapshot); } catch (e) { /* not ours */ } });
    }
  }

  // Back undoes exactly one step
  backBtn.addEventListener("click", function () {
    if (stack.length > 1) truncate(stack.length - 2);
  });

  if (modeBtn) {
    modeBtn.addEventListener("click", function () {
      var stepping = body.classList.toggle("wizard");
      modeBtn.innerHTML = stepping
        ? '<span class="long">Show full key</span><span class="short">Full key</span>'
        : '<span class="long">Step through</span><span class="short">Steps</span>';
      modeBtn.setAttribute("aria-pressed", stepping ? "false" : "true");
      if (!stepping) sections.forEach(function (sec) { if (sec.classList.contains("taxon")) fillDiagnosis(sec); });
      var active = byId[currentId()];
      if (!stepping && active && active.scrollIntoView) active.scrollIntoView();
      if (stepping) win.scrollTo(0, 0);
    });
  }

  if (pickBtn) {
    pickBtn.addEventListener("click", function () {
      var st = top();
      if (st.p) push({ o: st.o.slice(), s: { v: 1 } });
      else setPick(lastPick);
    });
  }

  if (mapBtn && mapEl) {
    var setMap = function (open) {
      body.classList.toggle("map-open", open);
      mapBtn.setAttribute("aria-expanded", open ? "true" : "false");
      mapBtn.textContent = open ? "Hide map" : "Map";
      try { localStorage.setItem("dimoose-map-open", open ? "1" : "0"); } catch (e) { /* storage unavailable */ }
      if (open) centerMap(currentId());
    };
    var saved = null;
    try { saved = localStorage.getItem("dimoose-map-open"); } catch (e) { /* storage unavailable */ }
    mapBtn.addEventListener("click", function () { setMap(!body.classList.contains("map-open")); });
    if (saved === "1") setMap(true);
  }

  // Keyboard: a/b/c... or 1/2/3... picks a lead of the current couplet,
  // u or ? says "not sure".
  doc.addEventListener("keydown", function (e) {
    if (!body.classList.contains("wizard") || e.altKey || e.ctrlKey || e.metaKey) return;
    var tag = (e.target.tagName || "").toLowerCase();
    if (tag === "input" || tag === "textarea" || tag === "select") return;
    var id = currentId();
    if (!isCouplet(id)) return;
    var links = leadLinks(id);
    var key = (e.key || "").toLowerCase();
    if (key === "u" || key === "?") {
      if (unsure(id)) e.preventDefault();
      return;
    }
    var n = /^[1-9]$/.test(key) ? parseInt(key, 10) - 1 : key.length === 1 ? "abcdefghi".indexOf(key) : -1;
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

  // Buttons the script added
  doc.addEventListener("click", function (ev) {
    var t = ev.target.closest && ev.target.closest("button");
    if (!t || t.disabled) return;
    var st = top();
    if (t.classList.contains("unsure-btn")) {
      var sec = t.closest("section");
      if (sec) unsure(sec.id);
    } else if (t.hasAttribute("data-focus")) {
      if (t.getAttribute("data-focus") !== currentId()) focusOn(t.getAttribute("data-focus"));
    } else if (t.classList.contains("pick-state")) {
      setPick((st.p || []).concat([[+t.getAttribute("data-char"), +t.getAttribute("data-state")]]));
    } else if (t.classList.contains("pick-remove")) {
      var c = +t.getAttribute("data-char");
      setPick((st.p || []).filter(function (x) { return x[0] !== c; }));
    } else if (t.classList.contains("pick-clear")) {
      setPick([]);
    } else if (t.classList.contains("narrow-clear")) {
      setNarrow(null);
    }
  });

  // Links within the page are followed here; see `stack` above.
  doc.addEventListener("click", function (ev) {
    if (ev.defaultPrevented || ev.button || ev.metaKey || ev.ctrlKey || ev.shiftKey || ev.altKey) return;
    var a = ev.target.closest && ev.target.closest("a");
    var href = a && (a.getAttribute("href") || a.getAttribute("xlink:href"));
    if (!href || href.charAt(0) !== "#") return;
    if (a.hasAttribute("data-step")) {            // a choice on the trail: back to it
      ev.preventDefault();
      var k = +a.getAttribute("data-step");
      if (k >= 0 && k < stack.length - 1) truncate(k);
      return;
    }
    var anchor;
    try { anchor = decodeURIComponent(href.slice(1)); } catch (e) { return; }
    if (!sectionOf(anchor)) return;
    ev.preventDefault();
    var st = top();
    var from = a.classList.contains("choose") && a.closest("section");
    if (from && !st.g && !st.p && st.o.indexOf(from.id) >= 0) {   // a lead of an open couplet
      choose(from.id, Array.prototype.indexOf.call(leadLinks(from.id), a));
      settle(anchor);
      return;
    }
    go(anchor);
  });

  // Back and forward buttons, and an address typed by hand
  function fromAddress(ev) {
    var kept = ev && ev.state && ev.state.dimoose ? validStack(ev.state.dimoose.stack) : null;
    if (kept) {
      stack = kept;
      update(true);
    } else {
      var h = readHash();
      var entry = parseHash(h);
      replaceNext = true;   // the browser already made the history entry
      if (!entry) {
        stack = [baseEntry()];
        replaceNext = false;
        update(true);
      } else if (!entry.g && !entry.p && entry.o.length === 1) {
        jump(h);
      } else if (h === "matrix") {
        jump(h);
      } else {
        entry.s = entry.g || entry.p ? { v: 1 } : { j: 1 };
        push(entry);
      }
      replaceNext = false;
    }
    // the browser may still jump to the anchor after this; a step starts at the top
    if (body.classList.contains("wizard") && currentId() !== "glossary" && win.requestAnimationFrame) {
      win.requestAnimationFrame(function () { win.scrollTo(0, 0); });
    }
  }
  win.addEventListener("popstate", fromAddress);
  win.addEventListener("hashchange", function () { if (readHash() !== hashOf(top())) fromAddress(); });

  doc.addEventListener("click", function (ev) {
    var fig = ev.target.closest && ev.target.closest(".fig");
    if (fig && !fig.closest("a")) fig.classList.toggle("big");
  });

  // Start: the stack this history entry holds (a reload), else the address
  // (a shared link), else the first couplet.
  var kept0 = null;
  try { kept0 = history.state && history.state.dimoose ? validStack(history.state.dimoose.stack) : null; } catch (e) { /* no history */ }
  if (kept0 && hashOf(kept0[kept0.length - 1]) === readHash()) {
    stack = kept0;
  } else {
    stack = [parseHash(readHash()) || baseEntry()];
  }
  update(false);
})();
