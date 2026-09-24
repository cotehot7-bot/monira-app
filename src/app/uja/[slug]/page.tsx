import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { PUBLIC_PRODUCT_COLUMNS, type PublicProduct, isReady, photoUrl } from '@/lib/public';
import ProductGrid, { VerifiedMark } from '../../_components/ProductGrid';
import styles from './uja.module.css';

const SLUG = /^[a-z0-9-]{1,80}$/;

type PublicUja = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  image_url: string | null;
  logo_url: string | null;
  is_open: boolean;
  verified: boolean;
  pickup_enabled: boolean;
  pickup_address: string | null;
  avenue_id: string | null;
};

// Só a vista pública: imagem e logo são as versões tratadas pela Monira, nunca os originais.
async function load(slug: string) {
  if (!SLUG.test(slug)) return null;
  const supabase = await createClient();
  const { data } = await supabase
    .from('monira_public_ujas')
    .select('id, name, slug, description, image_url, logo_url, is_open, verified, avenue_id, pickup_enabled, pickup_address')
    .eq('slug', slug)
    .maybeSingle();
  const uja = data as PublicUja | null;
  if (!uja) return null;

  const [{ data: rows }, { data: avenue }] = await Promise.all([
    supabase.from('monira_public_products').select(PUBLIC_PRODUCT_COLUMNS).eq('uja_id', uja.id).order('created_at', { ascending: false }),
    uja.avenue_id ? supabase.from('monira_avenues').select('name').eq('id', uja.avenue_id).maybeSingle() : Promise.resolve({ data: null }),
  ]);

  return { uja, avenue, products: ((rows ?? []) as PublicProduct[]).filter(isReady) };
}

// Pesquisa a morada no mapa, com a cidade para desambiguar.
function mapsUrl(address: string) {
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${address}, Luanda, Angola`)}`;
}

// Imagens publicadas pela Monira podem ser caminhos no bucket público ou URLs completos.
function imageSrc(value: string) {
  return /^https?:\/\//.test(value) ? value : photoUrl(value);
}

export async function generateMetadata(props: PageProps<'/uja/[slug]'>): Promise<Metadata> {
  const { slug } = await props.params;
  const data = await load(slug);
  return data ? { title: `${data.uja.name} · Monira`, description: data.uja.description ?? undefined } : { title: 'Monira' };
}

export default async function UjaPage(props: PageProps<'/uja/[slug]'>) {
  const { slug } = await props.params;
  const data = await load(slug);
  if (!data) notFound();
  const { uja, avenue, products } = data;

  return (
    <main className={styles.screen}>
      <header className={styles.top}>
        <Link href="/" className={styles.back} aria-label="Voltar ao início">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M15 6l-6 6 6 6" /></svg>
        </Link>
      </header>

      {uja.image_url && (
        // eslint-disable-next-line @next/next/no-img-element -- imagem da Uja tratada pela Monira
        <img src={imageSrc(uja.image_url)} alt="" className={styles.cover} />
      )}

      <section className={styles.identity}>
        {uja.logo_url ? (
          // eslint-disable-next-line @next/next/no-img-element -- logo tratado pela Monira
          <img src={imageSrc(uja.logo_url)} alt="" className={styles.logo} />
        ) : (
          <span className={styles.monogram} aria-hidden="true">{uja.name.trim().charAt(0).toUpperCase()}</span>
        )}

        <span className={styles.eyebrow}>Uja{avenue?.name ? ` · Avenida ${avenue.name}` : ''}</span>
        <h1 className={styles.name}>
          {uja.name}
          {uja.verified && <VerifiedMark size={20} />}
        </h1>
        <p className={styles.status}>
          <span className={uja.is_open ? styles.dotOpen : styles.dotClosed} aria-hidden="true" />
          {uja.is_open ? 'Aberta agora' : 'Fechada'}
        </p>
        {uja.pickup_enabled && uja.pickup_address && (
          <div className={styles.pickup}>
            <span className={styles.pickupLabel}>Levantamento</span>
            <span className={styles.pickupAddress}>{uja.pickup_address}</span>
            <a href={mapsUrl(uja.pickup_address)} target="_blank" rel="noopener noreferrer" className={styles.pickupMap}>Ver no mapa</a>
          </div>
        )}
        {uja.description && <p className={styles.about}>{uja.description}</p>}
      </section>

      <section className={styles.products} aria-labelledby="produtos">
        <h2 id="produtos" className={styles.sectionTitle}>Produtos</h2>
        {products.length === 0 ? (
          <p className={styles.empty}>Ainda sem produtos publicados.</p>
        ) : (
          <ProductGrid products={products} />
        )}
      </section>
    </main>
  );
}
