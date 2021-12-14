var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import chroma from 'chroma-js';
import PartsLayoutRenderer from 'components/activities/adaptive/components/delivery/PartsLayoutRenderer';
import React from 'react';
const PopupWindow = ({ config, parts, context, onClose, snapshot = {}, }) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
    const popupModalStyles = {
        width: (config === null || config === void 0 ? void 0 : config.width) || 300,
    };
    if (config === null || config === void 0 ? void 0 : config.palette) {
        if (config.palette.useHtmlProps) {
            popupModalStyles.backgroundColor = config.palette.backgroundColor;
            popupModalStyles.borderColor = config.palette.borderColor;
            popupModalStyles.borderWidth = config.palette.borderWidth;
            popupModalStyles.borderStyle = config.palette.borderStyle;
            popupModalStyles.borderRadius = config.palette.borderRadius;
        }
        else {
            popupModalStyles.borderWidth = `${((_a = config === null || config === void 0 ? void 0 : config.palette) === null || _a === void 0 ? void 0 : _a.lineThickness) ? ((_b = config === null || config === void 0 ? void 0 : config.palette) === null || _b === void 0 ? void 0 : _b.lineThickness) + 'px' : '1px'}`;
            popupModalStyles.borderRadius = '10px';
            popupModalStyles.borderStyle = 'solid';
            popupModalStyles.borderColor = `rgba(${((_c = config === null || config === void 0 ? void 0 : config.palette) === null || _c === void 0 ? void 0 : _c.lineColor) || ((_d = config === null || config === void 0 ? void 0 : config.palette) === null || _d === void 0 ? void 0 : _d.lineColor) === 0
                ? chroma((_e = config === null || config === void 0 ? void 0 : config.palette) === null || _e === void 0 ? void 0 : _e.lineColor).rgb().join(',')
                : '255, 255, 255'},${(_f = config === null || config === void 0 ? void 0 : config.palette) === null || _f === void 0 ? void 0 : _f.lineAlpha})`;
            popupModalStyles.backgroundColor = `rgba(${((_g = config === null || config === void 0 ? void 0 : config.palette) === null || _g === void 0 ? void 0 : _g.fillColor) || ((_h = config === null || config === void 0 ? void 0 : config.palette) === null || _h === void 0 ? void 0 : _h.fillColor) === 0
                ? chroma((_j = config === null || config === void 0 ? void 0 : config.palette) === null || _j === void 0 ? void 0 : _j.fillColor).rgb().join(',')
                : '255, 255, 255'},${(_k = config === null || config === void 0 ? void 0 : config.palette) === null || _k === void 0 ? void 0 : _k.fillAlpha})`;
        }
    }
    // position is an offset from the parent element now
    popupModalStyles.left = config.x || 0;
    popupModalStyles.top = config.y || 0;
    popupModalStyles.zIndex = config.z || 1000;
    popupModalStyles.height = config.height || 0;
    popupModalStyles.overflow = 'hidden';
    popupModalStyles.position = 'absolute';
    const popupCloseStyles = {
        position: 'absolute',
        padding: 0,
        zIndex: (config.z || 1000) + 1,
        background: 'transparent',
        textDecoration: 'none',
        width: '25px',
        height: '25px',
        fontSize: '1.4em',
        fontFamily: 'Arial',
        right: 0,
        opacity: 1,
    };
    const popupBGStyles = {
        top: 0,
        left: 0,
        bottom: 0,
        right: 0,
        borderRadius: 10,
        padding: 0,
        overflow: 'hidden',
        width: '100%',
        height: '100%',
    };
    const closeButtonSpanStyles = {
        marginLeft: 12,
        padding: 0,
        textShadow: 'none',
        top: 0,
        left: 0,
        bottom: 0,
        fontWeight: 'bold',
        fontFamily: 'Arial',
        marginTop: -6,
        position: 'absolute',
        right: 0,
    };
    const handleCloseIconClick = (e) => {
        if (onClose) {
            onClose();
        }
    };
    const handlePartInit = ({ id, responses }) => __awaiter(void 0, void 0, void 0, function* () {
        const result = {
            snapshot,
            context,
        };
        /*   console.log('PopupWindow.handlePartInit', { result, id, responses }); */
        return result;
    });
    return (<div className={`info-icon-popup ${(config === null || config === void 0 ? void 0 : config.customCssClass) ? config.customCssClass : ''}`} style={popupModalStyles}>
      <div className="popup-background" style={popupBGStyles}>
        <PartsLayoutRenderer onPartInit={handlePartInit} parts={parts}></PartsLayoutRenderer>
        <button aria-label="Close" className="close" style={popupCloseStyles} onClick={handleCloseIconClick}>
          <span aria-hidden={true} style={closeButtonSpanStyles}>
            x
          </span>
        </button>
      </div>
    </div>);
};
export default PopupWindow;
//# sourceMappingURL=PopupWindow.jsx.map