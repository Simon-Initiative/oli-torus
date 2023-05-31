// update server session timezone if timezone has not already been set for this browser session
const browser_timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;

fetch('/timezone', {
  method: 'post',
  headers: {
    Accept: 'application/json, text/plain, */*',
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ browser_timezone }),
})
  .then((_res) => {
    sessionStorage.setItem('browser_timezone', browser_timezone);
    console.log('local timezone information updated', browser_timezone);
  })
  .catch((_res) => console.error('failed to update local timezone information', browser_timezone));

export {};
