export function isSignedOutUrl(url: URL) {
  return url.pathname === '/' || url.pathname === '/authors/log_in';
}
