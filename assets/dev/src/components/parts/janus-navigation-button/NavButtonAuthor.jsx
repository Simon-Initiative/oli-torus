import React, { useEffect } from 'react';
const NavButtonAuthor = (props) => {
    const { model } = props;
    const { title, x = 0, y = 0, z = 0, width, height, textColor, buttonColor, visible = true, enabled = true, ariaLabel, transparent, selected, } = model;
    const styles = {
        width,
        height,
        cursor: 'move',
    };
    if (transparent || !visible || !enabled) {
        // TODO: some kind of strike through style?
        styles.opacity = 0.5;
    }
    if (textColor) {
        styles.color = textColor;
    }
    if (buttonColor) {
        styles.backgroundColor = buttonColor;
    }
    const handleStylingChanges = () => {
        const styleChanges = {};
        if (width !== undefined) {
            styleChanges.width = { value: width };
        }
        if (height != undefined) {
            styleChanges.height = { value: height };
        }
        props.onResize({ id: `${props.id}`, settings: styleChanges });
    };
    useEffect(() => {
        // all activities *must* emit onReady
        props.onReady({ id: `${props.id}` });
        handleStylingChanges();
    }, []);
    const buttonProps = {
        title,
        'aria-label': ariaLabel,
        disabled: false,
    };
    return (<div className={`navigation-button`}>
      <button data-janus-type={tagName} {...buttonProps} style={styles}>
        {title}
      </button>
    </div>);
};
export const tagName = 'janus-navigation-button';
export default NavButtonAuthor;
//# sourceMappingURL=NavButtonAuthor.jsx.map