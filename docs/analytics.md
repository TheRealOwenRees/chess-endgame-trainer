# Analytics

We use a self-hosted Matomo instance for privacy-conscious analytics on public
pages and the guest trainer.

## What is collected

- Page views on anonymous public pages and the guest trainer.
- Standard request data Matomo needs to count a visit, with IP anonymisation.

We do **not**:

- set Matomo cookies,
- use user IDs,
- track signed-in account, profile, or admin pages,
- enable cross-site or advertising features,
- share analytics data with third parties.

## Configuration

The app reads these environment variables at boot:

```sh
MATOMO_URL=https://analytics.owenrees.eu/
MATOMO_SITE_ID=6
```

They are configured in `config/runtime.exs` for production only. If either is
missing, no analytics config is rendered and no tracker is loaded.

The root layout renders a hidden `#matomo-config` element only when the visitor
is anonymous. `assets/js/analytics.js` initialises Matomo cookieless from that
element. Signed-in users never receive the element.

## Matomo settings

In the Matomo administration UI:

1. **Administration → Websites → Manage**
   - URL: `https://innersquare.app`
   - Site ID: `6`
   - Timezone: match the site
2. **Administration → Privacy → Anonymize data**
   - Enable IP anonymisation (at least the last byte; 2 bytes is safer)
   - Disable tracking cookies
   - Respect Do Not Track
   - Do not use user IDs
   - Set raw data retention to **180 days**
3. **Administration → System check / trusted hosts**
   - Add `innersquare.app` and `www.innersquare.app` if host validation is on.
4. Do not enable ecommerce, advertising, or cross-domain tracking.

The JavaScript also calls:

```js
_paq.push(["disableCookies"]);
_paq.push(["setDoNotTrack", true]);
```

## Opt-out

The privacy page has an **Analytics** section with an opt-out control. The
preference is stored in `localStorage["matomo_optout"]`, not a cookie. When set,
the tracker is never loaded and LiveView page views are skipped.

The preference is local to the browser. Clearing site data resets it. Users can
also object by emailing `support@innersquare.app`.

## Verification

On an anonymous public page:

```sh
curl -s https://innersquare.app/ | grep -c matomo-config
```

should return `1`.

In the browser:

- `matomo.js` and `matomo.php` load once.
- Matomo Real-time shows the page view.
- No `_pk_*` cookies are created.
- Opting out sets `matomo_optout=1` in localStorage and stops further requests.
- Signed-in pages produce no Matomo config or requests.
- A DNT browser setting suppresses tracking.

## Legal basis

Analytics runs on the basis of legitimate interests in improving the service.
The privacy policy discloses it, explains the data, and provides the opt-out.
This document is an engineering configuration guide, not legal advice; keep a
short legitimate-interest assessment on file.
