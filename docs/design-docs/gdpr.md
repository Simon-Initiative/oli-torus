# GDPR compliance

## Cookie compliance requirements

- Receive users’ consent before you use any cookies except strictly necessary cookies.
- Provide accurate and specific information about the data each cookie tracks and its purpose in plain language before consent is received.
- Document and store consent received from users.
- Allow users to access your service even if they refuse to allow the use of certain cookies
- Make it as easy for users to withdraw their consent as it was for them to give their consent in the first place.

The Cookie Law does not require that records of consent be kept but instead, indicates that you should be able to prove that consent occurred — even if that consent has been withdrawn.

To comply with the requirements, our approach needed to ensure that an opportunity for the user to provide consent is presented even in cases where a user never logins into our system. That consideration, combined with not having to maintain records of consent, meant that an approach that makes use of long-lived cookies to keep track of consent works fine in our use case. The approach works as follows.

- Each page on our site is instrumented with some cookie consent management scripts
- The scripts run every time any page is loaded on the browser
- The script first checks to see if a cookie with the name “\_cky_opt_in” is present and that its value is “true”. This cookie is used to track whether the consent pop-up has been launched in that particular browser before. If not a new one is created with a value “false” and an expiration value of 365 days (Compliant with GDPR).
- A cookie named “\_cky_opt_in_dismiss” with a duration of 1hr is also created whenever the cookie above is created. This cookie allows our website to re-prompt the user with the cookie consent pop-up every hour if they simply dismissed the pop-up without providing consent
- If the user agrees to allow cookies, a cookie named “\_cky_opt_choices” is created. Its duration is 365 days and the value is the consent preferences agreed to by the user. The value of the cookie “\_cky_opt_in” is updated to true.
- Note that after 365 days, our system will prompt the user for a new consent
- The cookie consent pop-up also presents the user with the option to modifly cookie preferences. The preferences dialog simply updates the values store in the “\_cky_opt_choices” cookie or creates one if one is not already present.
- Each page on our site has a footer containing a link that will directly launch the preferences dialog any time the user wishes to adjust their cookie preferences.
