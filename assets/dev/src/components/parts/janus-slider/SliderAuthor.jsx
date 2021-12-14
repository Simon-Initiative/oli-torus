import React, { useEffect, useRef, useState } from 'react';
import './Slider.scss';
const SliderAuthor = (props) => {
    const { id, model } = props;
    const { x, y, z, width, height, customCssClass, label, maximum = 1, minimum = 0, snapInterval, showDataTip, showValueLabels, showLabel, showTicks, invertScale, } = model;
    const styles = {
        width: '100%',
        flexDirection: showLabel ? 'column' : 'row',
    };
    const inputStyles = {
        width: '100%',
        height: `3px`,
        zIndex: z,
        direction: invertScale ? 'rtl' : 'ltr',
    };
    const divStyles = {
        width: '100%',
        display: `flex`,
        flexDirection: 'row',
        alignItems: 'center',
    };
    const [inputInnerWidth, setInputInnerWidth] = useState(0);
    const [spanInnerWidth, setSpanInnerWidth] = useState(0);
    const [sliderValue, setSliderValue] = useState(0);
    useEffect(() => {
        // all activities *must* emit onReady
        props.onReady({ id: `${props.id}` });
    }, []);
    const inputWidth = inputInnerWidth;
    const thumbWidth = spanInnerWidth;
    const thumbHalfWidth = thumbWidth / 2;
    const thumbPosition = ((Number(sliderValue) - minimum) / (maximum - minimum)) *
        (inputWidth - thumbWidth + thumbHalfWidth);
    const thumbMargin = thumbHalfWidth * -1 + thumbHalfWidth / 2;
    const inputTargetRef = useRef(null);
    useEffect(() => {
        var _a;
        if (inputTargetRef && inputTargetRef.current) {
            setInputInnerWidth((_a = inputTargetRef === null || inputTargetRef === void 0 ? void 0 : inputTargetRef.current) === null || _a === void 0 ? void 0 : _a.offsetWidth);
        }
    });
    const divTargetRef = useRef(null);
    useEffect(() => {
        var _a;
        if (divTargetRef && divTargetRef.current) {
            setSpanInnerWidth((_a = divTargetRef === null || divTargetRef === void 0 ? void 0 : divTargetRef.current) === null || _a === void 0 ? void 0 : _a.offsetWidth);
        }
    });
    const getTickOptions = () => {
        if (snapInterval) {
            const options = [];
            const numberOfTicks = (maximum - minimum) / snapInterval;
            for (let i = 0; i <= numberOfTicks; i++) {
                options.push(<option value={i * snapInterval}></option>);
            }
            return options;
        }
    };
    const internalId = `${id}__slider`;
    return (<div data-janus-type={tagName} style={styles} className={`slider`}>
      {showLabel && (<label className="input-label" htmlFor={internalId}>
          {label}
        </label>)}
      <div className="sliderInner">
        {showValueLabels && <label htmlFor={internalId}>{invertScale ? maximum : minimum}</label>}
        <div className="rangeWrap">
          <div style={divStyles}>
            {showDataTip && (<div className="rangeValue" id={`rangeV-${internalId}`}>
                <span ref={divTargetRef} id={`slider-thumb-${internalId}`} style={{
                left: `${invertScale ? undefined : thumbPosition}px`,
                marginLeft: `${invertScale ? undefined : thumbMargin}px`,
                right: `${invertScale ? thumbPosition : undefined}px`,
                marginRight: `${invertScale ? thumbMargin : undefined}px`,
            }}>
                  {sliderValue}
                </span>
              </div>)}
            <input ref={inputTargetRef} disabled={false} style={inputStyles} min={minimum} max={maximum} type={'range'} value={sliderValue} step={snapInterval} id={internalId} list={showTicks ? `datalist${internalId}` : ''}/>
            {showTicks && (<datalist style={{ display: 'none' }} id={`datalist${internalId}`}>
                {getTickOptions()}
              </datalist>)}
          </div>
        </div>
        {showValueLabels && <label htmlFor={internalId}>{invertScale ? minimum : maximum}</label>}
      </div>
    </div>);
};
export const tagName = 'janus-slider';
export default SliderAuthor;
//# sourceMappingURL=SliderAuthor.jsx.map