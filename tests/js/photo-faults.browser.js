// Manual check of "Identify from a photo" when things go wrong and without a
// connection, in a real browser: not run by the test suite. It serves a
// folder with python3 -m http.server and drives headless Chrome through
//   photo-offline.html  exportWizard(montanaKey(), "photo-offline.html", photoModel = <folder>, offline = TRUE):
//                       first use with a connection, then a reload and a photo with the network cut
//   photo.html          exportWizard(montanaKey(), "photo.html", photoModel = <folder>):
//                       the encoder cannot be fetched (then can), model.json is missing, no WebAssembly,
//                       a file that is no picture, and the desktop page by keyboard
// and prints what the page said each time. Read the lines; it exits 1 only
// when the script itself fails.
//
//   mkdir -p "$TMPDIR/dimoose-browser" && cd "$TMPDIR/dimoose-browser" && npm install playwright-core
//   NODE_PATH="$TMPDIR/dimoose-browser/node_modules" node photo-faults.browser.js <site dir> <screenshot dir> <photo>
//
// Uses Google Chrome if it is installed (DIMOOSE_CHROME names another
// executable), else the Chromium of `npx playwright install chromium`. Exits
// with status 0 and the word "skipped" when playwright-core or a browser is
// missing. The first use fetches onnxruntime-web from its CDN.
var cp = require("child_process"), path = require("path"), fs = require("fs");
var pw;
try { pw = require("playwright-core"); } catch (e) { console.log("skipped: playwright-core is not installed"); process.exit(0); }
var site = process.argv[2], shots = process.argv[3], photo = process.argv[4], port = +process.env.DIMOOSE_PORT || 8745;
if (!site || !shots || !photo) { console.error("usage: node photo-faults.browser.js <site dir> <screenshot dir> <photo>"); process.exit(2); }
fs.mkdirSync(shots, { recursive: true });
var srv = null;
function launch() {
  var tries = [];
  if (process.env.DIMOOSE_CHROME) tries.push({ headless: true, executablePath: process.env.DIMOOSE_CHROME });
  tries.push({ headless: true, channel: "chrome" }, { headless: true });
  return tries.reduce(function (p, opts) {
    return p["catch"](function () { return pw.chromium.launch(opts); });
  }, Promise.reject(new Error("none")));
}
function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
var U = "http://localhost:" + port + "/";
async function waitState(page, want, ms) { await page.waitForFunction(function (w) { return w.indexOf(window.dimoose.photo.state()) >= 0; }, want, { timeout: ms || 120000 }); return await page.evaluate(function () { return window.dimoose.photo.state() + ": " + document.querySelector("#mk-photo .photo-status").textContent; }); }
(async function () {
  var browser;
  try { browser = await launch(); } catch (e) { console.log("skipped: no browser (" + String(e.message).split("\n")[0] + ")"); process.exit(0); }
  srv = cp.spawn("python3", ["-m", "http.server", String(port), "--bind", "127.0.0.1", "--directory", site], { stdio: "ignore" });
  await sleep(800);
  // 1. offline build: first use online, then without network
  var ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  var page = await ctx.newPage();
  page.on("console", function (m) { if (m.type() === "error" && !/favicon/.test(m.location().url)) console.log("  console error: " + m.text().slice(0, 200)); });
  page.on("pageerror", function (e) { console.log("  pageerror " + e.message); });
  await page.goto(U + "photo-offline.html");
  await page.waitForFunction(function () { var n = document.getElementById("mk-offline"); return n && !n.hidden; });
  await page.reload();   // now controlled by the worker
  console.log("controlled: " + await page.evaluate(function () { return !!navigator.serviceWorker.controller; }));
  await page.setInputFiles("#mk-photo-file", photo);
  console.log("offline build, first: " + await waitState(page, ["ask", "error"]) + " | hint: " + await page.textContent("#mk-photo .photo-hint"));
  await page.click(".photo-load");
  console.log("  " + await waitState(page, ["done", "error"]));
  await sleep(1500);
  console.log("  caches: " + await page.evaluate(function () { return caches.keys().then(function (ks) { return Promise.all(ks.map(function (k) { return caches.open(k).then(function (c) { return c.keys(); }).then(function (rs) { return k + ": " + rs.map(function (r) { return r.url.split("/").pop(); }).join(","); }); })); }).then(function (x) { return x.join(" | "); }); }));
  console.log("  storage: " + await page.evaluate(function () { return navigator.storage.estimate().then(function (e) { return Math.round(e.usage / 1e6) + " MB used"; }); }));
  await ctx.setOffline(true);
  await page.reload();
  var t = Date.now();
  await page.setInputFiles("#mk-photo-file", photo);
  console.log("network cut, reload, photo: " + await waitState(page, ["done", "error", "ask"]) + " in " + (Date.now() - t) + " ms");
  await page.screenshot({ path: path.join(shots, "photo-offline-result.png") });
  await ctx.setOffline(false);
  await ctx.close();

  // 2. failures
  ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
  page = await ctx.newPage();
  await ctx.route("**/photo_model/image_encoder.onnx", function (r) { r.abort(); });
  await page.goto(U + "photo.html");
  await page.setInputFiles("#mk-photo-file", photo);
  await waitState(page, ["ask"]); await page.click(".photo-load");
  console.log("encoder fetch fails: " + await waitState(page, ["error", "done"]));
  await page.screenshot({ path: path.join(shots, "photo-error.png") });
  await page.click("section.active a.choose");
  console.log("  key still works: " + await page.evaluate(function () { return window.dimoose.state().shown; }));
  await ctx.unroute("**/photo_model/image_encoder.onnx");
  await page.click("#mk-restart");
  await page.click(".photo-retry");
  console.log("  retry after the fault is gone: " + await waitState(page, ["error", "done"]));
  await ctx.close();

  ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
  page = await ctx.newPage();
  await ctx.route("**/photo_model/model.json", function (r) { r.fulfill({ status: 404, body: "no" }); });
  await page.goto(U + "photo.html");
  await page.setInputFiles("#mk-photo-file", photo);
  console.log("model.json missing: " + await waitState(page, ["error", "ask"]));
  await ctx.close();

  ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
  page = await ctx.newPage();
  await page.addInitScript(function () { delete window.WebAssembly; Object.defineProperty(window, "WebAssembly", { value: undefined }); });
  await page.goto(U + "photo.html");
  await page.setInputFiles("#mk-photo-file", photo);
  await waitState(page, ["ask", "error"]); if (await page.$(".photo-load")) await page.click(".photo-load");
  console.log("no WebAssembly: " + await waitState(page, ["error", "done"]));
  await ctx.close();

  ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
  page = await ctx.newPage();
  await page.goto(U + "photo.html");
  await page.setInputFiles("#mk-photo-file", path.join(site, "photo.html"));
  await waitState(page, ["ask", "error"]); if (await page.$(".photo-load")) await page.click(".photo-load");
  console.log("not a picture: " + await waitState(page, ["error", "done"]));
  await ctx.close();

  // 3. desktop
  ctx = await browser.newContext({ viewport: { width: 1400, height: 900 } });
  page = await ctx.newPage();
  await page.goto(U + "photo.html");
  await page.screenshot({ path: path.join(shots, "photo-desk-idle.png") });
  console.log("desktop idle buttons: " + await page.$$eval("#mk-photo button", function (b) { return b.map(function (x) { return x.textContent; }).join(" | "); }) + " capture=" + await page.getAttribute("#mk-photo-file", "capture"));
  // keyboard: Tab to the button, Enter opens the chooser
  var stops = [];
  for (var i = 0; i < 6; i++) { await page.keyboard.press("Tab"); stops.push(await page.evaluate(function () { var e = document.activeElement; return e.tagName + "." + (e.className.baseVal != null ? e.className.baseVal : e.className).split(" ")[0]; })); }
  console.log("desktop tab stops: " + stops.join(" > "));
  var chooser = page.waitForEvent("filechooser", { timeout: 5000 }).catch(function () { return null; });
  await page.focus(".photo-pick"); await page.keyboard.press("Enter");
  var fc = await chooser; console.log("Enter on the button opens the file chooser: " + !!fc);
  if (fc) await fc.setFiles(photo);
  await waitState(page, ["ask"]); await page.screenshot({ path: path.join(shots, "photo-desk-ask.png") });
  await page.click(".photo-load"); console.log("desktop: " + await waitState(page, ["done", "error"]));
  await page.screenshot({ path: path.join(shots, "photo-desk-result.png") });
  await page.click(".photo-narrow"); await page.screenshot({ path: path.join(shots, "photo-desk-narrow.png") });
  console.log("desktop narrowed: " + await page.evaluate(function () { return JSON.stringify(window.dimoose.state()); }));
  await page.click(".photo-clear");
  console.log("cleared: " + await page.evaluate(function () { return JSON.stringify([window.dimoose.photo.state(), window.dimoose.state().narrowed, document.querySelectorAll(".likely:not([hidden]) li").length, document.querySelectorAll(".mnode.likely").length]); }));
  console.log("scroll " + await page.evaluate(function () { return document.documentElement.scrollWidth + "/" + window.innerWidth; }));
  await browser.close(); srv.kill();
})().catch(function (e) { console.error(e); if (srv) srv.kill(); process.exit(1); });
