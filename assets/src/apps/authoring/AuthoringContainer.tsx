import React from 'react';
import { Provider } from 'react-redux';
import Authoring, { AuthoringProps } from './Authoring';
import adaptiveStore from './store';

const AuthoringContainer: React.FC<AuthoringProps> = (props: AuthoringProps) => {
  return (
    <Provider store={adaptiveStore}>
      <Authoring {...props} />
    </Provider>
  );
};

export default AuthoringContainer;
