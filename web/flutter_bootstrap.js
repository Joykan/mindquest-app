{{flutter_js}}
{{flutter_build_config}}

// MindQuest's own start-up script (Flutter fills in the two lines above when
// building). It starts the app, removes the loading screen, and sets up the
// offline cache in sw.js instead of Flutter's own service worker.

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const loading = document.getElementById('loading');
    if (loading) loading.remove();
    startOfflineCache();
  },
});

// Saves the app's files in the browser so MindQuest still opens without
// internet (proposal NFR 6: works under low bandwidth, PWA caching).
function startOfflineCache() {
  if (!('serviceWorker' in navigator)) return;
  navigator.serviceWorker
    .register('sw.js')
    .then(function () { return navigator.serviceWorker.ready; })
    .then(function (registration) {
      // Files loaded before the cache was ready (the app itself, fonts,
      // pictures) are saved too, a few seconds after start-up.
      setTimeout(function () {
        const urls = performance
          .getEntriesByType('resource')
          .map(function (e) { return e.name; });
        urls.push(new URL('./', document.baseURI).href);
        if (registration.active) {
          registration.active.postMessage({ type: 'cache', urls: urls });
        }
      }, 5000);
    })
    .catch(function (e) { console.warn('Offline cache not available:', e); });
}
