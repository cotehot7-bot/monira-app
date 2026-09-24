import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/db/admin';
import ReviewForm from './ReviewForm';
import EditorialActions from './EditorialActions';

const DECISION_LABEL: Record<string, string> = {
  published: 'Publicado',
  changes_requested: 'Alterações pedidas',
  resubmitted: 'Quem vende enviou de novo',
};

function formatDate(iso: string) {
  return new Intl.DateTimeFormat('pt-PT', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: 'Africa/Luanda' }).format(new Date(iso));
}
import styles from '../revisao.module.css';

export const metadata: Metadata = { title: 'Rever produto · Monira' };

function formatKz(value: number) {
  return new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 0 }).format(value).replace(/\s/g, '.') + ' Kz';
}

export default async function ReviewProductPage(props: PageProps<'/revisao/[id]'>) {
  const { id } = await props.params;
  const supabase = await requireAdmin(`/revisao/${id}`);

  const { data: p } = await supabase
    .from('monira_products')
    .select('id, raw_name, raw_description, raw_photos, price_kz, name, description, admin_reviewed, attention_note, created_at, uja:monira_ujas(name), options:monira_product_options(name, position)')
    .eq('id', id)
    .maybeSingle();
  if (!p) notFound();

  const uja = Array.isArray(p.uja) ? p.uja[0] : p.uja;
  const options = [...(p.options ?? [])].sort((a, b) => a.position - b.position).map((o) => o.name);
  const rawPhotos: string[] = p.raw_photos ?? [];
  const { data: signed } = rawPhotos.length
    ? await supabase.storage.from('monira-raw').createSignedUrls(rawPhotos, 900)
    : { data: [] };
  const { data: history } = await supabase
    .from('monira_product_decisions')
    .select('id, decision, note, created_at')
    .eq('product_id', id)
    .order('created_at', { ascending: false });

  const photos = rawPhotos.map((path) => ({ path, url: signed?.find((s) => s.path === path)?.signedUrl ?? '' }));

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/revisao" className={styles.back}>← Revisão</Link>
        <h1 className={styles.title}>Rever produto</h1>
        <p className={styles.subtitle}>{uja?.name} · {formatKz(Number(p.price_kz))}</p>
      </header>

      {p.attention_note && (
        <p className={styles.attention}>
          <strong>À espera de quem vende</strong>
          {p.attention_note}
        </p>
      )}

      <section className={styles.raw} aria-label="O que quem vende enviou">
        <span className={styles.eyebrow}>Enviado por quem vende</span>
        <p className={styles.rawName}>{p.raw_name}</p>
        {p.raw_description && <p className={styles.rawText}>{p.raw_description}</p>}
        {options.length > 0 && <p className={styles.rawMeta}>Opções: {options.join(', ')}</p>}
      </section>

      <ReviewForm
        productId={p.id}
        photos={photos}
        defaultName={p.name ?? p.raw_name ?? ''}
        defaultDescription={p.description ?? p.raw_description ?? ''}
        republish={p.admin_reviewed}
      />

      <EditorialActions productId={p.id} canDelete={!p.admin_reviewed} />

      {history && history.length > 0 && (
        <section className={styles.history} aria-label="Histórico">
          <h2 className={styles.label}>Histórico</h2>
          {history.map((h) => (
            <p key={h.id} className={styles.historyItem}>
              <time dateTime={h.created_at}>{formatDate(h.created_at)}</time>
              {DECISION_LABEL[h.decision as string] ?? h.decision}
              {h.note ? ` — ${h.note}` : ''}
            </p>
          ))}
        </section>
      )}
    </main>
  );
}
