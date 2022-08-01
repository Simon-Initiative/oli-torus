/**
 * If user doesn't request server periodically (few minutes),
 * the session expires and user has to re-login again. If user
 * manages to request server before the time has expired, the
 * cookie is updated and the timer is reset.
 *
 * The problem is that almost the whole website uses LiveView,
 * even for navigation, which means that most of the requests
 * go through WebSockets, where you can't update cookies, and
 * so the session inevitably expires, even if user is actively
 * using the website.
 *
 * As a workaround, we periodically ping the server via a
 * regular AJAX requests, which resets the session cookie timer.
 *
 * More Info: https://github.com/danschultzer/pow/issues/271
 * https://elixirforum.com/t/get-user-id-with-pow-from-session-for-live-view/24206/4
 */

// Wait time set to 15 min which is the deafult time set by Pow to renew sessions (session_ttl_renewal)
const waitTime = 900000 // 15 minutes in ms

if (!window.keepAlive) {
  window.keepAlive = () => {
    // Check for which template (delivery or authoring) we're in
    const is_authoring = $("#layout-id").data("layout-id") === "authoring";
    const keepAliveUrl = `${is_authoring ? '/authoring' : ''}/keep-alive`;

    const wait = (ms: number) => {
      return () =>
        new Promise((resolve) => {
          setTimeout(resolve, ms);
        });
    };

    fetch(keepAliveUrl)
      .then(wait(waitTime))
      .then(window.keepAlive);
  };

  window.keepAlive();
}
