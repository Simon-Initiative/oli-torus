import React from 'react';
import { Provider } from 'react-redux';
import ReactShadowDOM from 'react-shadow';
import Authoring, { AuthoringProps } from './Authoring';
import adaptiveStore from './store';

const AuthoringContainer: React.FC<AuthoringProps> = (props: AuthoringProps) => {
  return (
    <ReactShadowDOM.div>
      <link
        rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/css/bootstrap.min.css"
        integrity="sha384-xOolHFLEh07PJGoPkLv1IbcEPTNtaed2xpHsD9ESMhqIYd0nLMwNLD69Npy4HI+N"
        crossOrigin="anonymous"
      />

      <link id="styles" rel="stylesheet" href="/css/styles.css" />

      <link
        rel="stylesheet"
        href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.2.1/css/all.min.css"
        integrity="sha512-MV7K8+y+gLIBoVD59lQIYicR65iaqukzvf/nwasF0nqhPay5w/9lJmVM2hMDcnK1OnMGCdVK+iQrJ7lzPJQd1w=="
        crossOrigin="anonymous"
        referrerPolicy="no-referrer"
      />
      <Provider store={adaptiveStore}>
        <Authoring {...props} />
      </Provider>
    </ReactShadowDOM.div>
  );
};

export default AuthoringContainer;
