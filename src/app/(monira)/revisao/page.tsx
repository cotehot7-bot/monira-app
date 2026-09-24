import type { Metadata } from 'next';
import Link from 'next/link';
import { requireAdmin } from '@/lib/db/admin';
import { formatKz } from '@/lib/public';
import styles from './revisao.module.css';

export const metadata: Metadata = { title: 'Revisão · Monira' };

type Row = {
  id: string;
  raw_name: string | null;
  name: string | null;
  price_kz: number;
  raw_photos: string[] | null;
  admin_reviewed: boolean;
  needs_review: boolean;
  attention_note: string | null;
  created_at: string;
  uja: { name: string } | { name: string }[] | null;
};

const NOTICES: Record<string, string> = {
  publicado: 'Publicado.',
  pedido: 'Pedido enviado a quem vende.',
  apagado: 'Envio apagado.',
};

function List({ items, thumb, meta }: { items: Row[]; thumb: Map<string, string>; meta: (p: Row) => string }) {
  return (
    <ul className={styles.list}>
      {items.map((p) => {
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
                <span className={styles.rowTitle}>{(p.admin_reviewed ? p.name : null) ?? p.raw_name}</span>
                <span className={styles.rowMeta}>{meta(p)}</span>
              </span>
            </Link>
          </li>
        );
      })}
    </ul>
  );
}

const ujaName = (p: Row) => (Array.isArray(p.uja) ? p.uja[0]?.name : p.uja?.name) ?? '';

export default async function ReviewListPage(props: PageProps<'/revisao'>) {
  const supabase = await requireAdmin('/revisao');
  const searchParams = await props.searchParams;
  const noticeKey = Object.keys(NOTICES).find((k) => searchParams[k] === '1');

  const { data } = await supabase
    .from('monira_products')
    .select('id, raw_name, name, price_kz, raw_photos, admin_reviewed, needs_review, attention_note, created_at, uja:monira_ujas(name)')
    .eq('active', true)
    .order('created_at', { ascending: true });
  const rows = (data ?? []) as Row[];

  // Três filas editoriais.
  const toReview = rows.filter((p) => !p.attention_note && (!p.admin_reviewed || p.needs_review));
  const waiting = rows.filter((p) => p.attention_note);
  const published = rows.filter((p) => p.admin_reviewed && !p.needs_review && !p.attention_note).reverse();

  const firstPhotos = rows.map((p) => p.raw_photos?.[0]).filter((x): x is string => Boolean(x));
  const { data: signed } = firstPhotos.length
    ? await supabase.storage.from('monira-raw').createSignedUrls(firstPhotos, 600)
    : { data: [] };
  const thumb = new Map<string, string>((signed ?? []).map((s) => [s.path ?? '', s.signedUrl ?? '']));


  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <h1 className={styles.title}>Revisão</h1>
        <p className={styles.subtitle}>{toReview.length ? `${toReview.length} por rever` : 'Nada por rever'}</p>
      </header>

      {noticeKey && <p className={styles.notice} role="status">{NOTICES[noticeKey]}</p>}

      {toReview.length > 0 && (
        <List items={toReview} thumb={thumb} meta={(p) => `${ujaName(p)} · ${formatKz(p.price_kz)}${p.admin_reviewed ? ' · alterado' : ''}`} />
      )}

      {waiting.length > 0 && (
        <section className={styles.group}>
          <h2 className={styles.groupTitle}>À espera de quem vende</h2>
          <List items={waiting} thumb={thumb} meta={(p) => `${ujaName(p)} · ${p.attention_note}`} />
        </section>
      )}

      {published.length > 0 && (
        <section className={styles.group}>
          <h2 className={styles.groupTitle}>Publicados</h2>
          <List items={published} thumb={thumb} meta={(p) => `${ujaName(p)} · ${formatKz(p.price_kz)}`} />
        </section>
      )}
    </main>
  );
}
