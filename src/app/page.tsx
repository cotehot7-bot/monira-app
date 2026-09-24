import type { Metadata } from 'next';
import Link from 'next/link';
import { createClient } from '@/lib/db/server';
import { PUBLIC_PRODUCT_COLUMNS, type PublicProduct, isReady, photoUrl, formatKz } from '@/lib/public';
import styles from './inicio.module.css';

export const metadata: Metadata = {
  title: 'Monira',
  description: 'Descobre o que chegou à Monira.',
};

function greeting() {
  const hour = Number(
    new Intl.DateTimeFormat('pt-PT', { hour: 'numeric', hourCycle: 'h23', timeZone: 'Africa/Luanda' }).format(new Date()),
  );
  if (hour < 12) return 'Bom dia.';
  if (hour < 19) return 'Boa tarde.';
  return 'Boa noite.';
}

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

  const [{ data: rows }, { data: ujas }] = await Promise.all([
    query,
    supabase.from('monira_public_ujas').select('id, name, verified'),
  ]);

  const products = ((rows ?? []) as PublicProduct[]).filter(isReady);
  const ujaById = new Map((ujas ?? []).map((u) => [u.id, u]));

  return (
    <main className={styles.screen}>
      <header className={styles.top}>
        <Link href="/" className={styles.wordmark}>Monira</Link>
      </header>

      <section className={styles.intro}>
        <h1 className={styles.greeting}>
          {greeting()}
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
          <ul className={styles.grid}>
            {products.map((p) => {
              const uja = ujaById.get(p.uja_id);
              return (
                <li key={p.id}>
                  <Link href={`/produto/${p.id}`} className={styles.card}>
                    {/* eslint-disable-next-line @next/next/no-img-element -- fotografia já tratada pela Monira (JPEG ≤1600 px) */}
                    <img src={photoUrl(p.photos[0])} alt={p.name} loading="lazy" className={styles.photo} />
                    <span className={styles.name}>{p.name}</span>
                    <span className={styles.price}>{formatKz(p.price_kz)}</span>
                    {uja && (
                      <span className={styles.uja}>
                        {uja.name}
                        {uja.verified && (
                          <svg aria-label="Uja verificada" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#6b21a8" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                            <circle cx="12" cy="12" r="9" />
                            <path d="M8 12.5l2.7 2.5L16 9.5" />
                          </svg>
                        )}
                      </span>
                    )}
                    {!p.available && <span className={styles.soldOut}>Esgotado</span>}
                  </Link>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </main>
  );
}
