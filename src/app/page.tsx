import type { Metadata } from 'next';
import Link from 'next/link';
import { createClient } from '@/lib/db/server';
import { PUBLIC_PRODUCT_COLUMNS, type PublicProduct, isReady } from '@/lib/public';
import ProductGrid from './_components/ProductGrid';
import { greeting } from '@/lib/greeting';
import styles from './inicio.module.css';

export const metadata: Metadata = {
  title: 'Monira',
  description: 'Descobre o que chegou à Monira.',
};

// Escapa os caracteres especiais do ILIKE e do filtro do PostgREST.
function searchPattern(q: string) {
  return `%${q.replace(/[\\%_]/g, (c) => `\\${c}`).replace(/[,()"]/g, ' ')}%`;
}

export default async function Inicio(props: PageProps<'/'>) {
  const searchParams = await props.searchParams;
  const rawQ = Array.isArray(searchParams.q) ? searchParams.q[0] : searchParams.q;
  const q = (rawQ ?? '').trim().slice(0, 80);

  const supabase = await createClient();

  let query = supabase
    .from('monira_public_products')
    .select(PUBLIC_PRODUCT_COLUMNS)
    .order('created_at', { ascending: false })
    .limit(24);
  if (q) {
    const pattern = searchPattern(q);
    query = query.or(`name.ilike.${pattern},description.ilike.${pattern}`);
  }

  const [{ data: rows }, { data: ujas }, { data: auth }] = await Promise.all([
    query,
    supabase.from('monira_public_ujas').select('id, name, verified'),
    supabase.auth.getUser(),
  ]);

  const products = ((rows ?? []) as PublicProduct[]).filter(isReady);
  const ujaById = new Map((ujas ?? []).map((u) => [u.id, u]));

  return (
    <main className={styles.screen}>
      <header className={styles.top}>
        <Link href="/" className={styles.wordmark}>Monira</Link>
        {auth.user && (
          <nav className={styles.topNav} aria-label="A minha conta">
            <Link href="/pedidos" className={styles.topLink}>Pedidos</Link>
            <Link href="/conversas" className={styles.topLink}>Conversas</Link>
          </nav>
        )}
      </header>

      <section className={styles.intro}>
        <h1 className={styles.greeting}>
          {greeting()}.
          <br />
          Descobre o que chegou à Monira.
        </h1>

        <form action="/" method="get" role="search" className={styles.search}>
          <label htmlFor="q" className={styles.srOnly}>Pesquisar na Monira</label>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#6b6b6b" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true">
            <circle cx="11" cy="11" r="7" />
            <path d="M20 20l-3.5-3.5" />
          </svg>
          <input id="q" name="q" type="search" defaultValue={q} placeholder="Pesquisar na Monira" className={styles.searchInput} />
        </form>
      </section>

      <section className={styles.section} aria-labelledby="lista">
        <h2 id="lista" className={styles.sectionTitle}>{q ? `Resultados para “${q}”` : 'Hoje'}</h2>

        {products.length === 0 ? (
          <p className={styles.empty}>{q ? 'Nada encontrado.' : 'Ainda não há nada por aqui.'}</p>
        ) : (
          <ProductGrid products={products} ujaById={ujaById} />
        )}
      </section>

      <footer className={styles.footer}>
        <Link href="/vender">Vender na Monira</Link>
        <Link href="/privacidade">Privacidade</Link>
      </footer>
    </main>
  );
}
