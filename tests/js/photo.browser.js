// Manual check of "Identify from a photo" in a real browser: not run by the
// test suite. It serves a folder with python3 -m http.server, opens a page
// written by exportWizard(photoModel = ) in headless Chrome at phone width,
// feeds photos through the file input and prints, per photo, the taxa the
// page ranks first, the time taken and the memory of the page's process.
//
//   mkdir -p "$TMPDIR/dimoose-browser" && cd "$TMPDIR/dimoose-browser" && npm install playwright-core
//   NODE_PATH="$TMPDIR/dimoose-browser/node_modules" node photo.browser.js <site dir> <page.html> <out.json> <photo>...
//
// Uses Google Chrome if it is installed (DIMOOSE_CHROME names another
// executable), else the Chromium of `npx playwright install chromium`. Exits
// with status 0 and the word "skipped" when playwright-core or a browser is
// missing. Screenshots go next to <out.json>.
var cp = require("child_process");
var fs = require("fs");
var path = require("path");

var pw;
try { pw = require("playwright-core"); } catch (e) { console.log("skipped: playwright-core is not installed"); process.exit(0); }

var site = process.argv[2], pageName = process.argv[3], outFile = process.argv[4], photos = process.argv.slice(5);
if (!site || !pageName || !outFile || !photos.length) {
  console.error("usage: node photo.browser.js <site dir> <page.html> <out.json> <photo>...");
  process.exit(2);
}
var port = +process.env.DIMOOSE_PORT || 8741;
var shots = path.dirname(outFile);
function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

function launch() {
  var tries = [];
  if (process.env.DIMOOSE_CHROME) tries.push({ headless: true, executablePath: process.env.DIMOOSE_CHROME });
  tries.push({ headless: true, channel: "chrome" }, { headless: true });
  return tries.reduce(function (p, opts) {
    return p["catch"](function () { return pw.chromium.launch(opts); });
  }, Promise.reject(new Error("none")));
}

function rssOf(pid) {
  try { return +cp.execSync("ps -o rss= -p " + pid, { encoding: "utf8" }).trim() * 1024; } catch (e) { return 0; }
}

(async function () {
  var browser;
  try { browser = await launch(); } catch (e) { console.log("skipped: no browser (" + String(e.message).split("\n")[0] + ")"); process.exit(0); }
  var server = cp.spawn("python3", ["-m", "http.server", String(port), "--bind", "127.0.0.1", "--directory", site], { stdio: "ignore" });
  await sleep(800);
  var report = { browser: browser.version(), page: pageName, errors: [], photos: [] };
  try {
    var ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
    var page = await ctx.newPage();
    page.on("console", function (m) {
      if (m.type() === "error" && !/favicon/.test(m.location().url || "")) report.errors.push("console: " + m.text());
    });
    page.on("pageerror", function (e) { report.errors.push("page: " + e.message); });
    var requests = [];
    page.on("requestfinished", function (r) { requests.push(r.url()); });

    // memory of the page's own process, sampled while it works
    var cdp = await browser.newBrowserCDPSession();
    var peak = 0, sampling = true;
    async function rendererRss() {
      var info = await cdp.send("SystemInfo.getProcessInfo");
      var most = 0;
      info.processInfo.forEach(function (p) { if (p.type === "renderer") most = Math.max(most, rssOf(p.id)); });
      return most;
    }
    (async function () {
      while (sampling) {
        try { peak = Math.max(peak, await rendererRss()); } catch (e) { /* browser closing */ }
        await sleep(200);
      }
    })();

    await page.goto("http://localhost:" + port + "/" + pageName);
    report.memoryBefore = await rendererRss();
    await page.screenshot({ path: path.join(shots, "photo-1-idle.png") });
    report.idle = await page.evaluate(function () {
      var box = document.getElementById("mk-photo"), input = document.getElementById("mk-photo-file");
      return { buttons: Array.prototype.map.call(box.querySelectorAll("button"), function (b) { return b.textContent; }),
               accept: input.accept, capture: input.getAttribute("capture"), hint: box.querySelector(".photo-hint").textContent };
    });

    // first photo: the page asks before it downloads anything large
    await page.setInputFiles("#mk-photo-file", photos[0]);
    await page.waitForFunction(function () { return window.dimoose.photo.state() === "ask"; }, null, { timeout: 30000 });
    report.ask = await page.textContent("#mk-photo .photo-status");
    report.fetchedBeforeConsent = requests.filter(function (u) { return /\.onnx|ort[.-]/.test(u); });
    await page.screenshot({ path: path.join(shots, "photo-2-ask.png") });
    var t0 = Date.now(), sawProgress = "";
    await page.click("#mk-photo .photo-load");
    for (;;) {
      var s = await page.evaluate(function () { return [window.dimoose.photo.state(), document.querySelector("#mk-photo .photo-status").textContent]; });
      if (s[0] === "loading" && /of \d+ MB/.test(s[1]) && !sawProgress) {
        sawProgress = s[1];
        await page.screenshot({ path: path.join(shots, "photo-3-loading.png") });
      }
      if (s[0] === "done" || s[0] === "error") break;
      if (Date.now() - t0 > 300000) throw new Error("no result after 5 minutes: " + s.join(" "));
      await sleep(50);
    }
    report.progressSeen = sawProgress;
    report.firstRunMs = Date.now() - t0;
    report.stateAfterFirst = await page.evaluate(function () { return window.dimoose.photo.state() + ": " + document.querySelector("#mk-photo .photo-status").textContent; });
    await page.screenshot({ path: path.join(shots, "photo-4-result.png"), fullPage: true });

    async function read(file, ms) {
      return {
        photo: path.basename(file), ms: ms,
        status: await page.textContent("#mk-photo .photo-status"),
        top: await page.evaluate(function () {
          return (window.dimoose.photo.result() || []).slice(0, 5).map(function (x) {
            return { taxon: x.taxon, score: Math.round(x.score * 1e4) / 1e4, similarity: Math.round(x.similarity * 1e4) / 1e4 };
          });
        }),
        marked: await page.$$eval(".mnode.mleaf.likely", function (n) { return n.length; }),
        listed: await page.$$eval("#mk-likely li", function (li) { return li.map(function (x) { return x.textContent; }); })
      };
    }
    report.photos.push(await read(photos[0], null));

    // the rest: the model is loaded, so this is the time per photo
    for (var i = 0; i < photos.length; i++) {
      var t = Date.now();
      await page.evaluate(function () { window.__before = window.dimoose.photo.result(); });
      await page.setInputFiles("#mk-photo-file", photos[i]);
      await page.waitForFunction(function () {
        var st = window.dimoose.photo.state();
        return (st === "done" && window.dimoose.photo.result() !== window.__before) || st === "error";
      }, null, { timeout: 120000, polling: 20 });
      var r = await read(photos[i], Date.now() - t);
      if (i === 0) report.photos[0].ms = r.ms;
      else report.photos.push(r);
    }

    // jump to the best result, then narrow the key and confirm with a couplet
    await page.click("#mk-photo .photo-go");
    report.jump = await page.evaluate(function () { return window.dimoose.state().shown + " " + document.querySelector("section.active h2").textContent; });
    await page.click("#mk-back");
    await page.click("#mk-photo .photo-narrow");
    report.narrow = await page.evaluate(function () {
      var s = window.dimoose.state();
      return { shown: s.shown, narrowed: s.narrowed, remaining: s.remaining, count: document.getElementById("mk-left").textContent,
               greyed: document.querySelectorAll("section.active li.lead.unlikely").length, note: document.querySelector("#mk-narrow p").textContent };
    });
    await page.screenshot({ path: path.join(shots, "photo-5-narrowed.png"), fullPage: true });
    await page.click("section.active li.lead:not(.unlikely) a.choose");
    report.afterLead = await page.evaluate(function () { return window.dimoose.state(); });
    await page.click("#mk-maptoggle");
    await page.screenshot({ path: path.join(shots, "photo-6-narrowed-map.png") });
    await page.click("#mk-narrow .narrow-clear");
    report.cleared = await page.evaluate(function () { return window.dimoose.state().narrowed; });
    report.scroll = await page.evaluate(function () { return [document.documentElement.scrollWidth, window.innerWidth]; });

    sampling = false;
    report.memoryPeak = peak;
    report.memoryAfter = await rendererRss();
    report.runtimeFrom = requests.filter(function (u) { return /ort[.-]/.test(u); });
  } catch (e) {
    report.errors.push("script: " + (e.stack || e.message));
  }
  sampling = false;
  fs.writeFileSync(outFile, JSON.stringify(report, null, 1));
  await browser.close();
  server.kill();
  var ms = report.photos.map(function (p) { return p.ms; }).filter(Boolean).sort(function (a, b) { return a - b; });
  console.log(report.photos.length + " photos, median " + (ms.length ? ms[Math.floor(ms.length / 2)] : "?") + " ms per photo, first run " +
    report.firstRunMs + " ms, peak memory " + Math.round((report.memoryPeak || 0) / 1e6) + " MB, " + report.errors.length + " errors");
  report.errors.forEach(function (e) { console.log("error: " + e); });
  process.exit(report.errors.length ? 1 : 0);
})();
