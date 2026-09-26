import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { formatKz } from '@/lib/public';
import { ORDER_STATUS_BUYER } from '@/lib/orders';
import styles from './pedidos.module.css';

export const metadata: Metadata = { title: 'Os meus pedidos · Monira' };

export default async function PedidosPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/entrar?next=/pedidos');

  // Só os pedidos em que sou quem compra (a RLS também deixa a loja ver os seus; filtramos por comprador).
  const { data: buyer } = await supabase.from('monira_buyers').select('id').eq('user_id', user.id).maybeSingle();
  const { data: orders } = buyer
    ? await supabase.from('monira_orders').select('id, order_number, total_kz, status, product_id, created_at').eq('buyer_id', buyer.id).order('created_at', { ascending: false })
    : { data: [] };
  const ids = [...new Set((orders ?? []).map((o) => o.product_id))];
  const { data: products } = ids.length ? await supabase.from('monira_public_products').select('id, name').in('id', ids) : { data: [] };
  const name = new Map((products ?? []).map((p) => [p.id, p.name as string]));

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/" className={styles.back}>← Início</Link>
        <h1 className={styles.title}>Os meus pedidos</h1>
      </header>
      {(orders ?? []).length === 0 ? (
        <p className={styles.empty}>Ainda não fizeste pedidos.</p>
      ) : (
        <ul className={styles.list}>
          {(orders ?? []).map((o) => (
            <li key={o.id}>
              <Link href={`/pedidos/${o.id}`} className={styles.row}>
                <span className={styles.rowText}>
                  <span className={styles.rowTitle}>{name.get(o.product_id) ?? 'Produto'}</span>
                  <span className={styles.rowMeta}>{o.order_number} · {formatKz(Number(o.total_kz))}</span>
                </span>
                <span className={styles.badge}>{ORDER_STATUS_BUYER[o.status] ?? o.status}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
