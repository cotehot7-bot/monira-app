import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { getMyUja } from '@/lib/db/seller';
import VenderForm from './VenderForm';
import styles from './vender.module.css';

export const metadata: Metadata = { title: 'Vender na Monira' };

export default async function VenderPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/entrar?next=/vender');

  // Quem já tem Uja vai directo para o painel.
  if (await getMyUja(supabase, user.id)) redirect('/painel');

  const [{ data: latest }, { data: categories }] = await Promise.all([
    supabase.from('monira_applications').select('status, decision_note, created_at').eq('user_id', user.id).order('created_at', { ascending: false }).limit(1).maybeSingle(),
    supabase.from('monira_avenues').select('id, name').eq('active', true).order('position'),
  ]);

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/" className={styles.back}>← Início</Link>
        <h1 className={styles.title}>Vender na Monira</h1>
      </header>

      {latest?.status === 'pendente' ? (
        <section className={styles.state}>
          <h2 className={styles.stateTitle}>Recebido.</h2>
          <p className={styles.text}>A Monira está a analisar o teu pedido. A resposta aparece aqui.</p>
        </section>
      ) : (
        <>
          {latest?.status === 'rejeitado' && latest.decision_note && (
            <p className={styles.note}>
              <strong>A Monira respondeu</strong>
              {latest.decision_note}
            </p>
          )}
          <p className={styles.intro}>Conta-nos sobre o teu negócio. A Monira analisa o pedido e prepara a tua Uja.</p>
          <VenderForm categories={(categories ?? []).map((c) => ({ id: c.id as string, name: c.name as string }))} />
        </>
      )}
    </main>
  );
}
