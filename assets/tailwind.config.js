// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/handmade_hub_web.ex",
    "../lib/handmade_hub_web/**/*.*ex",
    "./node_modules/preline/dist/*.js"
  ],
  // Ensure Heroicons classes like `hero-shopping-cart` are not purged
  safelist: [
    { pattern: /^(hero-).*/ }
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
      }
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Heroicons support for <.icon name="hero-*"> used in core_components
    plugin(function ({ matchComponents, theme }) {
      const iconsDir = path.join(__dirname, "../deps/heroicons/optimized");
      const values = {};

      const styles = [
        { dir: "24/outline", suffix: "" },
        { dir: "24/solid", suffix: "-solid" },
        { dir: "20/solid", suffix: "-mini" }
      ];

      for (const style of styles) {
        const fullDir = path.join(iconsDir, style.dir);
        if (!fs.existsSync(fullDir)) continue;
        for (const file of fs.readdirSync(fullDir)) {
          if (!file.endsWith(".svg")) continue;
          const name = file.replace(/\.svg$/, "");
          // The <.icon> component applies class="hero-<name>"; the Tailwind
          // matchComponents prefix "hero-" is added automatically, so our key
          // should be just the icon name (plus optional suffix for variants).
          const key = `${name}${style.suffix}`;
          const svg = fs.readFileSync(path.join(fullDir, file)).toString().replace(/\r?\n|\r/g, "");
          values[key] = svg;
        }
      }

      matchComponents(
        {
          hero: (svg) => ({
            mask: `url('data:image/svg+xml;utf8,${svg}')`,
            WebkitMask: `url('data:image/svg+xml;utf8,${svg}')`,
            maskRepeat: "no-repeat",
            WebkitMaskRepeat: "no-repeat",
            maskSize: "100% 100%",
            WebkitMaskSize: "100% 100%",
            backgroundColor: "currentColor",
            display: "inline-block",
            verticalAlign: "middle",
            width: theme("spacing.5"),
            height: theme("spacing.5")
          })
        },
        { values }
      );
    }),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"]))
  ]
}
