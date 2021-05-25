import React, { useEffect, useState } from 'react';
import ModalSelection from "components/modal/ModalSelection";
import { consentOptions, setCookies } from "components/cookies/utils";
import ReactDOM from 'react-dom';

let userOptions = consentOptions();

export type CookiePreferencesProps = {
};

export const CookiePreferences = (props: CookiePreferencesProps) => {
  const [functionalActive, setFunctionalActive] = useState(true);
  const [analyticsActive, setAnalyticActive] = useState(true);
  const [targetingActive, setTargetingActive] = useState(false);
  const [functionalLabel, setFunctionalLabel] = useState("On");
  const [analyticsLabel, setAnalyticLabel] = useState("On");
  const [targetingLabel, setTargetingLabel] = useState("Off");

  useEffect(() => {
    const userOptions = consentOptions();
    prefChange('functionalCookies', userOptions.functionality);
    prefChange('analyticsCookies', userOptions.analytics);
    prefChange('targetingCookies', userOptions.targeting);
  }, []);

  const prefChange = (id: string, checked: boolean) => {
    switch (id) {
      case "functionalCookies":
        setFunctionalActive(checked);
        setFunctionalLabel(checked ? "On" : "Off");
        userOptions.functionality = checked;
        break;
      case "analyticsCookies":
        setAnalyticActive(checked);
        setAnalyticLabel(checked ? "On" : "Off");
        userOptions.analytics = checked;
        break;
      case "targetingCookies":
        setTargetingActive(checked);
        setTargetingLabel(checked ? "On" : "Off");
        userOptions.targeting = checked;
        break;
      default:
        console.error("Unsupported cookie preference");
    }
  }

  return (
    <div>
      <div className="mb-4">
        <p>We are committed to privacy and data protection. When you provide us with your personal
        data, including preferences, we will only process information that is necessary for the purpose for which
          it has been collected.</p>
        <p><a href="https://www.cmu.edu/legal/privacy-notice.html">Privacy Notice</a></p>
      </div>
      <div className="accordion" id="preferenceAccordion">
        <div className="card z-depth-0 bordered">
          <div className="card-header d-flex justify-content-between" id="headingOne">
            <div className="mb-0 d-inline-block">
              <button className="btn btn-link" type="button" data-toggle="collapse"
                data-target="#collapseOne"
                aria-expanded="true" aria-controls="collapseOne">
                Strictly Necessary Cookies
                <i className="fas fa-angle-down rotate-icon"></i>
              </button>
            </div>
            <div className="custom-control custom-switch d-inline-block">
              <input type="checkbox" className="custom-control-input" id="strictCookies" checked disabled />
              <label className="custom-control-label small pt-1" htmlFor="strictCookies">On</label>
            </div>
          </div>
          <div id="collapseOne" className="collapse" aria-labelledby="headingOne"
            data-parent="#preferenceAccordion">
            <div className="card-body">
              <div className="mb-2">
                <p>These cookies are necessary for our website to function properly and cannot be switched off in our
                  systems.</p>
                <p>You can set your browser to block or alert you about these cookies, but some parts of
                the site will not then work. These cookies do not store any personally identifiable
                  information.</p>
              </div>
              <div className="small">
                <a href="#demo" data-toggle="collapse">View Cookies</a>
                <div id="demo" className="collapse">
                  <table className="table table-striped">
                    <thead>
                      <tr>
                        <th scope="col">Domain</th>
                        <th scope="col">Cookies</th>
                        <th scope="col">Type</th>
                        <th scope="col">Description</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td>canvas.oli.cmu.edu, proton.oli.cmu.edu, oli.cmu.edu, cmu.edu</td>
                        <td>_oli_key, _cky_opt_in, _cky_opt_in_dismiss, _cky_opt_choices, _legacy_normandy_session,
                        log_session_id, _csrf_token
                      </td>
                        <td>1st Party</td>
                        <td>This cookies are usually only set in response to actions made by you which amount to a
                        request for services, such as setting your privacy preferences, logging in or where
                        they’re essential to provide you with a service you have requested.
                      </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div className="card z-depth-0 bordered">
          <div className="card-header d-flex justify-content-between" id="headingTwo">
            <div className="mb-0 d-inline-block">
              <button className="btn btn-link collapsed" type="button" data-toggle="collapse"
                data-target="#collapseTwo" aria-expanded="false" aria-controls="collapseTwo">
                Functionality Cookies
                <i className="fas fa-angle-down rotate-icon"></i>
              </button>
            </div>
            <div className="custom-control custom-switch d-inline-block">
              <input type="checkbox" className="custom-control-input" id="functionalCookies" checked={functionalActive}
                onChange={(e: any) => prefChange(e.target.id, e.target.checked)} />
              <label className="custom-control-label small pt-1" htmlFor="functionalCookies">{functionalLabel}</label>
            </div>
          </div>
          <div id="collapseTwo" className="collapse" aria-labelledby="headingTwo"
            data-parent="#preferenceAccordion">
            <div className="card-body">
              <div className="mb-2">
                <p>These cookies are used to provide you with a more personalized experience on our
                  website and to remember choices you make when you use our website.</p>
                <p>For example, we may use functionality cookies to remember your language preferences
                  or remember your login details.</p>
              </div>
              <div className="small">
                <a href="#demo" data-toggle="collapse">View Cookies</a>
                <div id="demo" className="collapse">
                  <table className="table table-striped">
                    <thead>
                      <tr>
                        <th scope="col">Domain</th>
                        <th scope="col">Cookies</th>
                        <th scope="col">Type</th>
                        <th scope="col">Description</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td>None</td>
                        <td></td>
                        <td></td>
                        <td></td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div className="card z-depth-0 bordered">
          <div className="card-header d-flex justify-content-between" id="headingThree">
            <div className="mb-0 d-inline-block">
              <button className="btn btn-link collapsed" type="button" data-toggle="collapse"
                data-target="#collapseThree" aria-expanded="false"
                aria-controls="collapseThree">
                Analytics Cookies
                <i className="fas fa-angle-down rotate-icon"></i>
              </button>
            </div>
            <div className="custom-control custom-switch d-inline-block">
              <input type="checkbox" className="custom-control-input" id="analyticsCookies" checked={analyticsActive}
                onChange={(e: any) => prefChange(e.target.id, e.target.checked)} />
              <label className="custom-control-label small pt-1" htmlFor="analyticsCookies">{analyticsLabel}</label>
            </div>
          </div>
          <div id="collapseThree" className="collapse" aria-labelledby="headingThree"
            data-parent="#preferenceAccordion">
            <div className="card-body">
              <div className="mb-2">
                <p>These cookies are used to collect information to analyze the traffic to our website
                  and how visitors are using our website.</p>
                <p>For example, these cookies may track things such as how long you spend on the website
                or the pages you visit which helps us to understand how we can improve our website
                  site for you.</p>
                <p>The information collected through these tracking and performance cookies do not
                  identify any individual visitor.</p>
              </div>
              <div className="small">
                <a href="#demo" data-toggle="collapse">View Cookies</a>
                <div id="demo" className="collapse">
                  <table className="table table-striped">
                    <thead>
                      <tr>
                        <th scope="col">Domain</th>
                        <th scope="col">Cookies</th>
                        <th scope="col">Type</th>
                        <th scope="col">Description</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td>canvas.oli.cmu.edu, proton.oli.cmu.edu, oli.cmu.edu, cmu.edu</td>
                        <td>_gid, _ga, _ga_xxxxxxx, _utma, _utmb, _utmc, _utmz, nmstat</td>
                        <td>1st Party</td>
                        <td>This cookies record basic website information such as: repeat visits; page usage; country
                        of origin for use in Google analytics and other site improvements
                      </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div className="card z-depth-0 bordered">
          <div className="card-header d-flex justify-content-between" id="headingFour">
            <div className="mb-0 d-inline-block">
              <button className="btn btn-link collapsed" type="button" data-toggle="collapse"
                data-target="#collapseFour" aria-expanded="false" aria-controls="collapseFour">
                Targeting Cookies
                <i className="fas fa-angle-down rotate-icon"></i>
              </button>
            </div>
            <div className="custom-control custom-switch d-inline-block">
              <input type="checkbox" className="custom-control-input" id="targetingCookies" checked={targetingActive}
                onChange={(e: any) => prefChange(e.target.id, e.target.checked)} />
              <label className="custom-control-label small pt-1" htmlFor="targetingCookies">{targetingLabel}</label>
            </div>
          </div>
          <div id="collapseFour" className="collapse" aria-labelledby="headingFour"
            data-parent="#preferenceAccordion">
            <div className="card-body">
              <div className="mb-2">
                <p>These cookies are used to show advertising that is likely to be of interest to you
                  based on your browsing habits.</p>
                <p>These cookies, as served by our content and/or advertising providers, may combine
                information they collected from our website with other information they have
                independently collected relating to your web browser's activities across their
                  network of websites.</p>
                <p>If you choose to remove or disable these targeting or advertising cookies, you will
                  still see adverts but they may not be relevant to you.</p>
              </div>
              <div className="small">
                <a href="#demo" data-toggle="collapse">View Cookies</a>
                <div id="demo" className="collapse">
                  <table className="table table-striped">
                    <thead>
                      <tr>
                        <th scope="col">Domain</th>
                        <th scope="col">Cookies</th>
                        <th scope="col">Type</th>
                        <th scope="col">Description</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td>None</td>
                        <td></td>
                        <td></td>
                        <td></td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const savePreferences = () => {
  const days = 365 * 24 * 60 * 60 * 1000;
  setCookies([{ name: "_cky_opt_choices", value: JSON.stringify(userOptions), duration: days },
  { name: "_cky_opt_in", value: "true", duration: days }]);
}

export function selectCookiePreferences(): void {
  const cookiePreference = (
    <ModalSelection
      title="Cookie Preferences"
      onInsert={() => {
        dismiss();
        savePreferences();
      }}
      onCancel={
        () => {
          dismiss();
        }
      }
      okLabel="Save my preferences"
      cancelLabel="Cancel"
    >
      <CookiePreferences />
    </ModalSelection>
  );

  display(cookiePreference);
}

const display = (c: any) => {
  const cookiePrefs = document.querySelector("#cookie_prefs_display");
  if (cookiePrefs) {
    ReactDOM.render(c, cookiePrefs);
  }
}

const dismiss = () => {
  const cookiePrefs = document.querySelector("#cookie_prefs_display");
  if (cookiePrefs) {
    ReactDOM.unmountComponentAtNode(cookiePrefs);
  }
}