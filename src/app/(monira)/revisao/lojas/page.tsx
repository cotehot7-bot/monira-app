import type { Metadata } from 'next';
import Link from 'next/link';
import { requireAdmin } from '@/lib/db/admin';
import ApplicationDecision from './ApplicationDecision';
import styles from '../revisao.module.css';

export const metadata: Metadata = { title: 'Lojas por aprovar · Monira' };

function when(iso: string) {
  return new Intl.DateTimeFormat('pt-PT', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: 'Africa/Luanda' }).format(new Date(iso));
}

export default async function LojasPage() {
  const supabase = await requireAdmin('/revisao/lojas');

  const [{ data: apps }, { data: categories }] = await Promise.all([
    supabase.from('monira_applications').select('id, name, phone, description, avenue_id, city, created_at').eq('status', 'pendente').order('created_at'),
    supabase.from('monira_avenues').select('id, name').eq('active', true).order('position'),
  ]);
  const cats = (categories ?? []).map((c) => ({ id: c.id as string, name: c.name as string }));
  const catName = new Map(cats.map((c) => [c.id, c.name]));

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/revisao" className={styles.back}>← Revisão</Link>
        <h1 className={styles.title}>Lojas por aprovar</h1>
        <p className={styles.subtitle}>{apps?.length ? `${apps.length} ${apps.length === 1 ? 'pedido' : 'pedidos'}` : 'Nenhum pedido'}</p>
      </header>

      {(apps ?? []).map((a) => (
        <section key={a.id} className={styles.application}>
          <div className={styles.raw}>
            <span className={styles.eyebrow}>Pedido · {when(a.created_at as string)}</span>
            <p className={styles.rawName}>{a.name}</p>
            <p className={styles.rawText}>{a.description}</p>
            <p className={styles.rawMeta}>
              WhatsApp {a.phone}
              {a.city ? ` · ${a.city}` : ''}
              {a.avenue_id ? ` · ${catName.get(a.avenue_id as string) ?? ''}` : ''}
            </p>
          </div>
          <ApplicationDecision id={a.id as string} name={a.name as string} avenueId={(a.avenue_id as string) ?? null} categories={cats} />
        </section>
      ))}
    </main>
  );
}
