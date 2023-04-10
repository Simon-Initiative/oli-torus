// update server session timezone if timezone has not already been set for this browser session
const local_tz = Intl.DateTimeFormat().resolvedOptions().timeZone;

fetch('/timezone', {
  method: 'post',
  headers: {
    Accept: 'application/json, text/plain, */*',
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ local_tz }),
})
  .then((_res) => {
    sessionStorage.setItem('local_tz', local_tz);
    console.log('local timezone information updated', local_tz);
  })
  .catch((_res) => console.error('failed to update local timezone information', local_tz));

export {};
