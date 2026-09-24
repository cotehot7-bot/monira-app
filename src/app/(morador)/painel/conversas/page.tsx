import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { getMyUja } from '@/lib/db/seller';
import { listConversations } from '@/lib/db/conversations';
import ConversationList from '../../../_components/ConversationList';
import styles from '../../../conversas/conversas.module.css';

export const metadata: Metadata = { title: 'Conversas · Monira' };

// As conversas da Uja de quem vende. "Por responder" = a última mensagem é do cliente.
export default async function PainelConversasPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/entrar?next=/painel/conversas');

  const uja = await getMyUja(supabase, user.id);
  if (!uja) redirect('/painel');

  const rows = await listConversations(supabase, user.id, { ujaId: uja.id });
  const pending = rows.filter((r) => !r.lastFromMe).length;

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/painel" className={styles.back}>← Painel</Link>
        <h1 className={styles.title}>Conversas</h1>
        <p className={styles.subtitle}>{pending ? `${pending} por responder` : 'Tudo respondido'}</p>
      </header>
      <section className={styles.body}>
        {rows.length === 0 ? <p className={styles.empty}>Ainda sem conversas.</p> : <ConversationList rows={rows} side="seller" />}
      </section>
    </main>
  );
}
