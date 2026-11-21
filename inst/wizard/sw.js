// Service worker written by dimoose::exportWizard(offline = TRUE).
// It keeps a copy of the key so the page opens without a connection.
// exportWizard() fills in the values below.
var CACHE = "__CACHE__";              // one cache per version of the page
var PREFIX = "__PREFIX__";            // shared by all versions of this page
var PAGE = "__PAGE__";                // the key itself
var PRECACHE = [/*__PRECACHE__*/];    // files written next to the page
var EXTERNAL = [/*__EXTERNAL__*/];    // figures the page loads from other sites
// The photo model and the program that runs it are large and do not change
// with the page: files under these addresses are kept in a cache of their own
// once fetched, which a new version of the page does not empty.
var KEEP = [/*__KEEP__*/];
var KEPT = "__KEPT__";

function kept(url) {
  for (var i = 0; i < KEEP.length; i++) {
    if (url.indexOf(new URL(KEEP[i], self.location.href).href) === 0) return true;
  }
  return false;
}

function noop() {}

// Figures on other sites: ask with CORS first, because a copy fetched without
// it is opaque and browsers count each opaque copy as several megabytes of
// the storage they allow. Fall back to the opaque copy.
function fetchExternal(url) {
  return fetch(new Request(url, { mode: "cors", credentials: "omit" }))
    .then(function (r) { if (!r.ok) throw new Error("not ok"); return r; })
    ["catch"](function () { return fetch(new Request(url, { mode: "no-cors" })); });
}

function keep(cache, key, response) {
  if (response && (response.ok || response.type === "opaque")) {
    return cache.put(key, response)["catch"](noop);
  }
  return Promise.resolve();
}

self.addEventListener("install", function (event) {
  event.waitUntil(caches.open(CACHE).then(function (cache) {
    // The page and its files must all be stored, or the install fails and is
    // tried again on the next visit. Figures are stored as far as they load.
    return cache.addAll(PRECACHE).then(function () {
      return Promise.all(EXTERNAL.map(function (url) {
        return fetchExternal(url).then(function (r) { return keep(cache, url, r); })["catch"](noop);
      }));
    });
  }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener("activate", function (event) {
  event.waitUntil(caches.keys().then(function (names) {
    return Promise.all(names.map(function (name) {
      // older versions of this page only; other pages keep their caches
      return name !== CACHE && name !== KEPT && name.indexOf(PREFIX) === 0 ? caches["delete"](name) : null;
    }));
  }).then(function () { return self.clients.claim(); }));
});

self.addEventListener("fetch", function (event) {
  var request = event.request;
  if (request.method !== "GET" || !/^https?:/.test(request.url)) return;

  if (request.mode === "navigate") {
    // The page: the newest copy when there is a connection, the stored one otherwise
    event.respondWith(fetch(request).then(function (response) {
      var copy = response.clone();
      caches.open(CACHE).then(function (cache) { return keep(cache, PAGE, copy); });
      return response;
    })["catch"](function () {
      return caches.open(CACHE).then(function (cache) {
        return cache.match(request, { ignoreSearch: true }).then(function (hit) { return hit || cache.match(PAGE); });
      });
    }));
    return;
  }

  // Everything else: the stored copy if there is one; otherwise fetch it, and
  // keep files of this site and figures from other sites for next time.
  // A large file (the photo model) is still being stored when the page
  // has it, so the worker is asked to wait for that.
  var large = kept(request.url);
  event.respondWith(caches.open(large ? KEPT : CACHE).then(function (cache) {
    return cache.match(request).then(function (hit) {
      if (hit) return hit;
      return fetch(request).then(function (response) {
        var sameSite = request.url.indexOf(self.location.origin + "/") === 0;
        if (sameSite || request.destination === "image" || large) {
          var stored = keep(cache, request, response.clone());
          if (event.waitUntil) event.waitUntil(stored);
        }
        return response;
      });
    });
  }));
});
