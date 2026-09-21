# Global instructions

Personal instructions that apply to every project on this machine.

## General coding style
- Prefer longer descriptive names for variables, functions, etc over shorter, cryptic names. Avoid single-letter variable names.

## React
- Always write in TypeScript instead of plain JavaScript where possible and ensure it aligns with the project's tsconfig.json.
- Avoid React.useEffect if possible as it easily introduces bugs and makes the code harder to reason about. See https://react.dev/learn/you-might-not-need-an-effect.

## TypeScript
- Avoid any return types.

## PHP / Symfony

- No Yoda conditions — write `if ($status === self::ACTIVE)`, not `if (self::ACTIVE === $status)`.
