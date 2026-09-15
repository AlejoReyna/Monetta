import { useEffect, useMemo, useState } from 'react';
import type { ApiClient } from '../api/client.js';
import { createPoller, POLL_INTERVAL_DEFAULT_MS, type PollStatus } from '../api/poll.js';
import { ConnectionBanner } from '../components/ConnectionBanner.js';
import { Diff } from '../components/Diff.js';
import { JsonEditor } from '../components/JsonEditor.js';
import {
  canonicalJsonStringify,
  isSelectionError,
  isStageARuleKind,
  parseSelectionDocument,
} from '@selection/index.js';
import type { SelectionDocument } from '@selection/types.js';

interface CurrentSelection {
  readonly version: number;
  readonly hash: string;
  readonly appliedBy: string;
  readonly appliedAt: string;
  readonly note: string | null;
  readonly document: SelectionDocument;
}

interface PreviewRule {
  readonly ruleId: string;
  readonly kind: string;
  readonly stage: string;
  readonly matchedUrls: number;
  readonly fetchCosting: boolean;
}

interface PreviewSource {
  readonly source: string;
  readonly candidates: number;
  readonly selected: number;
  readonly maxSelectedUrls: number | null;
  readonly overBudget: boolean;
}

interface PreviewBody {
  readonly perRule: readonly PreviewRule[];
  readonly perSource: readonly PreviewSource[];
  readonly note: string | null;
}

interface VersionRow {
  readonly version: number;
  readonly hash: string;
  readonly appliedBy: string;
  readonly appliedAt: string;
  readonly note: string | null;
}

const APPLIED_BY_KEY = 'monetta.dashboard.appliedBy';

function storedAppliedBy(): string {
  try {
    return sessionStorage.getItem(APPLIED_BY_KEY) ?? '';
  } catch {
    return '';
  }
}

/**
 * The reason this dashboard exists (§ 6.3): edit the selection document with
 * the server's own validator, preview it, diff it, then apply it with a note.
 */
export function SelectionScreen(props: { readonly client: ApiClient }): JSX.Element {
  const [current, setCurrent] = useState<CurrentSelection | null>(null);
  const [poll, setPoll] = useState<PollStatus>('ok');
  const [text, setText] = useState<string | null>(null);
  const [note, setNote] = useState('');
  const [appliedBy, setAppliedBy] = useState(storedAppliedBy);
  const [armed, setArmed] = useState(false);
  const [secondConfirm, setSecondConfirm] = useState(false);
  const [preview, setPreview] = useState<PreviewBody | null>(null);
  const [versions, setVersions] = useState<readonly VersionRow[]>([]);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    const poller = createPoller<CurrentSelection>({
      client: props.client,
      path: '/admin/selection',
      intervalMs: POLL_INTERVAL_DEFAULT_MS,
      onData: (body) => {
        setCurrent(body);
        setText((previous) => previous ?? JSON.stringify(body.document, null, 2));
      },
      onStatus: (next) => setPoll(next),
    });
    poller.start();
    return () => poller.stop();
  }, [props.client]);

  useEffect(() => {
    let cancelled = false;
    void props.client
      .get<{ versions: VersionRow[] }>('/admin/selection/versions')
      .then((result) => {
        if (!cancelled && result.data !== null) setVersions(result.data.versions);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [props.client, current?.version]);

  const validation = useMemo((): { error: string | null; document: SelectionDocument | null } => {
    if (text === null) return { error: null, document: null };
    let raw: unknown = text;
    try {
      raw = JSON.parse(text);
    } catch (error) {
      return { error: `Malformed JSON: ${error instanceof Error ? error.message : String(error)}`, document: null };
    }
    const parsed = parseSelectionDocument(raw);
    if (isSelectionError(parsed)) {
      return { error: `${parsed.code}: ${parsed.message}`, document: null };
    }
    return { error: null, document: parsed };
  }, [text]);

  const changedSources = useMemo((): readonly string[] => {
    if (current === null || validation.document === null) return [];
    const before = current.document.sources;
    const after = validation.document.sources;
    const names = new Set([...Object.keys(before), ...Object.keys(after)]);
    return [...names].filter(
      (name) => canonicalJsonStringify(before[name] ?? null) !== canonicalJsonStringify(after[name] ?? null),
    );
  }, [current, validation.document]);

  // Guard rails (§ 6.3): a document that selects nothing, or a preview
  // that already exceeds a budget, needs a second worded confirmation.
  // The Stage-A check mirrors the engine's fetch-candidate gate
  // (`zero_stage_a_include_rules`): Stage-B/C-only documents fetch zero
  // pages, so counting `include.length` alone would miss them.
  const risky = useMemo((): string | null => {
    if (validation.document === null) return null;
    for (const [source, entry] of Object.entries(validation.document.sources)) {
      if (!entry.enabled) continue;
      const stageA = entry.include.filter((rule) => isStageARuleKind(rule.kind));
      if (stageA.length === 0) {
        return `Source ${source} is enabled but selects zero products.`;
      }
    }
    if (preview !== null) {
      for (const row of preview.perSource) {
        if (row.overBudget) {
          return `Source ${row.source} selects ${row.selected} URLs over its budget of ${row.maxSelectedUrls}.`;
        }
      }
    }
    return null;
  }, [validation.document, preview]);

  const canApply =
    validation.error === null &&
    validation.document !== null &&
    current !== null &&
    note.trim() !== '' &&
    appliedBy.trim() !== '' &&
    armed &&
    (risky === null || secondConfirm);

  async function runPreview(): Promise<void> {
    if (validation.document === null) return;
    const result = await props.client.send<PreviewBody>('/admin/selection/preview', 'POST', {
      document: validation.document,
    });
    if (result.data !== null) setPreview(result.data);
  }

  async function apply(): Promise<void> {
    if (!canApply || validation.document === null || current === null) return;
    try {
      sessionStorage.setItem(APPLIED_BY_KEY, appliedBy.trim());
    } catch {
      // Non-fatal: the name just won't persist.
    }
    const result = await props.client.send<{ applied: boolean; version: number }>(
      '/admin/selection',
      'PUT',
      { document: validation.document, note: note.trim() },
      { 'X-Applied-By': appliedBy.trim(), 'If-Match': `"${current.version}"` },
    );
    if (result.status === 412) {
      setMessage('Someone else changed the selection — reloaded, review the diff and confirm again.');
      setArmed(false);
      const refreshed = await props.client.get<CurrentSelection>('/admin/selection');
      if (refreshed.data !== null) {
        setCurrent(refreshed.data);
        setText(JSON.stringify(refreshed.data.document, null, 2));
      }
      return;
    }
    if (result.status === 201 || result.status === 200) {
      setMessage(`Applied as v${result.data?.version}.`);
      setArmed(false);
      setSecondConfirm(false);
      const refreshed = await props.client.get<CurrentSelection>('/admin/selection');
      if (refreshed.data !== null) {
        setCurrent(refreshed.data);
        setText(JSON.stringify(refreshed.data.document, null, 2));
      }
    } else {
      setMessage(`Apply failed (HTTP ${result.status}).`);
    }
  }

  async function rollback(version: number): Promise<void> {
    const result = await props.client.send<{ applied: boolean; version: number }>(
      '/admin/selection/rollback',
      'POST',
      { version },
      {
        'X-Applied-By': appliedBy.trim() === '' ? 'owner' : appliedBy.trim(),
        ...(current !== null ? { 'If-Match': `"${current.version}"` } : {}),
      },
    );
    if (result.data !== null) {
      setMessage(result.data.applied ? `Rolled back as v${result.data.version}.` : 'Already on that version.');
      const refreshed = await props.client.get<CurrentSelection>('/admin/selection');
      if (refreshed.data !== null) {
        setCurrent(refreshed.data);
        setText(JSON.stringify(refreshed.data.document, null, 2));
      }
    }
  }

  return (
    <section aria-label="Selection">
      <h2>Selection console</h2>
      <ConnectionBanner status={poll} lastOkAt={null} />
      {current === null ? (
        <p>Loading…</p>
      ) : (
        <>
          <p>
            v{current.version} · {current.hash.slice(0, 12)} · by {current.appliedBy} · {current.appliedAt}
            {current.note !== null && ` · ${current.note}`}
          </p>
          <JsonEditor value={text ?? ''} onChange={(value) => { setText(value); setArmed(false); setSecondConfirm(false); setPreview(null); }} error={validation.error} />
          <div>
            <button type="button" onClick={() => void runPreview()} disabled={validation.document === null}>
              Preview
            </button>
          </div>
          {preview !== null && (
            <section aria-label="preview">
              <h3>Preview</h3>
              {preview.note !== null && <p>{preview.note}</p>}
              <ul>
                {preview.perRule.map((rule) => (
                  <li key={rule.ruleId}>
                    {rule.ruleId} ({rule.kind}, stage {rule.stage}) — {rule.matchedUrls} URLs
                    {rule.fetchCosting ? ' · costs a fetch per candidate' : ''}
                  </li>
                ))}
              </ul>
              <ul>
                {preview.perSource.map((row) => (
                  <li key={row.source}>
                    {row.source}: {row.selected}/{row.candidates} selected
                    {row.overBudget ? ' · OVER BUDGET' : ''}
                  </li>
                ))}
              </ul>
            </section>
          )}
          {validation.document !== null && (
            <section aria-label="apply">
              <h3>Apply</h3>
              <Diff
                oldText={canonicalJsonStringify(current.document)}
                newText={canonicalJsonStringify(validation.document)}
              />
              <p>Affected sources: {changedSources.length === 0 ? 'none (identical)' : changedSources.join(', ')}</p>
              <label>
                Note (required){' '}
                <input aria-label="apply note" value={note} onChange={(e) => setNote(e.target.value)} />
              </label>{' '}
              <label>
                Applied by (required){' '}
                <input aria-label="applied by" value={appliedBy} onChange={(e) => setAppliedBy(e.target.value)} />
              </label>
              {risky !== null && (
                <label>
                  <input
                    aria-label="second confirmation"
                    type="checkbox"
                    checked={secondConfirm}
                    onChange={(e) => setSecondConfirm(e.target.checked)}
                  />{' '}
                  I understand: {risky}
                </label>
              )}
              {!armed ? (
                <button
                  type="button"
                  onClick={() => setArmed(true)}
                  disabled={validation.error !== null || note.trim() === '' || appliedBy.trim() === ''}
                >
                  Review and confirm…
                </button>
              ) : (
                <button type="button" onClick={() => void apply()} disabled={!canApply}>
                  Confirm apply to {changedSources.length} source(s)
                </button>
              )}
            </section>
          )}
          <section aria-label="history">
            <h3>Version history</h3>
            <ul>
              {versions.map((row) => (
                <li key={row.version}>
                  v{row.version} · {row.hash.slice(0, 12)} · {row.appliedBy} · {row.appliedAt}
                  {row.note !== null && ` · ${row.note}`}{' '}
                  <button type="button" onClick={() => void rollback(row.version)}>
                    Roll back to v{row.version}
                  </button>
                </li>
              ))}
            </ul>
          </section>
          {message !== null && <p role="status">{message}</p>}
        </>
      )}
    </section>
  );
}
