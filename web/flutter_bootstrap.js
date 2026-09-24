{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    // Signal the loading screen to fade out
    if (window._onFlutterAppLoaded) {
      window._onFlutterAppLoaded();
    }
    
    await appRunner.runApp();
  }
});
