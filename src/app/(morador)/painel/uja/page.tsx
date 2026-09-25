import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { getMyUja } from '@/lib/db/seller';
import UjaSettingsForm from './UjaSettingsForm';
import styles from './uja.module.css';

export const metadata: Metadata = { title: 'Minha Uja · Monira' };

// Funcionamento da Uja. A apresentação (nome, selo, Avenida, imagem, logo, descrição) é da Monira.
export default async function MinhaUjaPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/entrar?next=/painel/uja');

  const mine = await getMyUja(supabase, user.id);
  if (!mine) redirect('/painel');

  const [{ data: uja }, { data: zones }] = await Promise.all([
    supabase
      .from('monira_ujas')
      .select('is_open, pickup_enabled, pickup_address, pickup_reference, delivery_enabled, whatsapp, whatsapp_public, phone, calls_enabled')
      .eq('id', mine.id)
      .single(),
    supabase.from('monira_uja_delivery_zones').select('name, fee_kz').eq('uja_id', mine.id).eq('active', true).order('position'),
  ]);
  if (!uja) redirect('/painel');

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/painel" className={styles.back}>← Painel</Link>
        <h1 className={styles.title}>Minha Uja</h1>
        <p className={styles.subtitle}>
          {mine.name} · <Link href={`/uja/${mine.slug}`}>Ver como os clientes a vêem</Link>
        </p>
      </header>
      <UjaSettingsForm
        ujaId={mine.id}
        initial={{
          is_open: uja.is_open,
          pickup_enabled: uja.pickup_enabled,
          pickup_address: uja.pickup_address ?? '',
          pickup_reference: uja.pickup_reference ?? '',
          delivery_enabled: uja.delivery_enabled,
          whatsapp: uja.whatsapp ?? '',
          whatsapp_public: uja.whatsapp_public,
          phone: uja.phone ?? '',
          calls_enabled: uja.calls_enabled,
        }}
        zones={(zones ?? []).map((z) => ({ name: z.name as string, fee_kz: Number(z.fee_kz) }))}
      />
    </main>
  );
}
