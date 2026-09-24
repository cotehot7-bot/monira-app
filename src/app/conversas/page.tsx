import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { getMyUja } from '@/lib/db/seller';
import { listConversations } from '@/lib/db/conversations';
import ConversationList from '../_components/ConversationList';
import styles from './conversas.module.css';

export const metadata: Metadata = { title: 'Conversas · Monira' };

// As conversas de quem compra.
export default async function ConversasPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/entrar?next=/conversas');

  const myUja = await getMyUja(supabase, user.id);
  const rows = await listConversations(supabase, user.id, { excludeUjaId: myUja?.id });

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/" className={styles.back}>← Início</Link>
        <h1 className={styles.title}>Conversas</h1>
      </header>
      <section className={styles.body}>
        {rows.length === 0 ? <p className={styles.empty}>Ainda não tens conversas.</p> : <ConversationList rows={rows} side="buyer" />}
      </section>
    </main>
  );
}
