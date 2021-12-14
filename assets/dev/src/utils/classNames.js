export const classNames = (names) => {
    if (typeof names === 'string') {
        return names.trim();
    }
    return names.filter((n) => n).join(' ');
};
//# sourceMappingURL=classNames.js.map