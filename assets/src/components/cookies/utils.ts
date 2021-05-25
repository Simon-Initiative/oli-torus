import { selectCookieConsent } from "components/cookies/CookieConsent";

export type CookieDetails = {
  name: string,
  value: string,
  duration?: number,
  durationUtc?: string,
  expiresIso?: string,
  expiration?: string
};

export const setCookies = (cookies: CookieDetails[]) => {
  cookies.forEach((cookie) => {
    const d = new Date();
    if (cookie.duration)
      d.setTime(d.getTime() + cookie.duration);

    cookie.durationUtc = d.toUTCString();
    cookie.expiresIso = d.toISOString();

    console.log("the cookie " + JSON.stringify(cookie));

    setCookie(cookie.name, cookie.value, cookie.durationUtc);
  })
  persistCookie(cookies);
}

export const consentOptions = () => {
  let optSetCookie = getCookie('_cky_opt_choices');
  let userOptions = {
    necessary: true,
    functionality: true,
    analytics: true,
    targeting: false
  }
  if (optSetCookie !== "") {
    userOptions = JSON.parse(optSetCookie);
  }
  return userOptions;
}

const setCookie = (cname: string, cvalue: string, duration: string) => {
  const expires = "expires=" + duration;
  document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/;SameSite=None; Secure";
}

const getCookie = (cname: string) => {
  const name = cname + "=";
  const decodedCookie = decodeURIComponent(document.cookie);
  const ca = decodedCookie.split(';');
  for (let i = 0; i < ca.length; i++) {
    let c = ca[i];
    while (c.charAt(0) === ' ') {
      c = c.substring(1);
    }
    if (c.indexOf(name) === 0) {
      return c.substring(name.length, c.length);
    }
  }
  return "";
}

const processConsent = () => {
  let optInCookie = getCookie('_cky_opt_in');
  let dismissOptIn = getCookie('_cky_opt_in_dismiss');
  if (optInCookie === "") {
    const days = 365 * 24 * 60 * 60 * 1000;
    setCookies([{ name: "_cky_opt_in", value: "false", duration: days }]);
    optInCookie = "false";
  }

  if (optInCookie === "false" && dismissOptIn === "") {
    const minutes = 60 * 60 * 1000;
    setCookies([{ name: "_cky_opt_in_dismiss", value: "true", duration: minutes }]);
    selectCookieConsent();
  }
}

const persistCookie = (cookies: CookieDetails[]) => {
  fetch('/consent/cookie', {
    method: 'POST',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ cookies: cookies }),
  }).then((response) => response.json())
    .then((json) => {
      return json
    })
    .catch((error) => {
      return error
    });
}

export const retrieveCookies = (url: string) => {
  fetch(url, {
    method: 'GET',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    }
  }).then((response) => response.json())
    .then((json) => {
      if (!json.result) {
        const dateNow = new Date();
        json.forEach((c: CookieDetails) => {
          if (c.expiration) {
            const expiration = new Date(c.expiration);
            if (expiration > dateNow) {
              c.durationUtc = expiration.toUTCString();
              setCookie(c.name, c.value, c.durationUtc);
            }
          }
        })
      }
      processConsent();
      return json
    })
    .catch((error) => {
      return error
    });
}