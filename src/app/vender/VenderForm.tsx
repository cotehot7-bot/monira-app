'use client';

import { useActionState } from 'react';
import { submitApplication, type ApplyState } from './actions';
import styles from './vender.module.css';

export default function VenderForm({ categories }: { categories: { id: string; name: string }[] }) {
  const [state, action, pending] = useActionState<ApplyState, FormData>(submitApplication, { status: 'idle' });

  if (state.status === 'sent') {
    return (
      <section className={styles.state} aria-live="polite">
        <h2 className={styles.stateTitle}>Recebido.</h2>
        <p className={styles.text}>A Monira vai analisar o teu pedido e responde-te aqui.</p>
      </section>
    );
  }

  return (
    <form action={action} className={styles.form}>
      <div className={styles.field}>
        <label htmlFor="name" className={styles.label}>Nome do teu negócio</label>
        <input id="name" name="name" required maxLength={80} autoComplete="organization" className={styles.input} />
      </div>
      <div className={styles.field}>
        <label htmlFor="phone" className={styles.label}>WhatsApp</label>
        <input id="phone" name="phone" type="tel" required placeholder="+244 9XX XXX XXX" autoComplete="tel" className={styles.input} />
      </div>
      <div className={styles.field}>
        <label htmlFor="description" className={styles.label}>O que vendes?</label>
        <textarea id="description" name="description" required rows={3} maxLength={1000} placeholder="Ex.: telemóveis e acessórios originais" className={styles.textarea} />
      </div>
      <div className={styles.field}>
        <label htmlFor="avenue_id" className={styles.label}>Categoria principal</label>
        <select id="avenue_id" name="avenue_id" defaultValue="" className={styles.input}>
          <option value="">Escolher…</option>
          {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
      </div>
      <div className={styles.field}>
        <label htmlFor="city" className={styles.label}>Onde estás (cidade ou bairro)</label>
        <input id="city" name="city" maxLength={80} placeholder="Ex.: Luanda, Talatona" className={styles.input} />
      </div>
      {state.status === 'error' && <p className={styles.error} role="alert">{state.message}</p>}
      <button type="submit" className={styles.primary} disabled={pending}>{pending ? 'A enviar…' : 'Enviar pedido'}</button>
    </form>
  );
}
