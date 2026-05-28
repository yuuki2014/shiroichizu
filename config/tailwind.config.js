const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Noto Sans JP"', 'system-ui', 'sans-serif'],
        rounded: ['"M PLUS Rounded 1c"', '"Noto Sans JP"', 'sans-serif'],
        klee: ['"Klee One"', '"Noto Sans JP"', 'sans-serif'],
        yusei: ['"Yusei Magic"', '"Noto Sans JP"', 'sans-serif'],
        yomogi: ['"Yomogi"', '"Noto Sans JP"', 'sans-serif'],
      },
    },
  },
  plugins: [
    // require('@tailwindcss/forms'),
    // require('@tailwindcss/typography'),
    // require('@tailwindcss/container-queries'),
  ]
}
