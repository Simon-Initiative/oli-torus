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

// Wait time to renew session set to 10 min. Default Pow session renew is at 15 min
const waitTime = 600000; // 10 min in ms

if (!window.keepAlive) {
  window.keepAlive = () => {
    // Check for which template (delivery or authoring) we're in
    const isAuthoring = $('#layout-id').data('layout-id') === 'authoring';
    const keepAliveUrl = `${isAuthoring ? '/authoring' : ''}/keep-alive`;

    fetch(keepAliveUrl).then((res: any) => {
      if (res.status === 401 || res.status === 302) {
        window.location.href = `${
          isAuthoring ? '/authoring' : ''
        }/session/new?request_path=${encodeURIComponent(window.location.pathname)}`;
      } else {
        setTimeout(window.keepAlive, waitTime);
      }
    });
  };

  window.keepAlive();
}

export {};
