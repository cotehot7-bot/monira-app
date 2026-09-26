import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { getMyUja } from '@/lib/db/seller';
import { formatKz } from '@/lib/public';
import { ORDER_STATUS_SELLER, OFFLINE_METHOD, paymentLine } from '@/lib/orders';
import OrderActions from './OrderActions';
import styles from '../../../../pedidos/pedidos.module.css';

export const metadata: Metadata = { title: 'Pedido · Monira' };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function when(iso: string) {
  return new Intl.DateTimeFormat('pt-PT', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: 'Africa/Luanda' }).format(new Date(iso));
}

// O pedido visto pela loja.
export default async function PainelPedidoPage(props: PageProps<'/painel/pedidos/[id]'>) {
  const { id } = await props.params;
  if (!UUID.test(id)) notFound();
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?next=/painel/pedidos/${id}`);
  const uja = await getMyUja(supabase, user.id);
  if (!uja) redirect('/vender');

  const { data: o } = await supabase
    .from('monira_orders')
    .select('id, order_number, product_id, option_name, price_kz, delivery_fee_kz, total_kz, delivery_mode, delivery_zone_name, delivery_address, payment_method, customer_phone, status, cancel_reason, created_at')
    .eq('id', id)
    .eq('uja_id', uja.id)
    .maybeSingle();
  if (!o) notFound();

  const [{ data: product }, { data: pay }, { data: offline }] = await Promise.all([
    supabase.from('monira_products').select('name, raw_name').eq('id', o.product_id).maybeSingle(),
    supabase.from('monira_order_payment_state').select('payment_state').eq('order_id', id).maybeSingle(),
    supabase.from('monira_offline_payments').select('method, recorded_at').eq('order_id', id).maybeSingle(),
  ]);
  const total = formatKz(Number(o.total_kz));
  const phoneDigits = String(o.customer_phone ?? '').replace(/[^\d+]/g, '');

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/painel/pedidos" className={styles.back}>← Pedidos</Link>
        <h1 className={styles.title}>Pedido {o.order_number}</h1>
        <p className={styles.lead}>{ORDER_STATUS_SELLER[o.status] ?? o.status} · {when(o.created_at as string)}</p>
      </header>

      <dl className={styles.facts}>
        <div><dt>Produto</dt><dd>{product?.name ?? product?.raw_name}{o.option_name ? ` · ${o.option_name}` : ''}</dd></div>
        <div><dt>{o.delivery_mode === 'delivery' ? 'Entrega' : 'Levantamento'}</dt>
          <dd>{o.delivery_mode === 'delivery' ? `${o.delivery_address ?? ''}${o.delivery_zone_name ? ` · ${o.delivery_zone_name}` : ''}` : 'Na tua morada de levantamento'}</dd></div>
        <div><dt>Cliente</dt><dd>{phoneDigits ? <a href={`tel:${phoneDigits}`}>{o.customer_phone}</a> : '—'}</dd></div>
        <div><dt>Produto + entrega</dt><dd>{formatKz(Number(o.price_kz))} + {formatKz(Number(o.delivery_fee_kz))}</dd></div>
        <div><dt>Total</dt><dd>{total}</dd></div>
        <div><dt>Pagamento</dt><dd>
          {paymentLine(o.payment_method, pay?.payment_state ?? null, 'seller', total)}
          {offline ? ` · ${OFFLINE_METHOD[offline.method as string] ?? offline.method}` : ''}
        </dd></div>
        {o.status === 'cancelled' && o.cancel_reason && <div><dt>Motivo</dt><dd>{o.cancel_reason}</dd></div>}
      </dl>

      <OrderActions orderId={o.id} status={o.status} mode={o.delivery_mode} />
    </main>
  );
}
