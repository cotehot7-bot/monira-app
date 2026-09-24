'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/db/browser';
import styles from './page.module.css';

export default function EntrarForm({ next }: { next: string }) {
  const router = useRouter();
  const [step, setStep] = useState<'email' | 'code'>('email');
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [pending, setPending] = useState(false);

  async function sendCode(e: React.FormEvent) {
    e.preventDefault();
    setPending(true);
    setError('');
    const { error } = await createClient().auth.signInWithOtp({ email: email.trim() });
    setPending(false);
    if (error) return setError('Não foi possível enviar o código. Confirma o email.');
    setStep('code');
  }

  async function confirmCode(e: React.FormEvent) {
    e.preventDefault();
    setPending(true);
    setError('');
    const { error } = await createClient().auth.verifyOtp({ email: email.trim(), token: code.trim(), type: 'email' });
    setPending(false);
    if (error) return setError('Código inválido ou expirado.');
    router.replace(next);
    router.refresh();
  }

  if (step === 'email') {
    return (
      <form onSubmit={sendCode} className={styles.form}>
        <label htmlFor="email" className={styles.label}>Email</label>
        <input id="email" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} className={styles.input} />
        {error && <p role="alert" className={styles.error}>{error}</p>}
        <button type="submit" disabled={pending || !email.trim()} className={styles.primary}>{pending ? 'A enviar…' : 'Enviar código'}</button>
      </form>
    );
  }

  return (
    <form onSubmit={confirmCode} className={styles.form}>
      <p className={styles.text}>Enviámos um código para {email}.</p>
      <label htmlFor="code" className={styles.label}>Código</label>
      <input id="code" inputMode="numeric" autoComplete="one-time-code" required value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 10))} className={styles.input} />
      {error && <p role="alert" className={styles.error}>{error}</p>}
      <button type="submit" disabled={pending || code.length < 6} className={styles.primary}>{pending ? 'A confirmar…' : 'Confirmar'}</button>
      <button type="button" className={styles.link} onClick={() => { setStep('email'); setCode(''); setError(''); }}>Usar outro email</button>
    </form>
  );
}
