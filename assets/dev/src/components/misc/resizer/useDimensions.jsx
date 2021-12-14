import { clientBoundingRect, offsetBoundingRect } from 'components/misc/resizer/utils';
import { useState, useLayoutEffect, useRef } from 'react';
// Hook to give a client (default) or offset bounding rect and a ref
// to point at the element you want the dimensions for
export const useDimensions = (offset = false) => {
    const ref = useRef(null);
    const [dimensions, setDimensions] = useState();
    useLayoutEffect(() => {
        if (!ref.current)
            return;
        setDimensions(offset ? offsetBoundingRect(ref.current) : clientBoundingRect(ref.current));
    }, [ref.current]);
    return [ref, dimensions];
};
//# sourceMappingURL=useDimensions.jsx.map