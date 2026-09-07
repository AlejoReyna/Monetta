import type { ReactNode } from 'react';

/** Plain table: headers + rows, no library. */
export function DataTable(props: {
  readonly headers: readonly string[];
  readonly rows: ReadonlyArray<ReadonlyArray<ReactNode>>;
  readonly rowKeys: readonly string[];
}): JSX.Element {
  return (
    <table>
      <thead>
        <tr>
          {props.headers.map((header) => (
            <th key={header} scope="col">
              {header}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {props.rows.map((cells, index) => (
          <tr key={props.rowKeys[index]}>
            {cells.map((cell, cellIndex) => (
              // eslint-disable-next-line react/no-array-index-key
              <td key={cellIndex}>{cell}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
