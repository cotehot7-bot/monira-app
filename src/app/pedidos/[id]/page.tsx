import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { formatKz, photoUrl } from '@/lib/public';
import { ORDER_STATUS_BUYER, paymentLine } from '@/lib/orders';
import { startConversation } from '../../conversas/actions';
import styles from '../pedidos.module.css';

export const metadata: Metadata = { title: 'Pedido · Monira' };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// O pedido visto por quem comprou.
export default async function PedidoPage(props: PageProps<'/pedidos/[id]'>) {
  const { id } = await props.params;
  const sp = await props.searchParams;
  if (!UUID.test(id)) notFound();

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?next=/pedidos/${id}`);

  const { data: o } = await supabase
    .from('monira_orders')
    .select('id, order_number, product_id, uja_id, option_name, total_kz, delivery_fee_kz, delivery_mode, delivery_zone_name, delivery_address, payment_method, status, cancel_reason, created_at')
    .eq('id', id)
    .maybeSingle();
  if (!o) notFound();

  const [{ data: product }, { data: uja }, { data: pay }] = await Promise.all([
    supabase.from('monira_public_products').select('name, photos').eq('id', o.product_id).maybeSingle(),
    supabase.from('monira_public_ujas').select('name, slug, pickup_address').eq('id', o.uja_id).maybeSingle(),
    supabase.from('monira_order_payment_state').select('payment_state').eq('order_id', id).maybeSingle(),
  ]);
  const total = formatKz(Number(o.total_kz));
  const isNew = sp.novo === '1';

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/pedidos" className={styles.back}>← Os meus pedidos</Link>
        {isNew ? <h1 className={styles.hero}>Pedido feito.</h1> : <h1 className={styles.title}>Pedido {o.order_number}</h1>}
        {isNew && <p className={styles.lead}>A {uja?.name ?? 'loja'} já foi avisada e vai contactar-te.</p>}
      </header>

      <section className={styles.card}>
        {product?.photos?.[0] && (
          // eslint-disable-next-line @next/next/no-img-element -- fotografia já tratada pela Monira
          <img src={photoUrl(product.photos[0])} alt="" className={styles.photo} />
        )}
        <span className={styles.cardText}>
          <span className={styles.cardTitle}>{product?.name ?? 'Produto'}{o.option_name ? ` · ${o.option_name}` : ''}</span>
          <span className={styles.cardMeta}>{uja?.name} · {o.order_number}</span>
        </span>
      </section>

      <dl className={styles.facts}>
        <div><dt>Estado</dt><dd>{ORDER_STATUS_BUYER[o.status] ?? o.status}</dd></div>
        <div><dt>{o.delivery_mode === 'delivery' ? 'Entrega' : 'Levantamento'}</dt>
          <dd>{o.delivery_mode === 'delivery' ? `${o.delivery_address ?? ''}${o.delivery_zone_name ? ` · ${o.delivery_zone_name}` : ''}` : uja?.pickup_address ?? ''}</dd></div>
        <div><dt>Total</dt><dd>{total}</dd></div>
        <div><dt>Pagamento</dt><dd>{paymentLine(o.payment_method, pay?.payment_state ?? null, 'buyer', total)}</dd></div>
        {o.status === 'cancelled' && o.cancel_reason && <div><dt>Motivo</dt><dd>{o.cancel_reason}</dd></div>}
      </dl>

      <form action={startConversation.bind(null, o.product_id)} className={styles.actions}>
        <button type="submit" className={styles.secondary}>Conversar com a loja</button>
      </form>
    </main>
  );
}
