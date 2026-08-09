/** Joins class names, dropping anything falsy. Keeps a dependency out of the bundle. */
export function cx(...parts: readonly (string | false | null | undefined)[]): string {
  return parts.filter(Boolean).join(' ');
}
