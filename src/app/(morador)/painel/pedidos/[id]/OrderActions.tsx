'use client';

import { useActionState } from 'react';
import { cancelOrder, completeOffline, startDelivery, type OrderActionState } from './actions';
import styles from '../../../../pedidos/pedidos.module.css';

export default function OrderActions({ orderId, status, mode }: { orderId: string; status: string; mode: string }) {
  const [startState, startAction, starting] = useActionState<OrderActionState, FormData>(startDelivery.bind(null, orderId), { status: 'idle' });
  const [doneState, doneAction, completing] = useActionState<OrderActionState, FormData>(completeOffline.bind(null, orderId), { status: 'idle' });
  const [cancelState, cancelAction, cancelling] = useActionState<OrderActionState, FormData>(cancelOrder.bind(null, orderId), { status: 'idle' });
  const busy = starting || completing || cancelling;
  const error = [startState, doneState, cancelState].find((s) => s.status === 'error');

  const canStart = mode === 'delivery' && status === 'new';
  const canComplete = (mode === 'delivery' && status === 'delivering') || (mode === 'pickup' && status === 'new');
  const canCancel = status === 'new' || status === 'delivering';
  if (!canStart && !canComplete && !canCancel) return null;

  return (
    <div className={styles.actions}>
      {error?.status === 'error' && <p className={styles.error} role="alert">{error.message}</p>}

      {canStart && (
        <form action={startAction}>
          <button type="submit" className={styles.primary} disabled={busy} style={{ width: '100%' }}>{starting ? 'A actualizar…' : 'Começar entrega'}</button>
        </form>
      )}

      {canComplete && (
        <form action={doneAction} className={styles.actions} style={{ margin: 0 }}>
          <span className={styles.label}>Como recebeste o pagamento?</span>
          <div className={styles.methods}>
            <label className={styles.method}><input type="radio" name="method" value="cash" required />Dinheiro</label>
            <label className={styles.method}><input type="radio" name="method" value="tpa" />TPA</label>
            <label className={styles.method}><input type="radio" name="method" value="transfer" />Transferência</label>
          </div>
          <button type="submit" className={styles.primary} disabled={busy}>
            {completing ? 'A concluir…' : mode === 'delivery' ? 'Entregue e pago' : 'Levantado e pago'}
          </button>
        </form>
      )}

      {canCancel && (
        <details className={styles.danger}>
          <summary>Cancelar pedido</summary>
          <form action={cancelAction} className={styles.dangerBody}>
            <label htmlFor="reason" className={styles.label}>Motivo</label>
            <textarea id="reason" name="reason" rows={2} maxLength={300} placeholder="Ex.: sem stock do tamanho pedido" aria-describedby="reason-hint" className={styles.textarea} />
            <span id="reason-hint" className={styles.hint}>O cliente vê este motivo.</span>
            <button type="submit" className={styles.secondary} disabled={busy}>{cancelling ? 'A cancelar…' : 'Cancelar pedido'}</button>
          </form>
        </details>
      )}
    </div>
  );
}
