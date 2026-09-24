<?php
/**
 * gig.php — Deep link landing page for reskindev.com/gig/{id}
 *
 * Upload to: reskindev.com/gig/index.php
 * Requires .htaccess rewrite rule:
 *   RewriteRule ^gig/([^/]+)/?$ /gig/index.php [L,QSA]
 *
 * Firebase Project : reskindev-769d3
 * Firestore Collection: services
 */

// ─── Configuration ────────────────────────────────────────────────────────────
define('FIREBASE_PROJECT_ID', 'reskindev-769d3');
define('FIREBASE_API_KEY',    'AIzaSyCUnsddGBcU-_ncIPcht3KfHPuvgl8cPEo');
define('ANDROID_PACKAGE',     'com.reskindevdotcom.reskindev');
define('IOS_BUNDLE',          'com.reskindevdotcom.reskindev');
define('APP_SCHEME',          'reskindev');
define('SITE_BASE_URL',       'https://reskindev.com');
define('PRIMARY_COLOR',       '#1DBF73');

// ─── Parse Gig ID from URL ────────────────────────────────────────────────────
$request_uri = $_SERVER['REQUEST_URI'] ?? '';
$gig_id = '';

// Extract from path: /gig/{id}
if (preg_match('#/gig/([^/?#]+)#', $request_uri, $matches)) {
    $gig_id = trim($matches[1]);
}

// Fallback to query param
if (empty($gig_id) && isset($_GET['id'])) {
    $gig_id = trim($_GET['id']);
}

$gig_id = preg_replace('/[^a-zA-Z0-9_\-]/', '', $gig_id);

if (empty($gig_id)) {
    http_response_code(400);
    die('Missing gig ID.');
}

// ─── Fetch from Firestore REST API ───────────────────────────────────────────
$firestore_url = sprintf(
    'https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/services/%s?key=%s',
    FIREBASE_PROJECT_ID,
    urlencode($gig_id),
    FIREBASE_API_KEY
);

$ctx = stream_context_create([
    'http' => [
        'method'  => 'GET',
        'timeout' => 8,
        'header'  => "Accept: application/json\r\n",
        'ignore_errors' => true,
    ],
    'ssl' => ['verify_peer' => true],
]);

$raw  = @file_get_contents($firestore_url, false, $ctx);
$data = $raw ? json_decode($raw, true) : null;

// ─── Handle 404 / Error ───────────────────────────────────────────────────────
if (!$data || isset($data['error'])) {
    http_response_code(404);
    render_404($gig_id);
    exit;
}

// ─── Helpers: parse Firestore field types ────────────────────────────────────
function fs_string(array $data, string $field): string {
    return $data['fields'][$field]['stringValue'] ?? '';
}
function fs_number(array $data, string $field): ?float {
    if (isset($data['fields'][$field]['doubleValue']))  return (float)$data['fields'][$field]['doubleValue'];
    if (isset($data['fields'][$field]['integerValue'])) return (float)$data['fields'][$field]['integerValue'];
    return null;
}
function h(string $s): string {
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

// ─── Parse Document ───────────────────────────────────────────────────────────
$title       = fs_string($data, 'title')       ?: 'Untitled Gig';
$description = fs_string($data, 'description') ?: 'Check out this gig on ReskinDev.';
$image_url   = fs_string($data, 'imageUrl')    ?: '';
$seller      = fs_string($data, 'sellerName')  ?: fs_string($data, 'userName') ?: '';
$category    = fs_string($data, 'category')    ?: '';

// Starting price from packages[0].price
$starting_price = null;
$packages_array = $data['fields']['packages']['arrayValue']['values'] ?? [];
if (!empty($packages_array)) {
    $first_pkg = $packages_array[0]['mapValue']['fields'] ?? [];
    if (isset($first_pkg['price']['doubleValue']))  $starting_price = (float)$first_pkg['price']['doubleValue'];
    elseif (isset($first_pkg['price']['integerValue'])) $starting_price = (float)$first_pkg['price']['integerValue'];
}
if ($starting_price === null) {
    $starting_price = fs_number($data, 'price') ?? fs_number($data, 'startingPrice');
}

$price_display = ($starting_price !== null) ? '$' . number_format($starting_price, 2) : null;

// ─── Build URLs ───────────────────────────────────────────────────────────────
$page_url   = SITE_BASE_URL . '/gig/' . urlencode($gig_id);
$app_link   = APP_SCHEME . '://gig/' . urlencode($gig_id);
$play_store = 'https://play.google.com/store/apps/details?id=' . ANDROID_PACKAGE;
$app_store  = 'https://apps.apple.com/app/' . IOS_BUNDLE;

$og_description = mb_strlen($description) > 200
    ? mb_substr($description, 0, 197) . '...'
    : $description;

// ─── 404 render function ──────────────────────────────────────────────────────
function render_404(string $gig_id): void { ?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>Gig Not Found — ReskinDev</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f7f7f7;
     color:#333;display:flex;align-items:center;justify-content:center;min-height:100vh}
.card{background:#fff;border-radius:16px;padding:48px 36px;max-width:400px;text-align:center;
      box-shadow:0 4px 24px rgba(0,0,0,.08)}
h1{font-size:1.6rem;margin-bottom:12px;color:#222}
p{color:#666;line-height:1.6;margin-bottom:24px}
a{display:inline-block;background:#1DBF73;color:#fff;padding:12px 28px;border-radius:8px;
  text-decoration:none;font-weight:600;font-size:.95rem}
</style>
</head>
<body>
<div class="card">
  <div style="font-size:3rem;margin-bottom:16px">🔍</div>
  <h1>Gig Not Found</h1>
  <p>The gig you're looking for (<code><?= h($gig_id) ?></code>) doesn't exist or has been removed.</p>
  <a href="<?= SITE_BASE_URL ?>">Browse ReskinDev</a>
</div>
</body>
</html>
<?php }

// ─── Main Page ────────────────────────────────────────────────────────────────
?>
<!DOCTYPE html>
<html lang="en" prefix="og: https://ogp.me/ns#">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0,viewport-fit=cover"/>
<title><?= h($title) ?> — ReskinDev</title>

<!-- Open Graph -->
<meta property="og:type"         content="website"/>
<meta property="og:site_name"    content="ReskinDev"/>
<meta property="og:title"        content="<?= h($title) ?>"/>
<meta property="og:description"  content="<?= h($og_description) ?>"/>
<meta property="og:url"          content="<?= h($page_url) ?>"/>
<?php if ($image_url): ?>
<meta property="og:image"        content="<?= h($image_url) ?>"/>
<meta property="og:image:width"  content="1200"/>
<meta property="og:image:height" content="630"/>
<?php endif; ?>

<!-- Twitter Card -->
<meta name="twitter:card"        content="summary_large_image"/>
<meta name="twitter:title"       content="<?= h($title) ?>"/>
<meta name="twitter:description" content="<?= h($og_description) ?>"/>
<?php if ($image_url): ?>
<meta name="twitter:image"       content="<?= h($image_url) ?>"/>
<?php endif; ?>

<!-- App link meta -->
<meta name="google-play-app" content="app-id=<?= h(ANDROID_PACKAGE) ?>"/>
<meta name="apple-itunes-app" content="app-id=<?= h(IOS_BUNDLE) ?>, app-argument=<?= h($app_link) ?>"/>
<link rel="canonical" href="<?= h($page_url) ?>"/>

<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --green:#1DBF73;--green-dark:#17a362;--text:#222;--muted:#6b7280;
  --bg:#f4f5f7;--card-bg:#ffffff;--radius:14px;--shadow:0 4px 32px rgba(0,0,0,.10)
}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;
     background:var(--bg);color:var(--text);min-height:100vh;display:flex;flex-direction:column}

/* Banner */
#app-banner{display:none;position:sticky;top:0;z-index:100;background:#fff;
  border-bottom:1px solid #e5e7eb;padding:12px 16px;align-items:center;gap:12px}
#app-banner .b-icon{width:44px;height:44px;border-radius:10px;background:var(--green);
  display:flex;align-items:center;justify-content:center;flex-shrink:0}
#app-banner .b-icon svg{width:24px;height:24px;fill:#fff}
#app-banner .b-text{flex:1}
#app-banner .b-text strong{display:block;font-size:.88rem;color:var(--text)}
#app-banner .b-text span{font-size:.78rem;color:var(--muted)}
.btn-open{background:var(--green);color:#fff;border:none;border-radius:20px;
  padding:8px 18px;font-size:.85rem;font-weight:700;cursor:pointer;
  white-space:nowrap;text-decoration:none}
.btn-close{background:none;border:none;color:var(--muted);font-size:1.2rem;
  cursor:pointer;padding:4px;line-height:1}

/* Layout */
.container{max-width:680px;margin:0 auto;padding:24px 16px 48px;flex:1}
.site-header{display:flex;align-items:center;gap:10px;margin-bottom:28px}
.logo-mark{width:36px;height:36px;border-radius:8px;background:var(--green);
  display:flex;align-items:center;justify-content:center}
.logo-mark svg{width:20px;height:20px;fill:#fff}
.brand{font-size:1.1rem;font-weight:700;color:var(--text);text-decoration:none}

/* Card */
.card{background:var(--card-bg);border-radius:var(--radius);box-shadow:var(--shadow);overflow:hidden}
.gig-image{width:100%;aspect-ratio:16/9;object-fit:cover;display:block;background:#e5e7eb}
.gig-placeholder{width:100%;aspect-ratio:16/9;background:linear-gradient(135deg,#e5f7ee,#d1f0df);
  display:flex;align-items:center;justify-content:center}
.gig-placeholder svg{width:64px;height:64px;opacity:.4;fill:#1DBF73}
.card-body{padding:24px}

.badge{display:inline-block;background:#e8faf2;color:var(--green-dark);font-size:.72rem;
  font-weight:700;letter-spacing:.06em;text-transform:uppercase;padding:3px 10px;
  border-radius:20px;margin-bottom:12px}

h1.gig-title{font-size:clamp(1.1rem,3vw,1.45rem);font-weight:700;color:var(--text);
  line-height:1.35;margin-bottom:12px}

.seller-row{display:flex;align-items:center;gap:8px;margin-bottom:16px;
  color:var(--muted);font-size:.85rem}
.seller-avatar{width:28px;height:28px;border-radius:50%;background:var(--green);
  color:#fff;display:flex;align-items:center;justify-content:center;
  font-size:.75rem;font-weight:700;flex-shrink:0}

.gig-desc{color:#444;font-size:.92rem;line-height:1.65;margin-bottom:20px;
  display:-webkit-box;-webkit-line-clamp:4;-webkit-box-orient:vertical;overflow:hidden}

.action-row{display:flex;align-items:center;justify-content:space-between;gap:16px;
  flex-wrap:wrap;padding-top:20px;border-top:1px solid #f0f0f0}
.price-block .label{font-size:.72rem;color:var(--muted);text-transform:uppercase;
  letter-spacing:.05em;margin-bottom:2px}
.price-block .amount{font-size:1.6rem;font-weight:800;color:var(--text)}
.price-block .amount span{font-size:.85rem;font-weight:500;color:var(--muted)}

.btn-primary{display:inline-flex;align-items:center;gap:8px;background:var(--green);
  color:#fff;text-decoration:none;padding:13px 28px;border-radius:10px;font-weight:700;
  font-size:.97rem;border:none;cursor:pointer;transition:background .18s,transform .12s;
  -webkit-tap-highlight-color:transparent}
.btn-primary:hover{background:var(--green-dark)}
.btn-primary:active{transform:scale(.97)}
.btn-primary svg{width:18px;height:18px;fill:#fff;flex-shrink:0}

.store-links{display:flex;gap:10px;flex-wrap:wrap;justify-content:center;margin-top:20px}
.store-links a{display:flex;align-items:center;gap:7px;background:#111;color:#fff;
  text-decoration:none;padding:9px 18px;border-radius:9px;font-size:.8rem;font-weight:600}
.store-links a svg{width:18px;height:18px;fill:#fff}

.page-footer{text-align:center;padding:24px 16px;font-size:.8rem;color:var(--muted)}
.page-footer a{color:var(--green);text-decoration:none}

@media(max-width:480px){
  .action-row{flex-direction:column;align-items:stretch}
  .btn-primary{justify-content:center;width:100%}
}
</style>
</head>
<body>

<!-- Smart App Banner (mobile only) -->
<div id="app-banner" role="banner">
  <div class="b-icon">
    <svg viewBox="0 0 24 24"><path d="M17 1.01L7 1c-1.1 0-2 .9-2 2v18c0 1.1.9 2 2
      2h10c1.1 0 2-.9 2-2V3c0-1.1-.9-1.99-2-1.99zM17 19H7V5h10v14z"/></svg>
  </div>
  <div class="b-text">
    <strong>ReskinDev</strong>
    <span>Open in the app for the best experience</span>
  </div>
  <a id="btn-open-app" class="btn-open" href="<?= h($app_link) ?>">Open</a>
  <button class="btn-close" id="btn-close-banner" aria-label="Dismiss">&times;</button>
</div>

<div class="container">
  <header class="site-header">
    <div class="logo-mark">
      <svg viewBox="0 0 24 24"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2
        12l10 5 10-5"/></svg>
    </div>
    <a href="<?= h(SITE_BASE_URL) ?>" class="brand">ReskinDev</a>
  </header>

  <div class="card">
    <?php if ($image_url): ?>
    <img class="gig-image" src="<?= h($image_url) ?>" alt="<?= h($title) ?>" loading="eager"
      onerror="this.style.display='none';document.getElementById('imgph').style.display='flex'"/>
    <div id="imgph" class="gig-placeholder" style="display:none">
      <svg viewBox="0 0 24 24"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2
        2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5
        12l4.5 6H5l3.5-4.5z"/></svg>
    </div>
    <?php else: ?>
    <div class="gig-placeholder">
      <svg viewBox="0 0 24 24"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2
        2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5
        12l4.5 6H5l3.5-4.5z"/></svg>
    </div>
    <?php endif; ?>

    <div class="card-body">
      <?php if ($category): ?>
      <div class="badge"><?= h($category) ?></div>
      <?php endif; ?>

      <h1 class="gig-title"><?= h($title) ?></h1>

      <?php if ($seller): ?>
      <div class="seller-row">
        <div class="seller-avatar"><?= h(mb_strtoupper(mb_substr($seller, 0, 1))) ?></div>
        <span>by <strong><?= h($seller) ?></strong></span>
      </div>
      <?php endif; ?>

      <?php if ($description): ?>
      <p class="gig-desc"><?= h($description) ?></p>
      <?php endif; ?>

      <div class="action-row">
        <?php if ($price_display): ?>
        <div class="price-block">
          <div class="label">Starting at</div>
          <div class="amount"><?= h($price_display) ?> <span>/ package</span></div>
        </div>
        <?php else: ?>
        <div></div>
        <?php endif; ?>

        <a id="btn-cta" class="btn-primary"
           href="<?= h($app_link) ?>"
           data-play="<?= h($play_store) ?>"
           data-store="<?= h($app_store) ?>">
          <svg viewBox="0 0 24 24"><path d="M17 1.01L7 1c-1.1 0-2 .9-2 2v18c0
            1.1.9 2 2 2h10c1.1 0 2-.9 2-2V3c0-1.1-.9-1.99-2-1.99zM17
            19H7V5h10v14z"/></svg>
          Open in App
        </a>
      </div>
    </div>
  </div>

  <!-- Download store links (always visible as fallback) -->
  <div class="store-links">
    <a href="<?= h($play_store) ?>" target="_blank" rel="noopener noreferrer">
      <svg viewBox="0 0 24 24"><path d="M3 20.5v-17c0-.83.94-1.3 1.6-.8l14
        8.5c.6.36.6 1.24 0 1.6l-14 8.5c-.66.5-1.6.03-1.6-.8z"/></svg>
      Google Play
    </a>
    <a href="<?= h($app_store) ?>" target="_blank" rel="noopener noreferrer">
      <svg viewBox="0 0 24 24"><path d="M18.71 19.5c-.83 1.24-1.71
        2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2
        .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94
        12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02
        2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26
        3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65
        4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83
        1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83
        1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
      App Store
    </a>
  </div>
</div>

<footer class="page-footer">
  <p>Shared via <a href="<?= h(SITE_BASE_URL) ?>">ReskinDev</a> &nbsp;&middot;&nbsp;
  Download the app free on
  <a href="<?= h($play_store) ?>" target="_blank" rel="noopener">Android</a> &amp;
  <a href="<?= h($app_store) ?>" target="_blank" rel="noopener">iOS</a></p>
</footer>

<script>
(function(){
  'use strict';
  var APP_LINK  = <?= json_encode($app_link) ?>;
  var PLAY_URL  = <?= json_encode($play_store) ?>;
  var STORE_URL = <?= json_encode($app_store) ?>;

  function isMobile(){ return /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent); }
  function isAndroid(){ return /Android/i.test(navigator.userAgent); }
  function isIOS(){ return /iPhone|iPad|iPod/i.test(navigator.userAgent); }

  function tryOpenApp(fallbackUrl){
    var start = Date.now();
    var timer = setTimeout(function(){
      if(Date.now() - start < 3000){ window.location.href = fallbackUrl; }
    }, 2500);
    window.addEventListener('focus', function(){ clearTimeout(timer); }, {once:true});
    document.addEventListener('visibilitychange', function(){
      if(!document.hidden){ clearTimeout(timer); }
    }, {once:true});
    window.location.href = APP_LINK;
  }

  // Show banner on mobile
  if(isMobile()){
    var banner = document.getElementById('app-banner');
    if(banner) banner.style.display = 'flex';
  }

  // Main CTA
  var btnCTA = document.getElementById('btn-cta');
  if(btnCTA){
    btnCTA.addEventListener('click', function(e){
      if(isMobile()){
        e.preventDefault();
        tryOpenApp(isIOS() ? STORE_URL : PLAY_URL);
      }
    });
  }

  // Banner Open
  var btnOpen = document.getElementById('btn-open-app');
  if(btnOpen){
    btnOpen.addEventListener('click', function(e){
      e.preventDefault();
      tryOpenApp(isIOS() ? STORE_URL : PLAY_URL);
    });
  }

  // Banner close
  var btnClose = document.getElementById('btn-close-banner');
  if(btnClose){
    btnClose.addEventListener('click', function(){
      var b = document.getElementById('app-banner');
      if(b) b.style.display = 'none';
    });
  }

  // Auto-redirect on mobile when opened via referrer (shared link)
  if(isMobile() && document.referrer && document.referrer !== window.location.href){
    tryOpenApp(isIOS() ? STORE_URL : PLAY_URL);
  }
})();
</script>
</body>
</html>
