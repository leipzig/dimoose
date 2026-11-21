// Manual check of the exported pages in a real browser: not run by the test
// suite. It serves a folder with python3 -m http.server and drives headless
// Chrome at phone width (390 px) and on a desktop screen through the pages
// below: "I'm not sure" to the list of candidates, Back, reload, the
// browser's Back and Forward, a deep link, the keyboard, the map, the hook,
// the character list, a pruned key, the page without JavaScript, and the
// offline copy with the network cut and with the server stopped. It reports
// console errors, sideways scrolling and elements wider than the screen, and
// writes screenshots to look at.
//
// The pages, written from R into <site dir>:
//   exportWizard(montanaKey(), "montana.html"); exportWizard(sharkKey(), "shark.html")
//   exportWizard(vibrioKey(), "vibrio.html", matrix = vibrioMatrix())
//   exportWizard(k, "trees.html", matrix = trees, characters = characters)    # the keyFromMatrix() example
//   exportWizard(NULL, "matrixonly.html", matrix = trees, characters = characters)
//   exportWizard(pruneKey(montanaKey(), drop = c("Quercus macrocarpa", "Fraxinus pennsylvanica")), "pruned.html")
//   exportWizard(montanaKey(), "offline.html", offline = TRUE)
//
//   mkdir -p "$TMPDIR/dimoose-browser" && cd "$TMPDIR/dimoose-browser" && npm install playwright-core
//   NODE_PATH="$TMPDIR/dimoose-browser/node_modules" node wizard.browser.js <site dir> <screenshot dir>
//
// Uses Google Chrome if it is installed (DIMOOSE_CHROME names another
// executable), else the Chromium of `npx playwright install chromium`. Exits
// with status 0 and the word "skipped" when playwright-core or a browser is
// missing, 1 when it found problems.
var cp = require("child_process");
var path = require("path");
var fs = require("fs");
var pw;
try { pw = require("playwright-core"); } catch (e) { console.log("skipped: playwright-core is not installed"); process.exit(0); }
var site = process.argv[2], shots = process.argv[3], port = +process.env.DIMOOSE_PORT || 8731;
if (!site || !shots) { console.error("usage: node wizard.browser.js <site dir> <screenshot dir>"); process.exit(2); }
fs.mkdirSync(shots, { recursive: true });
function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
var problems = [];
function note(x) { console.log(x); }
function bad(x) { problems.push(x); console.log("PROBLEM " + x); }
function launch() {
  var tries = [];
  if (process.env.DIMOOSE_CHROME) tries.push({ headless: true, executablePath: process.env.DIMOOSE_CHROME });
  tries.push({ headless: true, channel: "chrome" }, { headless: true });
  return tries.reduce(function (p, opts) {
    return p["catch"](function () { return pw.chromium.launch(opts); });
  }, Promise.reject(new Error("none")));
}
var srv = null;
(async function () {
  var browser;
  try { browser = await launch(); } catch (e) { console.log("skipped: no browser (" + String(e.message).split("\n")[0] + ")"); process.exit(0); }
  srv = cp.spawn("python3", ["-m", "http.server", String(port), "--bind", "127.0.0.1", "--directory", site], { stdio: "ignore" });
  await sleep(800);
  var views = { phone: { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 }, desk: { viewport: { width: 1400, height: 900 } } };
  for (var vn of Object.keys(views)) {
    var ctx = await browser.newContext(views[vn]);
    var page = await ctx.newPage();
    var tag = "";
    page.on("console", function (m) { if ((m.type() === "error" || m.type() === "warning") && !/favicon/.test(m.location().url)) bad(vn + " " + tag + " console " + m.type() + ": " + m.text()); });
    page.on("pageerror", function (e) { bad(vn + " " + tag + " pageerror: " + e.message); });
    async function hs(label) {
      var r = await page.evaluate(function () { return [document.documentElement.scrollWidth, window.innerWidth, document.body.scrollWidth]; });
      if (r[0] > r[1] + 1) bad(vn + " " + tag + " " + label + " horizontal scroll " + JSON.stringify(r));
      // elements wider than viewport
      var wide = await page.evaluate(function () {
        var out = []; var w = window.innerWidth;
        Array.prototype.forEach.call(document.querySelectorAll("body *"), function (e) {
          var r = e.getBoundingClientRect();
          if (r.width > 0 && (r.right > w + 1 || r.left < -1) && !e.closest(".map-scroll, .table-scroll, .trail, svg")) out.push(e.tagName + "." + e.className + " " + Math.round(r.left) + ".." + Math.round(r.right));
        });
        return out.slice(0, 5);
      });
      if (wide.length) bad(vn + " " + tag + " " + label + " overflow: " + wide.join(" | "));
    }
    async function shot(label, full) { await hs(label); await page.screenshot({ path: path.join(shots, vn + "-" + tag + "-" + label + ".png"), fullPage: !!full }); }
    async function st() { return await page.evaluate(function () { return JSON.stringify([window.dimoose.state().shown, window.dimoose.state().open, window.dimoose.state().remaining.length, location.hash, document.getElementById("mk-left") && document.getElementById("mk-left").textContent]); }); }

    // montana
    tag = "montana";
    await page.goto("http://localhost:" + port + "/montana.html");
    await shot("start");
    note(vn + " montana start " + await st());
    await page.click("section.active .unsure-btn"); await shot("unsure1"); note(await st());
    await page.click("section.active .unsure-btn"); await shot("unsure2"); note(await st());
    await page.click("section.active a.choose"); await shot("answer"); note(await st());
    if (vn === "phone") { await page.click("#mk-maptoggle"); await shot("map"); await page.click("#mk-maptoggle"); }
    // stay unsure until candidates
    for (var i = 0; i < 30; i++) { var b = await page.$("section.active .unsure-btn"); if (!b) break; await b.click(); }
    await shot("candidates", true); note("cands " + await st());
    var tops = await page.$$eval("#mk-trail li", function (li) { return li.map(function (x) { return Math.round(x.getBoundingClientRect().top); }); });
    if (vn === "phone" && tops.some(function (t) { return t !== tops[0]; })) bad("phone: the choices on the trail are not on one line: " + tops.join(","));
    var beforeReload = await st();
    await page.reload(); var afterReload = await st();
    if (beforeReload !== afterReload) bad(vn + " reload changed state " + beforeReload + " -> " + afterReload);
    var trailN = await page.$$eval("#mk-trail li", function (x) { return x.length; }); note("trail after reload " + trailN);
    await page.click("#mk-candidates .cand-list a"); await shot("taxon", true); note(await st());
    await page.click("#mk-back"); note("back " + await st());
    await page.goBack(); note("history back " + await st());
    await page.goForward(); note("history fwd " + await st());
    // deep link in a fresh page
    var p2 = await ctx.newPage();
    await p2.goto("http://localhost:" + port + "/montana.html#open=c-3,t-1");
    note("deep " + await p2.evaluate(function () { return JSON.stringify(window.dimoose.state()); }));
    await p2.screenshot({ path: path.join(shots, vn + "-montana-deeplink.png") });
    await p2.close();
    // keyboard
    await page.goto("http://localhost:" + port + "/montana.html#");
    await page.reload();
    note("kb start " + await st());
    await page.keyboard.press("a"); note("kb a " + await st());
    await page.keyboard.press("u"); note("kb u " + await st());
    await page.keyboard.press("?"); note("kb ? " + await st());
    await page.keyboard.press("2"); note("kb 2 " + await st());
    // tab order: first tab stops
    await page.goto("http://localhost:" + port + "/montana.html");
    var stops = [];
    for (var t = 0; t < 12; t++) { await page.keyboard.press("Tab"); stops.push(await page.evaluate(function () { var e = document.activeElement; return e.tagName + (e.id ? "#" + e.id : "") + "." + String(e.className.baseVal != null ? e.className.baseVal : e.className).split(" ")[0]; })); }
    note("tab stops " + stops.join(" > "));
    if (stops.indexOf("A.choose") < 0 || stops.indexOf("A.choose") > 7) bad(vn + ": the keyboard needs more than 8 Tabs to reach a lead: " + stops.join(" > "));
    await page.keyboard.press("Enter"); note("enter on focus " + await st());
    await shot("focus");
    // highlight
    await page.evaluate(function () { window.dimoose.highlight({ "t-1": 0.62, "t-3": 0.2, "t-5": 0.1, "t-6": 0.05, "t-7": 0.02, "t-8": 0.01 }, { label: "From your photo" }); });
    await shot("highlight", true);
    if (vn === "phone") { await page.click("#mk-maptoggle"); await shot("highlight-map"); await page.click("#mk-maptoggle"); }
    // full key
    await page.click("#mk-mode"); await shot("fullkey"); await page.click("#mk-mode");

    // shark
    tag = "shark";
    await page.goto("http://localhost:" + port + "/shark.html");
    await page.waitForLoadState("load");
    await shot("start", true);
    await page.click("section.active .unsure-btn"); await page.click("section.active .unsure-btn"); await page.click("section.active .unsure-btn"); await shot("unsure3"); note(await st());
    if (vn === "phone") { await page.click("#mk-maptoggle"); await shot("map"); await page.click("#mk-maptoggle"); }

    // vibrio with matrix
    tag = "vibrio";
    await page.goto("http://localhost:" + port + "/vibrio.html");
    await shot("start"); note(await st());
    await page.click("#mk-pick"); await shot("pick0", true); note(await st());
    await page.click(".pick > .pick-chars .pick-state:not([disabled])"); await shot("pick1"); note(await st());
    await page.click(".pick > .pick-chars .pick-state:not([disabled])"); await page.click(".pick > .pick-chars .pick-state:not([disabled])"); await shot("pick3", true); note(await st());
    var pr = await st(); await page.reload(); var pr2 = await st(); if (pr !== pr2) bad(vn + " vibrio pick reload " + pr + " -> " + pr2);
    for (var j = 0; j < 12; j++) { var sb = await page.$(".pick > .pick-chars .pick-state:not([disabled])"); if (!sb) break; await sb.click(); }
    await shot("pickend", true); note(await st());
    var cont = await page.$(".pick-continue a"); note("continue link: " + (cont ? await cont.textContent() : "none"));
    await page.click("#mk-pick"); note("back to steps " + await st());
    await page.click("#mk-pick"); await page.click("details.matrix-table summary"); await shot("table");

    tag = "trees";
    await page.goto("http://localhost:" + port + "/trees.html");
    await shot("start");
    await page.click("#mk-pick"); await shot("pick0", true);
    await page.click(".pick > .pick-chars .pick-state:not([disabled])"); await shot("pick1", true); note(await st());
    cont = await page.$(".pick-continue a"); note("continue link: " + (cont ? await cont.textContent() : "none"));
    if (cont) { await cont.click(); note("continued " + await st()); await shot("continued"); }
    tag = "matrixonly";
    await page.goto("http://localhost:" + port + "/matrixonly.html");
    await shot("start", true);
    await page.click(".pick > .pick-chars .pick-state:not([disabled])"); await page.click(".pick > .pick-chars .pick-state:not([disabled])"); await shot("pick2", true); note(await st());
    tag = "pruned";
    await page.goto("http://localhost:" + port + "/pruned.html"); await shot("start", true);
    var notes = await page.$$eval("section.active .note", function (n) { return n.map(function (x) { return x.textContent + " | visible " + (x.getBoundingClientRect().height > 0); }); });
    note("notes at the first couplet: " + JSON.stringify(notes));
    if (!notes.length || !/visible true/.test(notes[0])) bad(vn + ": the note of the collapsed couplet is not shown");
    await page.click("section.active a.choose"); await shot("result", true);
    await ctx.close();
  }
  // no-JS
  var ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, javaScriptEnabled: false });
  var page = await ctx.newPage();
  await page.goto("http://localhost:" + port + "/trees.html"); await page.screenshot({ path: path.join(shots, "nojs-trees.png"), fullPage: true });
  await page.goto("http://localhost:" + port + "/pruned.html"); await page.screenshot({ path: path.join(shots, "nojs-pruned.png") });
  if (!(await page.$$eval(".couplet .note", function (n) { return n.length; }))) bad("no JavaScript: the notes are missing");
  var r = await page.evaluate("[document.documentElement.scrollWidth, window.innerWidth]").catch(function () { return null; }); note("nojs widths " + JSON.stringify(r));
  await ctx.close();

  // the offline copy: registered, then the network cut, then the server stopped
  ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  page = await ctx.newPage();
  page.on("console", function (m) { if (m.type() === "error") bad("offline console error: " + m.text()); });
  page.on("pageerror", function (e) { bad("offline pageerror " + e.message); });
  var file = "offline.html", url = "http://localhost:" + port + "/" + file;
  await page.goto(url);
  await page.waitForFunction(function () { var n = document.getElementById("mk-offline"); return n && !n.hidden; }, null, { timeout: 15000 });
  note("note: " + await page.textContent("#mk-offline"));
  note("controller: " + await page.evaluate(function () { return navigator.serviceWorker.ready.then(function (r) { return r.active.scriptURL + " scope " + r.scope + " controlled=" + !!navigator.serviceWorker.controller; }); }));
  note("caches: " + await page.evaluate(function () { return caches.keys().then(function (ks) { return Promise.all(ks.map(function (k) { return caches.open(k).then(function (c) { return c.keys(); }).then(function (rs) { return k + ": " + rs.map(function (r) { return r.url.split("/").pop(); }).join(","); }); })); }).then(function (x) { return x.join(" | "); }); }));
  var cdp = await ctx.newCDPSession(page);
  var man = await cdp.send("Page.getAppManifest");
  note("manifest url " + man.url + " errors " + JSON.stringify(man.errors));
  var m = JSON.parse(man.data); note("manifest " + JSON.stringify({ name: m.name, short_name: m.short_name, start_url: m.start_url, scope: m.scope, display: m.display, icons: m.icons.map(function (i) { return i.sizes + " " + i.src; }) }));
  try { note("installability errors " + JSON.stringify((await cdp.send("Page.getInstallabilityErrors")).installabilityErrors)); } catch (e) { note("installability query failed " + e.message); }
  for (var ic of m.icons) { var r = await page.evaluate(function (src) { return new Promise(function (res) { var i = new Image(); i.onload = function () { res(i.naturalWidth + "x" + i.naturalHeight); }; i.onerror = function () { res("failed"); }; i.src = src; }); }, ic.src); note("icon " + ic.src + " " + r); }
  // offline via the browser
  await ctx.setOffline(true);
  await page.reload();
  note("offline reload: title=" + await page.title() + " sections=" + await page.evaluate(function () { return document.querySelectorAll("main section").length + " state=" + JSON.stringify(window.dimoose.state().shown); }));
  var figs = await page.evaluate(function () { var f = document.querySelectorAll("section.active .fig"); return Array.prototype.map.call(f, function (e) { return e.tagName === "IMG" ? "img " + e.naturalWidth : "bg " + getComputedStyle(e).backgroundImage.slice(0, 30); }); });
  note("figures offline: " + JSON.stringify(figs));
  if (!figs.length || figs.some(function (f) { return !/^bg url|^img [1-9]/.test(f); })) bad("offline: the figures of the first couplet are missing");
  if (man.errors.length || !m.name || m.display !== "standalone" || !m.start_url || m.icons.length < 2) bad("offline: the manifest is incomplete");
  await page.click("section.active a.choose"); await page.screenshot({ path: path.join(shots, "offline-" + file + ".png") });
  await ctx.setOffline(false);
  // server stopped
  srv.kill(); srv = null; await sleep(500);
  var p2 = await ctx.newPage();
  var resp = await p2.goto(url + "#c-3").catch(function (e) { return "FAILED " + e.message; });
  note("server stopped, new tab: " + (typeof resp === "string" ? resp : resp.status() + " fromSW=" + resp.fromServiceWorker()) + " state=" + await p2.evaluate(function () { return window.dimoose && window.dimoose.state().shown; }).catch(function () { return "none"; }));
  await p2.screenshot({ path: path.join(shots, "offline-stopped-" + file + ".png") });
  var after = await p2.evaluate(function () { return window.dimoose && window.dimoose.state().shown; }).catch(function () { return null; });
  if (after !== "c-3") bad("with the server stopped the stored page did not open at #c-3");
  await browser.close();
  console.log(problems.length + " problems");
  process.exit(problems.length ? 1 : 0);
})().catch(function (e) { console.error(e); if (srv) srv.kill(); process.exit(1); });
