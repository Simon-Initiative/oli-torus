import { useState, useEffect } from 'react';
export const useMousePosition = () => {
    const [mousePosition, setMousePosition] = useState(null);
    const updateMousePosition = (ev) => {
        setMousePosition({ x: ev.clientX, y: ev.clientY });
    };
    useEffect(() => {
        window.addEventListener('mousemove', updateMousePosition);
        return () => window.removeEventListener('mousemove', updateMousePosition);
    }, []);
    return mousePosition;
};
//# sourceMappingURL=useMousePosition.jsx.map