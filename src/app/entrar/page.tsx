import type { Metadata } from 'next';
import EntrarForm from './EntrarForm';
import styles from './page.module.css';

export const metadata: Metadata = { title: 'Entrar · Monira' };

// Só aceita destinos internos (evita redireccionar para outro site).
function safeNext(value: string | string[] | undefined) {
  const next = Array.isArray(value) ? value[0] : value;
  return next && next.startsWith('/') && !next.startsWith('//') ? next : '/painel/produtos/novo';
}

export default async function EntrarPage(props: PageProps<'/entrar'>) {
  const searchParams = await props.searchParams;
  return (
    <main className={styles.screen}>
      <h1 className={styles.title}>Entrar</h1>
      <EntrarForm next={safeNext(searchParams.next)} linkFailed={searchParams.erro === 'link'} />
    </main>
  );
}
