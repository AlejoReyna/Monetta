/** Minimal line diff: common prefix/suffix trimmed, the middle is the change. */
export function diffLines(oldText: string, newText: string): {
  readonly removed: readonly string[];
  readonly added: readonly string[];
} {
  const oldLines = oldText.split('\n');
  const newLines = newText.split('\n');
  let prefix = 0;
  while (
    prefix < oldLines.length &&
    prefix < newLines.length &&
    oldLines[prefix] === newLines[prefix]
  ) {
    prefix += 1;
  }
  let suffix = 0;
  while (
    suffix < oldLines.length - prefix &&
    suffix < newLines.length - prefix &&
    oldLines[oldLines.length - 1 - suffix] === newLines[newLines.length - 1 - suffix]
  ) {
    suffix += 1;
  }
  return {
    removed: oldLines.slice(prefix, oldLines.length - suffix),
    added: newLines.slice(prefix, newLines.length - suffix),
  };
}

/** Diff-before-apply (§ 6.3): what exactly changes, no surprises. */
export function Diff(props: { readonly oldText: string; readonly newText: string }): JSX.Element {
  const { removed, added } = diffLines(props.oldText, props.newText);
  if (removed.length === 0 && added.length === 0) {
    return <p>No differences — the document is identical.</p>;
  }
  return (
    <div aria-label="diff">
      {removed.length > 0 && (
        <div>
          <h4>Removed</h4>
          <pre>{removed.join('\n')}</pre>
        </div>
      )}
      {added.length > 0 && (
        <div>
          <h4>Added</h4>
          <pre>{added.join('\n')}</pre>
        </div>
      )}
    </div>
  );
}
