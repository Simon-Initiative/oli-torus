import React, { useEffect } from 'react';
const AudioAuthor = (props) => {
    const { id, model } = props;
    const { x, y, z, width, src, height } = model;
    const styles = {
        cursor: 'pointer',
        width: '100%',
        outline: 'none',
        height,
        borderRadius: '25px',
        border: '1px solid #ccc!important',
        background: 'whitesmoke',
        textAlign: 'center',
    };
    useEffect(() => {
        // all activities *must* emit onReady
        props.onReady({ id: `${props.id}` });
    }, []);
    return (<div data-janus-type={tagName} style={styles}>
      <style>
        {`
          .fa-play, .fa-ellipsis-v {
            top: calc(50% - 10px);
            position: relative;
          }
        `}
      </style>
      <i className="fas fa-play fa-lg" style={{ float: 'left', paddingLeft: 5 }}></i>
      <i className="fas fa-ellipsis-v fa-lg" style={{ float: 'right', paddingRight: 5 }}></i>
    </div>);
};
export const tagName = 'janus-audio';
export default AudioAuthor;
//# sourceMappingURL=AudioAuthor.jsx.map