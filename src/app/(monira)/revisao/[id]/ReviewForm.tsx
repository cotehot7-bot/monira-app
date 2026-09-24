'use client';

import { useActionState } from 'react';
import { publishProduct, type PublishState } from './actions';
import styles from '../revisao.module.css';

type Props = {
  productId: string;
  photos: { path: string; url: string }[];
  defaultName: string;
  defaultDescription: string;
  republish: boolean;
};

export default function ReviewForm({ productId, photos, defaultName, defaultDescription, republish }: Props) {
  const [state, formAction, pending] = useActionState<PublishState, FormData>(
    publishProduct.bind(null, productId),
    { status: 'idle' },
  );

  return (
    <form action={formAction} className={styles.form}>
      <fieldset className={styles.fieldset}>
        <legend className={styles.label}>Fotografias a publicar</legend>
        <p className={styles.hint}>A primeira escolhida será a principal.</p>
        <div className={styles.photoGrid}>
          {photos.map((ph, i) => (
            <label key={ph.path} className={styles.photoPick}>
              {/* eslint-disable-next-line @next/next/no-img-element -- URL assinado e temporário do Storage privado */}
              <img src={ph.url} alt={`Fotografia ${i + 1}`} />
              <input type="checkbox" name="photo" value={ph.path} defaultChecked />
            </label>
          ))}
        </div>
      </fieldset>

      <div className={styles.field}>
        <label htmlFor="name" className={styles.label}>Nome apresentado</label>
        <input id="name" name="name" defaultValue={defaultName} maxLength={120} required className={styles.input} />
      </div>

      <div className={styles.field}>
        <label htmlFor="description" className={styles.label}>Descrição apresentada</label>
        <textarea id="description" name="description" defaultValue={defaultDescription} maxLength={1000} rows={4} className={styles.textarea} />
      </div>

      <div className={styles.footer}>
        {state.status === 'error' && <p className={styles.error} role="alert">{state.message}</p>}
        <button type="submit" className={styles.primary} disabled={pending}>
          {pending ? 'A publicar…' : republish ? 'Publicar alterações' : 'Publicar'}
        </button>
      </div>
    </form>
  );
}
