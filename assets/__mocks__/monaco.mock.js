module.exports = {
  languages: {
    register: function (language) {},
    setMonarchTokensProvider: function (name, tokens) {},
    registerCompletionItemProvider: function (name, provider) {},
  },
  editor: {
    create: function () {
      return {
        onDidContentSizeChange: function () {},
        onDidChangeModelContent: function () {},
        getContentHeight: function () {},
        layout: function () {},
      };
    },
    setTheme: function () {},
    defineTheme: function (name, theme) {},
  },
};
