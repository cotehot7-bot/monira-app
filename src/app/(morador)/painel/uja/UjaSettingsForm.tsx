'use client';

import { useActionState, useState } from 'react';
import { saveUjaSettings, type SaveState } from './actions';
import styles from './uja.module.css';

export type UjaSettings = {
  is_open: boolean;
  pickup_enabled: boolean;
  pickup_address: string;
  pickup_reference: string;
  delivery_enabled: boolean;
  whatsapp: string;
  whatsapp_public: boolean;
  phone: string;
  calls_enabled: boolean;
  accepts_pay_on_delivery: boolean;
  accepts_pay_on_pickup: boolean;
};

type Zone = { key: string; name: string; fee: string };

function formatKz(digits: string) {
  return digits.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

function Toggle({ name, label, hint, defaultChecked }: { name: string; label: string; hint?: string; defaultChecked: boolean }) {
  return (
    <label className={styles.toggle}>
      <span className={styles.toggleText}>
        <span className={styles.toggleLabel}>{label}</span>
        {hint && <span className={styles.hint}>{hint}</span>}
      </span>
      <input type="checkbox" role="switch" name={name} defaultChecked={defaultChecked} className={styles.switch} />
    </label>
  );
}

export default function UjaSettingsForm({ ujaId, initial, zones: initialZones }: {
  ujaId: string;
  initial: UjaSettings;
  zones: { name: string; fee_kz: number }[];
}) {
  const [state, action, pending] = useActionState<SaveState, FormData>(saveUjaSettings.bind(null, ujaId), { status: 'idle' });
  const [zones, setZones] = useState<Zone[]>(
    initialZones.map((z) => ({ key: z.name, name: z.name, fee: formatKz(String(Math.round(z.fee_kz))) })),
  );

  return (
    <form action={action} className={styles.form}>
      <section className={styles.block} aria-labelledby="estado">
        <h2 id="estado" className={styles.blockTitle}>Estado</h2>
        <Toggle name="is_open" label="Uja aberta" hint="Fechada, os teus produtos continuam visíveis, mas fica claro que não estás a atender agora." defaultChecked={initial.is_open} />
      </section>

      <section className={styles.block} aria-labelledby="levantamento">
        <h2 id="levantamento" className={styles.blockTitle}>Levantamento</h2>
        <Toggle name="pickup_enabled" label="Permitir levantamento" hint="A morada só aparece aos clientes com isto ligado." defaultChecked={initial.pickup_enabled} />
        <div className={styles.field}>
          <label htmlFor="pickup_address" className={styles.label}>Morada</label>
          <input id="pickup_address" name="pickup_address" defaultValue={initial.pickup_address} maxLength={200} className={styles.input} />
        </div>
        <div className={styles.field}>
          <label htmlFor="pickup_reference" className={styles.label}>Referência (opcional)</label>
          <input id="pickup_reference" name="pickup_reference" defaultValue={initial.pickup_reference} maxLength={200} placeholder="Ex.: ao lado da farmácia" className={styles.input} />
        </div>
        <Toggle name="accepts_pay_on_pickup" label="Aceita pagamento no levantamento" hint="O cliente faz o pedido na Monira e paga quando levanta." defaultChecked={initial.accepts_pay_on_pickup} />
      </section>

      <section className={styles.block} aria-labelledby="entrega">
        <h2 id="entrega" className={styles.blockTitle}>Entrega</h2>
        <Toggle name="delivery_enabled" label="Permitir entrega" defaultChecked={initial.delivery_enabled} />
        <Toggle name="accepts_pay_on_delivery" label="Aceita pagamento na entrega" hint="O cliente faz o pedido na Monira e paga quando recebe." defaultChecked={initial.accepts_pay_on_delivery} />
        <ul className={styles.zones}>
          {zones.map((z, i) => (
            <li key={z.key} className={styles.zone}>
              <label className={styles.srOnly} htmlFor={`zone-name-${z.key}`}>Zona</label>
              <input
                id={`zone-name-${z.key}`}
                name="zone_name"
                value={z.name}
                maxLength={60}
                placeholder="Zona"
                onChange={(e) => setZones(zones.map((x, j) => (j === i ? { ...x, name: e.target.value } : x)))}
                className={styles.input}
              />
              <div className={styles.feeBox}>
                <label className={styles.srOnly} htmlFor={`zone-fee-${z.key}`}>Preço de entrega</label>
                <input
                  id={`zone-fee-${z.key}`}
                  name="zone_fee"
                  inputMode="numeric"
                  value={z.fee}
                  placeholder="0"
                  onChange={(e) => setZones(zones.map((x, j) => (j === i ? { ...x, fee: formatKz(e.target.value.replace(/\D/g, '').slice(0, 10)) } : x)))}
                  className={styles.feeInput}
                />
                <span className={styles.unit}>Kz</span>
              </div>
              <button type="button" aria-label={`Retirar ${z.name || 'zona'}`} className={styles.remove} onClick={() => setZones(zones.filter((_, j) => j !== i))}>×</button>
            </li>
          ))}
        </ul>
        {zones.length < 30 && (
          <button type="button" className={styles.addZone} onClick={() => setZones([...zones, { key: crypto.randomUUID(), name: '', fee: '' }])}>
            + Adicionar zona
          </button>
        )}
      </section>

      <section className={styles.block} aria-labelledby="contactos">
        <h2 id="contactos" className={styles.blockTitle}>Contactos</h2>
        <div className={styles.field}>
          <label htmlFor="whatsapp" className={styles.label}>WhatsApp</label>
          <input id="whatsapp" name="whatsapp" type="tel" defaultValue={initial.whatsapp} placeholder="+244 9XX XXX XXX" className={styles.input} />
        </div>
        <Toggle name="whatsapp_public" label="Mostrar WhatsApp na Uja" hint="Aparece aos clientes dentro da Conversa." defaultChecked={initial.whatsapp_public} />
        <div className={styles.field}>
          <label htmlFor="phone" className={styles.label}>Telefone</label>
          <input id="phone" name="phone" type="tel" defaultValue={initial.phone} placeholder="+244 9XX XXX XXX" className={styles.input} />
        </div>
        <Toggle name="calls_enabled" label="Permitir chamadas" defaultChecked={initial.calls_enabled} />
      </section>

      <div className={styles.footer}>
        {state.status === 'error' && <p className={styles.error} role="alert">{state.message}</p>}
        {state.status === 'saved' && <p className={styles.saved} role="status">Guardado.</p>}
        <button type="submit" className={styles.primary} disabled={pending}>{pending ? 'A guardar…' : 'Guardar'}</button>
      </div>
    </form>
  );
}
