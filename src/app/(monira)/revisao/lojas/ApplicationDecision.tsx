'use client';

import { useActionState } from 'react';
import { approveApplication, rejectApplication, type DecisionState } from './actions';
import styles from '../revisao.module.css';

// Aprovar e recusar são decisões diferentes: formulários separados.
export default function ApplicationDecision({ id, name, avenueId, categories }: {
  id: string;
  name: string;
  avenueId: string | null;
  categories: { id: string; name: string }[];
}) {
  const [approveState, approveAction, approving] = useActionState<DecisionState, FormData>(approveApplication.bind(null, id), { status: 'idle' });
  const [rejectState, rejectAction, rejecting] = useActionState<DecisionState, FormData>(rejectApplication.bind(null, id), { status: 'idle' });
  const done = approveState.status === 'done' ? approveState : rejectState.status === 'done' ? rejectState : null;

  if (done) return <p className={styles.notice} role="status">{done.message}</p>;

  return (
    <>
      <form action={approveAction} className={styles.editorial}>
        <label htmlFor={`uja-${id}`} className={styles.label}>Nome da Uja</label>
        <input id={`uja-${id}`} name="uja_name" defaultValue={name} maxLength={80} className={styles.input} />
        <label htmlFor={`cat-${id}`} className={styles.label}>Categoria</label>
        <select id={`cat-${id}`} name="avenue_id" defaultValue={avenueId ?? ''} className={styles.input}>
          <option value="">Escolher…</option>
          {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
        <label className={styles.check}>
          <input type="checkbox" name="verified" />
          Marcar como verificada
        </label>
        {approveState.status === 'error' && <p className={styles.error} role="alert">{approveState.message}</p>}
        <button type="submit" className={styles.primary} disabled={approving || rejecting}>{approving ? 'A aprovar…' : 'Aprovar e criar Uja'}</button>
      </form>

      <details className={styles.danger}>
        <summary>Recusar este pedido</summary>
        <form action={rejectAction} className={styles.dangerBody}>
          <label htmlFor={`note-${id}`} className={styles.label}>Nota para quem pediu</label>
          <textarea id={`note-${id}`} name="note" rows={3} maxLength={500} placeholder="O que falta para aprovarmos?" className={styles.textarea} />
          {rejectState.status === 'error' && <p className={styles.error} role="alert">{rejectState.message}</p>}
          <button type="submit" className={styles.secondary} disabled={approving || rejecting}>{rejecting ? 'A enviar…' : 'Recusar com nota'}</button>
        </form>
      </details>
    </>
  );
}
