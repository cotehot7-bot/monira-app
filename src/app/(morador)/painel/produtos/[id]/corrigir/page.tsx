import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { getMyUja } from '@/lib/db/seller';
import AddProductForm from '../../novo/AddProductForm';
import styles from '../../novo/page.module.css';

export const metadata: Metadata = { title: 'Corrigir produto · Monira' };

export default async function CorrigirPage(props: PageProps<'/painel/produtos/[id]/corrigir'>) {
  const { id } = await props.params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?next=/painel/produtos/${id}/corrigir`);

  const uja = await getMyUja(supabase, user.id);
  if (!uja) redirect('/painel');

  // Só produtos da própria Uja com um pedido da Monira por responder.
  const { data: p } = await supabase
    .from('monira_products')
    .select('id, raw_name, raw_description, raw_photos, price_kz, attention_note, options:monira_product_options(name, position)')
    .eq('id', id)
    .eq('uja_id', uja.id)
    .maybeSingle();
  if (!p || !p.attention_note) redirect('/painel');

  const rawPhotos: string[] = p.raw_photos ?? [];
  const { data: signed } = rawPhotos.length
    ? await supabase.storage.from('monira-raw').createSignedUrls(rawPhotos, 1800)
    : { data: [] };
  const photos = rawPhotos
    .map((path) => ({ path, url: signed?.find((s) => s.path === path)?.signedUrl ?? '' }))
    .filter((ph) => ph.url);
  const options = [...(p.options ?? [])].sort((a, b) => a.position - b.position).map((o) => o.name as string);

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/painel" className={styles.back}>← Painel</Link>
        <h1 className={styles.title}>Corrigir produto</h1>
        <p className={styles.subtitle}>{uja.name}</p>
      </header>

      <p className={styles.attention}>
        <strong>A Monira pediu</strong>
        {p.attention_note}
      </p>

      <AddProductForm
        ujaId={uja.id}
        edit={{
          productId: p.id,
          name: p.raw_name ?? '',
          price: Number(p.price_kz),
          description: p.raw_description ?? '',
          options,
          photos,
        }}
      />
    </main>
  );
}
