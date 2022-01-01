// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration
module.exports = {
    mode: 'jit',
    purge: [
        "./js/**/*.js",
        '../lib/*_web.ex',
        "../lib/*_web/**/*.*ex",
        "../lib/*_web/**/*.sface",
    ],
    content: [
        './js/**/*.js',
        '../lib/*_web.ex',
        '../lib/*_web/**/*.*ex'
    ],
    darkMode: false, // or 'media' or 'class'
    theme: {
        // extend: {},
    },
    plugins: [
        require('daisyui'),
        require('@tailwindcss/forms'),
    ],
    daisyui: {
        styled: true,
        themes: true,
        base: true,
        utils: true,
        logs: true,
        rtl: false,
        themes: [
            'light',
            'dark',
        ],
    },
}