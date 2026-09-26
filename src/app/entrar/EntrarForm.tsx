'use client';

import { useState } from 'react';
import { createClient } from '@/lib/db/browser';
import styles from './page.module.css';

export default function EntrarForm({ next, linkFailed }: { next: string; linkFailed: boolean }) {
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [error, setError] = useState(linkFailed ? 'O link expirou ou já foi usado. Pede outro.' : '');
  const [pending, setPending] = useState(false);

  async function sendLink(e: React.FormEvent) {
    e.preventDefault();
    setPending(true);
    setError('');
    const redirect = new URL('/auth/callback', window.location.origin);
    redirect.searchParams.set('next', next);
    const { error } = await createClient().auth.signInWithOtp({
      email: email.trim(),
      options: { emailRedirectTo: redirect.toString() },
    });
    setPending(false);
    if (error) return setError('Não foi possível enviar o email. Confirma o endereço e tenta daqui a pouco.');
    setSent(true);
  }

  if (sent) {
    return (
      <div className={styles.form} aria-live="polite">
        <p className={styles.text}>Enviámos um link de entrada para <strong>{email.trim()}</strong>.</p>
        <p className={styles.text}>Abre-o neste mesmo telemóvel e neste mesmo browser.</p>
        <button type="button" className={styles.link} onClick={() => setSent(false)}>Usar outro email</button>
      </div>
    );
  }

  return (
    <form onSubmit={sendLink} className={styles.form}>
      <label htmlFor="email" className={styles.label}>Email</label>
      <input id="email" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} className={styles.input} />
      {error && <p role="alert" className={styles.error}>{error}</p>}
      <button type="submit" disabled={pending || !email.trim()} className={styles.primary}>{pending ? 'A enviar…' : 'Enviar link'}</button>
      <p className={styles.legal}>Ao entrar, aceitas a forma como a Monira trata os teus dados. <a href="/privacidade">Privacidade</a></p>
    </form>
  );
}
