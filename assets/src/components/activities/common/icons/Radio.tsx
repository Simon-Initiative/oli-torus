import React from 'react';

const Checked = () => (
  <i
    style={{
      color: '#00bc8c',
      fontSize: '30px',
      cursor: 'pointer',
    }}
    className="material-icons-outlined"
  >
    radio_button_checked
  </i>
);

const Unchecked = () => (
  <i
    style={{
      color: 'rgba(0,0,0,0.26)',
      fontSize: '30px',
      cursor: 'pointer',
    }}
    className="material-icons-outlined"
  >
    radio_button_unchecked
  </i>
);

export const Radio = {
  Checked,
  Unchecked,
};
