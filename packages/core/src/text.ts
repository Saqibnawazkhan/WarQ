/** Small text helpers shared by both apps, so a name renders identically everywhere. */

/**
 * Up to two initials for an avatar tile. `Ayesha Rehman` → `AR`.
 * Extra whitespace, single names and empty strings are all handled.
 */
export function initials(name: string, max = 2): string {
  return name
    .split(/\s+/)
    .filter((word) => word.length > 0)
    .slice(0, max)
    .map((word) => word[0]?.toUpperCase() ?? '')
    .join('');
}

/** `Sara Malik` → `Sara Malik's`, `Ms Jones` → `Ms Jones'`. */
export function possessive(name: string): string {
  return name.endsWith('s') ? `${name}’` : `${name}’s`;
}

/** `1 absence alert` / `3 absence alerts` — pluralises without a library. */
export function pluralize(count: number, singular: string, plural = `${singular}s`): string {
  return `${count} ${count === 1 ? singular : plural}`;
}

/**
 * Picks a stable colour index for a class from the series palette, so the same
 * class shows the same colour on web and on mobile without storing one.
 */
export function seriesIndex(key: string, paletteSize: number): number {
  let hash = 0;
  for (let i = 0; i < key.length; i += 1) {
    hash = (hash * 31 + key.charCodeAt(i)) | 0;
  }
  return Math.abs(hash) % paletteSize;
}
