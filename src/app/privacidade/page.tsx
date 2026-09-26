import type { Metadata } from 'next';
import Link from 'next/link';
import styles from './privacidade.module.css';

export const metadata: Metadata = { title: 'Privacidade · Monira' };

// RASCUNHO para o teste controlado. Descreve o que o sistema faz hoje.
// A versão jurídica completa é revista antes da abertura pública.
const CONTACT = 'monira.entrar@gmail.com';

export default function PrivacidadePage() {
  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href="/" className={styles.back}>← Início</Link>
        <h1 className={styles.title}>Privacidade</h1>
        <p className={styles.lead}>A Monira está em teste. Explicamos aqui, de forma simples, que dados guardamos e porquê.</p>
      </header>

      <section className={styles.section}>
        <h2>Que dados guardamos</h2>
        <ul>
          <li>O teu email, para entrares na Monira.</li>
          <li>Quando fazes um pedido: o teu telefone e a morada de entrega.</li>
          <li>As mensagens que trocas numa Conversa.</li>
          <li>Se vendes na Monira: o nome do negócio, os contactos, a morada de levantamento e as fotografias dos produtos.</li>
        </ul>
      </section>

      <section className={styles.section}>
        <h2>Para quê</h2>
        <p>Para a Monira funcionar: entrar, conversar, fazer e entregar pedidos, e avisar-te por email quando há algo novo. Não vendemos os teus dados nem os usamos para publicidade.</p>
      </section>

      <section className={styles.section}>
        <h2>Quem vê o quê</h2>
        <ul>
          <li><strong>A loja a quem compras</strong> recebe o teu telefone, a morada de entrega e os detalhes do pedido, para o poder entregar.</li>
          <li><strong>As conversas</strong> são entre ti e a loja. Hoje, a equipa da Monira não as lê. Se isso mudar, avisamos antes.</li>
          <li><strong>A equipa da Monira</strong> vê os produtos e os pedidos para vender, para os rever.</li>
        </ul>
      </section>

      <section className={styles.section}>
        <h2>Onde ficam</h2>
        <p>Os dados ficam guardados em servidores na Europa (Londres). Os emails de aviso são enviados a partir de uma conta de email da Monira.</p>
      </section>

      <section className={styles.section}>
        <h2>Apagar os teus dados</h2>
        <p>Podes pedir para ver, corrigir ou apagar os teus dados. Escreve para <a href={`mailto:${CONTACT}`}>{CONTACT}</a> a partir do email com que entras na Monira.</p>
      </section>

      <p className={styles.meta}>Versão de teste · Setembro de 2026</p>
    </main>
  );
}
