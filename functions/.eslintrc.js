module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json"],
    sourceType: "module",
    tsconfigRootDir: __dirname, // Añadido para ayudar a encontrar tsconfig.json
  },
  ignorePatterns: [
    "/lib/**/*", // Ignorar archivos construidos
    "/index.js", // Ignorar archivo de salida principal
    "/.eslintrc.js", // Ignorar este mismo archivo de configuración
  ],
  plugins: [
    "@typescript-eslint",
  ],
  rules: {
  },
};
