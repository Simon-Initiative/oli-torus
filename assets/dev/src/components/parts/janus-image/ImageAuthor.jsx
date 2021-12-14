/* eslint-disable react/prop-types */
import React, { useEffect, useState } from 'react';
const ImageAuthor = (props) => {
    const { model } = props;
    const [ready, setReady] = useState(false);
    const id = props.id;
    useEffect(() => {
        setReady(true);
    }, []);
    useEffect(() => {
        if (!ready) {
            return;
        }
        props.onReady({ id, responses: [] });
    }, [ready]);
    const { x, y, z, width, height, src, alt, customCssClass } = model;
    const imageStyles = {
        width,
        height,
    };
    return ready ? <img draggable="false" alt={alt} src={src} style={imageStyles}/> : null;
};
export const tagName = 'janus-image';
export default ImageAuthor;
//# sourceMappingURL=ImageAuthor.jsx.map