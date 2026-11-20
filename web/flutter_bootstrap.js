{{flutter_js}}
{{flutter_build_config}}

Promise.resolve(_flutter.loader.load({
  config: { canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href },
})).catch(() => window.dispatchEvent(new Event('kingdom-startup-error')));

if (/* kingdom-release */ false && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('pwa_service_worker.js', { updateViaCache: 'none' })
      .catch((error) => console.warn('Kingdom Foundry offline setup failed.', error));
  });
}
