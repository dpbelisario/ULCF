// MathJax configuration shared by every page (loaded before mathjax/tex-svg-full.js).
// Inline math: \( ... \)    Display math: \[ ... \]
window.MathJax = {
  tex: {
    inlineMath: [['\\(', '\\)']],
    displayMath: [['\\[', '\\]']],
    macros: {
      dB: '\\,\\mathrm{dB}',
      dBm: '\\,\\mathrm{dBm}',
      GHz: '\\,\\mathrm{GHz}'
    }
  },
  svg: { fontCache: 'global' },
  options: { skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'] }
};
