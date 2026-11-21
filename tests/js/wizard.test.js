// Behaviour tests of inst/wizard/wizard.js and inst/wizard/sw.js, run in jsdom.
//
//   NODE_PATH=<folder with jsdom>/node_modules node wizard.test.js <dir>
//
// <dir> holds the pages tests/testthat/test-wizard-js.R writes: key.html (a
// five-taxon key), both.html (the same key with a character matrix),
// matrix.html (the matrix alone), offline-sw.js, and photo.html and
// photo-offline.html with their made-up photo model (photo_model/). Prints one line per check:
// "ok<TAB>name" or "not ok<TAB>name<TAB>reason".
var fs = require("fs");
var path = require("path");
var vm = require("vm");
var JSDOM = require("jsdom").JSDOM;
var VirtualConsole = require("jsdom").VirtualConsole;

var dir = process.argv[2];
var results = [];
var pageErrors = [];

function check(name, fn) {
  return Promise.resolve().then(fn).then(function () {
    results.push("ok\t" + name);
  }, function (e) {
    results.push("not ok\t" + name + "\t" + String(e && e.message ? e.message : e).replace(/\s+/g, " "));
  });
}
function eq(got, want, what) {
  var a = JSON.stringify(got), b = JSON.stringify(want);
  if (a !== b) throw new Error((what || "value") + ": got " + a + ", want " + b);
}
function ok(x, what) { if (!x) throw new Error(what || "not true"); }
function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

function load(file, hash) {
  var vc = new VirtualConsole();
  vc.on("jsdomError", function (e) { pageErrors.push(file + ": " + (e.detail || e.message || e)); });
  vc.on("error", function (e) { pageErrors.push(file + ": " + e); });
  var dom = new JSDOM(fs.readFileSync(path.join(dir, file), "utf8"), {
    url: "http://localhost/" + file + (hash || ""),
    runScripts: "dangerously",
    pretendToBeVisual: true,
    virtualConsole: vc,
    beforeParse: function (w) {
      w.scrollTo = function () {};
      w.Element.prototype.scrollIntoView = function () {};
    }
  });
  var w = dom.window, d = w.document;
  var p = {
    win: w, doc: d,
    $: function (sel) { return d.querySelector(sel); },
    $$: function (sel) { return Array.prototype.slice.call(d.querySelectorAll(sel)); },
    click: function (target) {
      var e = typeof target === "string" ? d.querySelector(target) : target;
      if (!e) throw new Error("nothing to click: " + target);
      e.dispatchEvent(new w.MouseEvent("click", { bubbles: true, cancelable: true, button: 0 }));
    },
    key: function (k) { d.body.dispatchEvent(new w.KeyboardEvent("keydown", { key: k, bubbles: true, cancelable: true })); },
    active: function () { return p.$$("main section.active").map(function (s) { return s.id; }); },
    hash: function () { return decodeURIComponent(w.location.hash); },
    lead: function (label) { return d.querySelector('a.choose[data-lead="' + label + '"]'); },
    unsure: function () { return d.querySelector("section.active .unsure-btn"); },
    trail: function () { return p.$$("#mk-trail li").map(function (li) { return li.textContent; }); },
    count: function () { return p.$("#mk-left").textContent; },
    ahead: function () { return p.$$(".mnode.mleaf.ahead").map(function (n) { return n.getAttribute("data-id"); }).sort(); },
    state: function () { return w.dimoose.state(); },
    stateButton: function (ch, state) {
      return p.$$(".pick-state").filter(function (b) {
        return b.getAttribute("aria-label").indexOf(ch + ": " + state + ",") === 0;
      })[0];
    }
  };
  return p;
}

// The key: 1a -> 2, 1b -> 4; 2a Fly (t-1), 2b -> 3; 3a Ant (t-2), 3b Bee (t-3);
// 4a Silverfish (t-4), 4b Flea (t-5).
var tests = [];
function test(name, fn) { tests.push([name, fn]); }

test("starts at the first couplet with every taxon possible", function () {
  var p = load("key.html");
  eq(p.active(), ["c-1"]);
  ok(p.$("#mk-back").disabled, "Back is disabled at the start");
  eq(p.count(), "5 of 5 taxa still possible");
  eq(p.trail(), []);
  eq(p.win.location.hash, "");
});

test("choosing a lead moves on, narrows the count and Back undoes it", function () {
  var p = load("key.html");
  p.click(p.lead("1a"));
  eq(p.active(), ["c-2"]);
  eq(p.hash(), "#c-2");
  eq(p.count(), "3 of 5 taxa still possible");
  eq(p.ahead(), ["t-1", "t-2", "t-3"]);
  eq(p.trail(), ["1aWings present"]);
  ok(!p.$("#mk-back").disabled, "Back is enabled");
  p.click("#mk-back");
  eq(p.active(), ["c-1"]);
  eq(p.trail(), []);
  ok(p.$("#mk-back").disabled, "Back is disabled again");
});

test("reaching a taxon shows its section and says identified", function () {
  var p = load("key.html");
  p.click(p.lead("1b"));
  p.click(p.lead("4b"));
  eq(p.active(), ["t-5"]);
  eq(p.count(), "Identified · 1 of 5 taxa");
  eq(p.trail().length, 2);
});

test("the not-sure control is a real button on the couplet shown", function () {
  var p = load("key.html");
  var b = p.unsure();
  ok(b, "there is a button");
  eq(b.tagName, "BUTTON");
  eq(b.getAttribute("type"), "button");
  ok(/not sure/.test(b.textContent), "it says not sure");
  eq(p.$$(".unsure-btn").length, 1, "buttons are added only as couplets are shown");
});

test("not sure follows all leads: open set, union count, readable trail", function () {
  var p = load("key.html");
  p.click(p.unsure());
  eq(p.state().open, ["c-2", "c-4"]);
  eq(p.active(), ["c-2"], "one branch is asked at a time");
  eq(p.hash(), "#open=c-2,c-4");
  eq(p.count(), "5 of 5 taxa still possible");
  eq(p.trail(), ["?Couplet 1: not sure"]);
  var status = p.$("#mk-open .open-status");
  eq(status.getAttribute("role"), "status");
  ok(/following 2 branches, 2 questions still open/.test(status.textContent), status.textContent);
  ok(!p.$("#mk-open").hidden, "the open branches are listed");
  eq(p.$$("#mk-open button").map(function (b) { return b.textContent + ":" + b.getAttribute("aria-pressed"); }),
    ["Couplet 2:true", "Couplet 4:false"]);
  ok(p.$('.mnode[data-id="c-2"]').classList.contains("here"), "the couplet shown is here on the map");
  ok(p.$('.mnode[data-id="c-4"]').classList.contains("open"), "the other branch is marked open");
});

test("each answer narrows its own branch and the count is the union", function () {
  var p = load("key.html");
  p.click(p.unsure());
  p.click(p.lead("2b"));
  eq(p.state().open, ["c-3", "c-4"]);
  eq(p.active(), ["c-3"]);
  eq(p.count(), "4 of 5 taxa still possible");
  eq(p.ahead(), ["t-2", "t-3", "t-4", "t-5"]);
  eq(p.state().remaining.sort(), ["t-2", "t-3", "t-4", "t-5"]);
  p.click(p.lead("3a"));
  eq(p.state().open, ["t-2", "c-4"]);
  eq(p.active(), ["c-4"], "the next open couplet is asked");
  eq(p.count(), "3 of 5 taxa still possible");
  p.click(p.lead("4a"));
  eq(p.state().open, ["t-2", "t-4"]);
  eq(p.active(), ["mk-candidates"]);
  eq(p.trail(), ["?Couplet 1: not sure", "2bFour wings", "3aNarrow waist", "4aNo wings, long tail"]);
});

test("staying unsure ends in the list of candidates", function () {
  var p = load("key.html");
  p.click(p.unsure());   // 1
  p.click(p.unsure());   // 2 -> Fly, couplet 3, couplet 4
  eq(p.state().open, ["t-1", "c-3", "c-4"]);
  eq(p.active(), ["c-3"]);
  p.click(p.unsure());   // 3
  p.click(p.unsure());   // 4
  eq(p.active(), ["mk-candidates"]);
  eq(p.$$("#mk-candidates .cand-list a").map(function (a) { return a.textContent; }),
    ["Fly", "Ant", "Bee", "Silverfish", "Flea"]);
  ok(/5 of 5 taxa fit your answers. You were not sure at 4 couplets/.test(p.$(".cand-note").textContent), p.$(".cand-note").textContent);
  eq(p.count(), "5 of 5 taxa still possible");
  ok(p.$("#mk-open") === null || p.$("#mk-open").hidden, "the branch list is hidden on the candidates");
  eq(p.doc.activeElement.id, "h-mk-candidates", "focus moves to the heading");
});

test("Back undoes exactly one step through unsure answers", function () {
  var p = load("key.html");
  p.click(p.unsure());
  p.click(p.lead("2b"));
  p.click(p.unsure());   // at 3
  eq(p.state().open, ["t-2", "t-3", "c-4"]);
  p.click(p.unsure());   // at 4
  eq(p.active(), ["mk-candidates"]);
  p.click("#mk-back");
  eq(p.state().open, ["t-2", "t-3", "c-4"]);
  eq(p.active(), ["c-4"]);
  p.click("#mk-back");
  eq(p.state().open, ["c-3", "c-4"]);
  eq(p.active(), ["c-3"]);
  p.click("#mk-back");
  eq(p.state().open, ["c-2", "c-4"]);
  p.click("#mk-back");
  eq(p.state().open, ["c-1"]);
  ok(p.$("#mk-back").disabled, "nothing left to undo");
  ok(p.$("#mk-open").hidden, "the branch list is hidden again");
});

test("the reader can pick which open couplet to answer; that is not a step", function () {
  var p = load("key.html");
  p.click(p.unsure());
  p.click('#mk-open button[data-focus="c-4"]');
  eq(p.active(), ["c-4"]);
  eq(p.state().open, ["c-4", "c-2"]);
  eq(p.hash(), "#open=c-4,c-2");
  p.click(p.lead("4a"));
  eq(p.state().open, ["t-4", "c-2"]);
  eq(p.active(), ["c-2"]);
  eq(p.count(), "4 of 5 taxa still possible");
  eq(p.$$("#mk-open a").map(function (a) { return a.textContent; }), ["Silverfish"]);
  p.click("#mk-back");
  eq(p.active(), ["c-4"]);
  p.click("#mk-back");
  eq(p.active(), ["c-1"], "choosing a branch did not add a step");
});

test("a candidate can be opened and Back returns to the list", function () {
  var p = load("key.html");
  p.click(p.lead("1b"));
  p.click(p.unsure());
  eq(p.active(), ["mk-candidates"]);
  eq(p.count(), "2 of 5 taxa still possible");
  p.click("#mk-candidates .cand-list a");
  eq(p.active(), ["t-4"]);
  eq(p.count(), "Identified · 1 of 5 taxa");
  eq(p.trail(), ["1bWings absent", "?Couplet 4: not sure", "→Silverfish"]);
  p.click("#mk-back");
  eq(p.active(), ["mk-candidates"]);
});

test("a choice on the trail goes back to it", function () {
  var p = load("key.html");
  p.click(p.unsure());
  p.click(p.lead("2b"));
  p.click(p.lead("3a"));
  p.click(p.$$("#mk-trail a")[1]);    // "2b": back to before it
  eq(p.state().open, ["c-2", "c-4"]);
  eq(p.trail(), ["?Couplet 1: not sure"]);
});

test("the open set survives a reload through the address", function () {
  var p = load("key.html", "#open=c-3,c-4");
  eq(p.state().open, ["c-3", "c-4"]);
  eq(p.active(), ["c-3"]);
  eq(p.count(), "4 of 5 taxa still possible");
  ok(!p.$("#mk-open").hidden, "the branches are listed");
  var q = load("key.html", "#open=t-2,t-4");
  eq(q.active(), ["mk-candidates"]);
  eq(q.$$(".cand-list a").length, 2);
  var r = load("key.html", "#open=nope,c-99");
  eq(r.active(), ["c-1"], "an address that names nothing starts at the beginning");
  var s = load("key.html", "#c-3");
  eq(s.active(), ["c-3"]);
});

test("the browser's Back and Forward restore steps with the trail", function () {
  var p = load("key.html");
  p.click(p.unsure());
  p.click(p.lead("2b"));
  p.click(p.lead("3b"));
  eq(p.state().open, ["t-3", "c-4"]);
  p.win.history.back();
  return sleep(30).then(function () {
    eq(p.state().open, ["c-3", "c-4"]);
    eq(p.trail(), ["?Couplet 1: not sure", "2bFour wings"]);
    p.win.history.back();
    return sleep(30);
  }).then(function () {
    eq(p.state().open, ["c-2", "c-4"]);
    p.win.history.forward();
    return sleep(30);
  }).then(function () {
    eq(p.state().open, ["c-3", "c-4"]);
    p.win.history.go(-2);
    return sleep(30);
  }).then(function () {
    eq(p.active(), ["c-1"]);
    ok(p.$("#mk-back").disabled, "back at the start");
  });
});

test("keyboard: letters choose a lead, u and ? say not sure", function () {
  var p = load("key.html");
  p.key("u");
  eq(p.state().open, ["c-2", "c-4"]);
  p.key("b");
  eq(p.state().open, ["c-3", "c-4"]);
  p.key("?");
  eq(p.state().open, ["t-2", "t-3", "c-4"]);
  p.key("1");
  eq(p.state().open, ["t-2", "t-3", "t-4"]);
});

test("a map node below an open couplet is the next step; one already passed goes back", function () {
  var p = load("key.html");
  p.click(p.unsure());
  p.click('.mnode[data-id="c-3"]');
  eq(p.state().open, ["c-3", "c-4"]);
  eq(p.trail(), ["?Couplet 1: not sure", "2bFour wings"]);
  p.click('.mnode[data-id="c-1"]');
  eq(p.state().open, ["c-1"]);
  eq(p.trail(), []);
});

test("the full key and the step view can be switched", function () {
  var p = load("key.html");
  p.click("#mk-mode");
  ok(!p.doc.body.classList.contains("wizard"), "full key");
  eq(p.$("#mk-mode").getAttribute("aria-pressed"), "true");
  p.click(p.lead("1a"));
  eq(p.state().open, ["c-2"]);
  p.click("#mk-mode");
  ok(p.doc.body.classList.contains("wizard"), "stepping again");
});

test("window.dimoose lists taxa, highlights likely ones and goes to a taxon", function () {
  var p = load("key.html");
  var d = p.win.dimoose;
  eq(d.taxa.map(function (t) { return t.id + "=" + t.name; }), ["t-1=Fly", "t-2=Ant", "t-3=Bee", "t-4=Silverfish", "t-5=Flea"]);
  var seen = [];
  d.onChange(function (s) { seen.push(s.shown); });
  eq(d.highlight({ "bee": 0.7, "t-1": 0.2, "No such taxon": 1 }, { label: "From your photo" }), ["t-3", "t-1"]);
  var bee = p.$('.mnode.mleaf[data-id="t-3"]');
  ok(bee.classList.contains("likely") && bee.classList.contains("best"), "the best taxon is marked on the map");
  ok(p.$('.mnode.mleaf[data-id="t-1"]').classList.contains("likely"), "the other one too");
  ok(!p.$('.mnode.mleaf[data-id="t-2"]').classList.contains("likely"), "others are not");
  eq(p.$("#mk-likely .eyebrow").textContent, "From your photo");
  eq(p.$$("#mk-likely li").map(function (li) { return li.textContent; }), ["Bee70%", "Fly20%"]);
  // the list of candidates shows the scores too
  p.click(p.lead("1a"));
  p.click(p.lead("2b"));
  p.click(p.unsure());
  eq(p.$$(".cand-list li").map(function (li) { return li.textContent + ":" + li.classList.contains("likely"); }),
    ["Ant:false", "Bee70%:true"]);
  eq(d.highlight([{ taxon: "Ant", score: 12.5 }]), ["t-2"]);
  eq(p.$$(".cand-list li").map(function (li) { return li.textContent; }), ["Ant12.5", "Bee"]);
  eq(d.highlight(null), []);
  ok(p.$("#mk-likely").hidden, "cleared");
  eq(p.$$(".mnode.likely").length, 0);
  ok(d.goToTaxon("Flea"), "known taxon");
  eq(p.active(), ["t-5"]);
  ok(!d.goToTaxon("Yeti"), "unknown taxon");
  eq(p.active(), ["t-5"]);
  eq(seen, ["c-2", "c-3", "mk-candidates", "t-5"]);
});

// The matrix (characters cheapest first: Waist 1, Wings 2, Sting 3):
//   Fly present/broad/absent, Ant present|absent/narrow/NA, bee present/narrow/present,
//   Silverfish absent/broad/absent, Flea absent/broad/absent, Moth present/broad/absent
test("matrix: the character list is offered beside the key, cheapest first", function () {
  var p = load("both.html");
  eq(p.active(), ["c-1"]);
  var b = p.$("#mk-pick");
  eq(b.tagName, "BUTTON");
  p.click(b);
  eq(p.active(), ["matrix"]);
  eq(p.hash(), "#pick");
  eq(b.getAttribute("aria-pressed"), "true");
  eq(p.$(".pick-status").textContent, "6 of 6 taxa match");
  eq(p.$(".pick-status").getAttribute("role"), "status");
  eq(p.$$(".pick > .pick-chars .pick-name").map(function (e) { return e.textContent; }), ["Waist", "Wings", "Sting"]);
  eq(p.$$(".pick > .pick-chars .pick-meta").map(function (e) { return e.textContent; }), ["needs hand lens · summer"]);
  ok(p.$$(".pick-state").every(function (x) { return x.tagName === "BUTTON"; }), "states are buttons");
  eq(p.count(), "6 of 6 taxa match");
  ok(!p.$("details.matrix-table").open, "the whole table is folded away");
  p.click(b);
  eq(p.active(), ["c-1"], "and back to the steps");
});

test("matrix: a state removes taxa; variable taxa fit either state, unknown fits all", function () {
  var p = load("both.html", "#pick");
  p.click(p.stateButton("Wings", "absent"));
  eq(p.state().remaining, ["t-2", "t-4", "t-5"], "Ant is variable for wings and stays");
  eq(p.$(".pick-status").textContent, "3 of 6 taxa match");
  eq(p.state().picks, [{ character: "Wings", state: "absent" }]);
  eq(p.hash(), "#pick=1.1");
  eq(p.$$(".pick-chosen .pick-remove").map(function (x) { return x.textContent; }), ["Wings: absent×"]);
  eq(p.$$(".pick-taxa li").map(function (li) { return li.textContent; }), ["Ant", "Silverfish", "Flea"]);
  eq(p.ahead(), ["t-2", "t-4", "t-5"], "the map shows the taxa left");
  eq(p.count(), "3 of 6 taxa match");
  // what still splits the three: Waist (Ant narrow) and Sting (Ant unknown, so it fits "present" alone)
  eq(p.$$(".pick > .pick-chars .pick-name").map(function (e) { return e.textContent; }), ["Waist", "Sting"]);
  p.click(p.stateButton("Sting", "present"));
  eq(p.state().remaining, ["t-2"], "Ant's sting is unknown, so it fits");
  eq(p.$(".pick-status").textContent, "One taxon matches: Ant");
  eq(p.$$(".pick-taxa a").map(function (a) { return a.getAttribute("href"); }), ["#t-2"]);
});

test("matrix: characters that no longer split the remainder are set aside", function () {
  var p = load("both.html", "#pick");
  p.click(p.stateButton("Waist", "narrow"));
  eq(p.state().remaining, ["t-2", "t-3"]);
  eq(p.$(".pick h3").textContent, "Most useful next");
  // Ant | bee: Wings (Ant both, bee present) and Sting (Ant unknown, bee present) both keep "present" for all;
  // Wings absent keeps Ant alone, so Wings still splits; Sting absent keeps Ant alone too
  eq(p.$$(".pick > .pick-chars .pick-name").map(function (e) { return e.textContent; }), ["Wings", "Sting"]);
  var absent = p.stateButton("Wings", "absent");
  ok(/1 of 2 remaining taxa/.test(absent.getAttribute("aria-label")), absent.getAttribute("aria-label"));
  p.click(absent);
  eq(p.state().remaining, ["t-2"]);
  ok(p.$(".pick-rest").hidden === false, "the rest is listed apart");
  eq(p.$$(".pick-rest .pick-name").map(function (e) { return e.textContent; }), ["Sting"]);
});

test("matrix: Back undoes one pick, a chip removes its pick, picks survive a reload", function () {
  var p = load("both.html", "#pick");
  p.click(p.stateButton("Wings", "present"));
  p.click(p.stateButton("Waist", "broad"));
  eq(p.state().remaining, ["t-1", "m-6"], "Moth is only in the matrix");
  eq(p.$$(".pick-taxa li").map(function (li) { return li.textContent + ":" + !!li.querySelector("a"); }), ["Fly:true", "Moth:false"]);
  p.click("#mk-back");
  eq(p.state().picks.length, 1);
  eq(p.state().remaining.length, 4);
  p.click(p.stateButton("Waist", "broad"));
  p.click(p.$$(".pick-remove")[0]);
  eq(p.state().picks, [{ character: "Waist", state: "broad" }]);
  p.click(p.stateButton("Wings", "absent"));
  p.click(".pick-clear");
  eq(p.state().picks, []);
  var q = load("both.html", "#pick=0.1,1.0");
  eq(q.state().picks, [{ character: "Waist", state: "narrow" }, { character: "Wings", state: "present" }]);
  eq(q.state().remaining, ["t-2", "t-3"]);
  var r = load("both.html", "#pick=9.9,0.0");
  eq(r.state().picks, [{ character: "Waist", state: "broad" }], "picks that name nothing are dropped");
});

test("matrix: from the list into the key and back", function () {
  var p = load("both.html", "#pick");
  p.click(p.stateButton("Waist", "narrow"));
  var cont = p.$(".pick-continue a");
  eq(cont.textContent, "Continue step by step from Couplet 3");
  p.click(cont);
  eq(p.active(), ["c-3"]);
  eq(p.count(), "2 of 5 taxa still possible");
  p.click("#mk-back");
  eq(p.active(), ["matrix"]);
  eq(p.state().picks.length, 1);
  p.click(".pick-taxa a");
  eq(p.active(), ["t-2"]);
  p.click("#mk-back");
  eq(p.active(), ["matrix"]);
  p.click("#mk-restart");
  eq(p.active(), ["c-1"]);
});

test("matrix alone: the page is the character list", function () {
  var p = load("matrix.html");
  eq(p.active(), ["matrix"]);
  ok(p.$("#mk-mode") === null && p.$("#mk-pick") === null && p.$("#mk-map") === null, "no key controls");
  eq(p.$(".pick-status").textContent, "6 of 6 taxa match");
  ok(p.$("#mk-back").disabled, "nothing to undo");
  p.click(p.stateButton("Sting", "present"));
  eq(p.state().remaining, ["m-2", "m-3"]);
  eq(p.hash(), "#pick=2.1");
  eq(p.$$(".pick-taxa li").map(function (li) { return li.textContent; }), ["Ant", "bee"]);
  eq(p.win.dimoose.taxa.length, 6);
  eq(p.win.dimoose.highlight({ Ant: 0.9 }), ["m-2"]);
  ok(p.$('.pick-taxa li[data-taxon="m-2"]').classList.contains("likely"), "highlighted in the list");
  p.click("#mk-back");
  eq(p.state().picks, []);
  p.click(p.stateButton("Wings", "absent"));
  p.click("#mk-restart");
  eq(p.state().picks, []);
  var q = load("matrix.html", "#pick=1.1");
  eq(q.state().remaining, ["m-2", "m-4", "m-5"]);
});

test("without a service worker file named, none is registered", function () {
  var p = load("key.html");
  ok(!p.doc.body.hasAttribute("data-sw"), "single-file page");
});

// ---- the service worker, run against a fake cache and network ----------------

function runWorker(online, file) {
  var listeners = {}, stores = {}, fetched = [];
  function cacheFor(name) {
    var store = stores[name] = stores[name] || {};
    var keyOf = function (r) { return typeof r === "string" ? new URL(r, "https://example.org/keys/").href : r.url; };
    return {
      addAll: function (urls) {
        return Promise.all(urls.map(function (u) {
          return sandbox.fetch(keyOf(u)).then(function (r) { if (!r.ok) throw new Error("addAll " + u); store[keyOf(u)] = r; });
        }));
      },
      put: function (key, r) { store[keyOf(key)] = r; return Promise.resolve(); },
      match: function (key) { return Promise.resolve(store[keyOf(key)]); }
    };
  }
  function response(url, type) {
    var r = { url: url, ok: type !== "opaque", type: type || "basic" };
    r.clone = function () { return r; };
    return r;
  }
  var sandbox = {
    URL: URL, Promise: Promise, Error: Error,
    Request: function (url, init) { this.url = url; this.mode = init && init.mode; this.method = "GET"; },
    fetch: function (req) {
      var url = typeof req === "string" ? req : req.url;
      fetched.push(url + (req.mode ? " " + req.mode : ""));
      if (!online.value) return Promise.reject(new Error("offline"));
      if (/blocked/.test(url) && req.mode === "cors") return Promise.reject(new Error("no CORS"));
      if (/missing/.test(url)) return Promise.reject(new Error("gone"));
      return Promise.resolve(response(url, req.mode === "no-cors" ? "opaque" : "basic"));
    },
    caches: {
      open: function (name) { return Promise.resolve(cacheFor(name)); },
      keys: function () { return Promise.resolve(Object.keys(stores)); },
      "delete": function (name) { delete stores[name]; return Promise.resolve(true); }
    },
    self: {
      location: { origin: "https://example.org", href: "https://example.org/keys/" + (file || "offline-sw.js") },
      addEventListener: function (type, fn) { listeners[type] = fn; },
      skipWaiting: function () { return Promise.resolve(); },
      clients: { claim: function () { return Promise.resolve(); } }
    }
  };
  vm.runInNewContext(fs.readFileSync(path.join(dir, file || "offline-sw.js"), "utf8"), sandbox);
  function fire(type, extra) {
    var waited = null, answered;
    var ev = { waitUntil: function (p) { waited = p; }, respondWith: function (p) { answered = p; } };
    Object.keys(extra || {}).forEach(function (k) { ev[k] = extra[k]; });
    listeners[type](ev);
    return Promise.resolve(waited).then(function () { return answered; });
  }
  return { fire: fire, stores: stores, fetched: fetched };
}

test("service worker: install stores the page, its files and the outside figures", function () {
  var online = { value: true };
  var w = runWorker(online);
  return w.fire("install").then(function () {
    var names = Object.keys(w.stores);
    eq(names.length, 1);
    ok(/^dimoose-offline-[0-9a-f]+$/.test(names[0]), names[0]);
    eq(Object.keys(w.stores[names[0]]).sort(), [
      "https://example.org/keys/offline-icon-192.png",
      "https://example.org/keys/offline-icon-512.png",
      "https://example.org/keys/offline.html",
      "https://example.org/keys/offline.webmanifest",
      "https://img.example.net/blocked/b.png",
      "https://img.example.net/thumbs/a.gif"
    ], "a figure that cannot be fetched (missing.gif) is skipped, the rest is stored");
    eq(w.stores[names[0]]["https://img.example.net/blocked/b.png"].type, "opaque", "falls back to an opaque copy");
    eq(w.stores[names[0]]["https://img.example.net/thumbs/a.gif"].type, "basic", "asks with CORS first");
  });
});

test("service worker: offline, the page and stored figures come from the cache", function () {
  var online = { value: true };
  var w = runWorker(online);
  return w.fire("install").then(function () {
    online.value = false;
    return w.fire("fetch", { request: { method: "GET", mode: "navigate", url: "https://example.org/keys/offline.html?x=1#c-2" } });
  }).then(function (r) {
    eq(r.url, "https://example.org/keys/offline.html", "the stored page answers a navigation");
    return w.fire("fetch", { request: { method: "GET", mode: "no-cors", destination: "image", url: "https://img.example.net/thumbs/a.gif" } });
  }).then(function (r) {
    eq(r.url, "https://img.example.net/thumbs/a.gif");
    online.value = true;
    return w.fire("fetch", { request: { method: "GET", mode: "no-cors", destination: "image", url: "https://img.example.net/new.png" } });
  }).then(function (r) {
    eq(r.url, "https://img.example.net/new.png");
    return sleep(5);
  }).then(function () {
    var store = w.stores[Object.keys(w.stores)[0]];
    ok(store["https://img.example.net/new.png"], "a figure seen for the first time is kept");
    return w.fire("fetch", { request: { method: "POST", url: "https://example.org/x" } });
  }).then(function (r) {
    eq(r, undefined, "requests that are not GET are left alone");
  });
});

test("service worker: a new version removes this page's old caches only", function () {
  var online = { value: true };
  var w = runWorker(online);
  w.stores["dimoose-offline-old"] = {};
  w.stores["dimoose-other-1"] = {};
  return w.fire("install").then(function () { return w.fire("activate"); }).then(function () {
    var names = Object.keys(w.stores).sort();
    eq(names.length, 2);
    eq(names[1], "dimoose-other-1");
    ok(names[0] !== "dimoose-offline-old", "the old cache is gone");
  });
});

test("the page registers the service worker it names, with the page as scope", function () {
  var html = fs.readFileSync(path.join(dir, "offline.html"), "utf8");
  var calls = [];
  var dom = new JSDOM(html, {
    url: "https://example.org/keys/offline.html",
    runScripts: "dangerously",
    pretendToBeVisual: true,
    beforeParse: function (w) {
      w.scrollTo = function () {};
      w.Element.prototype.scrollIntoView = function () {};
      Object.defineProperty(w.navigator, "serviceWorker", {
        value: {
          register: function (file, opts) { calls.push([file, opts.scope]); return Promise.resolve({}); },
          ready: Promise.resolve({})
        }
      });
    }
  });
  return sleep(50).then(function () {
    eq(calls, [["offline-sw.js", "./offline.html"]]);
    var note = dom.window.document.getElementById("mk-offline");
    ok(note && !note.hidden && /without a connection/.test(note.textContent), "the page says it is saved");
  });
});

// ---- narrowing the key, and identifying from a photo with a made-up runtime ----

test("dimoose.narrow restricts what is still possible, greys the other leads and can be undone", function () {
  var p = load("key.html");
  var d = p.win.dimoose;
  eq(p.state().narrowed, null);
  eq(d.narrow(["Ant", "bee", "Yeti"]).sort(), ["t-2", "t-3"]);
  eq(p.state().remaining.sort(), ["t-2", "t-3"]);
  eq(p.count(), "2 of 5 taxa still possible (narrowed)");
  eq(p.$$("section.active li.lead.unlikely a.choose").map(function (a) { return a.getAttribute("data-lead"); }), ["1b"]);
  eq(p.ahead(), ["t-2", "t-3"], "the map shows only those taxa ahead");
  ok(/Narrowed to 2 taxa/.test(p.$("#mk-narrow p").textContent), p.$("#mk-narrow p").textContent);
  p.click(p.lead("1a"));
  eq(p.$$("section.active li.lead.unlikely a.choose").map(function (a) { return a.getAttribute("data-lead"); }), ["2a"]);
  // a greyed lead still works: the key decides
  p.click(p.lead("2a"));
  eq(p.active(), ["t-1"]);
  eq(p.count(), "Identified · 1 of 5 taxa");
  ok(/lead away/.test(p.$("#mk-narrow p").textContent), "the page says the answers left the narrowed taxa");
  p.click("#mk-back");
  eq(p.state().remaining.sort(), ["t-2", "t-3"], "Back does not undo the narrowing");
  p.click("#mk-narrow .narrow-clear");
  eq(p.state().narrowed, null);
  eq(p.state().remaining.sort(), ["t-1", "t-2", "t-3"]);
  eq(p.$$("li.lead.unlikely").length, 0);
  ok(p.$("#mk-narrow").hidden, "the note is gone");
  // narrowing from a place that cannot reach the taxa starts again at the first couplet
  p.click(p.lead("2a"));
  d.narrow(["Flea"]);
  eq(p.active(), ["c-1"]);
  eq(p.state().remaining, ["t-5"]);
  eq(d.narrow(null), []);
});

test("the map keeps only the place shown and the next steps as tab stops", function () {
  var p = load("key.html");
  var stops = function () { return p.$$(".mnode").filter(function (n) { return n.getAttribute("tabindex") === "0"; }).map(function (n) { return n.getAttribute("data-id"); }).sort(); };
  eq(stops(), ["c-1", "c-2", "c-4"]);
  p.click(p.lead("1a"));
  eq(stops(), ["c-2", "c-3", "t-1"]);
});

test("without a photo model the page has no photo button", function () {
  var p = load("key.html");
  eq(p.$("#mk-photo"), null);
  eq(p.win.dimoose.photo, undefined);
});

// photo.html with the made-up model: fetch reads the files exportWizard()
// copied, the runtime is a stub whose encoder returns `p.embedding`, and the
// picture decoder returns 2 x 2 grey pixels.
// Waits until the photo panel has stopped working (asked, done or failed)
function settled(p) {
  var t0 = Date.now();
  return new Promise(function (resolve, reject) {
    (function poll() {
      var st = p.win.dimoose.photo.state();
      if (st === "ask" || st === "done" || st === "error") resolve();
      else if (Date.now() - t0 > 10000) reject(new Error("the photo panel is still " + st + " after 10 s"));
      else setTimeout(poll, 5);
    })();
  });
}

function photoPage(file, opts) {
  opts = opts || {};
  var p = load(file || "photo.html");
  var w = p.win;
  p.fetched = [];
  p.embedding = [0, 0, 5, 0];
  p.fail = opts.fail || null;
  w.fetch = function (url) {
    url = String(url);
    p.fetched.push(url.replace("http://localhost/", ""));
    if (p.fail && p.fail.test(url)) return Promise.reject(new Error("net down"));
    var full = path.join(dir, url.replace("http://localhost/", ""));
    if (!fs.existsSync(full)) return Promise.resolve({ ok: false, status: 404 });
    var buf = fs.readFileSync(full);
    return Promise.resolve({
      ok: true, status: 200, headers: { get: function () { return null; } },
      json: function () {
        var j = JSON.parse(buf.toString("utf8"));
        if (opts.minSimilarity) j.min_similarity = opts.minSimilarity;
        return Promise.resolve(j);
      },
      arrayBuffer: function () { return Promise.resolve(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength)); }
    });
  };
  if (!opts.noRuntime) {
    w.ort = {
      env: { wasm: {} },
      Tensor: function (type, data, dims) { this.type = type; this.data = data; this.dims = dims; },
      InferenceSession: {
        create: function (bytes, o) {
          p.created = { bytes: bytes.length, providers: o.executionProviders };
          if (opts.createFails) return Promise.reject(opts.createFails);
          return Promise.resolve({ run: function (feeds) { p.fed = feeds; return Promise.resolve({ image_embeds: { data: new Float32Array(p.embedding) } }); } });
        }
      }
    };
  }
  w.dimoose.photo.decode = function () {
    var px = new Uint8ClampedArray(16);
    for (var i = 0; i < 16; i++) px[i] = i % 4 === 3 ? 255 : 128;
    return Promise.resolve({ data: px, width: 2, height: 2 });
  };
  p.choose = function () {
    var input = p.$("#mk-photo-file");
    Object.defineProperty(input, "files", { value: [{ name: "leaf.jpg" }], configurable: true });
    input.dispatchEvent(new w.Event("change", { bubbles: true }));
  };
  p.status = function () { return p.$("#mk-photo .photo-status").textContent; };
  p.buttons = function () { return p.$$("#mk-photo button").map(function (b) { return b.textContent; }); };
  return p;
}

test("photo: the button is there at the start, with a file input for pictures", function () {
  var p = photoPage();
  ok(!p.$("#mk-photo").hidden, "shown at the first couplet");
  eq(p.buttons(), ["Identify from a photo"]);
  var input = p.$("#mk-photo-file");
  eq([input.type, input.accept, input.hidden], ["file", "image/*", true]);
  eq(p.win.dimoose.photo.state(), "idle");
  eq(p.fetched, [], "nothing is fetched before a photo is chosen");
  p.click(p.lead("1a"));
  ok(p.$("#mk-photo").hidden, "out of the way while stepping through the key");
  p.click("#mk-back");
  ok(!p.$("#mk-photo").hidden);
});

test("photo: preprocessing follows model.json and Pillow's bicubic resize", function () {
  var p = photoPage();
  var pre = p.win.dimoose.photo.preprocess;
  var spec = { image_size: 2, resize: "shortest", resize_to: 2, interpolation: "bicubic", crop: "center",
               rescale: 1 / 255, mean: [0.5, 0.5, 0.5], std: [0.5, 0.25, 1] };
  var near = function (got, want, what) {
    eq(Array.prototype.map.call(got, function (v) { return Math.round(v * 1e4) / 1e4; }), want.map(function (v) { return Math.round(v * 1e4) / 1e4; }), what);
  };
  // 2 x 2, nothing to resize: channel by channel, (value / 255 - mean) / std
  var px = [255, 0, 128, 255, 0, 0, 0, 255, 51, 51, 51, 255, 255, 255, 255, 255];
  near(pre(px, 2, 2, spec), [1, -1, -0.6, 1, -2, -2, -1.2, 2, 128 / 255 - 0.5, -0.5, -0.3, 0.5], "NCHW, normalised");
  // 6 x 4 -> 3 x 2 -> the middle 2 x 2 (left edge round(0.5) = 0, as Python rounds); values from Pillow
  var plain = { image_size: 2, resize: "shortest", resize_to: 2, interpolation: "bicubic", crop: "center", rescale: 1, mean: [0, 0, 0], std: [1, 1, 1] };
  var img = [], x, y;
  for (y = 0; y < 4; y++) for (x = 0; x < 6; x++) img.push((x * 37 + y * 91) % 256, (x * 53 + y * 17) % 256, (x * 11 + y * 71) % 256, 255);
  eq(Array.prototype.slice.call(pre(img, 6, 4, plain)), [81, 131, 114, 87, 39, 152, 71, 169, 48, 70, 179, 190], "downscaled as Pillow does");
  // 2 x 3 -> 4 x 6 -> the middle 4 x 4; red channel from Pillow
  var up = [];
  for (y = 0; y < 3; y++) for (x = 0; x < 2; x++) up.push((x * 37 + y * 91) % 256, 0, 0, 255);
  plain.image_size = plain.resize_to = 4;
  eq(Array.prototype.slice.call(pre(up, 2, 3, plain), 0, 16), [15, 23, 44, 55, 62, 73, 94, 105, 114, 125, 146, 157, 164, 175, 196, 207], "upscaled as Pillow does");
});

test("photo: scores are the softmax of 100 x cosine similarity", function () {
  var p = photoPage();
  var s = p.win.dimoose.photo.score([0, 3, 4, 0], [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0], 3, 4, 100);
  eq(s.map(function (x) { return Math.round(x.similarity * 1e6) / 1e6; }), [0, 0.6, 0.8], "the embedding is normalised first");
  var e = [Math.exp(-80), Math.exp(-20), 1], sum = e[0] + e[1] + e[2];
  eq(s.map(function (x) { return Math.round(x.score * 1e9); }), e.map(function (v) { return Math.round(v / sum * 1e9); }));
});

test("photo: choosing a picture asks before the download, then marks and lists the likely taxa", function () {
  var p = photoPage();
  p.embedding = [0, 0, 1.8, 0.872];   // Bee, then Flea not far behind
  p.choose();
  return settled(p).then(function () {
    eq(p.win.dimoose.photo.state(), "ask");
    eq(p.fetched, ["photo_model/model.json"], "only the small description has been fetched");
    // the model is 2.5 MB; the runtime (15 MB more) is here already in this test
    ok(/downloads a model: 3 MB/.test(p.status()), "says the size: " + p.status());
    eq(p.buttons(), ["Download 3 MB", "Cancel"]);
    p.click("#mk-photo .photo-load");
    return settled(p);
  }).then(function () {
    eq(p.win.dimoose.photo.state(), "done");
    eq(p.fetched, ["photo_model/model.json", "photo_model/text_embeddings.bin", "photo_model/image_encoder.onnx"]);
    eq(p.created, { bytes: 64, providers: ["wasm"] }, "the encoder file went to the runtime, WebAssembly backend");
    var t = p.fed.pixel_values;
    eq([t.type, t.dims, t.data.length], ["float32", [1, 3, 2, 2], 12]);
    eq(Math.round(t.data[4] * 1e4), Math.round((128 / 255 - 0.5) / 0.25 * 1e4), "prepared with the model's mean and std");
    ok(/^Most like Bee \(\d+%\)$/.test(p.status()), p.status());
    var r = p.win.dimoose.photo.result();
    eq(r.map(function (x) { return x.taxon; }).slice(0, 3), ["Bee", "Flea", "Not in the key"]);
    eq(r[0].id, "t-3");
    eq(Math.round(r.reduce(function (a, x) { return a + x.score; }, 0) * 1e6), 1e6, "scores sum to 1 over all labels of the model");
    var listed = p.$$("#mk-likely li").map(function (li) { return li.textContent.replace(/\d+%$/, ""); });
    eq(listed, ["Bee", "Flea"], "the label that is not in the key and the taxa under 1% are left out");
    eq(p.$("#mk-likely .eyebrow").textContent, "From your photo");
    ok(p.$('.mnode.mleaf[data-id="t-3"]').classList.contains("best"), "marked on the map");
    eq(p.$$(".mnode.mleaf.likely").length, 2);
    eq(p.buttons(), ["Go to Bee", "Narrow the key to the top 2", "Another photo", "Clear"]);
    ok(/hint/.test(p.$("#mk-photo .photo-hint").textContent), "says a photo is a hint");
    // narrow the key: the couplets confirm
    p.click("#mk-photo .photo-narrow");
    eq(p.state().narrowed.sort(), ["t-3", "t-5"]);
    eq(p.active(), ["c-1"]);
    eq(p.count(), "2 of 5 taxa still possible (narrowed)");
    eq(p.$$("section.active li.lead.unlikely").length, 0, "both leads of the first couplet reach a candidate");
    p.click(p.lead("1a"));
    eq(p.$$("section.active li.lead.unlikely a.choose").map(function (a) { return a.getAttribute("data-lead"); }), ["2a"]);
    ok(!p.$("#mk-photo").hidden, "the result stays in view while stepping");
    // jump to the result
    p.click("#mk-photo .photo-go");
    eq(p.active(), ["t-3"]);
    // a second photo needs no question and no second download
    p.embedding = [9, 0, 0, 0];
    p.choose();
    return settled(p);
  }).then(function () {
    eq(p.win.dimoose.photo.state(), "done");
    eq(p.fetched.length, 3, "the model is loaded once");
    ok(/^Most like Fly/.test(p.status()), p.status());
    p.click("#mk-photo .photo-clear");
    eq(p.win.dimoose.photo.state(), "idle");
    eq(p.state().narrowed, null, "Clear undoes the narrowing");
    eq(p.$$(".mnode.likely").length, 0);
    ok(p.$("#mk-likely").hidden);
  });
});

test("photo: the size asked about includes the runtime when it is not loaded yet", function () {
  var p = photoPage("photo.html", { noRuntime: true });
  p.choose();
  return settled(p).then(function () {
    eq(p.buttons(), ["Download 17 MB", "Cancel"]);
    p.click("#mk-photo .photo-clear");
    eq(p.win.dimoose.photo.state(), "idle");
    eq(p.fetched, ["photo_model/model.json"]);
  });
});

test("photo: identify() runs the whole thing for another script", function () {
  var p = photoPage();
  p.embedding = [0, 0, 0, 2];
  return p.win.dimoose.photo.identify({ name: "x.jpg" }).then(function (list) {
    eq(list[0].taxon, "Silverfish");
    ok(list[0].score > 0.99);
    eq(p.win.dimoose.photo.state(), "done");
  });
});

test("photo: an unclear result says so", function () {
  var p = photoPage();
  p.embedding = [1, 1, 1, 0];
  return p.win.dimoose.photo.identify({}).then(function () {
    ok(/^Not clear\. Best guess: /.test(p.status()), p.status());
  });
});

test("photo: under the model's min_similarity the best match is not given a percentage", function () {
  var p = photoPage("photo.html", { minSimilarity: 0.97 });
  p.embedding = [1, 0, 3, 0];   // cosine 0.95 with Bee, and all of the softmax
  return p.win.dimoose.photo.identify({}).then(function (list) {
    ok(list[0].score > 0.99 && list[0].similarity < 0.97, JSON.stringify(list[0]));
    eq(p.status(), "Not much like any taxon of this key. Closest: Bee");
    var q = photoPage();
    q.embedding = [1, 0, 3, 0];
    return q.win.dimoose.photo.identify({}).then(function () { eq(q.status(), "Most like Bee (100%)"); });
  });
});

test("photo: a failed download is reported and the key stays usable; trying again works", function () {
  var p = photoPage("photo.html", { fail: /image_encoder/ });
  p.choose();
  return settled(p).then(function () {
    p.click("#mk-photo .photo-load");
    return settled(p);
  }).then(function () {
    eq(p.win.dimoose.photo.state(), "error");
    ok(/could not be downloaded/.test(p.status()) && /The key works as before/.test(p.status()), p.status());
    eq(p.buttons(), ["Try again", "Close"]);
    p.click(p.lead("1b"));
    eq(p.active(), ["c-4"]);
    p.fail = null;
    p.click("#mk-photo .photo-retry");
    return settled(p);
  }).then(function () {
    eq(p.win.dimoose.photo.state(), "done");
    ok(/^Most like Bee/.test(p.status()), p.status());
  });
});

test("photo: no WebAssembly, no memory and a wrong model each get a plain message", function () {
  var a = photoPage("photo.html", { noRuntime: true });
  a.win.WebAssembly = undefined;
  a.choose();
  var b = photoPage("photo.html", { createFails: new Error("failed to allocate memory for the session") });
  var c = photoPage();
  c.win.dimoose.photo.decode = function () { var e = new Error("not a picture"); e.kind = "image"; return Promise.reject(e); };
  var failed = 0;
  var swallow = function () { failed++; };
  return settled(a).then(function () {
    eq(a.win.dimoose.photo.state(), "error");
    ok(/cannot run the model/.test(a.status()), a.status());
    eq(a.fetched, [], "and nothing was downloaded for it");
    return Promise.all([b.win.dimoose.photo.identify({})["catch"](swallow), c.win.dimoose.photo.identify({})["catch"](swallow)]);
  }).then(function () {
    eq(failed, 2, "identify() rejects");
    ok(/ran out of memory/.test(b.status()), b.status());
    ok(/could not be read as a picture/.test(c.status()), c.status());
    a.click(a.lead("1a"));
    eq(a.active(), ["c-2"], "the key works as before");
  });
});

test("photo, offline copy: the worker keeps the model and the runtime apart from the page", function () {
  var online = { value: true };
  var w = runWorker(online, "photo-offline-sw.js");
  var model = "https://example.org/keys/photo-offline_model/image_encoder.onnx";
  var wasm = "https://cdn.jsdelivr.net/npm/onnxruntime-web@1.31.1/dist/ort-wasm-simd-threaded.wasm";
  var kept;
  return w.fire("install").then(function () {
    return w.fire("fetch", { request: { method: "GET", mode: "cors", url: model } });
  }).then(function () {
    return w.fire("fetch", { request: { method: "GET", mode: "cors", url: wasm } });
  }).then(function () {
    return w.fire("fetch", { request: { method: "GET", mode: "cors", url: "https://elsewhere.example.net/x.js" } });
  }).then(function () {
    kept = Object.keys(w.stores).filter(function (n) { return /-kept-/.test(n); });
    eq(kept.length, 1);
    eq(Object.keys(w.stores[kept[0]]).sort(), [wasm, model].sort(), "the model and the runtime, not other sites' files");
    w.stores["dimoose-photo-offline-old"] = {};
    return w.fire("activate");
  }).then(function () {
    ok(w.stores[kept[0]], "a new version of the page keeps the model");
    ok(!w.stores["dimoose-photo-offline-old"], "and drops the old page");
    online.value = false;
    return w.fire("fetch", { request: { method: "GET", mode: "cors", url: model } });
  }).then(function (r) {
    eq(r.url, model, "without a connection the model comes from the store");
  });
});

(function run(i) {
  if (i < tests.length) {
    check(tests[i][0], tests[i][1]).then(function () { run(i + 1); });
    return;
  }
  check("the page scripts raised no errors", function () { eq(pageErrors, []); }).then(function () {
    console.log(results.join("\n"));
    process.exit(0);
  });
})(0);
