import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { PUBLIC_PRODUCT_COLUMNS, type PublicProduct, isReady, photoUrl, formatKz } from '@/lib/public';
import BuyForm from './BuyForm';
import styles from './comprar.module.css';

export const metadata: Metadata = { title: 'Comprar · Monira' };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default async function ComprarPage(props: PageProps<'/comprar/[id]'>) {
  const { id } = await props.params;
  if (!UUID.test(id)) notFound();

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?next=/comprar/${id}`);

  const { data } = await supabase.from('monira_public_products').select(PUBLIC_PRODUCT_COLUMNS).eq('id', id).maybeSingle();
  const product = data as PublicProduct | null;
  if (!product || !isReady(product)) notFound();

  const [{ data: uja }, { data: zones }, { data: options }, { data: buyer }] = await Promise.all([
    supabase.from('monira_public_ujas').select('name, slug, is_open, pay_on_delivery, pay_on_pickup, pickup_address').eq('id', product.uja_id).maybeSingle(),
    supabase.from('monira_uja_delivery_zones').select('id, name, fee_kz').eq('uja_id', product.uja_id).order('position'),
    supabase.from('monira_product_options').select('id, name, position').eq('product_id', id).eq('active', true).order('position'),
    supabase.from('monira_buyers').select('phone').eq('user_id', user.id).maybeSingle(),
  ]);
  if (!uja) notFound();

  const zoneList = (zones ?? []).map((z) => ({ id: z.id as string, name: z.name as string, fee: Number(z.fee_kz) }));
  const delivery = Boolean(uja.pay_on_delivery) && zoneList.length > 0;
  const pickup = Boolean(uja.pay_on_pickup);
  const canBuy = uja.is_open && product.available && (delivery || pickup);

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href={`/produto/${product.id}`} className={styles.back}>← Produto</Link>
        <h1 className={styles.title}>Comprar</h1>
      </header>

      <div className={styles.product}>
        {/* eslint-disable-next-line @next/next/no-img-element -- fotografia já tratada pela Monira */}
        <img src={photoUrl(product.photos[0])} alt="" className={styles.photo} />
        <span className={styles.productText}>
          <span className={styles.productName}>{product.name}</span>
          <span className={styles.productMeta}>{uja.name} · {formatKz(product.price_kz)}</span>
        </span>
      </div>

      {canBuy ? (
        <BuyForm
          productId={product.id}
          price={Number(product.price_kz)}
          options={(options ?? []).map((o) => ({ id: o.id as string, name: o.name as string }))}
          delivery={delivery}
          pickup={pickup}
          zones={zoneList}
          pickupAddress={(uja.pickup_address as string) ?? null}
          phone={(buyer?.phone as string) ?? ''}
        />
      ) : (
        <p className={styles.unavailable}>
          {!uja.is_open ? 'Esta Uja está fechada neste momento.' : !product.available ? 'Este produto esgotou.' : 'Esta Uja ainda não recebe pedidos pela Monira.'}
          {' '}Podes <Link href={`/produto/${product.id}`}>conversar com a loja</Link>.
        </p>
      )}
    </main>
  );
}
