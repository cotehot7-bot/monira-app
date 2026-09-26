'use client';

import { useActionState, useState } from 'react';
import { createOrder, type BuyState } from './actions';
import styles from './comprar.module.css';

type Zone = { id: string; name: string; fee: number };

function kz(n: number) {
  return `${Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')} Kz`;
}

export default function BuyForm(props: {
  productId: string;
  price: number;
  options: { id: string; name: string }[];
  delivery: boolean;
  pickup: boolean;
  zones: Zone[];
  pickupAddress: string | null;
  phone: string;
}) {
  const [state, action, pending] = useActionState<BuyState, FormData>(createOrder.bind(null, props.productId), { status: 'idle' });
  const [mode, setMode] = useState<'delivery' | 'pickup'>(props.delivery ? 'delivery' : 'pickup');
  const [zoneId, setZoneId] = useState(props.zones.length === 1 ? props.zones[0].id : '');
  const [optionId, setOptionId] = useState('');

  const zone = props.zones.find((z) => z.id === zoneId);
  const fee = mode === 'delivery' ? zone?.fee ?? null : 0;
  const total = fee === null ? null : props.price + fee;

  return (
    <form action={action} className={styles.form}>
      <input type="hidden" name="mode" value={mode} />
      <input type="hidden" name="zone_id" value={zoneId} />
      <input type="hidden" name="option_id" value={optionId} />

      {props.options.length > 0 && (
        <fieldset className={styles.block}>
          <legend className={styles.label}>Opção</legend>
          <div className={styles.chips}>
            {props.options.map((o) => (
              <button key={o.id} type="button" aria-pressed={optionId === o.id} onClick={() => setOptionId(o.id)} className={optionId === o.id ? styles.chipOn : styles.chip}>
                {o.name}
              </button>
            ))}
          </div>
        </fieldset>
      )}

      {props.delivery && props.pickup && (
        <fieldset className={styles.block}>
          <legend className={styles.label}>Como recebes</legend>
          <div className={styles.segment}>
            <button type="button" aria-pressed={mode === 'delivery'} onClick={() => setMode('delivery')} className={mode === 'delivery' ? styles.segOn : styles.seg}>Entrega</button>
            <button type="button" aria-pressed={mode === 'pickup'} onClick={() => setMode('pickup')} className={mode === 'pickup' ? styles.segOn : styles.seg}>Levantamento</button>
          </div>
        </fieldset>
      )}

      {mode === 'delivery' && (
        <section className={styles.block}>
          {props.zones.length === 1 ? (
            // Uma só opção de entrega: nada para escolher.
            <div className={styles.fixed}>
              <span className={styles.fixedTitle}>Entrega · {kz(props.zones[0].fee)}</span>
              <span className={styles.fixedSub}>{props.zones[0].name}</span>
            </div>
          ) : (
            <fieldset className={styles.block}>
              <legend className={styles.label}>Onde queres receber?</legend>
              {props.zones.map((z) => (
                <label key={z.id} className={zoneId === z.id ? styles.radioOn : styles.radio}>
                  <input type="radio" name="zone_pick" checked={zoneId === z.id} onChange={() => setZoneId(z.id)} />
                  <span className={styles.radioName}>{z.name}</span>
                  <span>{kz(z.fee)}</span>
                </label>
              ))}
            </fieldset>
          )}
          <label htmlFor="address" className={styles.label}>Morada de entrega</label>
          <textarea id="address" name="address" rows={2} maxLength={300} required placeholder="Bairro, rua, referência" className={styles.textarea} />
        </section>
      )}

      {mode === 'pickup' && props.pickupAddress && (
        <div className={styles.fixed}>
          <span className={styles.fixedTitle}>Levantamento · sem custo</span>
          <span className={styles.fixedSub}>{props.pickupAddress}</span>
        </div>
      )}

      <section className={styles.block}>
        <label htmlFor="phone" className={styles.label}>O teu telefone</label>
        <input id="phone" name="phone" type="tel" required defaultValue={props.phone} placeholder="+244 9XX XXX XXX" autoComplete="tel" className={styles.input} />
        <span className={styles.hint}>Para a loja te contactar sobre o pedido.</span>
      </section>

      <section className={styles.summary}>
        <div className={styles.row}><span>Produto</span><span>{kz(props.price)}</span></div>
        <div className={styles.row}><span>{mode === 'delivery' ? 'Entrega' : 'Levantamento'}</span><span>{fee === null ? '—' : fee === 0 ? 'Sem custo' : kz(fee)}</span></div>
        <div className={styles.total}><span>Total</span><span>{total === null ? '—' : kz(total)}</span></div>
        <p className={styles.pay}>{mode === 'delivery' ? 'Pagas na entrega.' : 'Pagas no levantamento.'}</p>
      </section>

      <div className={styles.footer}>
        {state.status === 'error' && <p className={styles.error} role="alert">{state.message}</p>}
        <button type="submit" className={styles.primary} disabled={pending || (props.options.length > 0 && !optionId) || (mode === 'delivery' && !zoneId)}>
          {pending ? 'A enviar…' : 'Fazer pedido'}
        </button>
      </div>
    </form>
  );
}
