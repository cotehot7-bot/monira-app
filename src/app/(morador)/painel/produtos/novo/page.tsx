import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import Link from 'next/link';
import { getMyUja } from '@/lib/db/seller';
import AddProductForm from './AddProductForm';
import styles from './page.module.css';

export const metadata: Metadata = { title: 'Adicionar produto · Monira' };

export default async function AddProductPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/entrar?next=/painel/produtos/novo');

  const uja = await getMyUja(supabase, user.id);
  if (!uja) redirect('/vender');

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/painel" className={styles.back}>← Painel</Link>
        <h1 className={styles.title}>Adicionar produto</h1>
        {uja && <p className={styles.subtitle}>{uja.name}</p>}
      </header>
      {uja ? (
        <AddProductForm ujaId={uja.id} />
      ) : (
        <p className={styles.empty}>A tua Uja ainda está a ser preparada.</p>
      )}
    </main>
  );
}
