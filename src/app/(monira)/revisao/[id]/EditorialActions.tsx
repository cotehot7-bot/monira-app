'use client';

import { useActionState } from 'react';
import { deleteProduct, requestChanges, type PublishState } from './actions';
import styles from '../revisao.module.css';

// Pedir alterações e Apagar são decisões diferentes: nunca no mesmo botão.
export default function EditorialActions({ productId, canDelete }: { productId: string; canDelete: boolean }) {
  const [changesState, changesAction, changesPending] = useActionState<PublishState, FormData>(
    requestChanges.bind(null, productId),
    { status: 'idle' },
  );
  const [deleteState, deleteAction, deletePending] = useActionState<PublishState, FormData>(
    deleteProduct.bind(null, productId),
    { status: 'idle' },
  );

  return (
    <>
      <form action={changesAction} className={styles.editorial}>
        <label htmlFor="note" className={styles.label}>Pedir alterações a quem vende</label>
        <textarea id="note" name="note" rows={3} maxLength={500} placeholder="O que precisa de mudar?" className={styles.textarea} />
        {changesState.status === 'error' && <p className={styles.error} role="alert">{changesState.message}</p>}
        <button type="submit" className={styles.secondary} disabled={changesPending}>
          {changesPending ? 'A enviar…' : 'Pedir alterações'}
        </button>
      </form>

      {canDelete && (
        <details className={styles.danger}>
          <summary>Apagar este envio</summary>
          <form action={deleteAction} className={styles.dangerBody}>
            <p>Só para envios repetidos ou feitos por engano. Apaga o produto e as fotografias originais. Não pode ser desfeito.</p>
            {deleteState.status === 'error' && <p className={styles.error} role="alert">{deleteState.message}</p>}
            <button type="submit" className={styles.dangerButton} disabled={deletePending}>
              {deletePending ? 'A apagar…' : 'Apagar definitivamente'}
            </button>
          </form>
        </details>
      )}
    </>
  );
}
