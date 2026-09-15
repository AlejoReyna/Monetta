/** JSON editor with rule-level validation feedback (no forked validator). */
export function JsonEditor(props: {
  readonly value: string;
  readonly onChange: (value: string) => void;
  readonly error: string | null;
}): JSX.Element {
  return (
    <div>
      <label>
        Selection document (JSON)
        <textarea
          aria-label="Selection document"
          rows={20}
          cols={80}
          spellCheck={false}
          value={props.value}
          onChange={(event) => props.onChange(event.target.value)}
        />
      </label>
      {props.error !== null && <p role="alert">{props.error}</p>}
    </div>
  );
}
