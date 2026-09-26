import type { Metadata } from 'next';
import Link from 'next/link';
import styles from './privacidade.module.css';

export const metadata: Metadata = { title: 'Privacidade · Monira' };

// Texto de Carlos. O contacto está numa constante para poder ser trocado sem mexer no texto.
const CONTACT = 'privacidade@monira.ao';

export default function PrivacidadePage() {
  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/" className={styles.back}>← Início</Link>
        <h1 className={styles.title}>Privacidade</h1>
        <p className={styles.lead}>Os teus dados são teus. A Monira só os usa para o que pediste.</p>
      </header>

      <section className={styles.section}>
        <h2>O que guardamos</h2>
        <h3>Se compras na Monira:</h3>
        <ul>
          <li>Email — para entrares na plataforma</li>
          <li>Telefone e morada de entrega — só quando fazes um pedido</li>
          <li>Mensagens trocadas numa Conversa</li>
        </ul>
        <h3>Se vendes na Monira:</h3>
        <ul>
          <li>Nome do negócio, contactos e morada de levantamento</li>
          <li>Fotografias dos produtos</li>
        </ul>
      </section>

      <section className={styles.section}>
        <h2>Para quê</h2>
        <p>Para a Monira funcionar: entrar, conversar, fazer e receber pedidos, e avisar-te quando há novidades.</p>
        <p>Não vendemos os teus dados. Não os usamos para publicidade. Nunca.</p>
      </section>

      <section className={styles.section}>
        <h2>Quem vê o quê</h2>
        <div className={styles.tableWrap}>
          <table className={styles.table}>
            <thead>
              <tr><th scope="col">Quem</th><th scope="col">O quê</th></tr>
            </thead>
            <tbody>
              <tr><td>A loja onde compras</td><td>Telefone, morada de entrega e detalhes do pedido — para te entregar</td></tr>
              <tr><td>Tu e a loja</td><td>As mensagens da Conversa — mais ninguém</td></tr>
              <tr><td>Equipa Monira</td><td>Produtos e pedidos, para garantir que tudo corre bem</td></tr>
              <tr><td>Parceiros técnicos</td><td>Acesso limitado ao mínimo necessário para o serviço funcionar</td></tr>
            </tbody>
          </table>
        </div>
      </section>

      <section className={styles.section}>
        <h2>Onde ficam os dados</h2>
        <p>Em servidores fora de Angola, protegidos pela legislação europeia de protecção de dados. Isso significa que existem regras legais sobre como os teus dados podem ser usados — e nós cumprimo-las.</p>
      </section>

      <section className={styles.section}>
        <h2>A Monira está em teste</h2>
        <p>Isso não muda a forma como tratamos os teus dados. As mesmas regras desta página aplicam-se desde o primeiro dia. Se alguma coisa mudar, avisamos antes — não depois.</p>
        <p>Se a Monira encerrar, apagamos os teus dados.</p>
      </section>

      <section className={styles.section}>
        <h2>Os teus direitos</h2>
        <p>Podes pedir para ver, corrigir ou apagar os teus dados a qualquer momento. Respondemos em até 5 dias úteis.</p>
        <p>Escreve para <a href={`mailto:${CONTACT}`}>{CONTACT}</a></p>
      </section>

      <p className={styles.meta}><em>Última actualização: Setembro 2026</em></p>
    </main>
  );
}
