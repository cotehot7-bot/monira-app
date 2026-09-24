import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { PUBLIC_PRODUCT_COLUMNS, type PublicProduct, isReady, photoUrl, formatKz } from '@/lib/public';
import { VerifiedMark } from '../../_components/ProductGrid';
import { startConversation } from '../../conversas/actions';
import styles from './produto.module.css';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function load(id: string) {
  if (!UUID.test(id)) return null;
  const supabase = await createClient();
  const { data } = await supabase.from('monira_public_products').select(PUBLIC_PRODUCT_COLUMNS).eq('id', id).maybeSingle();
  const product = data as PublicProduct | null;
  if (!product || !isReady(product)) return null;

  const [{ data: uja }, { data: options }] = await Promise.all([
    supabase.from('monira_public_ujas').select('id, name, slug, verified, avenue_id, pickup_enabled, pickup_address').eq('id', product.uja_id).maybeSingle(),
    supabase.from('monira_product_options').select('name, position').eq('product_id', id).eq('active', true).order('position'),
  ]);
  const { data: avenue } = uja?.avenue_id
    ? await supabase.from('monira_avenues').select('name').eq('id', uja.avenue_id).maybeSingle()
    : { data: null };

  return { product, uja, avenue, options: (options ?? []).map((o) => o.name as string) };
}

export async function generateMetadata(props: PageProps<'/produto/[id]'>): Promise<Metadata> {
  const { id } = await props.params;
  const data = await load(id);
  if (!data) return { title: 'Monira' };
  return {
    title: `${data.product.name} · Monira`,
    description: data.product.description ?? undefined,
    openGraph: { images: [photoUrl(data.product.photos[0])] },
  };
}

export default async function ProdutoPage(props: PageProps<'/produto/[id]'>) {
  const { id } = await props.params;
  const data = await load(id);
  if (!data) notFound();
  const { product, uja, avenue, options } = data;

  return (
    <main className={styles.screen}>
      <div className={styles.gallery} aria-label="Fotografias">
        {product.photos.map((path, i) => (
          // eslint-disable-next-line @next/next/no-img-element -- fotografia já tratada pela Monira (JPEG ≤1600 px)
          <img key={path} src={photoUrl(path)} alt={i === 0 ? product.name : `${product.name}, fotografia ${i + 1}`} className={styles.photo} />
        ))}
        <Link href="/" aria-label="Voltar ao início" className={styles.back}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M15 6l-6 6 6 6" /></svg>
        </Link>
        {product.photos.length > 1 && <span className={styles.count}>{product.photos.length} fotos</span>}
      </div>

      <section className={styles.body}>
        <h1 className={styles.name}>{product.name}</h1>
        <p className={styles.price}>{formatKz(product.price_kz)}</p>
        {!product.available && <p className={styles.soldOut}>Esgotado</p>}
        {product.description && <p className={styles.description}>{product.description}</p>}

        {options.length > 0 && (
          <div className={styles.options}>
            <span className={styles.optionsLabel}>Opções</span>
            <ul className={styles.chips}>
              {options.map((o) => <li key={o} className={styles.chip}>{o}</li>)}
            </ul>
          </div>
        )}

        <form action={startConversation.bind(null, product.id)} className={styles.talk}>
          <button type="submit" className={styles.talkButton}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M5 18.5V6.5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H9l-4 3z" /></svg>
            Conversar sobre este produto
          </button>
        </form>

        {uja && (
          <Link href={`/uja/${uja.slug}`} className={styles.seller}>
            <span className={styles.sellerText}>
              <span className={styles.sellerLabel}>Vendido por</span>
              <span className={styles.sellerName}>
                Uja {uja.name}{avenue?.name ? ` — Avenida ${avenue.name}` : ''}
                {uja.verified && <VerifiedMark />}
              </span>
            </span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#8a8a8a" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
          </Link>
        )}
        {uja?.pickup_enabled && uja.pickup_address && (
          <p className={styles.pickup}>Levantamento em {uja.pickup_address}</p>
        )}
      </section>
    </main>
  );
}
