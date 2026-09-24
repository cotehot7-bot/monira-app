import type { Metadata } from 'next';
import Link from 'next/link';
import { requireAdmin } from '@/lib/db/admin';
import styles from './revisao.module.css';

export const metadata: Metadata = { title: 'Revisão · Monira' };

function formatKz(value: number) {
  return new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 0 }).format(value).replace(/\s/g, '.') + ' Kz';
}

export default async function ReviewListPage(props: PageProps<'/revisao'>) {
  const supabase = await requireAdmin('/revisao');
  const searchParams = await props.searchParams;

  // Por rever: nunca publicados, ou publicados mas alterados por quem vende.
  const { data: products } = await supabase
    .from('monira_products')
    .select('id, raw_name, price_kz, raw_photos, admin_reviewed, needs_review, created_at, uja:monira_ujas(name)')
    .or('admin_reviewed.eq.false,needs_review.eq.true')
    .eq('active', true)
    .order('created_at', { ascending: true });

  const firstPhotos = (products ?? []).map((p) => p.raw_photos?.[0]).filter((x): x is string => Boolean(x));
  const { data: signed } = firstPhotos.length
    ? await supabase.storage.from('monira-raw').createSignedUrls(firstPhotos, 600)
    : { data: [] };
  const thumb = new Map((signed ?? []).map((s) => [s.path, s.signedUrl]));

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <h1 className={styles.title}>Revisão</h1>
        <p className={styles.subtitle}>{products?.length ? `${products.length} por rever` : 'Nada por rever'}</p>
      </header>

      {searchParams.publicado === '1' && <p className={styles.notice} role="status">Publicado.</p>}

      <ul className={styles.list}>
        {(products ?? []).map((p) => {
          const uja = Array.isArray(p.uja) ? p.uja[0] : p.uja;
          const src = p.raw_photos?.[0] ? thumb.get(p.raw_photos[0]) : undefined;
          return (
            <li key={p.id}>
              <Link href={`/revisao/${p.id}`} className={styles.row}>
                {src ? (
                  // eslint-disable-next-line @next/next/no-img-element -- URL assinado e temporário do Storage privado
                  <img src={src} alt="" className={styles.thumb} />
                ) : (
                  <span className={styles.thumb} />
                )}
                <span className={styles.rowText}>
                  <span className={styles.rowTitle}>{p.raw_name}</span>
                  <span className={styles.rowMeta}>
                    {uja?.name} · {formatKz(Number(p.price_kz))}
                    {p.admin_reviewed && p.needs_review ? ' · alterado' : ''}
                  </span>
                </span>
              </Link>
            </li>
          );
        })}
      </ul>
    </main>
  );
}
