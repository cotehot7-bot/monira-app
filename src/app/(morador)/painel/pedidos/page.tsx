import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { getMyUja } from '@/lib/db/seller';
import { formatKz } from '@/lib/public';
import { ORDER_STATUS_SELLER } from '@/lib/orders';
import styles from '../../../pedidos/pedidos.module.css';

export const metadata: Metadata = { title: 'Pedidos · Monira' };

const TABS = [
  { key: 'new', label: 'Novos' },
  { key: 'delivering', label: 'A entregar' },
  { key: 'done', label: 'Concluídos' },
] as const;

export default async function PainelPedidosPage(props: PageProps<'/painel/pedidos'>) {
  const sp = await props.searchParams;
  const tab = (TABS.find((t) => t.key === sp.estado)?.key ?? 'new') as (typeof TABS)[number]['key'];
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/entrar?next=/painel/pedidos');
  const uja = await getMyUja(supabase, user.id);
  if (!uja) redirect('/vender');

  let q = supabase.from('monira_orders').select('id, order_number, total_kz, status, product_id, delivery_mode, created_at').eq('uja_id', uja.id).order('created_at', { ascending: false });
  q = tab === 'done' ? q.in('status', ['completed', 'cancelled']) : q.eq('status', tab);
  const { data: orders } = await q;
  const ids = [...new Set((orders ?? []).map((o) => o.product_id))];
  const { data: products } = ids.length ? await supabase.from('monira_products').select('id, name, raw_name').in('id', ids) : { data: [] };
  const name = new Map((products ?? []).map((p) => [p.id, (p.name ?? p.raw_name) as string]));

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/painel" className={styles.back}>← Painel</Link>
        <h1 className={styles.title}>Pedidos</h1>
      </header>
      <nav className={styles.tabs} aria-label="Estados">
        {TABS.map((t) => (
          <Link key={t.key} href={`/painel/pedidos?estado=${t.key}`} aria-current={t.key === tab ? 'page' : undefined} className={t.key === tab ? styles.tabOn : styles.tab}>{t.label}</Link>
        ))}
      </nav>
      {(orders ?? []).length === 0 ? (
        <p className={styles.empty}>Nada aqui.</p>
      ) : (
        <ul className={styles.list}>
          {(orders ?? []).map((o) => (
            <li key={o.id}>
              <Link href={`/painel/pedidos/${o.id}`} className={styles.row}>
                <span className={styles.rowText}>
                  <span className={styles.rowTitle}>{name.get(o.product_id) ?? 'Produto'}</span>
                  <span className={styles.rowMeta}>{o.order_number} · {formatKz(Number(o.total_kz))} · {o.delivery_mode === 'delivery' ? 'Entrega' : 'Levantamento'}</span>
                </span>
                <span className={styles.badge}>{ORDER_STATUS_SELLER[o.status] ?? o.status}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
