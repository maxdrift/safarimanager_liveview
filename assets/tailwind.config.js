// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration
module.exports = {
    content: [
        "./js/**/*.js",
        "../lib/*_web.ex",
        "../lib/*_web/**/*.*ex",
        "../lib/*_web/**/*.sface",
    ],
    theme: {
        // extend: {},
    },
    plugins: [
        require("@tailwindcss/typography"),
        require('@tailwindcss/forms'),
        require('daisyui'),
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
            'aqua',
            'night',
        ],
    },
}
