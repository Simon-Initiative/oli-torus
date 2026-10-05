export function isSignedOutUrl(url: URL) {
  return url.pathname === '/' || /^\/authors\/log_in/.test(url.pathname);
}
